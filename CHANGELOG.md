# 변경 이력

현재 버전: **v0.8.0**

## v0.8.0 — 팀의 단일 공용 UART에 직접 연결

- `sr04_stopwatch.v`: 명령 입력을 r_pulse에서 comm[47:0]/comm_valid로 교체. 자기 명령 ss_r CR/LF만 선택하여 내부 토글.
- 팀 공용 UART는 팀 TOP에 한 번만 배치. SR04 내부에 UART RX/TX를 넣지 않음.
- 별도 설계 TOP top_sr04_uart.v와 외부 어댑터 sr04_command_adapter.v 제거.
- 기존 tb_top_sr04_uart.sv를 tb_sr04_shared_uart.sv로 변경. UART와 SR04를 테스트벤치 안에서 서로 연결하여 검증.
- `tb_sr04_stopwatch.v`: 공용 명령 버스 형태로 입력 갱신.
- 새 안내 SR04_TEAM_CONNECTION.md: 기존 팀 TOP에서 사용할 신호 연결표와 SR04 인스턴스 예시.
- 공용 UART 네 파일은 업로드 원본 그대로 유지.
- 명령은 원본 UART 규격인 ss_r CR/LF이며 단일 r 입력은 지원하지 않음.
- 검증: Icarus Verilog 12.0에서 공용 원본 UART와의 직렬 연결 테스트 통과(58.3ms), 기존 제어·메시지·요청 테스트도 회귀 통과. 공용 네 파일의 원본 동일성 확인.
- 실제 팀 TOP/보드 연결 및 Vivado v0.8.0 검증은 미확인.

## v0.7.0 — 공용 UART 원본 유지, SR04 쪽에서 명령 연결

- 사용자 요청에 따라 uart_comm.v, fifo.v를 업로드 원본으로 복원. uart_rx.v, uart_tx.v도 원본 그대로 유지. 네 파일의 바이트 단위 동일성 확인.
- 새 파일 `sr04_command_adapter.v`: 공용 `comm[47:0]`, `comm_valid`를 받아 ss_r CR/LF일 때만 우리 쪽 r_pulse 생성.
- `top_sr04_uart.v`: 공용 UART의 직접 r_pulse 대신 SR04 명령 어댑터 사용. 송신 req/accept 인터페이스 유지.
- `tb_top_sr04_uart.sv`: 원본 명령 ss_r CR/LF로 시작·정지 및 직렬 메시지 검증. DHT 명령 분리와 단일 r 미인식 확인.
- 명령 차이: 원본 UART는 r 한 글자를 외부로 전달하지 않음. PC에서는 ss_r CR/LF를 반복 전송해야 함. 내부 SR04의 r_pulse 토글 방식은 유지.
- 검증: Icarus Verilog 12.0 직렬 통합 테스트 통과(약 58.3ms 시뮬레이션). 원본 네 파일의 바이트 동일성 확인.
- 아직 미검증: 실제 보드/PC 및 전체 Watch/DHT/FND 연결, Vivado v0.7.0 실행.
- FIFO의 원본 일반 모듈 이름도 복원됨. 팀 전체에서 다른 control_unit 등이 중복 정의되면 공용 담당자와 네임스페이스 조율 필요.

## v0.6.0 — 팀 UART 연결 및 직렬 통신 시뮬레이션

- 새 파일 `top_sr04_uart.v`: 팀 UART와 SR04_STOPWATCH 연결. DHT 송신 입력은 단독 검증을 위해 0으로 연결.
- 새 파일 `uart_comm.v`: 업로드된 팀 코드 기반. 기존 ss_r CR/LF 대신 단일 r을 즉시 토글 펄스로 해석. 선택적 CR/LF는 추가 토글하지 않음. dw_r CR/LF 명령 유지.
- 새 파일 `uart_rx.v`, `uart_tx.v`: 올바르게 다시 업로드된 RX/TX 원본 재사용.
- 새 파일 `fifo.v`: 업로드 원본 기반. fifo/register_file/control_unit 모듈 이름을 uart_rx_fifo/uart_fifo_storage/uart_fifo_control로 구분하고 uart_comm 인스턴스도 변경. 기능 변경 없음.
- 새 파일 `tb_top_sr04_uart.sv`: 100MHz, 9600bps 설정에서 직렬 RX 입력과 독립적인 PC 측 TX 비트 샘플링으로 연결 검증. Enter 없는 r, 송신 busy 중 정지, 메시지 전체 바이트, 센서 거리 결과, CR/LF 무시, DHT 명령 분리 확인.
- 검증: Icarus Verilog 12.0에서 실제 UART RX/TX RTL을 통한 9600bps 직렬 통합 시뮬레이션 통과. 기존 v0.5.0 제어·ASCII·대기열 테스트도 회귀 통과.
- Vivado v0.6.0 검증은 아직 미확인.
- 실제 보드 및 물리 PC 연결, 전체 Watch/DHT/FND 통합은 아직 미검증.
- 기존 SR04_STOPWATCH 소스는 변경하지 않음. 새 TOP에서 모듈들을 연결.

## v0.5.0 — r 하나로 시작·정지 토글

- `sr04_stopwatch.v`: 외부 `uart_start`, `uart_stop` 입력을 `r_pulse` 입력 하나로 교체.
- 정지 상태의 r: 시간과 현재 거리를 초기화하고 시간·거리 측정 시작, 시작 메시지 생성.
- 실행 상태의 r: 정지 시 시간·거리 저장, 결과 메시지 생성.
- 다음 r은 새 측정을 시작하며 이전 저장 결과는 다음 정지까지 유지.
- `tb_sr04_stopwatch.v`: 네 번의 r이 시작→정지→시작→정지가 되는지, 입력 없는 동안 상태 유지, 리셋 후 첫 r이 시작인지 검증.
- 메시지 형식과 UART 요청·수락·대기열 동작은 유지.
- UART 담당자는 ASCII r(0x72)을 수신할 때 100MHz 도메인의 1클럭 r_pulse를 생성해야 함. 이 프로젝트에는 실제 UART 수신 디코더가 없으며 해당 연결은 아직 미검증.
- 검증: Icarus Verilog 12.0 통합 테스트 통과. Vivado v0.5.0 검증은 아직 미확인.
- v0.4.0 검증: 사용자가 Vivado 요청 단독·통합 테스트 통과 확인.

## v0.4.0 — UART 요청·수락과 메시지 대기열

- 새 파일 `sr04_uart_request.v`: 완성된 메시지 4개를 FIFO에 복사·보관.
- `sr04_stopwatch.v`: `rx_busy`, `sw_accept` 입력과 `sw_req`, `sw_msg`, `sw_len`, `tx_queue_full`, `tx_overflow` 출력 추가.
- UART가 비어 있을 때만 1클럭 요청. 요청 수락 전까지 메시지와 길이 유지. 미수락 시 재시도.
- UART는 요청을 샘플링한 상승 엣지에서 메시지를 복사하고 `sw_accept`를 1클럭 등록 출력한다는 계약 사용.
- 대기열 가득 참: 기존 메시지 보존, 새 메시지 폐기, `tx_overflow`를 리셋까지 유지. 수락과 새 메시지가 같은 클럭이면 빈자리를 즉시 재사용.
- 새 파일 `tb_sr04_uart_request.v`: busy, 재시도, FIFO 순서/포인터 순환, 포화, 동시 입력·수락, 리셋, 요청 펄스 검증.
- `tb_sr04_stopwatch.v`: 가짜 UART로 실제 포트의 메시지 복사·수락, 첫 요청 거부 후 재시도 및 4건 순차 수락 검증.
- 검증: Icarus Verilog 12.0에서 요청 단독·통합·ASCII 테스트 전체 통과. 사용자가 Vivado v0.4.0 요청 단독·통합 테스트 통과 확인.
- 남은 작업: 팀 UART의 문자 배치·accept 타이밍·중재 규칙 최종 확인, 실제 UART/PC 송신 및 보드 검증. 센서 관련 기존 보완 사항 유지.
- `stopwatch.v`, `sr04.v`, ASCII 생성 모듈은 변경하지 않음.

## v0.3.0 — UART ASCII 메시지 생성

- 새 파일 `sr04_message_formatter.v`: 시작 메시지(17바이트)와 정지 결과 메시지(24바이트) 생성.
- `sr04_stopwatch.v`: 저장된 결과를 메시지 생성 모듈에 연결하고 `message`, `message_len`, `message_valid` 출력 추가.
- 새 파일 `tb_sr04_message_formatter.v`: 전체 ASCII 바이트, 길이, CR/LF, 0 채움, 메시지 유지·펄스, 리셋 검증.
- `tb_sr04_stopwatch.v`: 시작·정지·재시작 메시지의 통합 연결 검증 추가.
- `SR04_SETUP.txt`: 추가 파일 등록과 메시지 규격을 한글로 설명.
- 검증: Icarus Verilog 12.0 컴파일 및 단독·통합 시뮬레이션 통과. 기존 제어·결과 저장 테스트도 통과.
- Vivado 검증: 사용자가 v0.3.0 ASCII 단독·통합 테스트 통과 확인.
- 남은 작업: `sw_req`·`sw_accept`·`rx_busy`, 전송 대기 메시지 보관 및 충돌 처리, 팀 인터페이스 확정, 실제 UART 송신 검증.
- 메시지 규격은 첫 문자를 상위 바이트에 배치하며 거리는 세 자리로 고정. 팀 담당자와 최종 확인 필요.
- `stopwatch.v`, `sr04.v`는 변경하지 않음.

## v0.2.0 — 정지 결과 저장

- `sr04_stopwatch.v`: 정지 시 시간·거리 결과를 별도로 저장하고 `result_valid` 펄스 출력.
- 재시작과 FPGA 버튼 조작 후에도 이전 결과 유지. 다음 유효한 정지에서 갱신.
- `tb_sr04_stopwatch.v`: 결과 저장·유지·갱신·중복 정지·리셋 검증.
- 검증: Icarus 시뮬레이션 통과. 사용자가 Vivado에서도 제어·결과 저장 테스트 통과를 확인.

## v0.1.0 — FPGA·UART 제어 분리

- FPGA용·UART용으로 `stopwatch_datapath`를 각각 사용.
- FPGA Run/Stop, Clear, UP/DOWN, Lap 및 UART 시작·정지를 독립 제어.
- 기존 센서·스톱워치 하위 모듈 재사용, FND 출력은 임시 packed BCD 형식.
- 검증: Icarus 시뮬레이션 통과. 사용자가 Vivado에서도 제어 테스트 통과를 확인.
