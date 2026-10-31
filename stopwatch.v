`timescale 1ns / 1ps

module stopwatch (
    input clk,
    input rst,
    input btnR,
    input btnL,
    input btnU,
    input btnD,  // lap 버튼 추가
    input sw_display_mode,
    output [3:0] fnd_com,
    output [7:0] fnd_font
);
    parameter MSEC_BIT_WIDTH = 7;
    parameter SEC_BIT_WIDTH = 6;
    parameter MIN_BIT_WIDTH = 6;
    parameter HOUR_BIT_WIDTH = 5;

    wire w_btn_run_stop, w_run_stop;
    wire w_btn_clear, w_clear;
    wire w_btn_mode, w_mode;
    wire [MSEC_BIT_WIDTH-1:0] w_msec;
    wire [SEC_BIT_WIDTH-1:0] w_sec;
    wire [MIN_BIT_WIDTH-1:0] w_min;
    wire [HOUR_BIT_WIDTH-1:0] w_hour;
    wire w_btn_lap;
    wire [MSEC_BIT_WIDTH-1:0] w_display_msec;
    wire [SEC_BIT_WIDTH-1:0] w_display_sec;
    wire [MIN_BIT_WIDTH-1:0] w_display_min;
    wire [HOUR_BIT_WIDTH-1:0] w_display_hour;


    btn_debounce U_BD_LAP (
        .clk  (clk),
        .reset(rst),
        .i_btn(btnD),
        .o_btn(w_btn_lap)
    );

    btn_debounce U_BD_RUN_STOP (
        .clk  (clk),
        .reset(rst),
        .i_btn(btnR),
        .o_btn(w_btn_run_stop)
    );

    btn_debounce U_BD_CLEAR (
        .clk  (clk),
        .reset(rst),
        .i_btn(btnL),
        .o_btn(w_btn_clear)
    );

    btn_debounce U_BD_MODE (
        .clk  (clk),
        .reset(rst),
        .i_btn(btnU),
        .o_btn(w_btn_mode)
    );

    control_unit U_STOPWATCH_CONTROL_UNIT (
        .clk(clk),
        .reset(rst),
        .btn_run_stop(w_btn_run_stop),
        .btn_clear(w_btn_clear),
        .btn_mode(w_btn_mode),
        .run_stop(w_run_stop),
        .clear(w_clear),
        .mode(w_mode)
    );

    // stop watch datapath
    stopwatch_datapath U_STOPWATCH_DATAPATH (

        .clk(clk),
        .rst(rst),
        .run_stop(w_run_stop),
        .clear(w_clear),
        .mode(1'b0),
        .msec(w_msec),
        .sec(w_sec),
        .min(w_min),
        .hour(w_hour)
    );
    //fnd display controller
    fnd_controller U_FUN_CTRL (
        .clk(clk),
        .rst(rst),
        .sw_display_mode(sw_display_mode),
        .blink_sel(3'b000),  //추가
        .msec(w_display_msec),
        .sec(w_display_sec),
        .min(w_display_min),
        .hour(w_display_hour),
        .fnd_com(fnd_com),
        .fnd_font(fnd_font)
    );

    lap_controller #(
        .MSEC_BIT_WIDTH(MSEC_BIT_WIDTH),
        .SEC_BIT_WIDTH (SEC_BIT_WIDTH),
        .MIN_BIT_WIDTH (MIN_BIT_WIDTH),
        .HOUR_BIT_WIDTH(HOUR_BIT_WIDTH)
    ) U_LAP (
        .clk(clk),
        .rst(rst),
        .i_lap(w_btn_lap),
        .i_clear(w_clear),

        .i_msec(w_msec),
        .i_sec (w_sec),
        .i_min (w_min),
        .i_hour(w_hour),

        .o_msec(w_display_msec),
        .o_sec (w_display_sec),
        .o_min (w_display_min),
        .o_hour(w_display_hour)
    );


    // wire [1:0] w_ds_sel;
    // wire w_clk_800hz;
    // wire [3:0] w_msec_ds1, w_msec_ds10, w_sec_ds1, w_sec_ds10;
    // wire [3:0] w_min_ds1, w_min_ds10, w_hour_ds1, w_hour_ds10;
    // wire [3:0] w_mux_out, w_msec_sec_mux_out, w_min_hour_mux_out;
    //msec, sec, min, hour
    // clk_div_800hz U_CLK_DIV_800HZ (
    //     .clk(clk),
    //     .reset(reset),
    //     .o_clk_800hz(w_clk_800hz)
    // );
endmodule

module stopwatch_datapath #(
    parameter MSEC_BIT_WIDTH = 7,
    parameter SEC_BIT_WIDTH  = 6,
    parameter MIN_BIT_WIDTH  = 6,
    parameter HOUR_BIT_WIDTH = 5
) (
    input clk,
    input rst,
    input run_stop,
    input clear,
    input mode,
    output [MSEC_BIT_WIDTH-1:0] msec,
    output [SEC_BIT_WIDTH-1:0] sec,
    output [MIN_BIT_WIDTH-1:0] min,
    output [HOUR_BIT_WIDTH-1:0] hour
);
    wire w_tick_10ms;
    wire w_tick_sec;
    wire w_tick_min;
    wire w_tick_hour;

    tick_counter #(
        .TIMES(24),
        .BIT_WIDTH(HOUR_BIT_WIDTH)

    ) U_HOUR_COUNTER (
        .clk(clk),
        .rst(rst),
        .i_tick(w_tick_hour),
        .clear(clear),
        .mode(mode),
        .time_count(hour),
        .o_tick()
    );

    tick_counter #(
        .TIMES(60),
        .BIT_WIDTH(MIN_BIT_WIDTH)

    ) U_MIN_COUNTER (
        .clk(clk),
        .rst(rst),
        .i_tick(w_tick_min),
        .clear(clear),
        .mode(mode),
        .time_count(min),
        .o_tick(w_tick_hour)
    );

    tick_counter #(
        .TIMES(60),
        .BIT_WIDTH(SEC_BIT_WIDTH)
    ) U_SEC_COUNTER (
        .clk(clk),
        .rst(rst),
        .i_tick(w_tick_sec),
        .clear(clear),
        .mode(mode),
        .time_count(sec),
        .o_tick(w_tick_min)
    );

    tick_counter #(
        .TIMES(100),
        .BIT_WIDTH(MSEC_BIT_WIDTH)

    ) U_MSEC_COUNTER (
        .clk(clk),
        .rst(rst),
        .i_tick(w_tick_10ms),
        .clear(clear),
        .mode(mode),
        .time_count(msec),
        .o_tick(w_tick_sec)
    );

    tick_gen_100hz U_TICK_GEN_100HZ (
        .clk(clk),
        .rst(rst),
        .run_stop(run_stop),
        .clear(clear),
        .o_tick(w_tick_10ms)  //100hz tick

    );


endmodule

module tick_counter #(
    parameter TIMES = 100,
    BIT_WIDTH = 7
) (
    input clk,
    input rst,
    input i_tick,
    input clear,
    input mode,
    output [BIT_WIDTH-1:0] time_count,
    output reg o_tick
);
    reg [$clog2(TIMES)-1:0] counter_reg;

    assign time_count = counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst | clear) begin
            counter_reg <= 00;
            o_tick <= 1'b0;
        end else begin
            if (mode) begin
                //down count
                if (i_tick) begin
                    counter_reg <= counter_reg - 1;
                    if (counter_reg == 0) begin
                        counter_reg <= TIMES - 1;
                        o_tick <= 1'b1;
                    end else begin
                        o_tick <= 1'b0;
                    end
                end else begin
                    o_tick <= 1'b0;
                end
            end else begin
                //up count
                if (i_tick) begin
                    if (counter_reg == TIMES - 1) begin
                        counter_reg <= 0;
                        o_tick <= 1'b1;
                    end else begin
                        counter_reg <= counter_reg + 1;
                        o_tick <= 1'b0;
                    end
                end else begin
                    o_tick <= 1'b0;
                end
            end
        end
    end
endmodule


module tick_gen_100hz (
    input clk,
    input rst,
    input run_stop,
    input clear,
    output reg o_tick  //100hz tick
);

    //100Mhz->100hz
    parameter F_COUNT = 100_000_000 / 100;
    reg [$clog2(F_COUNT)-1:0] counter_reg;
    reg tick_reg;

    always @(posedge clk, posedge rst) begin
        if (rst | clear) begin
            counter_reg <= 0;
            o_tick <= 1'b0;
        end else begin
            if (run_stop) begin
                counter_reg <= counter_reg + 1;
                if (counter_reg == F_COUNT - 1) begin
                    counter_reg <= 0;
                    o_tick <= 1'b1;
                end else begin
                    o_tick <= 1'b0;
                end
            end else begin
                // run_stop 이 1이고 , o_tick이 1일때, run_stop이 0으로 바뀌면,
                //계속 o_tick이 1로 남는 경우를 해결하기 위함.
                o_tick <= 1'b0;
            end
        end
    end
endmodule

module lap_controller #(
    parameter MSEC_BIT_WIDTH = 7,
    parameter SEC_BIT_WIDTH  = 6,
    parameter MIN_BIT_WIDTH  = 6,
    parameter HOUR_BIT_WIDTH = 5
) (
    input clk,
    input rst,
    input i_lap,
    input i_clear,

    input [MSEC_BIT_WIDTH-1:0] i_msec,
    input [ SEC_BIT_WIDTH-1:0] i_sec,
    input [ MIN_BIT_WIDTH-1:0] i_min,
    input [HOUR_BIT_WIDTH-1:0] i_hour,

    output [MSEC_BIT_WIDTH-1:0] o_msec,
    output [ SEC_BIT_WIDTH-1:0] o_sec,
    output [ MIN_BIT_WIDTH-1:0] o_min,
    output [HOUR_BIT_WIDTH-1:0] o_hour
);

    reg lap_mode;

    reg [MSEC_BIT_WIDTH-1:0] lap_msec;
    reg [SEC_BIT_WIDTH-1:0] lap_sec;
    reg [MIN_BIT_WIDTH-1:0] lap_min;
    reg [HOUR_BIT_WIDTH-1:0] lap_hour;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            lap_mode <= 1'b0;
            lap_msec <= 0;
            lap_sec  <= 0;
            lap_min  <= 0;
            lap_hour <= 0;
        end else if (i_clear) begin
            lap_mode <= 1'b0;
            lap_msec <= 0;
            lap_sec  <= 0;
            lap_min  <= 0;
            lap_hour <= 0;
        end else if (i_lap) begin
            if (lap_mode == 1'b0) begin
                lap_msec <= i_msec;
                lap_sec  <= i_sec;
                lap_min  <= i_min;
                lap_hour <= i_hour;
            end
            lap_mode <= ~lap_mode;
        end
    end

    assign o_msec = lap_mode ? lap_msec : i_msec;
    assign o_sec  = lap_mode ? lap_sec : i_sec;
    assign o_min  = lap_mode ? lap_min : i_min;
    assign o_hour = lap_mode ? lap_hour : i_hour;

endmodule

