`timescale 1ns / 1ps
module tb_sr04_uart_request;
    reg clk=0, rst=1;
    always #5 clk=~clk;
    reg [239:0] message=0;
    reg [5:0] message_len=0;
    reg message_valid=0, rx_busy=1, sw_accept=0;
    wire sw_req, queue_full, overflow;
    wire [239:0] sw_msg;
    wire [5:0] sw_len;
    reg previous_req=0;
    sr04_uart_request dut (
        .clk(clk), .rst(rst), .message(message), .message_len(message_len),
        .message_valid(message_valid), .rx_busy(rx_busy), .sw_accept(sw_accept),
        .sw_req(sw_req), .sw_msg(sw_msg), .sw_len(sw_len),
        .queue_full(queue_full), .overflow(overflow)
    );
    always @(negedge clk) begin
        if (!rst && sw_req && previous_req) $fatal(1,"req longer than one clock");
        previous_req=sw_req;
    end
    task enqueue;
        input [7:0] value;
        begin
            @(negedge clk); message={232'b0,value}; message_len=value; message_valid=1;
            @(negedge clk); message_valid=0; message=0; message_len=0;
        end
    endtask
    task await_req;
        input [7:0] expected;
        begin
            wait(sw_req === 1'b1);
            @(negedge clk);
            if (sw_msg !== {232'b0,expected} || sw_len !== expected)
                $fatal(1,"FIFO head corrupted: expected %0d", expected);
        end
    endtask
    task grant;
        input [7:0] expected;
        begin
            rx_busy=0;
            await_req(expected);
            // Next rising edge samples req; registered UART response follows.
            @(negedge clk); sw_accept=1; rx_busy=1;
            @(negedge clk); sw_accept=0;
        end
    endtask
    initial begin
        #20; @(negedge clk); rst=0;
        enqueue(1); enqueue(2);
        repeat(5) @(negedge clk);
        if (sw_req !== 0 || sw_msg !== 240'd1) $fatal(1,"Busy handling failed");
        rx_busy=0;
        await_req(1);
        @(negedge clk); rx_busy=1; // Other module wins; no accept.
        repeat(5) @(negedge clk);
        if (sw_msg !== 240'd1) $fatal(1,"Rejected request lost");
        grant(1); grant(2);
        if (sw_len !== 0) $fatal(1,"Queue did not drain");
        enqueue(3); enqueue(4); enqueue(5); enqueue(6);
        if (queue_full !== 1) $fatal(1,"Full flag failed");
        enqueue(7);
        if (overflow !== 1 || sw_msg !== 240'd3) $fatal(1,"Overflow policy failed");
        // Full FIFO accepts a new message on the same edge an old one pops.
        rx_busy=0; await_req(3);
        @(negedge clk); sw_accept=1; rx_busy=1;
        message=240'd8; message_len=8; message_valid=1;
        @(negedge clk); sw_accept=0; message_valid=0;
        if (queue_full !== 1) $fatal(1,"Simultaneous push/pop count failed");
        grant(4); grant(5); grant(6); grant(8);
        if (sw_len !== 0) $fatal(1,"FIFO wraparound failed");
        enqueue(9); rx_busy=0; await_req(9);
        rst=1;
        @(negedge clk);
        if (sw_req !== 0 || sw_len !== 0 || overflow !== 0 || queue_full !== 0)
            $fatal(1,"Reset did not discard pending request");
        $display("ALL UART REQUEST TESTS PASSED");
        $finish;
    end
    initial begin
        #10000; $fatal(1,"UART request timeout");
    end
endmodule
