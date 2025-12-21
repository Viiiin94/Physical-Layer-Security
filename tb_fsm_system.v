`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/21/2025 11:04:08 AM
// Design Name: 
// Module Name: tb_fsm_system
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


module tb_FSM_Gate();

    // 1. 입력 신호 정의 (Reg)
    reg clk;
    reg reset_p;
    reg sw_launch;
    reg timer_done_sim; // 외부 타이머가 완료되었다고 가정하는 신호
    
    // 암호 모듈용 데이터 입력
    reg password_data_in;

    // 2. 출력 신호 연결 (Wire)
    wire timer_start;
    wire gate_open;
    wire [1:0] state_led;
    wire [2:0] debug_led; // 암호 모듈 확인용

    // 센서 모듈 연결용 (물리적 핀)
    wire echo_sim = 0;    // 시뮬레이션에선 사용 안함 (내부 값 강제 할당 예정)
    wire trig;
    wire dht11_io;        // Inout 핀

    // 3. 센서값 모니터링 및 판단 로직 (Wire)
    // 센서 모듈 내부의 결과값을 받아와서 판단
    wire [8:0] dist_cm_mon;
    wire [7:0] hum_mon;
    wire [7:0] temp_mon;

    // **핵심 로직 구현**: 사용자가 원한 조건
    // 초음파(100CM 이상 150초과), 온도(30도 이상), 습도(50% 이상)
    wire sonic_condition = (dist_cm_mon < 150 && dist_cm_mon >= 100);
    wire dht_condition   = (temp_mon >= 30 && hum_mon >= 50);

    // 4. 모듈 인스턴스화 (Unit Under Test)

    // (1) 메인 컨트롤러
    FSM_Controller u_fsm (
        .clk(clk),
        .reset_p(reset_p),
        .sw_launch(sw_launch),
        .timer_done(timer_done_sim),    // 테스트벤치에서 신호 줌
        .sonic_sensor_ok(sonic_condition), // 조건이 맞으면 OK 신호 전달
        .dht_sensor_ok(dht_condition),     // 조건이 맞으면 OK 신호 전달
        .timer_start(timer_start),
        .gate_open(gate_open),
        .state_led(state_led)
    );

    // (2) 암호 체크 모듈 (Gate Open 신호를 enable로 사용)
    password_check u_pass (
        .clk(clk),
        .reset_p(reset_p),
        .enable(gate_open),       // 문이 열려야 동작
        .data_in(password_data_in),
        .debug_led(debug_led)
    );

    // (3) 초음파 센서 (HC-SR04)
    hc_sr04 u_sonic (
        .clk(clk),
        .reset_p(reset_p),
        .echo(echo_sim),
        .trig(trig),
        .distance_cm() // 실제 출력 핀은 연결 안하고 내부 레지스터를 force 할 예정
    );

    // (4) 온습도 센서 (DHT11)
    dht11_cntr u_dht (
        .clk(clk),
        .reset_p(reset_p),
        .dht11_data(dht11_io),
        .humidity(),    // 내부 레지스터 force 예정
        .temperature(), // 내부 레지스터 force 예정
        .led()
    );

    // 시뮬레이션 편의를 위해 모듈 내부의 값을 밖으로 끌어옴 (모니터링)
    assign dist_cm_mon = u_sonic.distance_cm;
    assign temp_mon    = u_dht.temperature;
    assign hum_mon     = u_dht.humidity;

    // 5. 클럭 생성 (100MHz 가정)
    always #5 clk = ~clk; // 10ns 주기

    // 6. 테스트 시나리오 시작
    initial begin
        // 초기화
        clk = 0;
        reset_p = 1;
        sw_launch = 0;
        timer_done_sim = 0;
        password_data_in = 0;
        
        // 센서 초기값 (조건 불만족 상태로 시작)
        // force 명령어를 사용하여 센서 모듈 내부 레지스터 값을 강제로 씁니다.
        force u_sonic.distance_cm = 10; // 10cm
        force u_dht.temperature = 20;    // 20도
        force u_dht.humidity = 40;       // 40%

        #100;
        reset_p = 0; // 리셋 해제

        // ------------------------------------------------
        // 시나리오 1: 시스템 시작 (IDLE -> SILENT)
        // ------------------------------------------------
        $display("[Time: %0t] System Start via Switch...", $time);
        #50 sw_launch = 1;
        #20 sw_launch = 0;
        
        // FSM이 SILENT 상태가 되어 timer_start 신호를 내보냈는지 확인
        wait(timer_start == 1);
        $display("[Time: %0t] State: SILENT (Timer Started)", $time);

        // ------------------------------------------------
        // 시나리오 2: 타이머 종료 (SILENT -> VERIFY)
        // ------------------------------------------------
        #200; 
        // 외부 타이머가 시간을 다 셌다고 가정
        timer_done_sim = 1; 
        #20 timer_done_sim = 0;
        
        $display("[Time: %0t] State: VERIFY (Checking Sensors...)", $time);
        #50;

        // ------------------------------------------------
        // 시나리오 3: 센서 조건 만족 (VERIFY -> OPEN)
        // 조건: 150 > 거리 >= 100, 온도 >= 30, 습도 >= 50
        // ------------------------------------------------
        
        // (1) 거리만 만족시켜 봄 (문 안열림)
        force u_sonic.distance_cm = 110; 
        #50;
        if (gate_open == 0) $display(" -> Distance OK, but Temp/Hum fail. Gate Closed.");

        // (2) 모든 조건 만족 시킴
        force u_dht.temperature = 32; // 32도
        force u_dht.humidity = 60;    // 60%
        
        // FSM이 감지할 시간 여유 줌
        wait(gate_open == 1);
        $display("[Time: %0t] State: OPEN !!! (Conditions Met)", $time);

        // ------------------------------------------------
        // 시나리오 4: 암호 모듈 동작 확인
        // ------------------------------------------------
        // 문이 열렸으므로(enable=1), 데이터 입력에 따라 암호화 동작
        #100;
        password_data_in = 1;
        #100;
        password_data_in = 0;
        #100;
        $display("[Time: %0t] Password Module Active Checked", $time);

        // ------------------------------------------------
        // 시나리오 5: OPEN 상태 유지 및 타임아웃/센서오류 테스트
        // FSM 코드에 state_clk < 1000 일 때만 카운트 하도록 되어 있음
        // ------------------------------------------------
        
        // 센서가 갑자기 조건 불만족으로 변함 (OPEN -> FAULT)
        #500;
        $display("[Time: %0t] Sensor Fail Simulation...", $time);
        force u_sonic.distance_cm = 160; // 거리가 멀어짐
        
        wait(state_led == 2'b00); // FAULT 상태는 LED가 00임 (코드 참조)
        $display("[Time: %0t] State: FAULT (Sensor Lost signal during Open)", $time);

        #500;
        $stop;
    end

endmodule