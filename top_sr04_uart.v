`timescale 1ns / 1ps

// SR04 subsystem integration; buttons are already debounced one-clock pulses.
// Shared FND and Watch/DHT integration are outside this standalone top.
module top_sr04_uart #(
    parameter CLK_FREQ=100_000_000,
    parameter BAUD_RATE=9600
) (
    input clk, rst,
    input uart_rxd,
    output uart_txd,
    input btn_run_stop, btn_clear, btn_mode, btn_lap,
    input [1:0] sw_mode,
    input display_mode,
    input echo,
    output trig,
    output [15:0] data,
    output rx_busy,
    output tx_queue_full,
    output tx_overflow
);
    wire r_pulse, sw_req, sw_accept;
    wire [47:0] comm;
    wire comm_valid;
    wire [239:0] sw_msg;
    wire [5:0] sw_len;
    uart_comm #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) U_UART (
        .clk(clk), .rst(rst), .uart_rxd(uart_rxd), .uart_txd(uart_txd),
        .dht_req(1'b0), .dht_msg(240'b0), .dht_len(5'b0), .dht_accept(),
        .sw_req(sw_req), .sw_msg(sw_msg), .sw_len(sw_len), .sw_accept(sw_accept),
        .rx_busy(rx_busy), .comm(comm), .comm_valid(comm_valid), .r_pulse()
    );
    sr04_command_adapter U_COMMAND_ADAPTER (
        .clk(clk), .rst(rst), .comm(comm), .comm_valid(comm_valid),
        .r_pulse(r_pulse)
    );
    sr04_stopwatch U_SR04_STOPWATCH (
        .clk(clk), .rst(rst), .r_pulse(r_pulse),
        .btn_run_stop(btn_run_stop), .btn_clear(btn_clear),
        .btn_mode(btn_mode), .btn_lap(btn_lap),
        .sw_mode(sw_mode), .display_mode(display_mode),
        .echo(echo), .trig(trig), .data(data),
        .rx_busy(rx_busy), .sw_accept(sw_accept),
        .sw_req(sw_req), .sw_msg(sw_msg), .sw_len(sw_len),
        .tx_queue_full(tx_queue_full), .tx_overflow(tx_overflow),
        .result_valid(), .uart_msec(), .uart_sec(), .uart_min(), .uart_hour(),
        .uart_distance(), .result_msec(), .result_sec(), .result_min(),
        .result_hour(), .result_distance(),
        .message(), .message_len(), .message_valid()
    );
endmodule
