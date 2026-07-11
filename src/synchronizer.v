// module synchronizer #(parameter WIDTH = 16) (
//     input wire clk,
//     input wire [WIDTH-1:0] async_in,  // Tín hiệu thô
//     output reg [WIDTH-1:0] sync_out   // Tín hiệu sạch
// );
//     reg [WIDTH-1:0] stage1; // Flip-Flop tầng 1

//     always @(posedge clk) begin
//         stage1   <= async_in; // Tầng 1 hứng chịu rủi ro
//         sync_out <= stage1;   // Tầng 2 ổn định
//     end
// endmodule

module synchronizer #(parameter WIDTH = 16) (
    input wire clk,
    input wire rst_n,
    input wire [WIDTH-1:0] async_in,  // Tín hiệu thô
    output reg [WIDTH-1:0] sync_out   // Tín hiệu sạch
);
    reg [WIDTH-1:0] stage1; // Flip-Flop tầng 1

    // Khi mới chạy chương trình, các biến đều mặc định là rác (x)
    // Ép tất cả giá trị về 0 khi bật điện
    initial begin
        stage1 = 0;
        sync_out = 0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Khi Reset: Xóa sạch rác (x) thành 0
            stage1   <= 0;
            sync_out <= 0;
        end else begin
            stage1   <= async_in; // Tầng 1 hứng chịu rủi ro
            sync_out <= stage1;   // Tầng 2 ổn định
        end
    end
endmodule