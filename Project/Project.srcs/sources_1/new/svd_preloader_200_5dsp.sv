`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/31/2026 12:45:45 PM
// Design Name: 
// Module Name: svd_preloader_200_5dsp
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


module svd_preloader_200_5dsp #(
    parameter int W = 16,
    parameter int N = 200,
    parameter int K = 100,
    parameter int BUF = 5,
    parameter int EXP_MEM_DEPTH = ((3 * N * N) + N),
    parameter int EXP_ADDR_W = $clog2(EXP_MEM_DEPTH),
    parameter int IDX_V = (N * N),
    parameter int IDX_U = IDX_V + (N * N)
) (
    input  logic clk,
    input  logic rst,
    input  logic enable,
    input  logic start_pixel,

    input  logic [7:0] i,
    input  logic [7:0] j,

    input  logic bank0_ready,
    input  logic bank1_ready,

    input  logic [W-1:0] exp_u_bram_dout,
    input  logic [W-1:0] exp_v_bram_dout,
    output logic [EXP_ADDR_W-1:0] exp_u_bram_addr,
    output logic [EXP_ADDR_W-1:0] exp_v_bram_addr,

    output logic wr_en,
    output logic wr_bank,
    output logic [2:0] wr_lane,
    output logic signed [W-1:0] wr_u_data,
    output logic signed [W-1:0] wr_v_data,

    output logic ready_pulse,
    output logic ready_bank
);
    logic load_active;
    logic sched_bank;
    logic ld_bank;
    logic [7:0] next_load_t;
    logic [7:0] ld_base_t;
    logic [2:0] ld_issue_idx;
    logic [2:0] ld_cap_count;
    logic ld_cap_valid_d0;
    logic ld_cap_valid_d1;
    logic [2:0] ld_cap_lane_d0;
    logic [2:0] ld_cap_lane_d1;

    logic target_bank_ready;

    always_comb begin
        target_bank_ready = sched_bank ? bank1_ready : bank0_ready;

        wr_en = ld_cap_valid_d1;
        wr_bank = ld_bank;
        wr_lane = ld_cap_lane_d1;
        wr_u_data = $signed(exp_u_bram_dout);
        wr_v_data = $signed(exp_v_bram_dout);

        ready_pulse = load_active && ld_cap_valid_d1 && (ld_cap_count == BUF-1);
        ready_bank = ld_bank;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            exp_u_bram_addr <= IDX_U[EXP_ADDR_W-1:0];
            exp_v_bram_addr <= IDX_V[EXP_ADDR_W-1:0];

            load_active <= 1'b0;
            sched_bank <= 1'b0;
            ld_bank <= 1'b0;
            next_load_t <= '0;
            ld_base_t <= '0;
            ld_issue_idx <= '0;
            ld_cap_count <= '0;
            ld_cap_valid_d0 <= 1'b0;
            ld_cap_valid_d1 <= 1'b0;
            ld_cap_lane_d0 <= '0;
            ld_cap_lane_d1 <= '0;
        end else begin
            if (start_pixel) begin
                load_active <= 1'b0;
                sched_bank <= 1'b0;
                ld_bank <= 1'b0;
                next_load_t <= '0;
                ld_base_t <= '0;
                ld_issue_idx <= '0;
                ld_cap_count <= '0;
                ld_cap_valid_d0 <= 1'b0;
                ld_cap_valid_d1 <= 1'b0;
                ld_cap_lane_d0 <= '0;
                ld_cap_lane_d1 <= '0;
            end else if (enable) begin
                if ((!load_active) && (next_load_t < K) && (!target_bank_ready)) begin
                    load_active <= 1'b1;
                    ld_bank <= sched_bank;
                    ld_base_t <= next_load_t;
                    ld_issue_idx <= '0;
                    ld_cap_count <= '0;
                    ld_cap_valid_d0 <= 1'b0;
                    ld_cap_valid_d1 <= 1'b0;
                    ld_cap_lane_d0 <= '0;
                    ld_cap_lane_d1 <= '0;

                    next_load_t <= next_load_t + BUF;
                    sched_bank <= ~sched_bank;
                end else if (load_active) begin
                    ld_cap_valid_d1 <= ld_cap_valid_d0;
                    ld_cap_lane_d1 <= ld_cap_lane_d0;

                    if (ld_cap_valid_d1) begin
                        ld_cap_count <= ld_cap_count + 1'b1;
                    end

                    if (ld_issue_idx < BUF) begin
                        exp_u_bram_addr <= IDX_U + (i * N) + ld_base_t + ld_issue_idx;
                        exp_v_bram_addr <= IDX_V + (j * N) + ld_base_t + ld_issue_idx;
                        ld_cap_valid_d0 <= 1'b1;
                        ld_cap_lane_d0 <= ld_issue_idx;
                        ld_issue_idx <= ld_issue_idx + 1'b1;
                    end else begin
                        ld_cap_valid_d0 <= 1'b0;
                        if (ld_cap_valid_d1 && (ld_cap_count == BUF-1)) begin
                            load_active <= 1'b0;
                        end
                    end
                end
            end
        end
    end

endmodule

