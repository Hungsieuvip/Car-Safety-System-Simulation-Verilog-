# 🚗 Car Safety System Simulation (Verilog)

## 📌 Project Overview
Dự án thiết kế và mô phỏng bộ điều khiển trung tâm (ECU) cho hệ thống an toàn ô tô bằng ngôn ngữ phần cứng **Verilog HDL**. Hệ thống tích hợp song song hai khía cạnh an toàn cốt lõi:
*   **An toàn thụ động (Passive Safety):** Xử lý tín hiệu cảm biến áp suất để phân loại hành khách và điều khiển máy trạng thái (FSM) kích nổ túi khí.
*   **An toàn chủ động (Active Safety):** Tính toán vật lý thời gian thực (động năng, vòng tròn ma sát) để can thiệp phanh khẩn cấp tự động (AEB) và trợ lực lái tránh va chạm.

## 🛠 Technologies & Tools
*   **Hardware Description Language:** Verilog HDL (IEEE 1364)
*   **Simulation & Testing:** Python (cocotb, pygame)
*   **EDA Tools:** Icarus Verilog (Compiler/Simulator), GTKWave (Waveform Viewer), DigitalJS (RTL Synthesis & Visualization)

## 🧑‍💻 My Contributions (Phan Mạnh Hùng)
Trong khuôn khổ dự án nhóm (5 thành viên), tôi đảm nhiệm **15%** khối lượng công việc, tập trung vào mạch logic xử lý động lực học và đảm bảo chất lượng hệ thống:
1.  **Thiết kế hệ thống phanh (Active Safety Unit - ASU):**
    *   Xây dựng thuật toán tính toán lực phanh thời gian thực dựa trên động năng ($E \propto v^2$) và khoảng cách vật cản.
    *   Phát triển **Arbiter Logic (Bộ trọng tài)**: Tự động chiếm quyền điều khiển (override) và kích hoạt phanh tối đa (255) khi phát hiện nguy cơ va chạm mà tài xế không phản ứng đủ lực.
    *   Thiết kế cơ chế cân bằng Phanh - Lái: Tự động giảm lực phanh khi phát hiện thao tác đánh lái gấp để tránh khóa bánh (Skidding).
2.  **Xây dựng Testbench & Mô phỏng:**
    *   Thiết kế các kịch bản kiểm thử (Test cases) mô phỏng tín hiệu đầu vào đa dạng (vận tốc, cự ly, lực phanh/đánh lái của tài xế).
    *   Xác minh tính toàn vẹn của dữ liệu và logic chuyển trạng thái thông qua phân tích giản đồ xung.

## 🔄 System Architecture & Data Flow
Hệ thống xử lý luồng dữ liệu theo mô hình IPO (Input - Processing - Output) kết hợp kỹ thuật **Double Flopping** để xử lý bất đồng bộ:

*   **Inputs:** Tín hiệu Radar, Cảm biến tốc độ, Lực đạp phanh, Mô-men đánh lái, Cảm biến áp suất ghế (4 vị trí).
*   **Processing:**
    *   `Synchronizer`: Khử nhiễu Metastability cho tín hiệu thô.
    *   `Occupant_Classifier`: Lọc nhiễu bằng thuật toán Moving Average, phân loại hành khách (Empty, Child, Adult).
    *   `Airbag Control Unit (ACU)`: FSM quyết định kích nổ với cơ chế Interlock (chống nổ oan).
    *   `Active Safety Unit (ASU)`: Tính toán phanh và trợ lái.
*   **Outputs:** Kích nổ túi khí (Lái, Phụ, Rèm), Lực phanh thủy lực, Trợ lực lái điện, Đèn cảnh báo.

*(Hình ảnh minh họa kiến trúc hệ thống)*
<!-- Bạn hãy thay đường dẫn ảnh thực tế vào đây sau khi upload ảnh lên thư mục img/ -->
![System Architecture](img/system_architecture.png)

## 📂 Repository Structure
```text
📦 Car-Safety-System-Simulation-Verilog
 ┣ 📂 docs/                # Tài liệu dự án và báo cáo chi tiết
 ┣ 📂 img/                 # Hình ảnh minh họa (Architecture, Waveforms)
 ┣ 📂 src/                 # Mã nguồn Verilog (RTL)
 ┃ ┣ 📜 synchronizer.v
 ┃ ┣ 📜 Occupant_Classifier.v
 ┃ ┣ 📜 car_safety_system.v
 ┃ ┣ 📜 Active_Safety_Unit.v
 ┃ ┗ 📜 System_Top_Level.v
 ┣ 📂 sim/                 # Môi trường kiểm thử
 ┃ ┣ 📜 testbench.v
 ┃ ┗ 📜 interactive_sim.py
 ┗ 📜 README.md
