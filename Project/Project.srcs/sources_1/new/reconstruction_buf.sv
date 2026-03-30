`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/17/2026 08:27:15 PM
// Design Name: 
// Module Name: reconstruction_buf
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


module reconstruction_buf #(
    parameter int W      = 17,
    parameter int SRC_W  = 64,
    parameter int DST_W  = 640,
    parameter int A_BASE = 8258
)(
    input  logic [13:0]       in_bram_addr_in,
    input  logic [W-1:0]      in_bram_din,       // Q9.8
    input  logic              in_wea,

    output logic [15:0]       out_bram_addr_in,
    output logic [3:0]        out_bram_din,
    output logic              out_wea
);

//    logic [13:0] pix_idx;
//    logic [5:0]  x;
//    logic [5:0]  y;

//    always_comb begin
//        out_wea          = 1'b0;
//        out_bram_addr_in = 19'd0;
//        out_bram_din     = 4'd0;

//        if (in_wea &&
//            (in_bram_addr_in >= A_BASE) &&
//            (in_bram_addr_in <  A_BASE + SRC_W*SRC_W)) begin

//            pix_idx = in_bram_addr_in - A_BASE;   // 0~4095
//            x       = pix_idx[5:0];
//            y       = pix_idx[11:6];

//            out_wea          = 1'b1;
//            out_bram_addr_in = y * DST_W + x;

//            // Q9.8 ? 0~255 -> 0~15
//            if ($signed(in_bram_din) <= 0)
//                out_bram_din = 4'd0;
//            else if ($signed(in_bram_din) >= (17'sd255 <<< 8))
//                out_bram_din = 4'd15;
//            else
//                out_bram_din = in_bram_din[15:12];
//        end
//    end

    always_comb begin
            out_wea          = 1'b0;
            out_bram_addr_in = 19'd0;
            out_bram_din     = 4'd0;
    
            if (in_wea &&
                (in_bram_addr_in >= A_BASE) &&
                (in_bram_addr_in <  A_BASE + SRC_W*SRC_W)) begin
                
                out_wea          = 1'b1;
                out_bram_addr_in = in_bram_addr_in - A_BASE;
                
                if ($signed(in_bram_din) <= 0)
                    out_bram_din = 4'd0;
                else if ($signed(in_bram_din) >= (17'sd255 <<< 8))
                    out_bram_din = 4'd15;
                else
                    out_bram_din = in_bram_din[15:12];
            end
        end

endmodule
