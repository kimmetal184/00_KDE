`timescale 1ns / 1ps
module tb_sr04_shared_uart;
    localparam BIT_NS=104160; // 100MHz / (9600*16) truncates to 651 clocks/tick.
    reg clk=0, rst=1, uart_rxd=1, echo=0;
    always #5 clk=~clk;
    wire uart_txd, trig, rx_busy, tx_queue_full, tx_overflow;
    wire [15:0] data;
    integer bytes_seen=0, r_events=0, dht_events=0;
    string start_text={"start_stopwatch",8'h0d,8'h0a};
    string stop_text="";
    reg [7:0] received;
    integer bit_index;
    wire [47:0] comm;
    wire comm_valid, sw_req, sw_accept;
    wire [239:0] sw_msg;
    wire [5:0] sw_len;
    // Simulation-only peers, matching one shared UART in the team's TOP.
    uart_comm U_UART (
        .clk(clk), .rst(rst), .uart_rxd(uart_rxd), .uart_txd(uart_txd),
        .dht_req(1'b0), .dht_msg(240'b0), .dht_len(5'b0), .dht_accept(),
        .sw_req(sw_req), .sw_msg(sw_msg), .sw_len(sw_len), .sw_accept(sw_accept),
        .rx_busy(rx_busy), .comm(comm), .comm_valid(comm_valid), .r_pulse()
    );
    sr04_stopwatch U_SR04_STOPWATCH (
        .clk(clk), .rst(rst), .comm(comm), .comm_valid(comm_valid),
        .btn_run_stop(1'b0), .btn_clear(1'b0), .btn_mode(1'b0), .btn_lap(1'b0),
        .sw_mode(2'b10), .display_mode(1'b0), .echo(echo), .trig(trig), .data(data),
        .rx_busy(rx_busy), .sw_accept(sw_accept), .sw_req(sw_req),
        .sw_msg(sw_msg), .sw_len(sw_len),
        .tx_queue_full(tx_queue_full), .tx_overflow(tx_overflow)
    );
    task send_byte;
        input [7:0] value;
        integer i;
        begin
            @(negedge clk); uart_rxd=0;
            #(BIT_NS);
            for (i=0; i<8; i=i+1) begin
                uart_rxd=value[i]; #(BIT_NS);
            end
            uart_rxd=1; #(BIT_NS);
        end
    endtask
    task send_sw_command;
        begin
            send_byte("s"); send_byte("s"); send_byte("_"); send_byte("r");
            send_byte(8'h0d); send_byte(8'h0a);
        end
    endtask
    // Emulated sensor, but real UART RX/TX RTL with real serial bit timing.
    initial begin
        wait(rst == 0);
        @(negedge trig);
        #100000; echo=1;
        #5800000; echo=0;
    end
    always @(negedge clk) begin
        if (!rst && U_SR04_STOPWATCH.r_pulse) r_events=r_events+1;
        if (!rst && U_UART.comm_valid &&
            U_UART.comm == {"dw_r",8'h0d,8'h0a}) dht_events=dht_events+1;
        if (!rst && U_SR04_STOPWATCH.result_valid) begin
            stop_text=$sformatf("stop_%03dcm_%02d:%02d:%02d.%02d",
                U_SR04_STOPWATCH.result_distance,
                U_SR04_STOPWATCH.result_hour,
                U_SR04_STOPWATCH.result_min,
                U_SR04_STOPWATCH.result_sec,
                U_SR04_STOPWATCH.result_msec);
            stop_text={stop_text,8'h0d,8'h0a};
        end
    end
    // Independent PC-side 8N1 receiver: sample the actual tx pin, not tx_data.
    initial begin
        wait(rst == 0);
        forever begin
            @(negedge uart_txd);
            #(BIT_NS/2);
            if (uart_txd !== 0) $fatal(1,"Bad TX start bit");
            for (bit_index=0;bit_index<8;bit_index=bit_index+1) begin
                #(BIT_NS); received[bit_index]=uart_txd;
            end
            #(BIT_NS);
            if (uart_txd !== 1) $fatal(1,"Bad TX stop bit");
            if (bytes_seen < 17) begin
                if (received !== start_text[bytes_seen])
                    $fatal(1,"Start serial byte mismatch at %0d",bytes_seen);
            end else if (bytes_seen < 41) begin
                if (stop_text.len() != 24 || received !== stop_text[bytes_seen-17])
                    $fatal(1,"Stop serial byte mismatch at %0d",bytes_seen);
            end else $fatal(1,"Unexpected extra TX byte");
            bytes_seen=bytes_seen+1;
        end
    end
    initial begin
        #100; @(negedge clk); rst=0;
        repeat(1000) @(negedge clk);
        send_sw_command(); // Original shared UART accepts ss_r CR/LF.
        wait(r_events == 1);
        if (U_SR04_STOPWATCH.uart_run !== 1) begin
            @(negedge clk);
            if (U_SR04_STOPWATCH.uart_run !== 1) $fatal(1,"r did not start");
        end
        wait(U_SR04_STOPWATCH.distance_hold >= 99);
        if (U_SR04_STOPWATCH.distance_hold > 101)
            $fatal(1,"Sensor distance out of range");
        // Ensure at least one real 10ms stopwatch tick before stopping.
        #5000000;
        if (rx_busy !== 1) $fatal(1,"Expected stop during start message transmission");
        send_sw_command(); // Same command toggles stop, including while busy.
        send_byte(8'h0d); send_byte(8'h0a);
        wait(bytes_seen == 41);
        if (U_SR04_STOPWATCH.result_msec == 0)
            $fatal(1,"Expected nonzero real elapsed time");
        wait(rx_busy == 0);
        if (r_events != 2 || U_SR04_STOPWATCH.uart_run !== 0 || tx_overflow !== 0)
            $fatal(1,"Toggle, CR/LF handling or queue failed");
        send_byte("d"); send_byte("w"); send_byte("_"); send_byte("r");
        send_byte(8'h0d); send_byte(8'h0a);
        repeat(1000) @(negedge clk);
        if (r_events != 2 || dht_events != 1 || bytes_seen != 41)
            $fatal(1,"DHT command triggered stopwatch or was lost");
        // Bare r is NOT published by the original shared UART.
        send_byte("r"); send_byte(8'h0d); send_byte(8'h0a);
        repeat(1000) @(negedge clk);
        if (r_events != 2 || bytes_seen != 41)
            $fatal(1,"Unexpected bare-r behavior from original UART");
        $display("SERIAL START: %s",start_text);
        $display("SERIAL STOP: %s",stop_text);
        $display("ALL SERIAL UART INTEGRATION TESTS PASSED");
        $finish;
    end
    initial begin
        #70000000; $fatal(1,"Serial integration timeout");
    end
endmodule
