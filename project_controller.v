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
    integer state_clk;

    // 1. 상태 레지스터
    always @(posedge clk or posedge reset_p) begin
        if(reset_p) current_state <= IDLE;
        else    current_state <= next_state;
    end

    // 2. 다음 상태 결정
    always @(*) begin
        next_state = current_state;
        state_clk = 0; 

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
                // 센서 중 하나라도 꺼지면 에러 발생
                if(state_clk >= 1_000_000)begin
                    state_clk = 0;
                    if(~sonic_sensor_ok || ~dht_sensor_ok) next_state = FAULT; 
                end
                else begin
                    state_clk = state_clk + 1;
                end
            end  
            
            // [추가됨] FAULT 상태 처리
            FAULT: begin
                // 여기서 멈춰있음 (리셋 눌러야 탈출 가능)
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
            // 기본값 설정
            timer_start <= 0;
            gate_open   <= 0;
            state_led   <= 2'b00;

            // 반응성을 위해 next_state를 기준으로 출력 결정
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
                
                // [추가됨] FAULT 상태일 때 LED 점멸 등의 표시 가능
                FAULT: begin
                     state_led <= 2'b00; // 예: OPEN과 같은 LED 혹은 다른 패턴
                     gate_open <= 0;     // 게이트 강제 폐쇄 (안전)
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
            if (clk_counter == 67000000) begin
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
