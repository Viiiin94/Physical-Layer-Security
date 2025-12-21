테스트벤치용 코드수정

<controller.v>
1. module FSM_Controller
(1) if (current_state == OPEN) begin 에서,
    (state_clk < 1_000_000) -> (state_clk < 1_000) 
(2) OPEN: begin 에서,
    if(state_clk >= 1_000_000) begin -> if(state_clk >= 100) begin

2. module password_check
(clk_counter == 67_000_000) -> (clk_counter == 10) 

3. module hc_sr04
(1) cnt_sysclk의 26번째 비트 상승 에지 검출 -> 12번째
(2) cnt_sysclk의 9번째 비트 상승 에지 검출 -> 5번째

4. module dht11_cntr
(1) S_IDLE: begin 에서,
    (count_usec < 22'd3_000_000) -> (count_usec < 22'd3)
(2) S_LOW_18MS: begin 에서,
    (count_usec < 22'd20_000) -> (count_usec < 22'd200)
    
<sub_module.v>
1. module five_s_timer
(cnt_sysclk >= 250_000_000 - 1) -> (cnt_sysclk >= 5 - 1)


<테스트 시나리오 (Simulation Flow)>
테스트는 initial 블록 안에서 시간 흐름에 따라 순차적으로 진행됩니다.

(1) 초기화: 모든 신호를 리셋하고, 센서 값을 조건 불만족 상태로 설정하여 시작합니다.
(2) 시스템 가동: 스위치(sw_launch)를 눌러 시스템을 대기 모드(SILENT)로 진입시킵니다.
(3) 타이머 및 검증: 일정 시간이 지났다고 가정(timer_done_sim)하고 센서 값을 확인하는 단계(VERIFY)로 넘어갑니다.
(4) 조건 만족 및 개방: force 명령어를 사용해 센서 값을 강제로 "조건 만족" 값으로 변경합니다. 이때 gate_open 신호가 뜨는지 확인합니다.
(5) 암호 모듈 테스트: 문이 열린 상태에서 암호 데이터가 정상적으로 처리되는지 확인합니다.
(6) 예외 상황(Fault) 테스트: 문이 열려있는 도중 센서 값이 비정상(거리가 멀어짐)으로 변했을 때, 시스템이 이를 감지하고 에러 상태(FAULT)로 빠지는지 검증합니다.
