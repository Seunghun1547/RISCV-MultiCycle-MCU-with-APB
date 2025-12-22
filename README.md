# 📟 RISC-V 기반 Multi-Cycle MCU 및 AMBA APB 주변장치 설계
> **Multi-Cycle RISC-V CPU 설계, AMBA APB 버스 프로토콜 기반 UART IP 통합 및 C 언어 기반 HW/SW 통합 검증**

본 프로젝트는 효율적인 명령어 실행을 위해 **Multi-Cycle 구조**의 RISC-V 프로세서를 설계하고, 표준 버스 인터페이스인 **AMBA APB**를 직접 구현하여 UART와 같은 주변 장치를 연동한 MCU(Micro Controller Unit) 설계 프로젝트입니다.

---

## 1. 프로젝트 개요 (Introduction)
* **목적**: 단계별 명령어 처리를 통한 하드웨어 효율성 극대화 및 표준 버스 프로토콜을 이용한 시스템 확장성 확보.
* **주요 특징**:
    * **Multi-Cycle Architecture**: 각 명령어를 단계별(Fetch, Decode, Execute, Memory, Write-back)로 분리 처리하여 Single-Cycle 대비 클럭 효율 개선.
    * **APB Bus Bridge**: CPU와 주변 장치(UART, GPIO 등) 간의 데이터 전송을 위한 AMBA APB 프로토콜 설계.
    * **Full-Stack Verification**: 하드웨어 설계부터 C 언어를 이용한 실제 펌웨어 동작 확인까지 전체 설계 프로세스 수행.

---

## 2. 기술 스택 (Tech Stack)
* **Language**: SystemVerilog, C (Firmware)
* **Architecture**: RISC-V (RV32I), Multi-Cycle, AMBA APB
* **Tools**: Vivado, Logic Analyzer
* **Hardware**: Basys3 FPGA

---

## 3. 핵심 설계 내용 (Design Details)

### 🏗️ Multi-Cycle CPU Core
* Single-Cycle 구조의 제약(가장 긴 명령어 기준 클럭 설정)을 해결하기 위해 명령어 처리 단계를 분할하여 처리 속도 및 자원 활용도 최적화.

### 🔗 AMBA APB Peripheral Integration
* **APB Master/Slave**: 표준 APB 타이밍에 맞춘 읽기/쓰기 제어 로직 설계.
* **UART IP**: PC와의 직렬 통신을 위한 UART Controller 설계 및 APB 버스 인터페이스 래핑.

### 💻 C Test Code & HW/SW Co-Verification
* 하드웨어 레지스터 주소 정의 및 C 기반 드라이버 코드를 활용하여 LED 제어 및 UART 에코 테스트 수행.

---

## 🛠️ 4. Trouble Shooting (핵심 문제 해결 경험)

### 💥 UART FIFO 및 데이터 수신 타이밍 이슈
* **문제**: 고속 데이터 전송 시 데이터 유실 또는 중복 수신 현상 발생.
* **원인**: CPU의 데이터 처리 속도와 UART 통신 속도 차이로 인한 동기화 문제.
* **해결**: Tx/Rx FIFO를 강화하고, 상태 레지스터(Status Register)의 플래그(Full/Empty) 기반 제어 로직을 보완하여 데이터 무결성 확보.

### 💥 APB 버스 프로토콜 타이밍 정합성
* **문제**: 주변 장치 주소 접근 시 1클럭 지연으로 인해 잘못된 데이터를 읽어오는 현상.
* **해결**: APB State Machine에서 `PSEL`, `PENABLE` 신호의 타이밍을 재설계하여 데이터 샘플링 시점의 정합성 확보.

---

## 5. 결과 및 성과
* **시스템 설계 역량**: CPU 코어 설계뿐만 아니라 버스 인터페이스 및 주변 장치 설계까지 포함하는 MCU 설계 역량 입증.
* **디버깅 및 검증**: C 언어 기반 테스트를 통해 하드웨어와 소프트웨어의 통합 동작을 성공적으로 검증.
* **표준 프로토콜 숙지**: 업계 표준인 AMBA APB 프로토콜을 직접 구현하며 SoC 구조에 대한 깊은 이해도 확보.
