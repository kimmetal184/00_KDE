`timescale 1ns / 1ps

module sr04_stopwatch (
    input clk,
    input rst,
    // Debounced, one-clock button pulses (not raw board pins).
    input btn_run_stop,
    input btn_clear,
    input btn_mode,
    input btn_lap,
    // Decoded UART command pulses: sr_r / sr_s.
    input uart_start,
    input uart_stop,
    input [1:0] sw_mode,
    input display_mode,
    input echo,
    output trig,
    output [15:0] data,
    output reg result_valid,
    output [6:0] uart_msec,
    output [5:0] uart_sec,
    output [5:0] uart_min,
    output [4:0] uart_hour,
    output [8:0] uart_distance,
    // Frozen result: updated together with result_valid, retained until next result.
    output reg [6:0] result_msec,
    output reg [5:0] result_sec,
    output reg [5:0] result_min,
    output reg [4:0] result_hour,
    output reg [8:0] result_distance,
    // ASCII preview, not yet the UART req/accept interface.
    output [239:0] message,
    output [5:0] message_len,
    output message_valid
);
    reg fpga_run, fpga_mode;
    reg uart_run;
    reg start_valid;
    wire uart_clear = uart_start && !uart_stop;
    wire [6:0] fpga_msec, display_msec;
    wire [5:0] fpga_sec, fpga_min, display_sec, display_min;
    wire [4:0] fpga_hour, display_hour;
    wire [8:0] measured_distance;
    wire distance_valid, sr04_busy;
    reg sr04_start;
    reg [8:0] distance_hold;

    // FPGA controls affect only the FPGA stopwatch.
    // Clear resets the count/lap but preserves run and direction states.
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fpga_run <= 0;
            fpga_mode <= 0;
        end else begin
            if (btn_run_stop) fpga_run <= ~fpga_run;
            if (btn_mode) fpga_mode <= ~fpga_mode;
        end
    end

    // Snapshot the visible time at the clock accepting stop.
    // Start+stop gives stop priority; a repeated idle stop creates no result.
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            uart_run <= 0;
            start_valid <= 0;
            result_valid <= 0;
            result_msec <= 0;
            result_sec <= 0;
            result_min <= 0;
            result_hour <= 0;
            result_distance <= 0;
        end else begin
            start_valid <= uart_clear;
            result_valid <= uart_stop && uart_run;
            if (uart_stop)
                uart_run <= 0;
            else if (uart_start)
                uart_run <= 1;

            if (uart_stop && uart_run) begin
                result_msec <= uart_msec;
                result_sec <= uart_sec;
                result_min <= uart_min;
                result_hour <= uart_hour;
                result_distance <= distance_valid ? measured_distance : distance_hold;
            end
        end
    end

    sr04_message_formatter U_MESSAGE_FORMATTER (
        .clk(clk), .rst(rst), .start_valid(start_valid),
        .result_valid(result_valid), .result_msec(result_msec),
        .result_sec(result_sec), .result_min(result_min),
        .result_hour(result_hour), .result_distance(result_distance),
        .message(message), .message_len(message_len),
        .message_valid(message_valid)
    );

    stopwatch_datapath U_FPGA_STOPWATCH (
        .clk(clk), .rst(rst), .run_stop(fpga_run),
        .clear(btn_clear), .mode(fpga_mode),
        .msec(fpga_msec), .sec(fpga_sec),
        .min(fpga_min), .hour(fpga_hour)
    );

    lap_controller U_FPGA_LAP (
        .clk(clk), .rst(rst), .i_lap(btn_lap), .i_clear(btn_clear),
        .i_msec(fpga_msec), .i_sec(fpga_sec),
        .i_min(fpga_min), .i_hour(fpga_hour),
        .o_msec(display_msec), .o_sec(display_sec),
        .o_min(display_min), .o_hour(display_hour)
    );

    stopwatch_datapath U_UART_STOPWATCH (
        .clk(clk), .rst(rst), .run_stop(uart_run),
        .clear(uart_clear), .mode(1'b0),
        .msec(uart_msec), .sec(uart_sec),
        .min(uart_min), .hour(uart_hour)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) sr04_start <= 0;
        else begin
            sr04_start <= 0;
            if (uart_run && !uart_start && !uart_stop &&
                !sr04_busy && !sr04_start)
                sr04_start <= 1;
        end
    end

    top_sr04 U_TOP_SR04 (
        .clk(clk), .rst(rst), .sr04_start(sr04_start), .echo(echo),
        .trig(trig), .distance(measured_distance),
        .distance_valid(distance_valid), .busy(sr04_busy)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) distance_hold <= 0;
        else if (uart_clear) distance_hold <= 0;
        else if (uart_run && distance_valid)
            distance_hold <= measured_distance;
    end
    assign uart_distance = distance_hold;

    // Provisional four-digit packed BCD for the shared FND controller.
    // Must match the team's eventual FND interface.
    function [7:0] bcd2;
        input [6:0] value;
        begin
            bcd2[7:4] = value / 10;
            bcd2[3:0] = value % 10;
        end
    endfunction
    wire [15:0] time_bcd;
    wire [15:0] distance_bcd;
    assign time_bcd = display_mode ?
        {bcd2({2'b0, display_hour}), bcd2({1'b0, display_min})} :
        {bcd2({1'b0, display_sec}), bcd2(display_msec)};
    assign distance_bcd[15:12] = 4'd0;
    assign distance_bcd[11:8] = distance_hold / 100;
    assign distance_bcd[7:4] = (distance_hold / 10) % 10;
    assign distance_bcd[3:0] = distance_hold % 10;
    assign data = (sw_mode == 2'b10) ? distance_bcd : time_bcd;
endmodule
