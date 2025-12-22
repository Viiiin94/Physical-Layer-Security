`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/19/2025 03:59:33 PM
// Design Name: 
// Module Name: project_top
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


module prototype_top(
    input clk,
    input reset_p,
    input [2:0] button, // push 버튼
    output[5:0] led_bar_out 
);

bar_led led_bar_module(
    clk,
    reset_p,
    button,   // push 버튼
    led_bar_out 
);

endmodule

module fsm_password_test_top(
    input clk, 
    input reset_p,
    input button,        // 발사 버튼 (BTN)
    input [3:0] s_button, // 각종 센서 및 암호 입력용 스위치
    output [15:0] led    // 상태 표시 LED
    );
    
    // --- 기존 모듈 연결 ---
    wire btn_pedge;
    button_ctr start(.clk(clk), .reset_p(reset_p), .btn(button), .btn_pedge(btn_pedge));
    
    wire clk_sec;
    wire clk_sec_nedge;
    
    five_s_timer sec_timer(
        .clk(clk),
        .reset_p(reset_p),
        .clk_sec(clk_sec),
        .clk_sec_nedge(clk_sec_nedge)
    );

    wire timer_start, gate_open;
    wire [1:0] state_led;
    
    FSM_Controller fsm(
        .clk(clk),
        .reset_p(reset_p),
        .sw_launch(btn_pedge),            // 발사!
        .timer_done(clk_sec_nedge),       // 5초 경과
        .sonic_sensor_ok(s_button[0]),    // 스위치 0번: 고도 센서 역할
        .dht_sensor_ok(s_button[1]),      // 스위치 1번: 온, 습도 센서 역할
        .timer_start(timer_start),
        .gate_open(gate_open),            // ★ 핵심 신호: 문 열어!
        .state_led(state_led)
    );

    // --- [추가] 암호화 모듈 연결 ---
    // s_button[3]을 '보내려는 비밀 암호'라고 가정합니다.
    wire [2:0] crypto_leds;

    password_check my_crypto (
        .clk(clk),
        .reset_p(reset_p),
        .enable(gate_open),     // ★ FSM이 문을 열어줘야만 작동함!
        .data_in(s_button[3]),  // 스위치 3번을 데이터로 사용
        .debug_led(crypto_leds) // 암호화 결과 LED로 출력
    );

    // --- LED 연결 ---
    // [0~7] FSM 상태 표시
    assign led[0] = timer_start;
    assign led[3] = gate_open;      // 문이 열렸는지 확인
    assign led[5] = state_led[0];
    assign led[7] = state_led[1];

    // [13~15] 암호화 동작 확인 (문이 열린 뒤에만 켜짐)
    assign led[13] = crypto_leds[0]; // 원본 데이터 (스위치 3번 따라감)
    assign led[14] = crypto_leds[1]; // 암호화된 데이터 (난수랑 섞여서 깜빡거림)
    assign led[15] = crypto_leds[2]; // 복호화된 데이터 (원본과 같아야 함)

endmodule

module Physica_Layer_Security_test_top(
    input clk, 
    input reset_p,
    input button,          // 발사 버튼 (BTN)
    input [3:0]s_button,   // 비밀번호 slide sw[12, 13, 14, 15]
    output [15:0] led,     // 상태 표시 LED
    input echo,
    output trig,
    inout dht11_data,
    output [7:0] seg,
    output [3:0] com
    );
    
    // --- 기존 모듈 연결 ---
    wire btn_pedge;
    button_ctr start(.clk(clk), .reset_p(reset_p), .btn(button), .btn_pedge(btn_pedge));
    
    wire clk_sec;
    wire clk_sec_nedge;
    
    five_s_timer sec_timer(
        .clk(clk),
        .reset_p(reset_p),
        .clk_sec(clk_sec),
        .clk_sec_nedge(clk_sec_nedge)
    );

    wire timer_start, gate_open;
    wire [1:0] state_led;
    
    wire [7:0] humidity, temperature;
    wire [8:0] distance_cm;
    reg dht11_ok;
    reg sonic_ok;
    
    FSM_Controller fsm(
        .clk(clk),
        .reset_p(reset_p),
        .sw_launch(btn_pedge),            // 발사!
        .timer_done(clk_sec_nedge),       // 5초 경과
        .sonic_sensor_ok(sonic_ok),    // 스위치 0번: 고도 센서 역할
        .dht_sensor_ok(dht11_ok),      // 스위치 1번: 온, 습도 센서 역할
        .timer_start(timer_start),
        .gate_open(gate_open),            // ★ 핵심 신호: 문 열어!
        .state_led(state_led)
    );

    hc_sr04 ultra(.clk(clk), .reset_p(reset_p), .echo(echo), .trig(trig), .distance_cm(distance_cm));

    dht11_cntr DUT(.clk(clk), .reset_p(reset_p), .dht11_data(dht11_data), .humidity(humidity), .temperature(temperature));
    
    always @(posedge clk, posedge reset_p)begin
        if(reset_p)begin
            dht11_ok = 0;
            sonic_ok = 0;
        end
        else begin
            if(humidity >= 8'd10 && temperature >= 8'd10) dht11_ok = 1;
            else dht11_ok = 0;
            if(distance_cm < 9'd300) sonic_ok = 1;
            else sonic_ok = 0;
        end
    end    
    
    // --- [추가] 암호화 모듈 연결 ---
    // s_button[3:0]을 '보내려는 비밀 암호'라고 가정합니다.
    wire [11:0] crypto_leds;

    password_check my_crypto (
        .clk(clk),
        .reset_p(reset_p),
        .enable(gate_open),     // ★ FSM이 문을 열어줘야만 작동함!
        .pw_in(s_button),     // 스위치 15번을 데이터로 사용
        .debug_led(crypto_leds) // 암호화 결과 LED로 출력
    );

    wire [15:0] distance_bcd;
    bin_to_dec btd_x(.bin(distance_cm), .bcd(distance_bcd));
        
    FND_cntr fnd(.clk(clk), .reset_p(reset_p), .fnd_value(distance_bcd), .seg(seg), .com(com));

    // --- LED 연결 ---
    // [0~7] FSM 상태 표시
    assign led[0] = timer_start;
    assign led[1] = gate_open;      // 문이 열렸는지 확인
    assign led[2] = state_led[0];
    assign led[3] = state_led[1];

    // [13~15] 암호화 동작 확인 (문이 열린 뒤에만 켜짐)
    // crypto_leds[11:0] 전체를 led[15:4]에 한 번에 연결
    assign led[15:4] = crypto_leds[11:0];
    
endmodule

module led_mode(
    input clk, reset_p,
    input slide,
    input [2:0] button,
    output led_r, led_g, led_b,
    output [7:0] led_bar_out
    );

    wire [2:0] btn_pedge;
    button_ctr btn0(clk, reset_p, button[0], btn_pedge[0]);
    button_ctr btn1(clk, reset_p, button[1], btn_pedge[1]);
    button_ctr btn2(clk, reset_p, button[2], btn_pedge[2]);
    
    wire [2:0] btn_to_three; // 3색 LED 모듈로 갈 버튼 신호
    wire [2:0] btn_to_bar;   // Bar LED 모듈로 갈 버튼 신호

    assign btn_to_three = (slide == 1'b0) ? btn_pedge : 3'b000;
    assign btn_to_bar   = (slide == 1'b1) ? btn_pedge : 3'b000;
    
    three_led_top thrl(clk, reset_p, btn_to_three, led_r, led_g, led_b);
    bar_led barl(clk, reset_p, btn_to_bar, led_bar_out);
    
endmodule

module led_mode_v2(
    input clk, reset_p,
    input slide,
    input [2:0] button,
    output led_r, led_g, led_b,
    
    // 74HC595 연결용 출력
    output serial_data,  // DS
    output shift_clock,  // SHCP
    output latch_clock   // STCP
    );

    wire [2:0] btn_pedge;
    // 디바운싱 및 엣지 검출 모듈
    button_ctr btn0(clk, reset_p, button[0], btn_pedge[0]);
    button_ctr btn1(clk, reset_p, button[1], btn_pedge[1]);
    button_ctr btn2(clk, reset_p, button[2], btn_pedge[2]);
    
    wire [2:0] btn_to_three; // 3색 LED 모듈로 갈 버튼 신호
    wire [2:0] btn_to_bar;   // Bar LED 모듈로 갈 버튼 신호

    // Slide 스위치에 따른 입력 신호 분기 (MUX)
    assign btn_to_three = (slide == 1'b0) ? btn_pedge : 3'b000;
    assign btn_to_bar   = (slide == 1'b1) ? btn_pedge : 3'b000;
    
    // 1. 3색 LED 모듈 연결 (기존 모듈)
    // (이 모듈도 포트 이름을 명시해주는 것이 좋습니다)
    three_led thrl(
        .clk(clk), 
        .reset_p(reset_p), 
        .button(btn_to_three), // 모듈 내부 포트명이 btn 이라고 가정
        .led_r(led_r), 
        .led_g(led_g), 
        .led_b(led_b)
    );

    // 2. [수정] 74HC595 Bar LED 모듈 연결 (이름 매핑 적용)
    // bar_led_595 모듈 내부의 포트명(.hc_...)과 현재 모듈의 신호명(...)을 매칭
    bar_led_595 barl(
        .clk(clk), 
        .reset_p(reset_p), 
        .button(btn_to_bar),   
        .hc_data(serial_data),   // 내부 포트명: hc_data
        .hc_sclk(shift_clock),   // 내부 포트명: hc_sclk
        .hc_rclk(latch_clock)    // 내부 포트명: hc_rclk
    );
    
endmodule

//74HC595 연결 다이어그램 (참고용)
//SER (DS, Pin 14): 직렬 데이터 입력 (hc_data)
//SRCLK (SH_CP, Pin 11): 쉬프트 클럭 (hc_sclk)
//RCLK (ST_CP, Pin 12): 래치(저장) 클럭 (hc_rclk)

module tree_and_rocket_top(
    input clk, 
    input reset_p,
    input mode_s_button,             // rocket, tree mode 선택 slide button
    // input_tree
    input [2:0] button,              // tree mode change push button
    input tree_led_change_s_button,  // 두 개의 led 중 모드를 변경 할 led 선택  
    // input rocket
    input rocket_start_push_button,  // rocket start push button
    input [3:0]rocket_pw_s_button,   // rocket 비밀번호 (1010)
    output [15:0] led,               // 상태 표시 LED
    // in, out sensor
    input echo,
    output trig,
    inout dht11_data,
    // sonic sensor display
    output [7:0] seg,
    output [3:0] com,
    // tree display
    output led_r, led_g, led_b,
    output serial_data, shift_clock, latch_clock
);

    wire bin_to_rocket;                   // rocket 모듈로 갈 버튼 신호
    wire bin_to_tree_led_r;               // led_r 로 갈 led 신호 
    wire bin_to_tree_led_g;               // led_g 로 갈 led 신호 
    wire bin_to_tree_led_b;               // led_b 로 갈 led 신호 
    wire w_serial, w_shift, w_latch;      // Tree 모듈에서 나오는 신호
    
    Physica_Layer_Security_test_top rocket(
        .clk(clk), 
        .reset_p(reset_p),
        .button(btn_to_rocket),               // 발사 버튼 (BTN)
        .s_button(rocket_pw_s_button),        // 비밀번호 slide sw[15]
        .led(led),                            // 상태 표시 LED
        .echo(echo),
        .trig(trig),
        .dht11_data(dht11_data),
        .seg(seg),
        .com(com)
        );
    
    led_mode_v2 tree(
        .clk(clk), 
        .reset_p(reset_p),
        .button(button),
        .slide(tree_led_change_s_button),
        .led_r(bin_to_tree_led_r), 
        .led_g(bin_to_tree_led_g), 
        .led_b(bin_to_tree_led_b),
        // 595 신호 연결
        .serial_data(w_serial),
        .shift_clock(w_shift),
        .latch_clock(w_latch)
        );
    
    assign btn_to_rocket = (mode_s_button == 1'b1) ? rocket_start_push_button : 1'b0;
    assign led_r         = (mode_s_button == 1'b0) ? bin_to_tree_led_r        : 1'b0;
    assign led_g         = (mode_s_button == 1'b0) ? bin_to_tree_led_g        : 1'b0;
    assign led_b         = (mode_s_button == 1'b0) ? bin_to_tree_led_b        : 1'b0;
    assign serial_data   = (mode_s_button == 1'b0) ? w_serial                 : 1'b0;
    assign shift_clock   = (mode_s_button == 1'b0) ? w_shift                  : 1'b0;
    assign latch_clock   = (mode_s_button == 1'b0) ? w_latch                  : 1'b0;
    
endmodule