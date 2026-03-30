`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/17/2026 07:53:50 PM
// Design Name: 
// Module Name: vga_buf
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


module vga_buf(
    input clk,
    input reset,
    input en,
    input [3:0] data_in,
    output [15:0] bram_addrb,
    output [11:0] data_out,
    output HSYNC,
    output VSYNC
    );
    
    reg [11:0] vga_data_in;
    wire data_valid;
    wire [9:0] h_valid_count;
    wire [9:0] v_valid_count;
    wire in_range;
    
    reg data_valid_delayed;
     
    vga_output vga_output_1(
        .clk           (clk),
        .reset         (reset),
        .en            (en),
        .data_in       (vga_data_in),
        .data_out      (data_out),
        .HSYNC         (HSYNC),
        .VSYNC         (VSYNC),
        .data_valid    (data_valid),
        .h_valid_count (h_valid_count),
        .v_valid_count (v_valid_count)
    );

    assign in_range = (v_valid_count < 64) && (h_valid_count < 64);
    assign bram_addrb = in_range ? (v_valid_count * 64 + h_valid_count):0;

//    always @(posedge clk) begin
//        if (!en) begin
//            vga_data_in <= 12'h000;
//        end
//        else if (!data_valid) begin
//            vga_data_in <= 12'h000;
//        end
//        else begin
//            vga_data_in <= {data_in[7:4],data_in[7:4],data_in[7:4]};
//        end
//    end

    always @(posedge clk) begin
        if (reset)
            data_valid_delayed <= 1'b0;
        else
            data_valid_delayed <= data_valid;
    end

    always @(posedge clk) begin
        if (!en)
            vga_data_in <= 12'h000;
        else if (!data_valid_delayed)
            vga_data_in <= 12'h000;
        else begin
            if (in_range)
                vga_data_in <= {data_in[3:0],data_in[3:0],data_in[3:0]};
            else
                vga_data_in <= 12'h000;
        end
    end
endmodule
