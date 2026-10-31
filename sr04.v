`timescale 1ns / 1ps
module top_sr04 (
    input clk,
    input rst,
    input sr04_start,
    input echo,

    output trig,
    output [8:0] distance,
    output distance_valid,
    output busy
);

    wire w_us_tick;

    tick_gen_us U_TICK_GEN_US (
        .clk(clk),
        .rst(rst),
        .us_tick(w_us_tick)
    );

    sr04_controller U_SR04_CONTROLLER (
        .clk(clk),
        .rst(rst),
        .sr04_start(sr04_start),
        .echo(echo),
        .us_tick(w_us_tick),
        .trig(trig),
        .distance(distance),
        .distance_valid(distance_valid),
        .busy(busy)
    );

endmodule

module sr04_controller (
    input            clk,
    input            rst,
    input            sr04_start,
    input            echo,
    input            us_tick,
    output           trig,
    output     [8:0] distance,
    output           busy,
    output reg       distance_valid
);

    localparam IDLE = 0, START = 1, WAIT = 2, DISTANCE = 3, STOP = 4;
    localparam WAIT_TIMEOUT = 30_000;  // 30ms
    reg [2:0] c_state, n_state;
    reg [15:0] tick_cnt_reg, tick_cnt_next;
    reg [8:0] distance_reg, distance_next;
    reg trig_reg, trig_next;

    assign distance = distance_reg;
    assign trig = trig_reg;
    assign busy = (c_state != IDLE);

    // state register
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state        <= IDLE;
            tick_cnt_reg   <= 0;
            distance_reg   <= 0;
            trig_reg       <= 0;
            distance_valid <= 0;
        end else begin
            c_state <= n_state;
            tick_cnt_reg <= tick_cnt_next;
            distance_reg <= distance_next;
            trig_reg <= trig_next;

            distance_valid <= us_tick &&
            (
                (c_state == DISTANCE &&
                (!echo || tick_cnt_reg >= 36_000 - 1))
                ||
                (c_state == WAIT &&
                !echo && tick_cnt_reg >= WAIT_TIMEOUT - 1)
            );
        end
    end

    //next
    always @(*) begin
        n_state = c_state;
        tick_cnt_next = tick_cnt_reg;
        distance_next = distance_reg;
        trig_next = trig_reg;
        case (c_state)
            IDLE: begin
                trig_next = 0;
                if (sr04_start) begin
                    distance_next = 0;
                    tick_cnt_next = 0;
                    n_state = START;
                end
            end
            START: begin
                trig_next = 1'b1;
                if (us_tick) begin
                    if (tick_cnt_reg == 9) begin
                        tick_cnt_next = 0;
                        n_state = WAIT;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end
            WAIT: begin
                trig_next = 1'b0;

                if (us_tick) begin
                    if (echo) begin
                        tick_cnt_next = 0;
                        n_state = DISTANCE;
                    end else if (tick_cnt_reg >= WAIT_TIMEOUT - 1) begin
                        distance_next = 400;
                        tick_cnt_next = 0;
                        n_state = STOP;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end
            DISTANCE: begin
                if (us_tick) begin
                    if (!echo) begin
                        distance_next = tick_cnt_reg / 58;
                        tick_cnt_next = 0;
                        n_state = STOP;
                    end else if (tick_cnt_reg >= 36_000 - 1) begin
                        distance_next = 400;
                        tick_cnt_next = 0;
                        n_state = STOP;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                if (us_tick) begin
                    if (tick_cnt_reg >= 10_000) begin
                        n_state = IDLE;
                    end else begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end



endmodule

module tick_gen_us (
    input clk,
    input rst,
    output reg us_tick
);
    parameter FREQ = 100_000_000 / 1_000_000;
    reg [$clog2(FREQ)-1:0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            us_tick     <= 0;
        end else begin
            counter_reg <= counter_reg + 1;

            if (counter_reg == (FREQ - 1)) begin
                counter_reg <= 0;
                us_tick <= 1'b1;
            end else begin
                us_tick <= 1'b0;
            end
        end
    end

endmodule
