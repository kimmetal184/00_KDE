# 변경 이력

현재 버전: **v0.5.0**

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
