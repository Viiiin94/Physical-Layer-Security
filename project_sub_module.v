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

module edge_detector_p(
    input clk, reset_p,
    input cp,
    output p_edge, n_edge);

    reg ff_cur, ff_old;
    
    always @(posedge clk, posedge reset_p)begin
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

module five_s_timer(
    input clk, reset_p,
    output reg clk_sec,
    output clk_sec_nedge, clk_sec_pedge
    );
    
    // 32비트 정수형 (21억까지 저장 가능하므로 2.5억은 충분함)
    integer cnt_sysclk;

    always @(posedge clk, posedge reset_p) begin
        if(reset_p) begin
            cnt_sysclk <= 0;
            clk_sec <= 0;
        end
        else begin
            // 100MHz 기준: 250,000,000 = 2.5초
            // 2.5초 Low -> 2.5초 High = 1주기 5초
            if(cnt_sysclk >= 250_000_000 - 1) begin 
                cnt_sysclk <= 0;
                clk_sec <= ~clk_sec;
            end
            else begin
                cnt_sysclk <= cnt_sysclk + 1;
            end
        end
    end
    
    // [중요] 포트 연결 오류 수정됨
    edge_detector_n ed(
        .clk(clk), 
        .reset_p(reset_p), 
        .cp(clk_sec), 
        .p_edge(clk_sec_pedge), // p_edge는 p_edge로 연결 
        .n_edge(clk_sec_nedge)  // n_edge는 n_edge로 연결
    );
 
endmodule

// 1us, duty 50%
module clock_usec(
    input clk, reset_p,
    output reg clk_usec,
    output clk_usec_nedge, clk_usec_pedge);
    
    reg [5:0] cnt_sysclk;
    always @(posedge clk, posedge reset_p)begin
        if(reset_p)begin
            cnt_sysclk = 0;
            clk_usec = 0;
        end
        else begin
            if(cnt_sysclk >= 49)begin //49였음 
                cnt_sysclk = 0;
                clk_usec = ~clk_usec;
            end
            else cnt_sysclk = cnt_sysclk + 1;
        end
    end
    
    edge_detector_n ed(.clk(clk), .reset_p(reset_p), 
                           .cp(clk_usec), .p_edge(clk_usec_pedge), .n_edge(clk_usec_nedge));
 
endmodule

module seg_decoder(
    input [3:0] hex_value,
    output reg [7:0] seg);

    always @(hex_value) begin
        case(hex_value)
            //             pgfe_dcba
            4'd0: seg = 8'b1100_0000;
            4'd1: seg = 8'b1111_1001;
            4'd2: seg = 8'b1010_0100;
            4'd3: seg = 8'b1011_0000;
            4'd4: seg = 8'b1001_1001;
            4'd5: seg = 8'b1001_0010;
            4'd6: seg = 8'b1000_0010;
            4'd7: seg = 8'b1111_1000;
            4'd8: seg = 8'b1000_0000;
            4'd9: seg = 8'b1001_1000;
            
            4'd10: seg = 8'b1000_1000; // A
            4'd11: seg = 8'b1000_0011; // B
            4'd12: seg = 8'b1100_0110; // C
            4'd13: seg = 8'b1010_0001; // D
            4'd14: seg = 8'b1000_0110; // E
            4'd15: seg = 8'b1000_1110; // F
            
        endcase
    end   
endmodule

module bin_to_dec(
    input [11:0] bin,
    output reg[15:0] bcd);

    integer i;
    
    always @(bin) begin
        bcd = 0;
        for(i = 0; i < 12; i = i+1) begin
            if(bcd[3:0] >= 5) bcd[3:0] = bcd[3:0] + 3; 
            if(bcd[7:4] >= 5) bcd[7:4] = bcd[7:4] + 3;
            if(bcd[11:8] >= 5) bcd[11:8] = bcd[11:8] + 3;
            if(bcd[15:12] >= 5) bcd[15:12] = bcd[15:12] + 3;
            bcd = {bcd[14:0], bin[11-i]};
        end
    end

endmodule