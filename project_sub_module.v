`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/19/2025 03:36:49 PM
// Design Name: 
// Module Name: project_sub_module
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

module edge_detector_n(
    input clk, reset_p,
    input cp,
    output p_edge, n_edge);

    reg ff_cur, ff_old;
    
    always @(negedge clk, posedge reset_p)begin
        if(reset_p)begin
            ff_cur = 0;
            ff_old = 0;
        end
        else begin
            ff_old = ff_cur;
            ff_cur = cp;
        end
    end
    
    assign p_edge = ({ff_cur, ff_old} == 2'b10) ? 1 : 0;
    assign n_edge = ({ff_cur, ff_old} == 2'b01) ? 1 : 0;
        
endmodule

module button_ctr(
    input clk, reset_p,
    input btn,
    output btn_pedge, btn_nedge);
    
    reg[15:0] cnt_sysclk;
    reg debounced_btn;
    always @(posedge clk, posedge reset_p)begin
        if(reset_p) begin
            cnt_sysclk = 0;
            debounced_btn = 0;
        end
        else begin
            if(cnt_sysclk[15])begin
                debounced_btn = btn;
                cnt_sysclk = 0;
            end
            else cnt_sysclk = cnt_sysclk + 1;
        end   
    end
    
    edge_detector_n ed(.clk(clk), .reset_p(reset_p), .cp(debounced_btn),
                    .p_edge(btn_pedge), .n_edge(btn_nedge));
endmodule

module pwm_Nfreq_Nstep(
    input clk, reset_p,
    input [31:0] duty,
    output reg pwm
);

    parameter SYS_CLK_FREQ = 100_000_000;
    parameter PWM_FREQ = 10_000;
    parameter DUTY_STEP = 200;
    parameter TEMP = SYS_CLK_FREQ / (PWM_FREQ * DUTY_STEP) / 2 - 1;
    
    integer cnt;
    reg pwm_freqXstep;
    always @(posedge clk, posedge reset_p)begin
    
        if(reset_p)begin
            cnt = 0;
            pwm_freqXstep = 0;
        end
        else begin
            if(cnt >= TEMP)begin
                cnt = 0;
                pwm_freqXstep = ~pwm_freqXstep;
            end
            else cnt = cnt + 1;
        end
    end
    
    wire pwm_freqXstep_pedge;
    edge_detector_n ed(.clk(clk), .reset_p(reset_p), .cp(pwm_freqXstep),
                       .p_edge(pwm_freqXstep_pedge));
                       
    integer cnt_duty;
    always @(posedge clk, posedge reset_p)begin
        if(reset_p)begin
            cnt_duty = 0;
        end
        else if(pwm_freqXstep_pedge) begin
            if(cnt_duty >= DUTY_STEP-1)cnt_duty = 0;
            else cnt_duty = cnt_duty + 1;
            
            if(cnt_duty < duty) pwm = 1;
            else pwm = 0;
        end
    end
                    
endmodule