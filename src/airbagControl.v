// -------------------------------------------------------------------------
// MODULE 2: HỆ THỐNG AN TOÀN XE HƠI (TOP MODULE)
// -------------------------------------------------------------------------
module car_safety_system (
    input wire clk,
    input wire rst_n,

    // --- INPUTS TỪ CẢM BIẾN (ASYNCHRONOUS) ---
    input wire signed [15:0] raw_accel_x, 
    input wire signed [15:0] raw_accel_y, 
    input wire raw_obstacle_det,

    // Phân loại hành khách từ modun occupantClassifier
    input wire [1:0] driver,  
    input wire [1:0] pass_front,
    input wire [1:0] pass_back_left,
    input wire [1:0] pass_back_right,

    // --- OUTPUTS (SYNCHRONOUS) ---
    // Túi khí phía trước
    output reg deploy_driver,
    output reg deploy_passenger,

    //Túi khí bên hông
    output reg deploy_front_left,   
    output reg deploy_front_right,
    output reg deploy_back_left,
    output reg deploy_back_right,

    // 2 túi khí đặc biệt đặt phía sau hàng ghế đầu
    output reg deploy_rear_left,
    output reg deploy_rear_right,

    output wire [1:0] fsm_state    // Giới thiệu 3 trạng thái hệ thống
);

    // --- 1. KHAI BÁO TÍN HIỆU SẠCH (INTERNAL SIGNALS) ---
    // Sau khi qua synchronizer, ta sẽ dùng các dây này để tính toán
    wire signed [15:0] clean_accel_x;
    wire signed [15:0] clean_accel_y;
    wire clean_obstacle;
    
    // --- 2. CÁC NGƯỠNG AN TOÀN ---
    localparam signed [15:0] THRESHOLD_FRONT_HARD = -16'd5000; 
    localparam signed [15:0] THRESHOLD_FRONT_SOFT = -16'd3000; 
    localparam signed [15:0] THRESHOLD_SIDE       =  16'd3000;   

    localparam IDLE    = 2'b00;
    localparam WARNING = 2'b01;
    localparam FIRED   = 2'b10;

    localparam ADULT = 2'b10;

    reg [1:0] current_state, next_state;

    // --- 3. KHỐI ĐỒNG BỘ HÓA (INPUT BARRIER) ---
    // Đây là "Tường lửa" bảo vệ logic khỏi thế giới bên ngoài

    // 3.1 Đồng bộ hóa Gia tốc X (16 bit)
    synchronizer #(.WIDTH(16)) sync_acc_x (
        .clk(clk),
        .rst_n(rst_n),
        .async_in(raw_accel_x),
        .sync_out(clean_accel_x)
    );

    // 3.2 Đồng bộ hóa Gia tốc Y (16 bit)
    synchronizer #(.WIDTH(16)) sync_acc_y (
        .clk(clk),
        .rst_n(rst_n),
        .async_in(raw_accel_y),
        .sync_out(clean_accel_y)
    );

    // 3.3 Đồng bộ hóa Radar (1 bit)
    synchronizer #(.WIDTH(1)) sync_radar (
        .clk(clk),
        .rst_n(rst_n),
        .async_in(raw_obstacle_det),
        .sync_out(clean_obstacle)
    );

    // --- 4. LOGIC XỬ LÝ CHÍNH (DÙNG TÍN HIỆU SẠCH) ---
    
    // 4.1 FSM Túi khí trước
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) current_state <= IDLE;
        else        current_state <= next_state;
    end

    always @(*) begin
        next_state = current_state; 

        case (current_state)
            IDLE: begin
                // Dùng clean_accel_x thay vì raw
                if (clean_accel_x <= THRESHOLD_FRONT_HARD) //-5000
                    next_state = FIRED;
                else if (clean_obstacle) 
                    next_state = WARNING;
            end

            WARNING: begin
                if (clean_accel_x <= THRESHOLD_FRONT_SOFT) //-3000
                    next_state = FIRED;
                else if (!clean_obstacle)  
                    next_state = IDLE;
            end

            FIRED: next_state = FIRED;  
            
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            deploy_driver    <= 1'b0;
            deploy_passenger <= 1'b0;
            deploy_rear_left <= 1'b0;
            deploy_rear_right<= 1'b0;
        end else begin
            // Logic kích nổ dựa trên NEXT_STATE để phản ứng nhanh
            if (next_state == FIRED) begin
                if (driver == ADULT)          deploy_driver    <= 1'b1;
                if (pass_front == ADULT)      deploy_passenger <= 1'b1;
                if (pass_back_left == ADULT)  deploy_rear_left <= 1'b1;
                if (pass_back_right == ADULT) deploy_rear_right<= 1'b1;
            end
        end
    end

    // 4.2 Logic Túi khí hông
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            deploy_front_left  <= 1'b0;
            deploy_front_right <= 1'b0;
            deploy_back_left   <= 1'b0; // Sửa dấu phẩy thành chấm phẩy
            deploy_back_right  <= 1'b0;
        end else begin
            // BÊN TRÁI
            if (clean_accel_y >= THRESHOLD_SIDE) begin
                if (driver == ADULT)         deploy_front_left <= 1'b1;
                if (pass_back_left == ADULT) deploy_back_left  <= 1'b1;
            end 

            // BÊN PHẢI
            if (clean_accel_y <= -THRESHOLD_SIDE) begin
                if (pass_front == ADULT)      deploy_front_right <= 1'b1;
                if (pass_back_right == ADULT) deploy_back_right  <= 1'b1;
            end
        end
    end

    assign fsm_state = current_state;

endmodule