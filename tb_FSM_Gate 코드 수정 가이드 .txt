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
