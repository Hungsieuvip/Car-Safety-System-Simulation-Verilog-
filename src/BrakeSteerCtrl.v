// -------------------------------------------------------------------------
// MODULE 3: HỆ THỐNG PHANH & TRỢ LỰC LÁI KHẨN CẤP (ACTIVE SAFETY)
// -------------------------------------------------------------------------
module Active_Safety_Unit (
    input wire clk,
    input wire rst_n,

    // --- INPUT (DỮ LIỆU ĐÃ XỬ LÝ TỪ CẢM BIẾN XE) ---
    // Giả sử tốc độ và khoảng cách đã được lọc ở module sensor khác
    input is_obstacle_valid,
    input wire [7:0]  current_velocity,      // m/s
    input wire [15:0] distance_to_obstacle,  // cm

    // --- INPUT (DỮ LIỆU THÔ TỪ TÀI XẾ - ASYNCHRONOUS) ---
    input wire [7:0]        async_driver_brake_pedal,   // 0 - 255
    input wire signed [7:0] async_driver_steering_torque, // -128 đến +127 (Trái/Phải)

    // --- OUTPUT (ĐIỀU KHIỂN ĐỘNG CƠ THỰC THI) ---
    output reg [7:0]        final_brake_command,   // Lực phanh chốt hạ
    output reg signed [7:0] steer_assist_command,  // Lực trợ lái bổ sung
    output reg              warning_visual_active  // Đèn cảnh báo táp-lô
);
    
    // =========================================================
    // 1. ĐỒNG BỘ HÓA TÍN HIỆU (INPUT BARRIER)
    // =========================================================
    
    // 1.1 Đồng bộ chân phanh
    wire [7:0] clean_brake_pedal;
    synchronizer #(.WIDTH(8)) u_sync_brake (
        .clk(clk), 
        .rst_n(rst_n), 
        .async_in(async_driver_brake_pedal), 
        .sync_out(clean_brake_pedal)
    );

    // 1.2 Đồng bộ lực đánh lái
    // Lưu ý: Synchronizer xử lý bit thô, ta ép kiểu signed sau khi đã đồng bộ
    wire [7:0] raw_steer_sync; 
    synchronizer #(.WIDTH(8)) u_sync_steer (
        .clk(clk), 
        .rst_n(rst_n), 
        .async_in(async_driver_steering_torque), // Verilog tự map bit signed sang wire
        .sync_out(raw_steer_sync)
    );

    // Ép kiểu lại sang signed để tính toán logic
    wire signed [7:0] clean_steer_torque;
    assign clean_steer_torque = $signed(raw_steer_sync);

    // =========================================================
    // 2. TÍNH TOÁN VẬT LÝ & NGỮ CẢNH (CONTEXT AWARENESS)
    // =========================================================
    
    // --- Tham số Tuning (Calibration) ---
    localparam [7:0] BRAKE_GAIN           = 8'd10; 
    localparam [7:0] STEER_PENALTY_FACTOR = 8'd2; // Hệ số phản/phạt phanh (1 lực đánh lái ~ -2 lực phanh)
    localparam [7:0] STEER_ASSIST_GAIN    = 8'd3; // Hệ số hỗ trợ đánh lái 
    
    // --- Các ngưỡng kích hoạt (Thresholds) ---
    localparam [7:0] CRITICAL_BRAKE_THRESHOLD = 8'd250; // Điểm không thể quay đầu
    localparam [7:0] EVASIVE_ASSIST_TRIGGER   = 8'd150; // Ngưỡng kích hoạt chế độ lái khẩn cấp
                                                        // -> Hỗ trợ lực lái + chống trượt (giảm phanh)
    localparam [7:0] MAX_ASSIST_TORQUE        = 8'd80;  // Giới hạn an toàn phần cứng

    // --- Biến nội bộ ---
    reg [31:0] velocity_squared;
    reg [31:0] required_brake_energy;    // Lực phanh cần thiết tạm tính
    reg [7:0]  calculated_physics_brake; // Lực phanh được tính bởi máy tính
    
    reg [7:0]  abs_steer_torque;        // Trị tuyệt đối lực đánh lái
    reg [7:0]  traction_limit_brake;    // Giới hạn phanh chống trượt
    reg signed [15:0] raw_assist_cal; // Lực quay bánh lái đã trợ lực tạm tính
                                        //Dùng 16 bit để tránh tràn khi nhân
    
    reg enable_evasive_assist;  // Kích hoạt trạng thái lái khẩn cấp

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            calculated_physics_brake <= 0;
            enable_evasive_assist    <= 0;
            steer_assist_command     <= 0;
            traction_limit_brake     <= 255;
            abs_steer_torque         <= 0;
            velocity_squared         <= 0;
            required_brake_energy    <= 0;
            raw_assist_cal           <= 0;
        end else begin
            if (is_obstacle_valid == 1'b0) begin
                // TRƯỜNG HỢP: KHÔNG CÓ VẬT CẢN (SAFE)
                // Reset hết các biến tính toán nội bộ
                calculated_physics_brake <= 0;
                enable_evasive_assist    <= 0;
                steer_assist_command     <= 0; // Tắt trợ lực lái
                traction_limit_brake     <= 255; // Không giới hạn phanh
                
            end else begin
                // TRƯỜNG HỢP: CÓ VẬT CẢN (ACTIVE)
                // --- 2.1. Tính Lực Phanh Cần Thiết ---
                velocity_squared = current_velocity * current_velocity;
                
                if (distance_to_obstacle > 0) begin
                    required_brake_energy = (velocity_squared * BRAKE_GAIN) / distance_to_obstacle;
                    if (required_brake_energy >= 255) calculated_physics_brake <= 8'd255;
                    else calculated_physics_brake <= required_brake_energy[7:0];
                end else begin
                    calculated_physics_brake <= 8'd255;
                end

                // --- 2.2. Xác định Chế Độ Lái ---
                if ((calculated_physics_brake > EVASIVE_ASSIST_TRIGGER) || // Đạt ngưỡng kích hoạt lái xe khẩn cấp
                    (clean_brake_pedal > EVASIVE_ASSIST_TRIGGER)) begin
                    enable_evasive_assist <= 1'b1;
                end else begin
                    enable_evasive_assist <= 1'b0;
                end
                
                // --- 2.3. Tính toán Giới hạn Bám đường ---
                if (clean_steer_torque < 0) abs_steer_torque <= -clean_steer_torque;
                else abs_steer_torque <= clean_steer_torque;

                if (enable_evasive_assist) begin
                    if ((abs_steer_torque * STEER_PENALTY_FACTOR) > 255)
                        traction_limit_brake <= 8'd0;
                    else
                        traction_limit_brake <= 8'd255 - (abs_steer_torque * STEER_PENALTY_FACTOR);
                end else begin
                    traction_limit_brake <= 8'd255;
                end

                    // --- 2.4. Tính Trợ lực lái ---
                    if (enable_evasive_assist) raw_assist_cal = clean_steer_torque * $signed(STEER_ASSIST_GAIN);
                    else raw_assist_cal = 0; 

                    // Giới hạn hỗ trợ đánh lái [-80, +80]
                    if (raw_assist_cal > $signed(MAX_ASSIST_TORQUE))
                        steer_assist_command <= $signed(MAX_ASSIST_TORQUE);
                    else if (raw_assist_cal < -$signed(MAX_ASSIST_TORQUE))
                        steer_assist_command <= -$signed(MAX_ASSIST_TORQUE);
                    else
                        steer_assist_command <= raw_assist_cal[7:0];
            end 
        end
    end

    // =========================================================
    // 3. BỘ TRỌNG TÀI QUYẾT ĐỊNH (FINAL ARBITER)
    // =========================================================
    reg [7:0] tentative_brake;  // Lực phanh dự kiến

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            final_brake_command   <= 0;
            warning_visual_active <= 0;
            tentative_brake       <= 0;
        end else begin
            if (is_obstacle_valid == 1'b0) begin
                // CHẾ ĐỘ THƯỜNG (PASSTHROUGH)
                // Output = Input của người lái
                final_brake_command   <= clean_brake_pedal;
                warning_visual_active <= 1'b0;
                
            end else begin
                // CHẾ ĐỘ ACTIVE SAFETY (CÓ VẬT CẢN)
                // --- BƯỚC A: Ưu tiên an toàn ---
                if ((calculated_physics_brake >= CRITICAL_BRAKE_THRESHOLD) && 
                    (clean_brake_pedal < CRITICAL_BRAKE_THRESHOLD)) begin
                    tentative_brake       = 8'd255; 
                    warning_visual_active <= 1'b1;  
                end else begin
                    tentative_brake       = clean_brake_pedal; 
                    warning_visual_active <= 1'b0;
                end
                // --- BƯỚC B: Chống trượt ---
                if (enable_evasive_assist && (tentative_brake > traction_limit_brake)) begin
                    final_brake_command <= traction_limit_brake;
                end else begin
                    final_brake_command <= tentative_brake;
                end
            end // Kết thúc else (Có vật cản)
        end
    end

endmodule