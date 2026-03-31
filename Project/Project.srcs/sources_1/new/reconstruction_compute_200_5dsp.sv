`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/31/2026 12:44:41 PM
// Design Name: 
// Module Name: reconstruction_compute_200_5dsp
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


module reconstruction_compute_200_5dsp #(
    parameter int W = 16,
    parameter int OUT_W = 4,
    parameter int FRAC_UV = 14,
    parameter int N = 200,
    parameter int K = 100,
    parameter int BUF = 5,
    parameter int EXP_MEM_DEPTH = ((3 * N * N) + N),
    parameter int OUT_MEM_DEPTH = (N * N),
    parameter int EXP_ADDR_W = $clog2(EXP_MEM_DEPTH),
    parameter int OUT_ADDR_W = $clog2(OUT_MEM_DEPTH)
) (
    input  logic clk,
    input  logic rst,

    input  logic [W-1:0] exp_u_bram_dout,
    input  logic [W-1:0] exp_v_bram_dout,
    output logic [EXP_ADDR_W-1:0] exp_u_bram_addr,
    output logic [EXP_ADDR_W-1:0] exp_v_bram_addr,

    output logic [OUT_ADDR_W-1:0] out_bram_addr,
    output logic [OUT_W-1:0] out_bram_din,
    output logic out_bram_we,

    output logic done
);
    localparam int IDX_V = (N * N);
    localparam int IDX_U = IDX_V + (N * N);
    localparam int IDX_SIGMA = IDX_U + (N * N);
    localparam int FRAC_SV = 11;
    localparam int FRAC_TERM = FRAC_UV + FRAC_SV;
    localparam int S_MUL_W = 25;
    localparam int SV_DSP_W = 25;
    localparam int SV_BUF_W = 32;
    localparam int VT_MUL_W = 18;

    localparam int ST_LOAD_S_STREAM = 0;
    localparam int ST_INIT_PIXEL    = 1;
    localparam int ST_WAIT_BUF      = 2;
    localparam int ST_MUL_SV        = 3;
    localparam int ST_MUL_TERM      = 4;
    localparam int ST_WRITE_A       = 5;
    localparam int ST_DONE          = 6;

    logic [2:0] state;

    // Sigma preload streamer.
    logic [EXP_ADDR_W-1:0] s_bram_addr;
    logic [7:0] s_issue_idx;
    logic [7:0] s_cap_idx_d0;
    logic [7:0] s_cap_idx_d1;
    logic s_cap_valid_d0;
    logic s_cap_valid_d1;

    // Shared preload outputs.
    logic [EXP_ADDR_W-1:0] pre_u_bram_addr;
    logic [EXP_ADDR_W-1:0] pre_v_bram_addr;
    logic pre_wr_en;
    logic pre_wr_bank;
    logic [2:0] pre_wr_lane;
    logic signed [W-1:0] pre_wr_u_data;
    logic signed [W-1:0] pre_wr_v_data;
    logic pre_ready_pulse;
    logic pre_ready_bank;

    // Sigma is stored as an unsigned 16-bit integer in memory.
    // Keep a zero-extended signed copy locally so the S*V multiply
    // cannot reinterpret values above 0x7fff as negative.
    logic signed [W:0] s_cache [0:K-1];
    logic signed [W-1:0] u_buf_bank [0:1][0:BUF-1];
    logic signed [W-1:0] v_buf_bank [0:1][0:BUF-1];
    // Keep a sign-extended copy of the Q14.11 result for debug and stable signed handling.
    // Only the lower 25 bits feed the U*SV DSP path.
    logic signed [SV_BUF_W-1:0] sv_buf [0:BUF-1];
    logic ready_bank [0:1];

    logic comp_bank;
    logic [7:0] comp_base_t;
    logic [7:0] i;
    logic [7:0] j;

    logic signed [47:0] acc;
    logic signed [47:0] chunk_sum;
    logic signed [47:0] acc_int;
    logic [7:0] pixel_u8;

    logic pre_enable;
    logic pre_start_pixel;

    integer lane_comb;
    integer lane_ff;

    function automatic logic signed [SV_BUF_W-1:0] calc_sv_q14_11(
        input logic signed [W:0] s_val,
        input logic signed [W-1:0] vt_val
    );
        logic signed [S_MUL_W-1:0] s_ext;
        logic signed [VT_MUL_W-1:0] vt_ext;
        logic signed [S_MUL_W+VT_MUL_W-1:0] prod;
        begin
            s_ext = $signed({{(S_MUL_W-(W+1)){1'b0}}, s_val});
            vt_ext = $signed({{(VT_MUL_W-W){vt_val[W-1]}}, vt_val});
            prod = s_ext * vt_ext;
            calc_sv_q14_11 = prod >>> (FRAC_UV - FRAC_SV);
        end
    endfunction

    assign pre_enable = (state >= ST_WAIT_BUF) && (state <= ST_MUL_TERM);
    assign pre_start_pixel = (state == ST_INIT_PIXEL);

    assign exp_u_bram_addr = pre_u_bram_addr;
    assign exp_v_bram_addr = (state == ST_LOAD_S_STREAM) ? s_bram_addr : pre_v_bram_addr;

    always_comb begin
        chunk_sum = '0;
        for (lane_comb = 0; lane_comb < BUF; lane_comb = lane_comb + 1) begin
            chunk_sum = chunk_sum
                      + ($signed(u_buf_bank[comp_bank][lane_comb])
                       * $signed(sv_buf[lane_comb][SV_DSP_W-1:0]));
        end

        acc_int = acc >>> FRAC_TERM;

        if (acc_int < 0) begin
            pixel_u8 = 8'd0;
        end else if (acc_int > 48'sd255) begin
            pixel_u8 = 8'd255;
        end else begin
            pixel_u8 = acc_int[7:0];
        end
    end

    svd_preloader_200_5dsp #(
        .W(W),
        .N(N),
        .K(K),
        .BUF(BUF),
        .EXP_MEM_DEPTH(EXP_MEM_DEPTH),
        .EXP_ADDR_W(EXP_ADDR_W),
        .IDX_U(IDX_U),
        .IDX_V(IDX_V)
    ) u_preloader (
        .clk(clk),
        .rst(rst),
        .enable(pre_enable),
        .start_pixel(pre_start_pixel),
        .i(i),
        .j(j),
        .bank0_ready(ready_bank[0]),
        .bank1_ready(ready_bank[1]),
        .exp_u_bram_dout(exp_u_bram_dout),
        .exp_v_bram_dout(exp_v_bram_dout),
        .exp_u_bram_addr(pre_u_bram_addr),
        .exp_v_bram_addr(pre_v_bram_addr),
        .wr_en(pre_wr_en),
        .wr_bank(pre_wr_bank),
        .wr_lane(pre_wr_lane),
        .wr_u_data(pre_wr_u_data),
        .wr_v_data(pre_wr_v_data),
        .ready_pulse(pre_ready_pulse),
        .ready_bank(pre_ready_bank)
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= ST_LOAD_S_STREAM;
            s_bram_addr <= IDX_SIGMA[EXP_ADDR_W-1:0];

            out_bram_addr <= '0;
            out_bram_din <= '0;
            out_bram_we <= 1'b0;
            done <= 1'b0;

            s_issue_idx <= '0;
            s_cap_idx_d0 <= '0;
            s_cap_idx_d1 <= '0;
            s_cap_valid_d0 <= 1'b0;
            s_cap_valid_d1 <= 1'b0;

            ready_bank[0] <= 1'b0;
            ready_bank[1] <= 1'b0;

            comp_bank <= 1'b0;
            comp_base_t <= '0;
            i <= '0;
            j <= '0;
            acc <= '0;

            for (lane_ff = 0; lane_ff < K; lane_ff = lane_ff + 1) begin
                s_cache[lane_ff] <= '0;
            end
            for (lane_ff = 0; lane_ff < BUF; lane_ff = lane_ff + 1) begin
                u_buf_bank[0][lane_ff] <= '0;
                u_buf_bank[1][lane_ff] <= '0;
                v_buf_bank[0][lane_ff] <= '0;
                v_buf_bank[1][lane_ff] <= '0;
                sv_buf[lane_ff] <= '0;
            end
        end else begin
            out_bram_we <= 1'b0;

            if (pre_wr_en) begin
                u_buf_bank[pre_wr_bank][pre_wr_lane] <= pre_wr_u_data;
                v_buf_bank[pre_wr_bank][pre_wr_lane] <= pre_wr_v_data;
            end
            if (pre_ready_pulse) begin
                ready_bank[pre_ready_bank] <= 1'b1;
            end

            case (state)
                ST_LOAD_S_STREAM: begin
                    if (s_cap_valid_d1) begin
                        s_cache[s_cap_idx_d1] <= $signed({1'b0, exp_v_bram_dout});
                    end

                    s_cap_idx_d1 <= s_cap_idx_d0;
                    s_cap_valid_d1 <= s_cap_valid_d0;

                    if (s_issue_idx < K) begin
                        s_bram_addr <= IDX_SIGMA + s_issue_idx;
                        s_cap_idx_d0 <= s_issue_idx;
                        s_cap_valid_d0 <= 1'b1;
                        s_issue_idx <= s_issue_idx + 1'b1;
                    end else begin
                        s_cap_valid_d0 <= 1'b0;
                    end

                    if (s_cap_valid_d1 && (s_cap_idx_d1 == K-1)) begin
                        state <= ST_INIT_PIXEL;
                    end
                end

                ST_INIT_PIXEL: begin
                    acc <= '0;
                    comp_base_t <= '0;
                    comp_bank <= 1'b0;
                    ready_bank[0] <= 1'b0;
                    ready_bank[1] <= 1'b0;
                    state <= ST_WAIT_BUF;
                end

                ST_WAIT_BUF: begin
                    if (ready_bank[comp_bank]) begin
                        state <= ST_MUL_SV;
                    end
                end

                ST_MUL_SV: begin
                    for (lane_ff = 0; lane_ff < BUF; lane_ff = lane_ff + 1) begin
                        sv_buf[lane_ff] <= calc_sv_q14_11(
                            s_cache[comp_base_t + lane_ff],
                            v_buf_bank[comp_bank][lane_ff]
                        );
                    end
                    state <= ST_MUL_TERM;
                end

                ST_MUL_TERM: begin
                    acc <= acc + chunk_sum;
                    ready_bank[comp_bank] <= 1'b0;

                    if ((comp_base_t + BUF) >= K) begin
                        state <= ST_WRITE_A;
                    end else begin
                        comp_base_t <= comp_base_t + BUF;
                        comp_bank <= ~comp_bank;
                        state <= ST_WAIT_BUF;
                    end
                end

                ST_WRITE_A: begin
                    out_bram_addr <= (i * N) + j;
                    out_bram_din <= pixel_u8[7:4];
                    out_bram_we <= 1'b1;

                    if ((i == N-1) && (j == N-1)) begin
                        state <= ST_DONE;
                    end else begin
                        if (j == N-1) begin
                            i <= i + 1'b1;
                            j <= '0;
                        end else begin
                            j <= j + 1'b1;
                        end
                        state <= ST_INIT_PIXEL;
                    end
                end

                ST_DONE: begin
                    done <= 1'b1;
                    state <= ST_DONE;
                end

                default: begin
                    done <= 1'b1;
                    state <= ST_DONE;
                end
            endcase
        end
    end

endmodule

