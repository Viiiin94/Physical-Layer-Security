`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/19/2025 03:34:10 PM
// Design Name: 
// Module Name: project_controller
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// ==========================================
// button[0]: r, g, b 변경
// button[1]: 기본모드 or 느리게 깜빡임 
// button[2]: 기본모드 or 빠르게 깜빡임 
// ==========================================
module three_led_top(
    input clk, reset_p,
    input [2:0] button,
    output led_r, led_g, led_b
);

// 1. 모드 정의
    localparam MODE_COLOR_CYCLE = 3'b001; // 버튼 0: 색상 자동 순환
    localparam MODE_DIMMING     = 3'b010; // 버튼 1: 숨쉬기
    localparam MODE_FAST_BLINK  = 3'b100; // 버튼 2: 빠르게 깜빡임
    
    reg [2:0] current_mode;
    reg [1:0] color_sel;

    wire [2:0] btn_pedge;
    button_ctr btn_cycle(clk, reset_p, button[0], btn_pedge[0]);
    button_ctr btn_dimming(clk, reset_p, button[1], btn_pedge[1]);
    button_ctr btn_blink(clk, reset_p, button[2], btn_pedge[2]);
    
    always @(posedge clk or posedge reset_p) begin
        if(reset_p) begin
            current_mode <= MODE_COLOR_CYCLE;
            color_sel <= 0; 
        end
        else begin
            // [버튼 0] 색상 변경 (R->G->B->R...)
            if (btn_pedge[0]) begin
                if(color_sel >= 2) color_sel <= 0;
                else color_sel <= color_sel + 1;
            end
            // [버튼 1] 서서히 켜졌다 꺼짐
            else if (btn_pedge[1]) begin 
                if (current_mode == MODE_DIMMING) begin
                    current_mode <= MODE_COLOR_CYCLE; // 이미 켜져있으면 -> 끔 (기본모드 복귀)
                end
                else begin
                    current_mode <= MODE_DIMMING;
                end
            end
            // [버튼 2] 빠르게 깜빡
            else if (btn_pedge[2]) begin 
                // 이미 깜빡임 모드라면? -> 기본 모드(그냥 켜짐)로 복귀
                if (current_mode == MODE_FAST_BLINK) begin
                    current_mode <= MODE_COLOR_CYCLE;
                end
                // 아니라면? -> 깜빡임 모드 진입
                else begin
                    current_mode <= MODE_FAST_BLINK;
                end
            end
        end
    end
    
    reg [7:0] duty_count;
    reg dimming_state;
    reg [23:0] dimming_duty_count;
    
    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            duty_count <= 0;
            dimming_state <= 0;
            dimming_duty_count <= 0;
        end
        else begin
            if (dimming_duty_count >= 24'd250_000) begin 
                dimming_duty_count <= 0;
                if (dimming_state == 0) begin // 밝아지는 중
                    if (duty_count == 8'd255) dimming_state <= 1;
                    else duty_count <= duty_count + 1;
                end
                else begin // 어두워지는 중
                    if (duty_count == 8'd0) dimming_state <= 0;
                    else duty_count <= duty_count - 1;
                end
            end
            else begin
                dimming_duty_count <= dimming_duty_count + 1;
            end
        end
    end
    
    reg blink_on_off;
    reg [23:0] blink_timer;
    
    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            blink_on_off <= 0;
            blink_timer <= 0;
        end
        else begin
            if (blink_timer >= 24'd5_000_000) begin 
                blink_timer <= 0;
                blink_on_off <= ~blink_on_off;
            end
            else begin
                blink_timer <= blink_timer + 1;
            end
        end
    end
    
    reg [7:0] r_duty, g_duty, b_duty;
    always @(*) begin
        r_duty = 0; g_duty = 0; b_duty = 0;

        case(current_mode)
            // 모드 1: 수동 색상 변경 (버튼 0)
            MODE_COLOR_CYCLE: begin
                case(color_sel)
                    0: r_duty = 255; // Red
                    1: g_duty = 255; // Green
                    2: b_duty = 255; // Blue
                    default: begin r_duty=0; g_duty=0; b_duty=0; end
                endcase
            end

            // 모드 2: 숨쉬기 (버튼 1)
            MODE_DIMMING: begin
                case(color_sel)
                    0: r_duty = duty_count; // Red
                    1: g_duty = duty_count; // Green
                    2: b_duty = duty_count; // Blue
                    default: begin r_duty=0; g_duty=0; b_duty=0; end
                endcase
            end

            // 모드 3: 빠른 깜빡임 (버튼 2)
            MODE_FAST_BLINK: begin
                // blink_on_off가 1이면 최대 밝기, 0이면 꺼짐
                if(blink_on_off) begin
                    case(color_sel)
                        0: r_duty = 255; // Red
                        1: g_duty = 255; // Green
                        2: b_duty = 255; // Blue
                        default: begin r_duty=0; g_duty=0; b_duty=0; end
                    endcase
                end
                else begin
                    r_duty = 0; g_duty = 0; b_duty = 0;
                end
            end
        endcase
    end
    
    pwm_Nfreq_Nstep led_pwm_red(.clk(clk), .reset_p(reset_p), .duty(r_duty), .pwm(led_r));
    pwm_Nfreq_Nstep led_pwm_green(.clk(clk), .reset_p(reset_p), .duty(g_duty), .pwm(led_g));
    pwm_Nfreq_Nstep led_pwm_blue(.clk(clk), .reset_p(reset_p), .duty(b_duty), .pwm(led_b));    
endmodule

// ==========================================
// button[0]: 왼쪽 shift / 우측 shift 변환
// button[1]: 깜빡임 
// button[2]: 깜빡임 없음
// ==========================================

module bar_led(
    input clk,
    input reset_p,
    input [2:0] button, // push 버튼
    output reg [5:0] led_bar_out 
);
    
    reg reight_left;
    always @(posedge clk, posedge reset_p) begin
        if(reset_p)begin
            reight_left = 0; 
        end
        if(button[0])begin
            reight_left = ~reight_left;
        end
    end
    
    reg [5:0] shift;
    reg on_off_mode;
    reg [26:0] clk_counter;
    reg [26:0] clk_shift_counter;
     
    always @(posedge clk, posedge reset_p) begin
        if (reset_p) begin
             shift = 5'b000001;
             clk_counter = 0;
             led_bar_out = 0;
        end
        else begin
            if(reight_left)begin
                if(clk_shift_counter == 10000000)begin
                    clk_shift_counter = 0;
                    shift = {shift[0], shift[5:1]};
                end
                else begin
                    clk_shift_counter = clk_shift_counter + 1;
                end
            end
            else begin
                 if(clk_shift_counter == 10000000)begin
                    clk_shift_counter = 0;
                    shift = {shift[4:0], shift[5]};
                end
                else begin
                    clk_shift_counter = clk_shift_counter + 1;
                end           
            end
            if(on_off_mode)begin
                if (clk_counter < 100000000) begin
                    clk_counter = clk_counter + 1;
                    led_bar_out[5:0] = 0;
                end 
                else if(clk_counter < 200000000)  begin
                    clk_counter = clk_counter + 1;
                    led_bar_out[5:0] = shift;
                end
                else if(clk_counter >= 200000000) begin
                    clk_counter =0;
                end
            end
            else begin
                led_bar_out[5:0] = shift;
            end
        end
    end
 
    reg [26:0] clk_counter;

    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            on_off_mode = 0;
        end 
        else if(button[1]) begin
            on_off_mode = 1;
        end
        else if(button[2])begin
            on_off_mode = 0;
        end
    end   
endmodule

module FSM_Controller(
    input clk,
    input reset_p,
    input sw_launch,
    input timer_done,
    input sonic_sensor_ok,
    input dht_sensor_ok,
    
    output reg timer_start,
    output reg gate_open,
    output reg [1:0] state_led
    );

    localparam IDLE   =  3'd0;
    localparam SILENT =  3'd1;
    localparam VERIFY =  3'd2;
    localparam OPEN   =  3'd3;
    localparam FAULT  =  3'd4;

    reg [2:0] current_state, next_state;
    
    // [수정 1] 카운터는 반드시 reg여야 하며, 별도 로직으로 분리
    integer state_clk; 

    // 1. 상태 레지스터
    always @(posedge clk or posedge reset_p) begin
        if(reset_p) current_state <= IDLE;
        else    current_state <= next_state;
    end

    // [수정 2] 카운터 로직 (순차 회로: 클럭에 맞춰 동작)
    always @(posedge clk or posedge reset_p) begin
        if(reset_p) begin
            state_clk <= 0;
        end
        else begin
            // OPEN 상태일 때만 숫자를 센다
            if (current_state == OPEN) begin
                // 시뮬레이션용으로 1000 정도로 작게 설정 (실제는 1,000,000)
                if (state_clk < 1_000_000) 
                    state_clk <= state_clk + 1;
            end
            else begin
                state_clk <= 0; // 다른 상태면 초기화
            end
        end
    end

    // 2. 다음 상태 결정 (조합 회로)
    always @(*) begin
        next_state = current_state;
        
        case(current_state)
            IDLE: begin
                if(sw_launch) next_state = SILENT;
            end
            
            SILENT: begin
                if(timer_done) next_state = VERIFY;
            end
            
            VERIFY: begin
                if(sonic_sensor_ok && dht_sensor_ok) next_state = OPEN; 
            end

            OPEN: begin
                // [수정 3] 카운터 값만 확인 (여기서 더하지 않음)
                // 시뮬레이션용 숫자(1000)와 맞춰줌
                if(state_clk >= 1_000_000) begin
                    // 시간이 좀 지난 뒤에 센서가 꺼지면 에러로 이동
                    if(~sonic_sensor_ok || ~dht_sensor_ok) next_state = FAULT; 
                end
            end  
            
            FAULT: begin
                next_state = FAULT;
            end

            default: next_state = IDLE;
        endcase
    end

    // 3. 출력 로직 (Look-ahead Output)
    always @(posedge clk or posedge reset_p) begin
        if(reset_p) begin
            timer_start <= 0;
            gate_open   <= 0;
            state_led   <= 2'b00;
        end
        else begin
            timer_start <= 0;
            gate_open   <= 0;
            state_led   <= 2'b00;

            case(next_state) 
                IDLE: begin
                    state_led <= 2'b00;
                end
                
                SILENT: begin
                    timer_start <= 1; 
                    state_led   <= 2'b01;
                end
                
                VERIFY: begin
                    state_led <= 2'b10;
                end
                
                OPEN: begin
                    state_led <= 2'b11;
                    gate_open <= 1;
                end
                
                FAULT: begin
                      state_led <= 2'b00; 
                      gate_open <= 0;      
                end
            endcase
        end
    end
endmodule

module password_check(
    input clk,
    input reset_p,
    input enable,          // FSM의 gate_open 신호와 연결 (문이 열려야 작동)
    input data_in,         // 보내려는 데이터 (스위치 등)
    output [2:0] debug_led // 상태 확인용 LED
);

    reg [3:0] r_lfsr;
    wire feedback;
    reg [26:0] clk_counter;
    reg clk_enable;

    // 1. 난수 생성기 (LFSR)
    assign feedback = r_lfsr[3] ^ r_lfsr[2]; 

    // 2. 시간 지연 (눈으로 깜빡임 확인용, 약 0.6초)
    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            clk_counter <= 0;
            clk_enable <= 0;
        end else begin
            if (clk_counter == 67_000_000) begin // 67000000
                clk_counter <= 0;
                clk_enable <= 1;
            end else begin
                clk_counter <= clk_counter + 1;
                clk_enable <= 0;
            end
        end
    end

    // 3. LFSR 난수값 갱신
    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            r_lfsr <= 4'b0001; // 초기 시드값
        end else begin
            if (clk_enable == 1) begin
                r_lfsr <= {r_lfsr[2:0], feedback}; 
            end
        end
    end

    // =========================================================
    // 암호화 로직 (XOR Cipher)
    // =========================================================
    
    // 키(Key): LFSR에서 나온 난수 (r_lfsr[0])
    wire key_bit = r_lfsr[0];

    // 암호화: 데이터 ^ 키
    wire encrypted_data = data_in ^ key_bit;

    // 복호화: 암호문 ^ 키 (원래 데이터가 나와야 함)
    wire decrypted_data = encrypted_data ^ key_bit;

    // =========================================================
    // 출력 제어 (물리적 차단 구현)
    // =========================================================
    
    // enable(gate_open)이 1일 때만 LED에 신호를 보냄
    // 문이 닫혀있으면(0) LED는 꺼짐(0)
    assign debug_led[0] = (enable) ? data_in : 1'b0;        // 원본
    assign debug_led[1] = (enable) ? encrypted_data : 1'b0; // 암호문 (막 깜빡임)
    assign debug_led[2] = (enable) ? decrypted_data : 1'b0; // 복호문 (원본과 같음)

endmodule

module hc_sr04(
    input clk, reset_p,          // clk: 100MHz 시스템 클럭, reset_p: High 레벨 리셋 신호
    input echo,                  // echo: 초음파 센서로부터 들어오는 에코 신호 (입력)
    output reg trig,             // trig: 초음파 센서로 보내는 트리거 신호 (출력)
    output reg [8:0] distance_cm // distance_cm: 계산된 거리 값 (cm 단위)
    );
    
    // [파라미터 설정]
    // 소리의 속도: 340m/s = 34,000cm/s
    // 1cm를 왕복(2cm)하는 데 걸리는 시간: 2cm / 34,000cm/s ≈ 58.8us
    // 따라서 58us마다 거리가 1cm씩 증가한다고 봅니다.
    localparam time_1cm = 58; 

    // [변수 선언]
    integer cnt_sysclk;   // 전체 시스템 타이밍용 메인 카운터 (Trigger 생성용)
    integer cnt_sysclk0;  // 1us 단위를 만들기 위한 클럭 분주용 카운터
    integer cnt_usec;     // 1cm 거리 환산(58us)을 세기 위한 마이크로초 카운터
    
    reg count_usec_e;     // 거리 측정을 시작할지 결정하는 Enable 신호 (Echo가 High일 때 1)
    reg [8:0] cnt_cm;     // 측정 중인 현재 거리를 저장하는 임시 카운터 (cm 단위)
    
    // [메인 시스템 카운터]
    // Trigger 신호의 주기와 펄스 폭을 결정하기 위해 계속 숫자를 증가시킴
    always @(posedge clk) cnt_sysclk = cnt_sysclk + 1;
    
    // [거리 계산 로직]
    // Echo 신호가 떠 있는 동안 시간을 재서 cm 단위로 변환하는 핵심 블록
    always @(posedge clk, posedge reset_p) begin
        if(reset_p) begin
            // 리셋 시 모든 카운터 초기화
            cnt_sysclk0 = 0;
            cnt_usec = 0;
            cnt_cm = 0;
        end
        else if(count_usec_e) begin // Echo가 High가 되어 측정이 시작되면(Enable = 1)
            // 1. 1us 시간 만들기 (100MHz 클럭 기준: 10ns * 100 = 1000ns = 1us)
            // 0~99까지 세면 100클럭이므로 1us가 됨
            if(cnt_sysclk0 >= 99) begin
                cnt_sysclk0 = 0; // 1us가 지나면 초기화하고 다음 단계로
                
                // 2. 1cm 거리 환산 (58us마다 1cm 증가)
                if(cnt_usec >= time_1cm - 1) begin // 58us가 되었는지 확인
                    cnt_usec = 0;       // 58us 카운터 초기화
                    cnt_cm = cnt_cm + 1; // 거리를 1cm 증가시킴
                end
                else cnt_usec = cnt_usec + 1; // 아직 58us가 안 됐으면 us 카운터 증가
            end
            else cnt_sysclk0 = cnt_sysclk0 + 1; // 아직 1us가 안 됐으면 클럭 카운터 증가
        end
        else begin
            // 측정이 아닐 때는(Echo가 Low일 때) 계산용 카운터들을 0으로 대기시킴
            cnt_sysclk0 = 0;
            cnt_usec = 0;
            cnt_cm = 0;
        end
    end
    
    // [엣지 디텍터 연결]
    // 카운터의 특정 비트가 0->1로 변하는 순간(Rising Edge)을 포착하기 위함
    wire cnt26_pedge, cnt9_pedge;
    
    // cnt_sysclk의 26번째 비트 상승 에지 검출 -> Trigger 주기를 결정 (약 0.67초마다)
    edge_detector_n ed26(.clk(clk), .reset_p(reset_p), .cp(cnt_sysclk[26]), .p_edge(cnt26_pedge));
    
    // cnt_sysclk의 9번째 비트 상승 에지 검출 -> Trigger 펄스 폭을 결정 (약 5~10us)
    edge_detector_n ed9(.clk(clk), .reset_p(reset_p), .cp(cnt_sysclk[9]), .p_edge(cnt9_pedge));                       
                       
    // [Trigger 신호 생성]
    // 센서에게 "초음파를 발사하라"는 명령 신호 생성
    always @(posedge clk, posedge reset_p) begin
        if(reset_p) begin
            trig = 0;        
        end
        // 약 0.67초마다(2^26 * 10ns) 트리거를 High로 올림
        else if(cnt26_pedge) trig = 1; 
        // 트리거가 High가 된 후, 짧은 시간 뒤에(2^9 * 10ns ≈ 5.12us 주기) 다시 Low로 내림
        // HC-SR04는 최소 10us 펄스가 필요하므로 이 부분은 펄스 폭을 만드는 역할을 함
        else if(cnt9_pedge) trig = 0;  
    end
    
    // [Echo 신호 엣지 검출]
    // 센서에서 돌아온 Echo 신호의 시작(상승)과 끝(하강)을 감지
    wire echo_pedge, echo_nedge;
    edge_detector_n ed_echo(.clk(clk), .reset_p(reset_p), .cp(echo), .p_edge(echo_pedge), .n_edge(echo_nedge)); 
    
    // [거리 측정 제어 및 출력 업데이트]
    always @(posedge clk, posedge reset_p) begin
        if(reset_p) begin
            distance_cm = 0;
            count_usec_e = 0;        
        end
        else if(echo_pedge) begin
            // Echo 신호가 0->1로 올라가면(초음파 발사 직후), 시간 측정을 시작하라고 신호를 줌
            count_usec_e = 1;
        end
        else if(echo_nedge) begin
            // Echo 신호가 1->0으로 떨어지면(초음파가 되돌아옴), 측정을 중단함
            count_usec_e = 0;
            // 지금까지 잰 거리(cnt_cm)를 최종 출력(distance_cm)에 업데이트
            distance_cm = cnt_cm;
        end
    end 
endmodule

module dht11_cntr(
    input clk, reset_p,            // clk: 시스템 클럭, reset_p: 리셋 신호 (Active High)
    inout dht11_data,              // dht11_data: 센서와 연결된 양방향 데이터 선 (inout 포트)
    output reg [7:0] humidity,     // humidity: 읽어온 습도 값 (정수 부분만 사용)
    output reg [7:0] temperature,  // temperature: 읽어온 온도 값 (정수 부분만 사용)
    output [15:0] led              // led: 디버깅용 LED 출력 (현재 코드에서는 연결된 로직 없음)
    );

    // [상태 머신 상태 정의 - One-hot 인코딩 방식]
    localparam S_IDLE      = 6'b00_0001; // 대기 상태 (3초 대기)
    localparam S_LOW_18MS  = 6'b00_0010; // MCU가 시작 신호를 보내는 상태 (18ms 이상 Low 유지)
    localparam S_HIGH_20US = 6'b00_0100; // MCU가 신호를 풀고 센서 응답을 기다리는 준비 상태
    localparam S_LOW_80US  = 6'b00_1000; // 센서가 응답 신호(Low)를 보내는 구간 확인
    localparam S_HIGH_80US = 6'b01_0000; // 센서가 응답 신호(High)를 보내는 구간 확인
    localparam S_READ_DATA = 6'b10_0000; // 실제 40비트 데이터를 읽는 상태
    
    // [데이터 읽기용 서브 상태 정의]
    localparam S_WAIT_PEDGE = 2'b01; // 비트 시작 전 Low 구간이 끝나길(상승 엣지) 기다림
    localparam S_WAIT_NEDGE = 2'b10; // 비트 데이터 구간(High)이 끝나길(하강 엣지) 기다림
    
    // [1us(마이크로초) 클럭 생성기 인스턴스]
    // DHT11은 시간 길이로 0과 1을 구분하므로 정밀한 시간 측정이 필요함
    wire clk_usec_nedge;
    clock_usec usec_clk(
        .clk(clk), 
        .reset_p(reset_p),
        .clk_usec_nedge(clk_usec_nedge) // 1us마다 떨어지는 엣지 신호 발생
    );
    
    // [시간 측정용 카운터]
    reg [21:0] count_usec; // 최대 약 4초까지 셀 수 있는 넉넉한 비트 폭
    reg count_usec_e;      // 카운터 동작 허용 신호 (Enable)
    
    always @(negedge clk, posedge reset_p) begin
        if(reset_p) begin
            count_usec = 0; // 리셋 시 카운터 0으로 초기화
        end
        // 1us 클럭이 발생하고(Enable 상태일 때만) 카운터 증가
        else if(clk_usec_nedge && count_usec_e) count_usec = count_usec + 1;
        // Enable이 꺼지면 카운터를 0으로 리셋 (다음 측정을 위해 대기)
        else if(!count_usec_e) count_usec = 0;
    end
    
    // [엣지 검출기 인스턴스]
    // DHT11 데이터 라인의 신호 변화(상승/하강)를 감지하기 위함
    wire dht_nedge, dht_pedge;
    edge_detector_p ed(
        .clk(clk), 
        .reset_p(reset_p), 
        .cp(dht11_data),    // DHT11 데이터 라인 감시
        .p_edge(dht_pedge), // 상승 엣지(0->1) 감지 신호
        .n_edge(dht_nedge)  // 하강 엣지(1->0) 감지 신호
    );

    // [양방향(inout) 포트 제어 로직]
    // DHT11 데이터 핀은 하나로 입력과 출력을 모두 해야 함 (Tri-state Buffer)
    reg dht11_data_buffer, dht11_data_out_e;
    // dht11_data_out_e가 1이면: 출력 모드 (buffer 값을 내보냄)
    // dht11_data_out_e가 0이면: 입력 모드 (High-Z 상태, 외부에서 신호를 읽음)
    assign dht11_data = dht11_data_out_e ? dht11_data_buffer : 'bz;
  
    // [상태 머신: 현재 상태 레지스터 업데이트]
    reg [5:0] state, next_state;
    always @(negedge clk, posedge reset_p) begin
        if(reset_p) state = S_IDLE; // 리셋 시 IDLE 상태로
        else state = next_state;    // 그 외엔 다음 상태로 업데이트
    end
    
    assign led[5:0] = state; // 디버깅용
    // [데이터 처리용 변수]
    reg [39:0] temp_data;   // 읽어온 40비트 데이터를 임시 저장할 공간
    reg [5:0] cnt_data;     // 읽은 비트 개수 카운터 (0~40)
    assign led[15:10] = cnt_data; // 디버깅용
    reg [1:0] read_state;   // 데이터 읽기 단계의 내부 상태
    
    // [상태 머신: 다음 상태 및 출력 로직]
    always @(posedge clk, posedge reset_p) begin
        if(reset_p) begin
            // 리셋 시 모든 변수 초기화
            next_state = S_IDLE;
            temp_data = 0;
            cnt_data = 0;
            count_usec_e = 0;
            dht11_data_out_e = 0;
            dht11_data_buffer = 0;
            read_state = S_WAIT_PEDGE;
        end
        else begin
            case(state)
                // 1. [대기 상태]
                // DHT11은 전원 인가 후 안정화 시간이 필요하며, 연속 측정 시 일정 간격 필요
                S_IDLE: begin 
                    // 3초(3,000,000us) 동안 대기
                    if(count_usec < 22'd3_000_000) begin
                        count_usec_e = 1;      // 타이머 작동
                        dht11_data_out_e = 0;  // 입력 모드 (Pull-up 저항에 의해 High 유지됨)
                    end
                    else begin
                        count_usec_e = 0;        // 타이머 리셋
                        next_state = S_LOW_18MS; // 시작 신호 보내러 이동
                    end
                end

                // 2. [시작 신호 전송]
                // MCU가 데이터 선을 18ms 이상 Low로 떨어뜨려 센서를 깨움
                S_LOW_18MS: begin
                    if(count_usec < 22'd20_000) begin // 20ms(20_000) 동안 (넉넉하게 18ms 이상)
                        count_usec_e = 1;             // 타이머 작동
                        dht11_data_out_e = 1;         // 출력 모드 전환
                        dht11_data_buffer = 0;        // 데이터 선에 '0' (Low) 출력
                    end
                    else begin
                        count_usec_e = 0;             // 타이머 리셋
                        dht11_data_out_e = 0;         // 출력 모드 해제 (입력 모드/High-Z) -> Pull-up에 의해 High가 됨
                        next_state = S_HIGH_20US;
                    end
                end 

                // 3. [센서 응답 대기 준비]
                // MCU가 손을 뗀 후(High), 센서가 응답(Low)을 줄 때까지 대기
                S_HIGH_20US: begin
                    if(dht_nedge) begin
                        count_usec_e = 0;
                        next_state = S_LOW_80US;
                    end                
                end

                // 4. [센서 응답 신호: Low 구간]
                // DHT11은 응답으로 약 80us 동안 Low를 유지함
                S_LOW_80US: begin
                    // 센서가 Low 신호를 끝내고 High로 올리면(상승 엣지)
                    if(dht_pedge) begin
                        next_state = S_HIGH_80US;
                    end                
                end 

                // 5. [센서 응답 신호: High 구간]
                // DHT11은 다시 약 80us 동안 High를 유지함. 이 구간이 끝나면 데이터 전송 시작.
                S_HIGH_80US: begin
                    // 센서가 High 신호를 끝내고 데이터 전송을 위해 Low로 내리면(하강 엣지)
                    if(dht_nedge) begin
                        next_state = S_READ_DATA; // 데이터 읽기 단계로 진입
                    end                
                end

                // 6. [데이터 읽기 (40비트)]
                // 데이터 포맷: 50us Low -> (26~28us High = '0') or (70us High = '1')
                S_READ_DATA: begin
                    case(read_state)
                        // [비트 시작 대기] 
                        // 모든 비트는 50us의 Low 신호로 시작함. 이 Low가 끝나길(상승 엣지) 기다림.
                        S_WAIT_PEDGE: begin
                            if(dht_pedge) read_state = S_WAIT_NEDGE;
                            count_usec_e = 0; // High 구간 길이를 재야 하므로 카운터 리셋 대기
                        end

                        // [비트 값 판별]
                        // High 구간의 길이를 측정하여 0인지 1인지 판별
                        S_WAIT_NEDGE: begin
                            count_usec_e = 1; // High 구간 시간 측정 시작
                            if(dht_nedge) begin // High 구간이 끝나면(하강 엣지)
                                // High 유지 시간이 50us보다 짧으면 '0', 길면 '1'로 판단
                                // (스펙상 '0': ~28us, '1': ~70us 이므로 기준을 50us로 잡음)
                                if(count_usec < 50) temp_data = {temp_data[38:0], 1'b0}; // 왼쪽으로 밀고 0 추가
                                else temp_data = {temp_data[38:0], 1'b1};                // 왼쪽으로 밀고 1 추가
                                
                                cnt_data = cnt_data + 1; // 읽은 비트 수 증가
                                read_state = S_WAIT_PEDGE; // 다음 비트 읽기 준비
                            end
                        end
                        default: read_state = S_WAIT_PEDGE;
                    endcase

                    // [40비트 다 읽었는지 확인]
                    if(cnt_data >= 40) begin 
                        next_state = S_IDLE; // 다시 처음 대기 상태로 복귀
                        cnt_data = 0;        // 비트 카운터 초기화
                        
                        // [데이터 파싱]
                        // DHT11 데이터 구조: 습도 정수(8bit) + 습도 소수(8bit) + 온도 정수(8bit) + 온도 소수(8bit) + 체크섬(8bit)
                        // 여기서는 정수 부분만 잘라서 출력에 연결
                        humidity = temp_data[39:32];    // 상위 8비트: 습도
                        temperature = temp_data[23:16]; // 3번째 바이트: 온도
                    end                    
                end
                default: next_state = S_IDLE;
            endcase
        end
    end
endmodule 

module FND_cntr(
    input clk, reset_p,
    input [15:0] fnd_value,
    output [7:0] seg,
    output reg[3:0] com);
    
    reg [16:0] clk_div;
    always @(posedge clk)clk_div = clk_div + 1;
    
    wire clk_div_ed;
    edge_detector_n ed_com(.clk(clk), .reset_p(reset_p), .cp(clk_div[16]), .p_edge(clk_div_ed));
    
    always @(posedge clk, posedge reset_p) begin
        if(reset_p)com = 4'b1110;
        else if (clk_div_ed) begin
            if(com[0] + com[1] + com[2] + com[3] != 3) com = 4'b1110;
            else com = {com[2:0], com[3]};
        end
    end

    reg [3:0] digit_value;
    
    always @(posedge clk, posedge reset_p)begin
        if(reset_p)digit_value = 0;
        else begin
            case(com)
                4'b1110: digit_value = fnd_value[3:0];
                4'b1101: digit_value = fnd_value[7:4];
                4'b1011: digit_value = fnd_value[11:8];
                4'b0111: digit_value = fnd_value[15:12];
            endcase
        end
    end
    
    seg_decoder dec(.hex_value(digit_value),.seg(seg));
    
endmodule 