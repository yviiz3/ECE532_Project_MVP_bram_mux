`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/22/2026 02:03:33 PM
// Design Name: 
// Module Name: uart_buf
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


module uart_buf(
    input clk,
    input reset,
    input write_en,
    input [7:0] data_in,
    output reg bram_ena,
    output reg [0:0] bram_wea,
    output reg [16:0] bram_addra,
    output reg [15:0] bram_dina,
    output reg uart_done
    );

    localparam integer BUF_DEPTH = 120200;

    (* mark_debug = "true" *) reg [16:0] row_count_write;

    reg [7:0] byte0;
    reg [1:0] byte_count;

    always @(posedge clk) begin
        if (reset) begin
            row_count_write <= 14'b0;
            byte0           <= 8'd0;
            byte_count      <= 2'd0;

            bram_ena        <= 1'b0;
            bram_wea        <= 1'b0;
            bram_addra      <= 14'b0;
            bram_dina       <= 17'd0;
            uart_done       <= 1'b0;
        end
        else begin
            bram_ena  <= 1'b0;
            bram_wea  <= 1'b0;
            uart_done <= 1'b0;

            if (write_en) begin
                if (row_count_write < BUF_DEPTH) begin
                    case (byte_count)
                        2'd0: begin
                            byte0      <= data_in;
                            byte_count <= 2'd1;
                        end
                    
                        2'd1: begin
                            bram_ena   <= 1'b1;
                            bram_wea   <= 1'b1;
                            bram_addra <= row_count_write;
                            bram_dina  <= {data_in, byte0};
                    
                            row_count_write <= row_count_write + 1'b1;
                            byte_count      <= 2'd0;
                    
                            if (row_count_write == BUF_DEPTH - 1)
                                uart_done <= 1'b1;
                        end
                    
                        default: begin
                            byte_count <= 2'd0;
                        end
                    endcase
                end
            end
        end
    end

endmodule
