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
    wire [6:0] result_msec;
    wire [5:0] result_sec, result_min;
    wire [4:0] result_hour;
    wire [8:0] result_distance;
    wire [239:0] message;
    wire [5:0] message_len;
    wire message_valid;
    integer start_messages=0, stop_messages=0;
    integer events=0;
    sr04_stopwatch dut (
        .clk(clk), .rst(rst), .btn_run_stop(btn_run_stop),
        .btn_clear(btn_clear), .btn_mode(btn_mode), .btn_lap(btn_lap),
        .uart_start(uart_start), .uart_stop(uart_stop),
        .sw_mode(sw_mode), .display_mode(display_mode), .echo(echo),
        .trig(trig), .data(data), .result_valid(result_valid),
        .uart_msec(uart_msec), .uart_sec(uart_sec),
        .uart_min(uart_min), .uart_hour(uart_hour),
        .uart_distance(uart_distance),
        .result_msec(result_msec), .result_sec(result_sec),
        .result_min(result_min), .result_hour(result_hour),
        .result_distance(result_distance),
        .message(message), .message_len(message_len), .message_valid(message_valid)
    );
    // Accelerate only the stopwatch dividers: 100 clocks per centisecond.
    defparam dut.U_FPGA_STOPWATCH.U_TICK_GEN_100HZ.F_COUNT = 100;
    defparam dut.U_UART_STOPWATCH.U_TICK_GEN_100HZ.F_COUNT = 100;
    always @(negedge clk) if (result_valid) events=events+1;
    // Check wrapper wiring for start, stop, restart and duplicate idle stop.
    always @(negedge clk) begin
        if (!rst && message_valid) begin
            if (message_len == 17) begin
                if (message !== {"start_stopwatch",8'h0d,8'h0a,104'b0})
                    $fatal(1,"Integrated start message mismatch");
                start_messages = start_messages + 1;
            end else if (message_len == 24) begin
                if (stop_messages == 0 &&
                    message !== {"stop_123cm_00:00:00.07",8'h0d,8'h0a,48'b0})
                    $fatal(1,"Integrated first stop mismatch");
                if (stop_messages == 1 &&
                    message !== {"stop_000cm_00:00:00.01",8'h0d,8'h0a,48'b0})
                    $fatal(1,"Integrated second stop mismatch");
                stop_messages = stop_messages + 1;
            end else $fatal(1,"Integrated message length mismatch");
        end
    end
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
        // Emulate a sensor completion coincident with stop, avoiding a long
        // sensor timing test here. The real sensor is still instantiated.
        force dut.distance_valid = 1'b1;
        force dut.measured_distance = 9'd123;
        uart_stop=1;
        @(negedge clk); uart_stop=0;
        release dut.distance_valid;
        release dut.measured_distance;
        if ({result_hour,result_min,result_sec,result_msec} !== {5'd0,6'd0,6'd0,7'd7}
            || result_distance !== 9'd123 || result_valid !== 1'b1)
            $fatal(1,"Stop snapshot or simultaneous distance completion failed");
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
        if (result_msec !== 7'd7 || result_distance !== 9'd123)
            $fatal(1,"Restart changed previous result");
        // Idle stop must not replace the last result or emit another event.
        uart_stop=1;
        @(negedge clk); uart_stop=0;
        @(negedge clk);
        if (result_msec !== 7'd1 || result_distance !== 9'd0)
            $fatal(1,"Next stop did not replace snapshot");
        uart_stop=1;
        @(negedge clk); uart_stop=0;
        if (result_valid !== 1'b0 || result_msec !== 7'd1)
            $fatal(1,"Idle stop changed result");
        @(negedge clk);
        if (start_messages != 2 || stop_messages != 2)
            $fatal(1,"Missing or duplicate messages");
        rst=1;
        @(negedge clk);
        if ({result_hour,result_min,result_sec,result_msec,result_distance} !== 0)
            $fatal(1,"Reset did not clear result");
        $display("ALL CONTROL TESTS PASSED");
        $display("ALL SNAPSHOT TESTS PASSED");
        $display("ALL INTEGRATED MESSAGE TESTS PASSED");
        $finish;
    end
    initial begin
        #100_000;
        $fatal(1,"Simulation timeout");
    end
endmodule
