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
            if(s_button && reight_left)begin
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
            if(s_button && on_off_mode)begin
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