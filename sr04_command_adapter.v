`timescale 1ns / 1ps

// SR04-owned adapter; shared UART remains unmodified.
// The original UART only publishes recognized complete line commands.
module sr04_command_adapter (
    input clk,
    input rst,
    input [47:0] comm,
    input comm_valid,
    output reg r_pulse
);
    localparam [47:0] CMD_SW = {"ss_r",8'h0d,8'h0a};
    always @(posedge clk or posedge rst) begin
        if (rst) r_pulse <= 0;
        else r_pulse <= comm_valid && (comm == CMD_SW);
    end
endmodule
