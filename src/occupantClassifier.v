module Occupant_Classifier (
    input wire clk,
    input wire rst_n,

    input wire [7:0] SensorFrontLeft_raw,
    input wire [7:0] SensorFrontRight_raw,
    input wire [7:0] SensorBackLeft_raw,
    input wire [7:0] SensorBackRight_raw,

    output reg [7:0] weight_kg,   
    output reg [1:0] classify
);
    
    reg [9:0] current_total;
    reg [9:0] history [0:3];
    reg [11:0] sum_history;
    wire [7:0] FL_sync;
    wire [7:0] FR_sync;
    wire [7:0] BL_sync;
    wire [7:0] BR_sync;

    localparam [7:0] CHILD_LIMIT = 8'd10;
    localparam [7:0] ADULT_LIMIT = 8'd30;
    localparam [7:0] MAX_KG = 8'd255;
    localparam [7:0] MAX_REAL_WEIGHT = 8'd200;

    localparam EMPTY = 2'b00;
    localparam CHILD = 2'b01;
    localparam ADULT = 2'b10;
    localparam ERROR = 2'b11;


    initial begin
        weight_kg <= 0;
            classify <= EMPTY;
            current_total <= 0;
            history[0] <= 0;
            history[1] <= 0;
            history[2] <= 0;
            history[3] <= 0;
    end

    synchronizer #(.WIDTH(8)) u_sync_1 (.clk(clk), .rst_n(rst_n), .async_in(SensorFrontLeft_raw), .sync_out(FL_sync));
    synchronizer #(.WIDTH(8)) u_sync_2 (.clk(clk), .rst_n(rst_n), .async_in(SensorFrontRight_raw), .sync_out(FR_sync));
    synchronizer #(.WIDTH(8)) u_sync_3 (.clk(clk), .rst_n(rst_n), .async_in(SensorBackLeft_raw), .sync_out(BL_sync));
    synchronizer #(.WIDTH(8)) u_sync_4 (.clk(clk), .rst_n(rst_n), .async_in(SensorBackRight_raw), .sync_out(BR_sync));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            weight_kg <= 0;
            classify <= EMPTY;
            current_total <= 0;
            history[0] <= 0;
            history[1] <= 0;
            history[2] <= 0;
            history[3] <= 0;
        end else begin
            current_total <= FL_sync + FR_sync + BL_sync + BR_sync;

            history[0] <= current_total;
            history[1] <= history[0];
            history[2] <= history[1];
            history[3] <= history[2];

            weight_kg <= (history[0] + history[1] + history[2] + history[3]) >> 2;

            if ((FL_sync == MAX_KG) || (FR_sync == MAX_KG) || (BL_sync == MAX_KG) || (BR_sync == MAX_KG) || (weight_kg > MAX_REAL_WEIGHT)) begin
                classify <= ERROR;
            end
            else if (weight_kg < CHILD_LIMIT) begin
                classify <= EMPTY;
            end
            else if (weight_kg  >= CHILD_LIMIT && weight_kg <= ADULT_LIMIT) begin
                classify <= CHILD;
            end
            else begin
                classify <= ADULT;  
            end

        end
    end
endmodule