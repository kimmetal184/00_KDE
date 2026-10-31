`timescale 1ns / 1ps
module tb_sr04_stopwatch;
    reg clk=0, rst=1;
    always #5 clk=~clk;
    reg btn_run_stop=0, btn_clear=0, btn_mode=0, btn_lap=0;
    reg r_pulse=0;
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
    reg rx_busy=1, sw_accept=0;
    wire sw_req, tx_queue_full, tx_overflow;
    wire [239:0] sw_msg;
    wire [5:0] sw_len;
    reg [239:0] expected_messages [0:15];
    reg [5:0] expected_lengths [0:15];
    integer produced=0, accepted=0, busy_cycles=400;
    reg reject_once=1;
    integer events=0;
    sr04_stopwatch dut (
        .clk(clk), .rst(rst), .btn_run_stop(btn_run_stop),
        .btn_clear(btn_clear), .btn_mode(btn_mode), .btn_lap(btn_lap),
        .comm({"ss_r",8'h0d,8'h0a}), .comm_valid(r_pulse),
        .sw_mode(sw_mode), .display_mode(display_mode), .echo(echo),
        .trig(trig), .data(data), .result_valid(result_valid),
        .uart_msec(uart_msec), .uart_sec(uart_sec),
        .uart_min(uart_min), .uart_hour(uart_hour),
        .uart_distance(uart_distance),
        .result_msec(result_msec), .result_sec(result_sec),
        .result_min(result_min), .result_hour(result_hour),
        .result_distance(result_distance),
        .message(message), .message_len(message_len), .message_valid(message_valid),
        .rx_busy(rx_busy), .sw_accept(sw_accept), .sw_req(sw_req),
        .sw_msg(sw_msg), .sw_len(sw_len),
        .tx_queue_full(tx_queue_full), .tx_overflow(tx_overflow)
    );
    // Fake UART: copy the entire payload on the request sampling edge,
    // then register accept/busy. Reject the first request to emulate arbitration.
    always @(posedge clk) begin
        sw_accept <= 0;
        if (!rst) begin
            if (message_valid) begin
                expected_messages[produced] = message;
                expected_lengths[produced] = message_len;
                produced = produced + 1;
            end
            if (busy_cycles > 0) begin
                busy_cycles = busy_cycles - 1;
                rx_busy <= 1;
            end else begin
                rx_busy <= 0;
                if (sw_req && !rx_busy) begin
                    if (reject_once) begin
                        reject_once = 0;
                        rx_busy <= 1;
                        busy_cycles = 5;
                    end else begin
                        if (accepted >= produced ||
                            sw_msg !== expected_messages[accepted] ||
                            sw_len !== expected_lengths[accepted])
                            $fatal(1,"UART accepted wrong payload or order");
                        accepted = accepted + 1;
                        sw_accept <= 1;
                        rx_busy <= 1;
                        busy_cycles = 20;
                    end
                end
            end
        end
    end
    // Accelerate only the stopwatch dividers: 100 clocks per centisecond.
    defparam dut.U_FPGA_STOPWATCH.U_TICK_GEN_100HZ.F_COUNT = 100;
    defparam dut.U_UART_STOPWATCH.U_TICK_GEN_100HZ.F_COUNT = 100;
    always @(negedge clk) if (result_valid) events=events+1;
    // Check four r pulses produce start, stop, start, stop in order.
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
        r_pulse=1;
        @(negedge clk); r_pulse=0;
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
        r_pulse=1;
        @(negedge clk); r_pulse=0;
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
        r_pulse=1;
        @(negedge clk); r_pulse=0;
        if (uart_msec !== 7'd0) $fatal(1,"UART restart did not clear");
        repeat(150) @(negedge clk);
        if (uart_msec !== 7'd1) $fatal(1,"UART restart did not run");
        if (result_msec !== 7'd7 || result_distance !== 9'd123)
            $fatal(1,"Restart changed previous result");
        // Fourth r stops the restarted measurement.
        r_pulse=1;
        @(negedge clk); r_pulse=0;
        @(negedge clk);
        if (result_msec !== 7'd1 || result_distance !== 9'd0)
            $fatal(1,"Next stop did not replace snapshot");
        repeat(4) @(negedge clk);
        if (result_valid !== 1'b0 || result_msec !== 7'd1 || dut.uart_run !== 0)
            $fatal(1,"State changed without another r pulse");
        @(negedge clk);
        if (start_messages != 2 || stop_messages != 2)
            $fatal(1,"Missing or duplicate messages");
        wait(accepted == 4);
        repeat(5) @(negedge clk);
        if (produced != 4 || tx_overflow !== 0)
            $fatal(1,"Integrated queue lost or overflowed messages");
        rst=1;
        @(negedge clk);
        if ({result_hour,result_min,result_sec,result_msec,result_distance} !== 0)
            $fatal(1,"Reset did not clear result");
        rst=0;
        r_pulse=1;
        @(negedge clk); r_pulse=0;
        if (dut.uart_run !== 1 || uart_msec !== 0 || result_valid !== 0)
            $fatal(1,"First r after reset did not start from zero");
        wait(accepted == 5);
        @(negedge clk);
        $display("ALL R TOGGLE TESTS PASSED");
        $display("ALL CONTROL TESTS PASSED");
        $display("ALL SNAPSHOT TESTS PASSED");
        $display("ALL INTEGRATED MESSAGE TESTS PASSED");
        $display("ALL INTEGRATED UART TESTS PASSED");
        $finish;
    end
    initial begin
        #100_000;
        $fatal(1,"Simulation timeout");
    end
endmodule
