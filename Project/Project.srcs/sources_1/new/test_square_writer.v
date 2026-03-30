`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/17/2026 09:23:50 PM
// Design Name: 
// Module Name: test_square_writer
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module test_square_writer(
    input  logic        clk,
    input  logic        rst,
    output logic [18:0] bram_addr_in,
    output logic [3:0]  bram_din,
    output logic wea
);

    logic [11:0] cnt;   // 0~4095
    logic [5:0]  x;
    logic [5:0]  y;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt          <= 12'd0;
            bram_addr_in <= 19'd0;
            bram_din     <= 4'd0;
            wea          <= 1'b0;
        end
        else begin
            if (cnt < 13'd4096) begin
                x = cnt[5:0];
                y = cnt[11:6];

                bram_addr_in <= y * 19'd640 + x;
                bram_din     <= 4'hF;
                wea          <= 1'b1;
                cnt          <= cnt + 1'b1;
            end
            else begin
                wea <= 1'b0;
            end
        end
    end

endmodule
