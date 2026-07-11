// -------------------------------------------------------------------------
// FILE: main.v
// ĐÂY LÀ FILE TỔNG: Kết nối Túi khí + Phanh + Lái thành 1 hệ thống
// -------------------------------------------------------------------------
module System_Top_Level (
    input wire clk,
    input wire rst_n,

    // ==========================================
    // 1. INPUT CHO TÚI KHÍ (CŨ)
    // ==========================================
    input wire signed [15:0] accel_x_in,
    input wire signed [15:0] accel_y_in,
    input wire               obstacle_in, 

    // Cảm biến ghế (16 dây)
    input wire [7:0] dr_s1, dr_s2, dr_s3, dr_s4, 
    input wire [7:0] ps_s1, ps_s2, ps_s3, ps_s4, 
    input wire [7:0] rl_s1, rl_s2, rl_s3, rl_s4, 
    input wire [7:0] rr_s1, rr_s2, rr_s3, rr_s4, 

    // ==========================================
    // 2. INPUT CHO PHANH & LÁI (MỚI THÊM)
    // ==========================================
    // Bạn cần các cổng này để nối vào file BrakeSteerCtrl.v
    input wire [7:0]        current_velocity,     
    input wire [15:0]       distance_to_obstacle, 
    input wire [7:0]        driver_brake_pedal,   
    input wire signed [7:0] driver_steering_torque, 

    // ==========================================
    // 3. OUTPUTS (ĐẦU RA)
    // ==========================================
    // Output Túi khí
    output wire deploy_driver, deploy_passenger,
    output wire deploy_front_left, deploy_front_right,
    output wire deploy_back_left, deploy_back_right,
    output wire deploy_rear_left, deploy_rear_right,
    output wire [1:0] system_state,

    // Output Phanh & Lái (Lấy từ BrakeSteerCtrl đưa ra ngoài)
    output wire [7:0]        ctrl_brake_force,
    output wire signed [7:0] ctrl_steer_assist,
    output wire              visual_warning
);

    // Dây nội bộ
    wire [1:0] class_driver, class_pass, class_rear_left, class_rear_right;
    wire [7:0] w_dr, w_ps, w_rl, w_rr;

    // --- KHỐI 1: PHÂN LOẠI GHẾ (4 cái) ---
    Occupant_Classifier OCM_DRIVER (.clk(clk), .rst_n(rst_n), .SensorFrontLeft_raw(dr_s1), .SensorFrontRight_raw(dr_s2), .SensorBackLeft_raw (dr_s3), .SensorBackRight_raw (dr_s4), .weight_kg(w_dr), .classify (class_driver));
    Occupant_Classifier OCM_PASSENGER (.clk(clk), .rst_n(rst_n), .SensorFrontLeft_raw(ps_s1), .SensorFrontRight_raw(ps_s2), .SensorBackLeft_raw (ps_s3), .SensorBackRight_raw (ps_s4), .weight_kg(w_ps), .classify (class_pass));
    Occupant_Classifier OCM_REAR_LEFT (.clk(clk), .rst_n(rst_n), .SensorFrontLeft_raw(rl_s1), .SensorFrontRight_raw(rl_s2), .SensorBackLeft_raw (rl_s3), .SensorBackRight_raw (rl_s4), .weight_kg(w_rl), .classify (class_rear_left));
    Occupant_Classifier OCM_REAR_RIGHT (.clk(clk), .rst_n(rst_n), .SensorFrontLeft_raw(rr_s1), .SensorFrontRight_raw(rr_s2), .SensorBackLeft_raw (rr_s3), .SensorBackRight_raw (rr_s4), .weight_kg(w_rr), .classify (class_rear_right));

    // --- KHỐI 2: ĐIỀU KHIỂN TÚI KHÍ (Nằm trong file airbagControl.v) ---
    car_safety_system ACU_MAIN_UNIT (
        .clk(clk), .rst_n(rst_n),
        .raw_accel_x(accel_x_in), .raw_accel_y(accel_y_in), .raw_obstacle_det(obstacle_in),
        .driver(class_driver), .pass_front(class_pass), .pass_back_left(class_rear_left), .pass_back_right(class_rear_right),
        .deploy_driver(deploy_driver), .deploy_passenger(deploy_passenger),
        .deploy_front_left(deploy_front_left), .deploy_front_right(deploy_front_right),
        .deploy_back_left(deploy_back_left), .deploy_back_right(deploy_back_right),
        .deploy_rear_left(deploy_rear_left), .deploy_rear_right(deploy_rear_right),
        .fsm_state(system_state)
    );

    // --- KHỐI 3: PHANH & LÁI (Nằm trong file BrakeSteerCtrl.v) ---
    // ĐÂY LÀ PHẦN BẠN BỊ THIẾU
    Active_Safety_Unit ASU_BRAKE_STEER (
        .clk(clk), 
        .rst_n(rst_n),
        // Input nối vào
        .is_obstacle_valid(obstacle_in),
        .current_velocity(current_velocity),
        .distance_to_obstacle(distance_to_obstacle),
        .async_driver_brake_pedal(driver_brake_pedal),
        .async_driver_steering_torque(driver_steering_torque),
        // Output đi ra
        .final_brake_command(ctrl_brake_force),
        .steer_assist_command(ctrl_steer_assist),
        .warning_visual_active(visual_warning)
    );

endmodule