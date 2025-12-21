# SmartGate 시뮬레이션용 코드 수정 및 테스트 시나리오

본 문서는 `tb_SmartGate` 시뮬레이션 수행 시간을 단축하기 위해 실제 하드웨어용 타이밍(카운터 값)을 시뮬레이션용 축소 값으로 변경하는 수정 사항과, 이를 기반으로 한 테스트 검증 순서를 정의합니다.

## 1. 코드 수정 사항 (Code Modifications)

시뮬레이션 시간을 단축하기 위해 각 모듈의 타이머 및 카운터 임계값을 대폭 축소합니다.

### A. `<controller.v>` 수정

#### 1. Module: `FSM_Controller`
상태 유지 시간 및 타임아웃 카운트를 축소합니다.

* **Logic (Always Block - State Monitor)**
    * 변경 전: `(state_clk < 1_000_000)`
    * **변경 후**: `(state_clk < 1_000)`
* **State Machine (OPEN State)**
    * 변경 전: `if(state_clk >= 1_000_000)`
    * **변경 후**: `if(state_clk >= 100)`

#### 2. Module: `password_check`
암호 체크 주기를 축소합니다.

* **Clock Counter**
    * 변경 전: `(clk_counter == 67_000_000)`
    * **변경 후**: `(clk_counter == 10)`

#### 3. Module: `hc_sr04` (Ultrasonic Sensor)
초음파 트리거 및 에코 카운팅 비트 위치를 조정하여 주기를 단축합니다.

* **Trigger Logic**
    * 변경 전: `cnt_sysclk`의 **26번째** 비트 상승 에지 검출
    * **변경 후**: `cnt_sysclk`의 **12번째** 비트 상승 에지 검출
* **Echo Logic**
    * 변경 전: `cnt_sysclk`의 **9번째** 비트 상승 에지 검출
    * **변경 후**: `cnt_sysclk`의 **5번째** 비트 상승 에지 검출

#### 4. Module: `dht11_cntr` (Temp/Humidity Sensor)
온습도 센서의 초기화 및 대기 시간을 단축합니다.

* **State: S_IDLE**
    * 변경 전: `(count_usec < 22'd3_000_000)`
    * **변경 후**: `(count_usec < 22'd3)`
* **State: S_LOW_18MS**
    * 변경 전: `(count_usec < 22'd20_000)`
    * **변경 후**: `(count_usec < 22'd200)`

---

### B. `<sub_module.v>` 수정

#### 1. Module: `five_s_timer`
타이머의 카운트 값을 하드웨어 클럭(100MHz 기준 5초)에서 시뮬레이션용(5클럭)으로 변경합니다.

* **Counter Logic**
    * 변경 전: `(cnt_sysclk >= 250_000_000 - 1)`
    * **변경 후**: `(cnt_sysclk >= 5 - 1)`

---

## 2. 테스트 시나리오 (Simulation Flow)

테스트벤치(`initial` 블록)는 시간 흐름에 따라 아래의 6단계 순서로 진행됩니다.

1.  **초기화 (Initialization)**
    * 모든 시스템 신호를 리셋(`reset_p`)합니다.
    * `force` 명령어를 사용하여 센서 값을 초기 상태(조건 불만족)로 설정합니다.
2.  **시스템 가동 (System Start)**
    * 스위치 신호(`sw_launch`)를 인가하여 시스템을 **IDLE**에서 **SILENT(대기)** 모드로 진입시킵니다.
3.  **타이머 및 검증 (Timer & Verify)**
    * 타이머가 종료되었다고 가정하는 신호(`timer_done_sim`)를 주입합니다.
    * 시스템은 **VERIFY** 상태로 전환되어 센서 값을 확인하기 시작합니다.
4.  **조건 만족 및 개방 (Conditions Met & Gate Open)**
    * `force` 명령어로 센서 값을 강제로 **"조건 만족"** 상태(거리<30cm, 고온, 고습)로 변경합니다.
    * FSM이 이를 감지하고 `gate_open` 신호를 출력(High)하는지 확인합니다.
5.  **암호 모듈 테스트 (Password Module)**
    * 게이트가 열린 상태(`gate_open == 1`)에서 암호 모듈이 활성화되었는지 확인합니다.
    * 암호 데이터가 입력되었을 때 정상 처리되는지 검증합니다.
6.  **예외 상황 테스트 (Fault Injection)**
    * 문이 열려있는 도중(OPEN 상태), `force` 명령어로 센서 값을 **"비정상"** 상태(예: 거리가 멀어짐)로 변경합니다.
    * 시스템이 즉시 이를 감지하고 에러 상태(**FAULT**)로 전환되는지 검증합니다.
