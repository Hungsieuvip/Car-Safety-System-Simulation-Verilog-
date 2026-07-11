// -------------------------------------------------------------------------
// FILE: tb_main_v.v
// TESTBENCH HOÀN CHỈNH CHO TOÀN BỘ HỆ THỐNG AN TOÀN Ô TÔ
// BAO GỒM LOGIC PHẢN HỒI VẬT LÝ VÀ KIỂM TRA ĐẦY ĐỦ CÁC NGƯỠNG AN TOÀN
// ĐÃ SỬA LỖI CÚ PHÁP: KHAI BÁO BIẾN Ở ĐẦU MODULE
// -------------------------------------------------------------------------
`timescale 1ns / 1ps // Đơn vị thời gian mô phỏng: 1ns (đơn vị), 1ps (độ chính xác)

module tb_main_v;

    // ==========================================
    // 1. KHAI BÁO TÍN HIỆU INPUTS (REG) & HẰNG SỐ MÔ PHỎNG
    // ==========================================
    reg clk;             // Tín hiệu đồng hồ (Clock)
    reg rst_n;           // Tín hiệu Reset tích cực mức thấp (Active Low Reset)

    // Airbag & Collision Inputs (Dữ liệu từ cảm biến va chạm và vật cản)
    reg signed [15:0] accel_x_in;       // Gia tốc theo trục X (trước/sau). Dùng cho túi khí trước.
    reg signed [15:0] accel_y_in;       // Gia tốc theo trục Y (ngang). Dùng cho túi khí hông.
    reg obstacle_in;                    // Cờ hiệu phát hiện vật cản (1: Có, 0: Không).

    // Brake & Steer Inputs (Dữ liệu cho hệ thống an toàn chủ động - ADAS)
    reg [7:0] current_velocity_reg;     // Tốc độ hiện tại của xe (Được cập nhật trong Khối 5).
    reg [15:0] distance_to_obstacle;    // Khoảng cách đến vật cản.
    reg [7:0] driver_brake_pedal;       // Lực nhấn bàn đạp phanh của tài xế (0-255).
    reg signed [7:0] driver_steering_torque; // Mô-men xoắn tay lái của tài xế.

    // Occupant Sensor Raw Inputs (Dữ liệu cảm biến trọng lượng, 4 cảm biến/ghế)
    reg [7:0] dr_s1, dr_s2, dr_s3, dr_s4; // Ghế Tài xế (Driver - DR)
    reg [7:0] ps_s1, ps_s2, ps_s3, ps_s4; // Ghế Hành khách (Passenger - PS)
    reg [7:0] rl_s1, rl_s2, rl_s3, rl_s4; // Ghế Sau Trái (Rear Left - RL)
    reg [7:0] rr_s1, rr_s2, rr_s3, rr_s4; // Ghế Sau Phải (Rear Right - RR)

    // KHAI BÁO HẰNG SỐ MÔ PHỎNG VẬT LÝ
    localparam [7:0] MAX_BRAKE_CMD  = 8'd255; // Lực phanh tối đa (chuẩn hóa).
    localparam [7:0] DECEL_UNIT     = 8'd13;  // Đơn vị giảm tốc cơ sở trong mô hình vật lý.
    
    // ==========================================
    // 2. KHAI BÁO OUTPUTS (WIRE) VÀ BIẾN NỘI BỘ
    // (Outputs là lệnh điều khiển từ DUT)
    // ==========================================
    wire deploy_driver, deploy_passenger;         // Lệnh bung túi khí chính phía trước.
    wire deploy_front_left, deploy_front_right;   // Lệnh bung túi khí hông trước.
    wire deploy_back_left, deploy_back_right;     // Lệnh bung túi khí hông sau (hoặc rèm).
    wire deploy_rear_left, deploy_rear_right;     // Lệnh bung túi khí rèm.
    wire [1:0] system_state;                      // Trạng thái FSM của hệ thống (IDLE, WARNING, ACTIVE_SAFETY, FIRED).
    wire [7:0] ctrl_brake_force;                  // Lực phanh do hệ thống tự động điều khiển (0-255).
    wire signed [7:0] ctrl_steer_assist;          // Lực hỗ trợ lái do hệ thống điều khiển.
    wire visual_warning;                          // Tín hiệu cảnh báo trực quan.

    reg [15:0] total_decel_step; // Biến tạm tính lượng tốc độ giảm trong 1 chu kỳ.
    // >>> >>>
    
    // ==========================================
    // 3. KẾT NỐI MODULE KIỂM TRA (DUT)
    // ==========================================
    System_Top_Level DUT ( // Khởi tạo module cấp cao nhất (Device Under Test)
        .clk(clk), .rst_n(rst_n),
        
        // Inputs
        .accel_x_in(accel_x_in), .accel_y_in(accel_y_in), .obstacle_in(obstacle_in),
        
        .dr_s1(dr_s1), .dr_s2(dr_s2), .dr_s3(dr_s3), .dr_s4(dr_s4), 
        .ps_s1(ps_s1), .ps_s2(ps_s2), .ps_s3(ps_s3), .ps_s4(ps_s4), 
        .rl_s1(rl_s1), .rl_s2(rl_s2), .rl_s3(rl_s3), .rl_s4(rl_s4), 
        .rr_s1(rr_s1), .rr_s2(rr_s2), .rr_s3(rr_s3), .rr_s4(rr_s4), 
        
        .current_velocity(current_velocity_reg),
        .distance_to_obstacle(distance_to_obstacle),
        .driver_brake_pedal(driver_brake_pedal),
        .driver_steering_torque(driver_steering_torque),
        
        // Outputs
        .deploy_driver(deploy_driver), .deploy_passenger(deploy_passenger),
        .deploy_front_left(deploy_front_left), .deploy_front_right(deploy_front_right),
        .deploy_back_left(deploy_back_left), .deploy_back_right(deploy_back_right),
        .deploy_rear_left(deploy_rear_left), .deploy_rear_right(deploy_rear_right),
        .system_state(system_state),
        .ctrl_brake_force(ctrl_brake_force),
        .ctrl_steer_assist(ctrl_steer_assist),
        .visual_warning(visual_warning)
    );

    // ==========================================
    // 4. KHỐI TẠO ĐỒNG HỒ, GIÁM SÁT VÀ DẠNG SÓNG
    // ==========================================
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk; // Tạo xung clock, chu kỳ 10ns
    end
    
    // Xuất dạng sóng VCD
    initial begin
        $dumpfile("System_Trace.vcd");
        $dumpvars(0, tb_main_v); // Ghi lại tất cả các biến trong module Testbench
    end

    // Giám sát: In kết quả chính ra terminal
    initial begin
        $display("---------------- SIMULATION START (MAIN TOP LEVEL) ----------------");
        $display("TIME | STATE | OBSTACLE | VELOCITY | BRAKE_CMD | STEER_AS | WARNING | AIRBAGS (DR/PS)");
        $monitor("%0t | %b | %b | %d | %d | %d | %b | %b/%b", 
                  $time, system_state, obstacle_in, current_velocity_reg, 
                  ctrl_brake_force, ctrl_steer_assist, visual_warning, deploy_driver, deploy_passenger);
        // $monitor tự động in các giá trị này khi có bất kỳ sự thay đổi nào xảy ra.
    end
    
    // ==========================================
    // 5. KHỐI PHẢN HỒI VẬT LÝ (Cập nhật Tốc độ) 
    // (Mô phỏng sự giảm tốc của xe dựa trên lệnh phanh)
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_velocity_reg <= 8'd0; // Reset tốc độ về 0
            total_decel_step     <= 0;    // Reset lượng giảm tốc
        end else begin
            // 1. TÍNH GIA TỐC PHANH
            // Tính lượng tốc độ giảm trong một chu kỳ clock (giả định)
            total_decel_step = (ctrl_brake_force * DECEL_UNIT) / MAX_BRAKE_CMD; 

            // 2. ÁP DỤNG GIẢM TỐC
            if (current_velocity_reg > total_decel_step) begin
                // Tốc độ mới = Tốc độ cũ - Lượng giảm tốc
                current_velocity_reg <= current_velocity_reg - total_decel_step[7:0]; 
            end else begin
                current_velocity_reg <= 8'd0; // Dừng hẳn
            end
        end
    end

    // ==========================================
    // 6. KỊCH BẢN KIỂM THỬ TỔNG HỢP (STIMULI)
    // (Thiết lập các tình huống đầu vào để kiểm tra DUT)
    // ==========================================
    initial begin
        // --- 6.0 KHỞI TẠO VÀ RESET ---
        rst_n = 1'b0;                           // Bắt đầu bằng Reset
        current_velocity_reg   = 8'd0; 
        distance_to_obstacle   = 16'd500; 
        driver_brake_pedal     = 8'd0;   
        driver_steering_torque = 8'd0;
        accel_x_in             = 16'd0;
        accel_y_in             = 16'd0;
        obstacle_in            = 1'b0;

        // Cấu hình ban đầu: Ghế trước ADULT (trọng lượng cao), ghế sau EMPTY (trọng lượng 0)
        dr_s1 = 8'd20; dr_s2 = 8'd20; dr_s3 = 8'd20; dr_s4 = 8'd20; // DR: ADULT (20x4 = 80)
        ps_s1 = 8'd20; ps_s2 = 8'd20; ps_s3 = 8'd20; ps_s4 = 8'd20; // PS: ADULT
        rl_s1 = 8'd0; rl_s2 = 8'd0; rl_s3 = 8'd0; rl_s4 = 8'd0;      // RL: EMPTY
        rr_s1 = 8'd0; rr_s2 = 8'd0; rr_s3 = 8'd0; rr_s4 = 8'd0;      // RR: EMPTY

        #20 rst_n = 1'b1; // Kết thúc Reset -> DUT chuyển sang IDLE (00)
        
        
        // --- 6.1 TEST 1: CHUYỂN TRẠNG THÁI (IDLE <-> WARNING) ---
        #50 $display("\n--- TEST 1: TRẠNG THÁI WARNING ---");
        obstacle_in = 1'b1;             // Kích hoạt vật cản (IDLE -> WARNING)
        #50 $display(" [KIỂM TRA]: State=%b (WARNING) khi có vật cản", system_state);
        obstacle_in = 1'b0;
            #50 $display(" [KIỂM TRA]: State=%b (IDLE) khi vật cản biến mất", system_state);


        // --- 6.2 TEST 2: PHANH CRITICAL & QUAN SÁT GIẢM TỐC ---
        #50 $display("\n--- TEST 2: PHANH CRITICAL (Tốc độ giảm) ---");
        current_velocity_reg = 8'd40;
        obstacle_in = 1'b1; 
        #20 distance_to_obstacle = 16'd10; // Khoảng cách CRITICAL -> Kích hoạt Phanh Tự động (ACTIVE_SAFETY)
        
        // Chờ 100ns (20 chu kỳ clock) để tốc độ giảm nhờ lực phanh tự động
            #100 $display(" [KIỂM TRA]: Velocity=%d (Cần xấp xỉ 0), BrakeCmd=%d", current_velocity_reg, ctrl_brake_force);
        obstacle_in = 1'b0; // Thoát khỏi trạng thái an toàn chủ động


        // --- 6.3 TEST 3: LÁI NÉ TRÁNH & GIỚI HẠN PHANH (ABS/Steer Assist) ---
        #50 $display("\n--- TEST 3: LÁI NÉ TRÁNH VÀ GIỚI HẠN PHANH ---");
        current_velocity_reg  = 8'd80; 
        driver_brake_pedal  = 8'd255; // Tài xế phanh tối đa
        distance_to_obstacle  = 16'd100; // Kích hoạt Active Safety
        obstacle_in = 1'b1; 
        #10 driver_steering_torque = 8'd60; // Tài xế đánh lái mạnh -> Kích hoạt Hỗ trợ lái
        
        // Kiểm tra Steer Assist (>0) và giới hạn Phanh (<255)
            #50 $display(" [KIỂM TRA]: SteerAssistCmd=%d (Cần > 0), BrakeCmd=%d (Cần < 255)", ctrl_steer_assist, ctrl_brake_force);
        driver_steering_torque = 8'd0;
        obstacle_in = 1'b0;


        // --- 6.4 TEST 4: TÚI KHÍ TRƯỚC (ADULT) ---
        #50 $display("\n--- TEST 4: AIRBAG TRƯỚC (ADULT) ---");
        current_velocity_reg = 8'd30;
        // ps_sX vẫn là ADULT
        accel_x_in = -16'd5000; // Va chạm mạnh -> Kích hoạt FIRED (11)
        
            #50 $display(" [KIỂM TRA]: Deploy Driver=%b, Deploy Pass=%b (Cần 1/1)", deploy_driver, deploy_passenger);


        // --- 6.5 TEST 5: TÚI KHÍ TRƯỚC (CHILD/INHIBITION) ---
        #50 $display("\n--- TEST 5: AIRBAG TRƯỚC (CHILD/INHIBITION) ---");
        ps_s1 = 8'd5; ps_s2 = 8'd5; ps_s3 = 8'd5; ps_s4 = 8'd5; // Ghế PS chuyển sang CHILD
        accel_x_in = -16'd5000; // Va chạm lại
        
        #20 rst_n = 1'b0; // Phải Reset FSM sau va chạm FIRED
        #20 rst_n = 1'b1; 
        accel_x_in = -16'd5000; // Kích hoạt lại va chạm
        
            #50 $display(" [KIỂM TRA]: Deploy Driver=%b (1), Deploy Pass=%b (Cần 0)", deploy_driver, deploy_passenger); // PS bị ức chế

        // --- 6.6 TEST 6: TÚI KHÍ HÔNG (SIDE COLLISION) ---
        #50 $display("\n--- TEST 6: AIRBAG HÔNG (SIDE ADULT/EMPTY) ---");
        accel_x_in = 16'd0; 
        accel_y_in = 16'd3000; // Va chạm hông trái mạnh
        
        // Kiểm tra FL (ADULT) = 1, BL (EMPTY) = 0
            #50 $display(" [KIỂM TRA]: Deploy FL=%b (Cần 1), Deploy BL=%b (Cần 0)", 
                deploy_front_left, deploy_back_left);

 #100 $finish; // Kết thúc mô phỏng
 end

endmodule