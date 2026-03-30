`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/17/2026 08:00:19 PM
// Design Name: 
// Module Name: svd_bram_firstcol_checker
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


module svd_bram_firstcol_checker #(
    parameter int W = 17,
    parameter int N = 64,
    parameter int IDX_A = 8258
) (
    input  logic clk,
    input  logic rst,
    input  logic start_capture,
    input  logic start_verify,
    output logic busy,
    output logic done_capture,
    output logic done_verify,
    output logic pass,
    output logic [13:0] rd_addr,
    input  logic [W-1:0] rd_data
);
    localparam int ST_IDLE      = 0;
    localparam int ST_CAP_ADDR  = 1;
    localparam int ST_CAP_WAIT  = 2;
    localparam int ST_CAP_STORE = 3;
    localparam int ST_VFY_ADDR  = 4;
    localparam int ST_VFY_WAIT  = 5;
    localparam int ST_VFY_CMP   = 6;

    logic [2:0] state;
    logic signed [W-1:0] exp_A0 [N];
    int unsigned idx;

    always_ff @(posedge clk) begin
        int r;
        if (rst) begin
            state <= ST_IDLE;
            busy <= 1'b0;
            done_capture <= 1'b0;
            done_verify <= 1'b0;
            pass <= 1'b0;
            rd_addr <= '0;
            idx <= 0;
            for (r = 0; r < N; r = r + 1) begin
                exp_A0[r] <= '0;
            end
        end else begin
            done_capture <= 1'b0;
            done_verify <= 1'b0;

            case (state)
                ST_IDLE: begin
                    busy <= 1'b0;
                    if (start_capture) begin
                        busy <= 1'b1;
                        idx <= 0;
                        state <= ST_CAP_ADDR;
                    end else if (start_verify) begin
                        busy <= 1'b1;
                        pass <= 1'b1;
                        idx <= 0;
                        state <= ST_VFY_ADDR;
                    end
                end

                ST_CAP_ADDR: begin
                    rd_addr <= IDX_A + (idx * N);
                    state <= ST_CAP_WAIT;
                end

                ST_CAP_WAIT: begin
                    state <= ST_CAP_STORE;
                end

                ST_CAP_STORE: begin
                    exp_A0[idx] <= $signed(rd_data);
                    if (idx == N-1) begin
                        busy <= 1'b0;
                        done_capture <= 1'b1;
                        state <= ST_IDLE;
                    end else begin
                        idx <= idx + 1;
                        state <= ST_CAP_ADDR;
                    end
                end

                ST_VFY_ADDR: begin
                    rd_addr <= IDX_A + (idx * N);
                    state <= ST_VFY_WAIT;
                end

                ST_VFY_WAIT: begin
                    state <= ST_VFY_CMP;
                end

                ST_VFY_CMP: begin
                    if ($signed(rd_data) !== exp_A0[idx]) begin
                        pass <= 1'b0;
                    end
                    if (idx == N-1) begin
                        busy <= 1'b0;
                        done_verify <= 1'b1;
                        state <= ST_IDLE;
                    end else begin
                        idx <= idx + 1;
                        state <= ST_VFY_ADDR;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                    busy <= 1'b0;
                end
            endcase
        end
    end

endmodule
