`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/22/2026 01:59:17 PM
// Design Name: 
// Module Name: uart_rx
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


module uart_rx(
    input clk,
    input reset,
    input data_in,
    output reg [7:0] data_out,
    output reg out_state
    );

    reg data_prev;
    reg data_curr;
    reg en;
    (* mark_debug = "true" *) reg [3:0] bit_count;
    (* mark_debug = "true" *) reg [15:0] clk_count;
    
    // detect the falling edge of data signal
    always @(posedge clk) begin
        if (reset) begin
            data_prev <= 1'b0;
            data_curr <= 1'b0;
            en <= 1'b0;
            out_state <= 1'b0;
        end
        else begin
            data_curr <= data_in;
            data_prev <= data_curr;
            if ((data_curr == 0) && (data_prev == 1) && (bit_count == 4'd0))
                en <= 1'b1;
            else if ((bit_count == 4'd9) && (clk_count == 100000000/(2*115200) - 1)) 
                out_state <= 1'b1;
            else if ((bit_count == 4'd9) && (clk_count == 100000000/(2*115200))) begin
                en <= 1'b0;
                out_state <= 1'b0;
            end
        end
    end
    
    // output
    always @(posedge clk) begin
        if (reset)
            data_out <= 8'd0;
        else begin
            if (en) begin
                if (clk_count == 100000000/(2*115200))begin
                    case(bit_count)
                        4'd1: data_out[0] <= data_in;
                        4'd2: data_out[1] <= data_in;
                        4'd3: data_out[2] <= data_in;
                        4'd4: data_out[3] <= data_in;
                        4'd5: data_out[4] <= data_in;
                        4'd6: data_out[5] <= data_in;
                        4'd7: data_out[6] <= data_in;
                        4'd8: data_out[7] <= data_in;
                    endcase
                end
            end else
                data_out <= 8'd0;
        end
    end
    
    // counting how many clock cycles passed
    always @(posedge clk) begin
        if (reset)
            clk_count <= 16'd0;
        else begin
            if (en) begin
                if (clk_count < (100000000/115200 - 1))
                    clk_count <= clk_count + 1;
                else
                    clk_count <= 16'd0;
            end
            else
                clk_count <= 16'd0;
        end
    end
    
    // counting how many bits sent
    always @(posedge clk) begin
        if (reset)
            bit_count <= 4'd0;
        else begin
            if (en) begin
                if (clk_count == (100000000/115200 - 1))
                    bit_count <= bit_count + 1;
                else
                    bit_count <= bit_count;
            end
            else
                bit_count <= 4'd0;
        end
    end
    
endmodule
