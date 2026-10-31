`timescale 1ns / 1ps

// UART 통합 모듈
// RX : PC 명령(dw_r / ss_r) 수신 -> comm, comm_valid 출력
// TX : Watch / Stopwatch의 완성된 ASCII 메시지를 받아 PC로 전송
//      메시지 처리 중에는 새 요청을 받지 않음 (rx_busy = 1)
module uart_comm #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 9600
) (
    input              clk,
    input              rst,
    input              uart_rxd,
    output             uart_txd,

    // Watch + DHT11 -> UART
    input              dht_req,
    input      [239:0] dht_msg,
    input      [  4:0] dht_len,
    output reg         dht_accept,

    // SR04 + Stopwatch -> UART
    input              sw_req,
    input      [239:0] sw_msg,
    input      [  5:0] sw_len,
    output reg         sw_accept,

    // 공통
    output reg         rx_busy,

    // UART -> 각 모듈: PC 명령 수신 결과
    output reg [ 47:0] comm,
    output reg         comm_valid,
    output reg         r_pulse      // ss_r 명령 수신 시 Stopwatch에 1클럭
);


    // 1. UART 공통 Baud Tick (9600bps, 16배 오버샘플링)
    wire w_b_tick;

    uart_comm_baud_tick #(
        .CLK_FREQ (CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) U_BAUD_TICK (
        .clk   (clk),
        .rst   (rst),
        .b_tick(w_b_tick)
    );

    // 2. RX : UART RX -> RX FIFO -> 명령 수신
    wire [7:0] w_rx_data;
    wire       w_rx_done;

    uart_rx U_UART_RX (
        .clk    (clk),
        .rst    (rst),
        .b_tick (w_b_tick),
        .rx     (uart_rxd),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)
    );

    wire [7:0] w_fifo_data;
    wire       w_fifo_full, w_fifo_empty;
    wire       w_fifo_pop = !w_fifo_empty;

    fifo #(
        .DEPTH      (8),
        .A_BIT_WIDTH(3),
        .D_BIT_WIDTH(8)
    ) U_RX_FIFO (
        .clk      (clk),
        .rst      (rst),
        .push     (w_rx_done),
        .pop      (w_fifo_pop),
        .push_data(w_rx_data),
        .pop_data (w_fifo_data),
        .full     (w_fifo_full),
        .empty    (w_fifo_empty)
    );

    // 명령어는 총 6바이트: "dw_r\r\n" 또는 "ss_r\r\n"
    // 한 글자씩 모았다가 LF(0x0A)를 받으면 명령을 확인한다.
    localparam [47:0] CMD_DHT = {"dw_r", 8'h0D, 8'h0A};
    localparam [47:0] CMD_SW  = {"ss_r", 8'h0D, 8'h0A};

    reg  [47:0] comm_shift;
    wire [47:0] w_new_comm = {comm_shift[39:0], w_fifo_data};

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            comm       <= 48'd0;
            comm_shift <= 48'd0;
            comm_valid <= 1'b0;
            r_pulse    <= 1'b0;
        end else begin
            comm_valid <= 1'b0;
            r_pulse    <= 1'b0;

            if (w_fifo_pop) begin
                if (w_fifo_data == 8'h0A) begin
                    comm_shift <= 48'd0;
                    if (w_new_comm == CMD_DHT || w_new_comm == CMD_SW) begin
                        comm       <= w_new_comm;
                        comm_valid <= 1'b1;  // 새 명령 도착 알림 (1클럭)
                        if (w_new_comm == CMD_SW)
                            r_pulse <= 1'b1;
                    end
                end else begin
                    comm_shift <= w_new_comm;
                end
            end
        end
    end

    // 3. TX : 메시지 선택 -> 메시지 저장 -> 문자별 전송
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] SEND_BYTE = 2'd1;
    localparam [1:0] WAIT_BUSY = 2'd2;
    localparam [1:0] WAIT_DONE = 2'd3;

    reg [1:0]   state;
    reg [255:0] message_reg;  // 내부 32바이트, 외부 메시지는 최대 30바이트
    reg [5:0]   length_reg;
    reg [5:0]   byte_count;
    reg [7:0]   tx_data;
    reg         tx_start;
    wire        w_tx_byte_busy;

    uart_tx U_UART_TX (
        .clk     (clk),
        .rst     (rst),
        .b_tick  (w_b_tick),
        .tx_start(tx_start),
        .tx_data (tx_data),
        .tx      (uart_txd),
        .tx_busy (w_tx_byte_busy)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state       <= IDLE;
            message_reg <= 256'd0;
            length_reg  <= 6'd0;
            byte_count  <= 6'd0;
            tx_data     <= 8'd0;
            tx_start    <= 1'b0;
            rx_busy     <= 1'b0;
            dht_accept  <= 1'b0;
            sw_accept   <= 1'b0;
        end else begin
            tx_start   <= 1'b0;
            dht_accept <= 1'b0;
            sw_accept  <= 1'b0;

            case (state)
                IDLE: begin
                    rx_busy <= 1'b0;

                    // 두 요청이 동시에 오면 Stopwatch 우선
                    if (sw_req && sw_len >= 1 && sw_len <= 30) begin
                        message_reg <= {sw_msg, 16'd0};
                        length_reg  <= sw_len;
                        byte_count  <= 6'd0;
                        sw_accept   <= 1'b1;
                        rx_busy     <= 1'b1;
                        state       <= SEND_BYTE;
                    end else if (dht_req && dht_len >= 1 && dht_len <= 30) begin
                        message_reg <= {dht_msg, 16'd0};
                        length_reg  <= {1'b0, dht_len};
                        byte_count  <= 6'd0;
                        dht_accept  <= 1'b1;
                        rx_busy     <= 1'b1;
                        state       <= SEND_BYTE;
                    end
                end

                SEND_BYTE: begin
                    // 저장된 메시지에서 현재 문자 1바이트를 선택
                    if (!w_tx_byte_busy) begin
                        tx_data  <= message_reg[255 - (byte_count * 8) -: 8];
                        tx_start <= 1'b1;
                        state    <= WAIT_BUSY;
                    end
                end

                WAIT_BUSY: begin
                    // UART TX가 현재 문자 송신을 시작할 때까지 대기
                    if (w_tx_byte_busy)
                        state <= WAIT_DONE;
                end

                WAIT_DONE: begin
                    // 현재 문자 송신이 끝나면 다음 문자로 진행
                    if (!w_tx_byte_busy) begin
                        if (byte_count == length_reg - 1'b1) begin
                            rx_busy <= 1'b0;  // 마지막 문자까지 송신 완료
                            state   <= IDLE;
                        end else begin
                            byte_count <= byte_count + 1'b1;
                            state      <= SEND_BYTE;
                        end
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule


// UART RX/TX에서 같이 사용할 16배 Baud Tick 생성기
module uart_comm_baud_tick #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 9600
) (
    input      clk,
    input      rst,
    output reg b_tick
);
    localparam integer DIVIDER = CLK_FREQ / (BAUD_RATE * 16);
    localparam integer COUNT_MAX = (DIVIDER < 1) ? 1 : DIVIDER;
    reg [$clog2(COUNT_MAX + 1)-1:0] count_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count_reg <= 0;
            b_tick    <= 1'b0;
        end else if (count_reg == COUNT_MAX - 1) begin
            count_reg <= 0;
            b_tick    <= 1'b1;
        end else begin
            count_reg <= count_reg + 1'b1;
            b_tick    <= 1'b0;
        end
    end
endmodule