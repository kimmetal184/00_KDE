# 팀 TOP에서 연결하기 — v0.8.0

공용 UART는 **팀 TOP에 딱 하나** 둡니다. `sr04_stopwatch` 안에는 UART RX/TX가 없습니다.
이 저장소는 팀 전체 TOP을 만들지 않습니다. 아래는 기존 TOP에 추가할 연결 예시입니다.

```text
팀 TOP
├─ 공용 uart_comm 1개
│   ├─ comm/comm_valid/rx_busy → 각 기능에 전달
│   ├─ sw_req/sw_msg/sw_len ← SR04_STOPWATCH
│   ├─ sw_accept → SR04_STOPWATCH
│   └─ dht_req/dht_msg/dht_len ↔ 다른 팀원 모듈
├─ sr04_stopwatch
└─ 다른 팀원 모듈들
```

## 연결할 신호

| 공용 UART 포트 | SR04 포트 | 방향 |
|---|---|---|
| comm[47:0] | comm[47:0] | UART → SR04 |
| comm_valid | comm_valid | UART → SR04 |
| rx_busy | rx_busy | UART → SR04 |
| sw_accept | sw_accept | UART → SR04 |
| sw_req | sw_req | SR04 → UART |
| sw_msg[239:0] | sw_msg[239:0] | SR04 → UART |
| sw_len[5:0] | sw_len[5:0] | SR04 → UART |

기존 TOP에 이미 있는 공용 comm/comm_valid/rx_busy 배선을 재사용합니다.
SR04 송신 배선은 다른 모듈의 송신 배선과 분리하며 UART의 sw_* 포트에 연결합니다.
다른 팀원의 dht_* 포트는 그대로 연결합니다. 공용 UART의 직접 r_pulse 출력은
SR04에 연결하지 않습니다. SR04가 comm과 comm_valid로 자기 명령을 선택합니다.

## 기존 팀 TOP 안에 넣을 SR04 인스턴스 예시

아래 예시의 w_*는 기존 팀 TOP의 실제 배선 이름에 맞춥니다.
공용 UART 인스턴스를 새로 추가하는 코드가 아닙니다.

```verilog
sr04_stopwatch U_SR04_STOPWATCH (
    .clk(clk),
    .rst(rst),
    .comm(w_comm),
    .comm_valid(w_comm_valid),
    .rx_busy(w_rx_busy),
    .sw_accept(w_sw_accept),
    .sw_req(w_sw_req),
    .sw_msg(w_sw_msg),
    .sw_len(w_sw_len),
    .btn_run_stop(w_btn_run_stop),
    .btn_clear(w_btn_clear),
    .btn_mode(w_btn_mode),
    .btn_lap(w_btn_lap),
    .sw_mode(w_sw_mode),
    .display_mode(w_display_mode),
    .echo(echo),
    .trig(trig),
    .data(w_sr04_fnd_data),
    .tx_queue_full(),
    .tx_overflow()
    // 나머지 결과·확인용 출력은 필요할 때 연결합니다.
);
```

`data[15:0]`는 공용 FND 쪽의 모드 선택 MUX에 연결합니다.
버튼 입력에는 팀 쪽에서 디바운스한 1클럭 펄스를 전달합니다.
