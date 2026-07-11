# 🚗 Car Safety System Simulation (Verilog)

## 📌 Project Overview
Dự án thiết kế và mô phỏng bộ điều khiển trung tâm (ECU) cho hệ thống an toàn ô tô bằng ngôn ngữ phần cứng **Verilog HDL**. Hệ thống tích hợp song song hai khía cạnh an toàn cốt lõi:
*   **An toàn thụ động (Passive Safety):** Xử lý tín hiệu cảm biến áp suất để phân loại hành khách và điều khiển máy trạng thái (FSM) kích nổ túi khí.
*   **An toàn chủ động (Active Safety):** Tính toán vật lý thời gian thực (động năng, vòng tròn ma sát) để can thiệp phanh khẩn cấp tự động (AEB) và trợ lực lái tránh va chạm.

## 🛠 Technologies & Tools
*   **Hardware Description Language:** Verilog HDL (IEEE 1364)
*   **EDA Tools:** Icarus Verilog (Compiler/Simulator), GTKWave (Waveform Viewer)
*   **Logic Synthesis:** DigitalJS (RTL Synthesis & Visualization)

## 🧑‍💻 My Contributions (Phan Mạnh Hùng)
Trong khuôn khổ dự án, tôi đảm nhiệm **15%** khối lượng công việc, tập trung vào mạch logic xử lý động lực học và đảm bảo chất lượng hệ thống:
1.  **Thiết kế hệ thống phanh (Module BrakeSteerCtrl):**
    *   Xây dựng thuật toán tính toán lực phanh thời gian thực dựa trên động năng ($E \propto v^2$) và khoảng cách vật cản.
    *   Phát triển **Arbiter Logic (Bộ trọng tài)**: Tự động chiếm quyền điều khiển (override) và kích hoạt phanh tối đa (255) khi phát hiện nguy cơ va chạm mà tài xế không phản ứng đủ lực.
    *   Thiết kế cơ chế cân bằng Phanh - Lái: Tự động giảm lực phanh khi phát hiện thao tác đánh lái gấp để tránh khóa bánh (Skidding).
2.  **Xây dựng Testbench & Mô phỏng:**
    *   Thiết kế kịch bản kiểm thử (`tb_main.v`) để xác minh tính toàn vẹn của dữ liệu luân chuyển trong hệ thống.
    *   Phân tích giản đồ xung trên GTKWave để gỡ lỗi quá trình chuyển trạng thái của hệ thống.

## 🔄 System Architecture & Data Flow
Hệ thống xử lý luồng dữ liệu theo mô hình IPO (Input - Processing - Output) kết hợp kỹ thuật **Double Flopping** để xử lý bất đồng bộ, đảm bảo dữ liệu sạch trước khi đi vào logic cốt lõi:

*   **Inputs:** Tín hiệu Radar, Cảm biến tốc độ, Lực đạp phanh, Mô-men đánh lái, Cảm biến áp suất ghế.
*   **Processing:**
    *   `synchronizer`: Khử nhiễu Metastability cho tín hiệu thô.
    *   `occupantClassifier`: Lọc nhiễu bằng thuật toán Moving Average, phân loại hành khách (Empty, Child, Adult).
    *   `airbagControl`: FSM quyết định kích nổ túi khí với cơ chế Interlock (chống nổ oan).
    *   `BrakeSteerCtrl`: Tính toán phanh và trợ lái.
    *   `main`: Tích hợp các luồng dữ liệu (Data routing) giữa các module con.
*   **Outputs:** Tín hiệu kích nổ túi khí, Lực phanh thủy lực, Trợ lực lái điện, Đèn cảnh báo.


## 📂 Repository Structure
```text
📦 Car-Safety-System-Simulation-Verilog
 ┣ 📂 docs/                # Báo cáo chi tiết kiến trúc máy tính
 ┣ 📂 img/                 # Hình ảnh minh họa (Architecture, Waveforms)
 ┣ 📂 src/                 # Mã nguồn Verilog (RTL)
 ┃ ┣ 📜 airbagControl.v
 ┃ ┣ 📜 BrakeSteerCtrl.v
 ┃ ┣ 📜 main.v
 ┃ ┣ 📜 occupantClassifier.v
 ┃ ┗ 📜 synchronizer.v
 ┣ 📂 sim/                 # Môi trường kiểm thử
 ┃ ┣ 📜 system_trace.vcd
 ┃ ┣ 📜 tb_main_v.v
 ┃ ┗ 📜 test
 ┃ ┣ 📜 dump.vcd
 ┗ 📜 README.md
