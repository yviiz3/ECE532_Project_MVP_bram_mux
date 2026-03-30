`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/17/2026 07:54:29 PM
// Design Name: 
// Module Name: vga_output
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


module vga_output(
    input clk,
    input reset,
    input en,
    input [11:0] data_in,
    output [11:0] data_out,
    output reg HSYNC,
    output reg VSYNC,
    output reg data_valid,
    output reg [9:0] h_valid_count,
    output reg [9:0] v_valid_count
    );
    
    parameter H_SYNC = 'd95;
    parameter V_SYNC = 'd1;
    parameter H_VISIBLE_LEFT = 'd143;
    parameter H_VISIBLE_RIGHT = 'd783;
    parameter V_VISIBLE_TOP = 'd34;
    parameter V_VISIBLE_BOTTOM = 'd514;
    parameter H_TOTAL = 'd799;
    parameter V_TOTAL = 'd524;
    
    reg [9:0] h_count;
    reg [9:0] v_count;
    
    reg en_delay;
    always @(posedge clk) begin
        if (reset)
            en_delay <= 0;
        else if (en)
            en_delay <= en;
        else 
            en_delay <= 0;
    end
    
    // h_count
    always @(posedge clk) begin
        if (reset)
            h_count <= 0;
        else if (en_delay) begin
            if (h_count == H_TOTAL)
                h_count <= 0;
            else
                h_count <= h_count + 1;
        end
        else 
            h_count <= 0;
    end
    
    // v_count
    always @(posedge clk) begin
        if (reset)
            v_count <= 0;
        else if (en_delay) begin
            if ((v_count == V_TOTAL) && (h_count == H_TOTAL))
                v_count <= 0;
            else if (h_count == H_TOTAL)
                v_count <= v_count + 1;
            else
                v_count <= v_count;
        end
        else 
            v_count <= 0;
    end
    
    // HSYNC
    always @(posedge clk) begin
        if (reset)
            HSYNC <= 1;
        else if (en) begin
            if ((h_count < H_SYNC) || (h_count == H_TOTAL))
                HSYNC <= 0;
            else
                HSYNC <= 1;
        end
        else 
            HSYNC <= 1;
    end
        
    // VSYNC
    always @(posedge clk) begin
        if (reset)
            VSYNC <= 1;
        else if (en) begin
            if (v_count < V_SYNC)
                VSYNC <= 0;
            else if ((v_count == V_SYNC) && (h_count < H_TOTAL))
                VSYNC <= 0;
            else if ((v_count == V_TOTAL) && (h_count == H_TOTAL))
                VSYNC <= 0;
            else
                VSYNC <= 1;
        end
        else 
            VSYNC <= 1;
    end
        
    // valid
    always @(posedge clk) begin
        if (reset)
            data_valid <= 0;
        else if (en) begin
            if ((h_count >= H_VISIBLE_LEFT) && (h_count < H_VISIBLE_RIGHT) && (v_count > V_VISIBLE_TOP) && (v_count <= V_VISIBLE_BOTTOM))
                data_valid <= 1;
            else
                data_valid <= 0;
        end
        else 
            data_valid <= 0;
    end
    
    // data_out
    assign data_out = data_valid? data_in : 'd0;
    
    always @(posedge clk) begin
        if (reset) begin
            h_valid_count <= 0;
            v_valid_count <= 0;
        end
        else if (en) begin
            if ((h_count >= H_VISIBLE_LEFT) && (h_count < H_VISIBLE_RIGHT) && (v_count > V_VISIBLE_TOP) && (v_count <= V_VISIBLE_BOTTOM)) begin
                h_valid_count <= h_count - H_VISIBLE_LEFT;
                v_valid_count <= v_count - V_VISIBLE_TOP - 1;
            end
            else begin
                h_valid_count <= 0;
                v_valid_count <= 0;
            end
        end
        else begin
            h_valid_count <= 0;
            v_valid_count <= 0;
        end
    end
    
endmodule
