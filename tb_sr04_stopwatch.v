`timescale 1ns / 1ps
module tb_sr04_stopwatch;
    reg clk=0, rst=1;
    always #5 clk=~clk;
    reg btn_run_stop=0, btn_clear=0, btn_mode=0, btn_lap=0;
    reg uart_start=0, uart_stop=0;
    reg [1:0] sw_mode=0;
    reg display_mode=0, echo=0;
    wire trig, result_valid;
    wire [15:0] data;
    wire [6:0] uart_msec;
    wire [5:0] uart_sec, uart_min;
    wire [4:0] uart_hour;
    wire [8:0] uart_distance;
    integer events=0;
    sr04_stopwatch dut (
        .clk(clk), .rst(rst), .btn_run_stop(btn_run_stop),
        .btn_clear(btn_clear), .btn_mode(btn_mode), .btn_lap(btn_lap),
        .uart_start(uart_start), .uart_stop(uart_stop),
        .sw_mode(sw_mode), .display_mode(display_mode), .echo(echo),
        .trig(trig), .data(data), .result_valid(result_valid),
        .uart_msec(uart_msec), .uart_sec(uart_sec),
        .uart_min(uart_min), .uart_hour(uart_hour),
        .uart_distance(uart_distance)
    );
    // Accelerate only the stopwatch dividers: 100 clocks per centisecond.
    defparam dut.U_FPGA_STOPWATCH.U_TICK_GEN_100HZ.F_COUNT = 100;
    defparam dut.U_UART_STOPWATCH.U_TICK_GEN_100HZ.F_COUNT = 100;
    always @(negedge clk) if (result_valid) events=events+1;
    initial begin
        #100; @(negedge clk); rst=0;
        uart_start=1;
        @(negedge clk); uart_start=0;
        repeat(350) @(negedge clk);
        if (uart_msec !== 7'd3 || dut.fpga_msec !== 7'd0)
            $fatal(1,"UART start affected FPGA or UART count failed");
        btn_run_stop=1;
        @(negedge clk); btn_run_stop=0;
        repeat(350) @(negedge clk);
        if (dut.fpga_msec !== 7'd3 || uart_msec !== 7'd7)
            $fatal(1,"Independent simultaneous counting failed");
        uart_stop=1;
        @(negedge clk); uart_stop=0;
        repeat(350) @(negedge clk);
        if (uart_msec !== 7'd7 || dut.fpga_msec !== 7'd7 || events != 1)
            $fatal(1,"UART stop or completion pulse failed");
        btn_lap=1;
        @(negedge clk); btn_lap=0;
        repeat(200) @(negedge clk);
        if (data !== 16'h0007 || dut.fpga_msec !== 7'd9)
            $fatal(1,"Lap did not freeze display only");
        btn_clear=1;
        @(negedge clk); btn_clear=0;
        if (dut.fpga_msec !== 7'd0 || data !== 16'h0000 || uart_msec !== 7'd7)
            $fatal(1,"FPGA clear isolation failed");
        uart_start=1;
        @(negedge clk); uart_start=0;
        if (uart_msec !== 7'd0) $fatal(1,"UART restart did not clear");
        repeat(150) @(negedge clk);
        if (uart_msec !== 7'd1) $fatal(1,"UART restart did not run");
        $display("ALL CONTROL TESTS PASSED");
        $finish;
    end
    initial begin
        #100_000;
        $fatal(1,"Simulation timeout");
    end
endmodule
