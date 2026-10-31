`timescale 1ns / 1ps
module tb_sr04_message_formatter;
    reg clk=0, rst=1, start_valid=0, result_valid=0;
    always #5 clk=~clk;
    reg [6:0] result_msec=0;
    reg [5:0] result_sec=0, result_min=0;
    reg [4:0] result_hour=0;
    reg [8:0] result_distance=0;
    wire [239:0] message;
    wire [5:0] message_len;
    wire message_valid;
    sr04_message_formatter dut (
        .clk(clk), .rst(rst), .start_valid(start_valid),
        .result_valid(result_valid), .result_msec(result_msec),
        .result_sec(result_sec), .result_min(result_min),
        .result_hour(result_hour), .result_distance(result_distance),
        .message(message), .message_len(message_len), .message_valid(message_valid)
    );
    task stop_check;
        input [8:0] cm;
        input [4:0] hh;
        input [5:0] mm, ss;
        input [6:0] cc;
        input [191:0] expected;
        begin
            @(negedge clk);
            result_distance=cm; result_hour=hh; result_min=mm;
            result_sec=ss; result_msec=cc; result_valid=1;
            @(negedge clk);
            result_valid=0;
            if (message_valid !== 1 || message_len !== 24 ||
                message !== {expected,48'b0})
                $fatal(1,"Stop ASCII mismatch: %h",message);
            @(negedge clk);
            if (message_valid !== 0 || message !== {expected,48'b0})
                $fatal(1,"Message pulse or retention failed");
        end
    endtask
    initial begin
        #20; @(negedge clk); rst=0;
        start_valid=1;
        @(negedge clk); start_valid=0;
        if (message_valid !== 1 || message_len !== 17 ||
            message !== {"start_stopwatch",8'h0d,8'h0a,104'b0})
            $fatal(1,"Start ASCII mismatch");
        @(negedge clk);
        if (message_valid !== 0) $fatal(1,"Start pulse too long");
        stop_check(123,0,1,23,45,{"stop_123cm_00:01:23.45",8'h0d,8'h0a});
        stop_check(0,0,0,0,0,{"stop_000cm_00:00:00.00",8'h0d,8'h0a});
        stop_check(9,1,2,3,4,{"stop_009cm_01:02:03.04",8'h0d,8'h0a});
        stop_check(400,23,59,59,99,{"stop_400cm_23:59:59.99",8'h0d,8'h0a});
        @(negedge clk); rst=1;
        @(negedge clk);
        if (message !== 0 || message_len !== 0 || message_valid !== 0)
            $fatal(1,"Reset failed");
        $display("ALL ASCII TESTS PASSED");
        $finish;
    end
    initial begin
        #10000; $fatal(1,"Timeout");
    end
endmodule
