`timescale 1ns / 1ps

// v0.3.0: ASCII generation only; req/accept and buffering are a later stage.
// First byte is message[239:232]; unused trailing bytes are zero.
module sr04_message_formatter (
    input clk,
    input rst,
    input start_valid,
    input result_valid,
    input [6:0] result_msec,
    input [5:0] result_sec,
    input [5:0] result_min,
    input [4:0] result_hour,
    input [8:0] result_distance,
    output reg [239:0] message,
    output reg [5:0] message_len,
    output reg message_valid
);
    function [7:0] digit;
        input [8:0] value;
        begin
            digit = 8'h30 + (value % 10);
        end
    endfunction

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            message <= 0;
            message_len <= 0;
            message_valid <= 0;
        end else begin
            message_valid <= 0;
            // Stop has priority if both events are supplied to this module.
            if (result_valid) begin
                // 24 bytes: stop_DDDcm_hh:mm:ss.cc\r\n
                message <= {
                    "stop_",
                    digit(result_distance / 100),
                    digit(result_distance / 10),
                    digit(result_distance),
                    "cm_",
                    digit(result_hour / 10), digit({4'b0,result_hour}),
                    ":", digit(result_min / 10), digit({3'b0,result_min}),
                    ":", digit(result_sec / 10), digit({3'b0,result_sec}),
                    ".", digit(result_msec / 10), digit({2'b0,result_msec}),
                    8'h0d, 8'h0a,
                    48'b0
                };
                message_len <= 6'd24;
                message_valid <= 1;
            end else if (start_valid) begin
                // 17 bytes, padded to the 30-byte bus width.
                message <= {"start_stopwatch", 8'h0d, 8'h0a, 104'b0};
                message_len <= 6'd17;
                message_valid <= 1;
            end
        end
    end
endmodule
