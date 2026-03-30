`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/17/2026 06:40:46 PM
// Design Name: 
// Module Name: reconstruction_compute_64_1dsp
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


module reconstruction_compute_64_1dsp #(
    parameter int W = 17,
    parameter int FRAC = 8,
    parameter int N = 64,
    parameter int MEM_DEPTH = 12354,
    parameter int LED_BLINK_BIT = 24
) (
    input  logic clk,
    input  logic rst,
    input  logic [W-1:0] bram_dout,
    output logic [13:0] bram_addr,
    output logic [13:0] bram_addr_in,
    output logic [W-1:0] bram_din,
    output logic wea,
    output logic led_pass
);
    localparam int IDX_SCALE = 0;
    localparam int IDX_K = 1;
    localparam int IDX_U = 2;
    localparam int IDX_S = IDX_U + (N * N);
    localparam int IDX_VT = IDX_S + N;
    localparam int IDX_A = IDX_VT + (N * N);

    localparam int ST_RD_SCALE_ADDR   = 0;
    localparam int ST_RD_SCALE_WAIT   = 1;
    localparam int ST_RD_SCALE_CAP    = 2;
    localparam int ST_RD_K_ADDR       = 3;
    localparam int ST_RD_K_WAIT       = 4;
    localparam int ST_RD_K_CAP        = 5;
    localparam int ST_CHK_CAP_START   = 6;
    localparam int ST_CHK_CAP_WAIT    = 7;
    localparam int ST_CHECK_T         = 8;
    localparam int ST_RD_S_ADDR       = 9;
    localparam int ST_RD_S_WAIT       = 10;
    localparam int ST_RD_S_CAP        = 11;
    localparam int ST_RD_U_ADDR       = 12;
    localparam int ST_RD_U_WAIT       = 13;
    localparam int ST_RD_U_CAP        = 14;
    localparam int ST_RD_V_ADDR       = 15;
    localparam int ST_RD_V_WAIT       = 16;
    localparam int ST_RD_V_CAP        = 17;
    localparam int ST_MUL_SCALE       = 18;
    localparam int ST_MUL_SV          = 19;
    localparam int ST_MUL_TERM        = 20;
    localparam int ST_WRITE_A         = 21;
    localparam int ST_CHK_VFY_START   = 22;
    localparam int ST_CHK_VFY_WAIT    = 23;
    localparam int ST_CHK_VFY_DECIDE  = 24;
    localparam int ST_PASS            = 25;
    localparam int ST_FAIL            = 26;

    logic [4:0] state;
    logic [13:0] compute_rd_addr;

    logic checker_start_capture;
    logic checker_start_verify;
    logic checker_busy;
    logic checker_done_capture;
    logic checker_done_verify;
    logic checker_pass;
    logic [13:0] checker_rd_addr;

    logic ready;
    logic done;

    logic signed [W-1:0] scale_reg;
    logic [$clog2(N+1)-1:0] k_reg;
    int unsigned i;
    int unsigned j;
    int unsigned t;

    logic signed [W-1:0] s_reg;
    logic signed [W-1:0] u_reg;
    logic signed [W-1:0] vt_reg;
    logic signed [W-1:0] scaled_s_reg;
    logic signed [W-1:0] sv_reg;
    logic signed [W-1:0] mul_a;
    logic signed [W-1:0] mul_b;
    logic signed [W-1:0] mul_out;
    logic signed [2*W+2:0] acc;
    logic signed [2*W+2:0] acc_next;
    logic [31:0] led_ctr;
    logic [31:0] counter;
    logic [W-1:0] ila_bram_din;

    function automatic logic signed [W-1:0] fx_mul(
        input logic signed [W-1:0] a,
        input logic signed [W-1:0] b
    );
        logic signed [2*W-1:0] prod;
        begin
            prod = a * b;
            fx_mul = prod >>> FRAC;
        end
    endfunction

    assign bram_addr = checker_busy ? checker_rd_addr : compute_rd_addr;
    assign ila_bram_din = bram_din;

    svd_bram_firstcol_checker #(
        .W(W),
        .N(N),
        .IDX_A(IDX_A)
    ) u_checker (
        .clk(clk),
        .rst(rst),
        .start_capture(checker_start_capture),
        .start_verify(checker_start_verify),
        .busy(checker_busy),
        .done_capture(checker_done_capture),
        .done_verify(checker_done_verify),
        .pass(checker_pass),
        .rd_addr(checker_rd_addr),
        .rd_data(bram_dout)
    );

//    ila_0 u_ila (
//        .clk(clk),
//        .probe0(ila_bram_din),
//        .probe1({ready}),
//        .probe2({done})
//    );

    always_comb begin
        mul_a = '0;
        mul_b = '0;
        case (state)
            ST_MUL_SCALE: begin
                mul_a = s_reg;
                mul_b = scale_reg;
            end
            ST_MUL_SV: begin
                mul_a = scaled_s_reg;
                mul_b = vt_reg;
            end
            ST_MUL_TERM: begin
                mul_a = u_reg;
                mul_b = sv_reg;
            end
            default: begin
                mul_a = '0;
                mul_b = '0;
            end
        endcase
    end

    assign mul_out = fx_mul(mul_a, mul_b);
    assign acc_next = acc + {{(W+3){mul_out[W-1]}}, mul_out};

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= ST_RD_SCALE_ADDR;
            wea <= 1'b0;
            bram_addr_in <= '0;
            bram_din <= '0;
            compute_rd_addr <= '0;
            checker_start_capture <= 1'b0;
            checker_start_verify <= 1'b0;
            ready <= 1'b0;
            done <= 1'b0;
            led_pass <= 1'b0;
            led_ctr <= '0;
            counter <= '0;
            scale_reg <= '0;
            k_reg <= '0;
            i <= 0;
            j <= 0;
            t <= 0;
            s_reg <= '0;
            u_reg <= '0;
            vt_reg <= '0;
            scaled_s_reg <= '0;
            sv_reg <= '0;
            acc <= '0;
        end else begin
            wea <= 1'b0;
            done <= 1'b0;
            checker_start_capture <= 1'b0;
            checker_start_verify <= 1'b0;

            if (state == ST_PASS) begin
                led_ctr <= led_ctr + 1'b1;
                led_pass <= led_ctr[LED_BLINK_BIT];
            end else begin
                led_ctr <= '0;
                led_pass <= 1'b0;
            end

            case (state)
                ST_RD_SCALE_ADDR: begin
                    compute_rd_addr <= IDX_SCALE;
                    state <= ST_RD_SCALE_WAIT;
                end

                ST_RD_SCALE_WAIT: begin
                    state <= ST_RD_SCALE_CAP;
                end

                ST_RD_SCALE_CAP: begin
                    scale_reg <= $signed(bram_dout);
                    state <= ST_RD_K_ADDR;
                end

                ST_RD_K_ADDR: begin
                    compute_rd_addr <= IDX_K;
                    state <= ST_RD_K_WAIT;
                end

                ST_RD_K_WAIT: begin
                    state <= ST_RD_K_CAP;
                end

                ST_RD_K_CAP: begin
                    k_reg <= bram_dout[$clog2(N+1)-1:0];
                    ready <= 1'b0;
                    state <= ST_CHK_CAP_START;
                end

                ST_CHK_CAP_START: begin
                    checker_start_capture <= 1'b1;
                    state <= ST_CHK_CAP_WAIT;
                end

                ST_CHK_CAP_WAIT: begin
                    if (checker_done_capture) begin
                        ready <= 1'b1;
                        i <= 0;
                        j <= 0;
                        t <= 0;
                        acc <= '0;
                        state <= ST_CHECK_T;
                    end
                end

                ST_CHECK_T: begin
                    if (t >= k_reg) begin                       
                        state <= ST_WRITE_A;                   
                    end else begin
                        state <= ST_RD_S_ADDR;
                    end
                end

                ST_RD_S_ADDR: begin
                    compute_rd_addr <= IDX_S + t;
                    state <= ST_RD_S_WAIT;
                end

                ST_RD_S_WAIT: begin
                    state <= ST_RD_S_CAP;
                end

                ST_RD_S_CAP: begin
                    s_reg <= $signed(bram_dout);
                    state <= ST_RD_U_ADDR;
                end

                ST_RD_U_ADDR: begin
                    compute_rd_addr <= IDX_U + (i * N) + t;
                    state <= ST_RD_U_WAIT;
                end

                ST_RD_U_WAIT: begin
                    state <= ST_RD_U_CAP;
                end

                ST_RD_U_CAP: begin
                    u_reg <= $signed(bram_dout);
                    state <= ST_RD_V_ADDR;
                end

                ST_RD_V_ADDR: begin
                    compute_rd_addr <= IDX_VT + (t * N) + j;
                    state <= ST_RD_V_WAIT;
                end

                ST_RD_V_WAIT: begin
                    state <= ST_RD_V_CAP;
                end

                ST_RD_V_CAP: begin
                    vt_reg <= $signed(bram_dout);
                    state <= ST_MUL_SCALE;
                end

                ST_MUL_SCALE: begin
                    scaled_s_reg <= mul_out;
                    state <= ST_MUL_SV;
                end

                ST_MUL_SV: begin
                    sv_reg <= mul_out;
                    state <= ST_MUL_TERM;
                end

                ST_MUL_TERM: begin
                    acc <= acc_next;
                    if (t == N-1) begin
                        state <= ST_WRITE_A;
                    end else begin
                        t <= t + 1;
                        state <= ST_CHECK_T;
                    end
                end

                ST_WRITE_A: begin
                    bram_addr_in <= IDX_A + (i * N) + j;
                    bram_din <= acc[W-1:0] <<< 8;
                    wea <= 1'b1;

                    if (i == N-1 && j == N-1) begin
                        state <= ST_CHK_VFY_START;
                    end else begin
                        if (j == N-1) begin
                            i <= i + 1;
                            j <= 0;
                        end else begin
                            j <= j + 1;
                        end
                        t <= 0;
                        acc <= '0;
                        state <= ST_CHECK_T;
                    end
                end

                ST_CHK_VFY_START: begin
                    checker_start_verify <= 1'b1;
                    state <= ST_CHK_VFY_WAIT;
                end

                ST_CHK_VFY_WAIT: begin
                    if (checker_done_verify) begin
                        if (checker_pass) begin
                            state <= ST_PASS;
                        end else begin
                            state <= ST_FAIL;
                        end
                    end
                end

                ST_PASS: begin
                    done <= 1'b1;
                    ready <= 1'b1;
                    state <= ST_PASS;
                end

                ST_FAIL: begin
                    done <= 1'b1;
                    ready <= 1'b1;
                    state <= ST_FAIL;
                end

                default: begin
                    counter <= counter + 1'b1;
                    if (counter[30]) begin
                        state <= ST_RD_SCALE_ADDR;
                        ready <= 1'b0;
                        done <= 1'b0;
                        i <= 0;
                        j <= 0;
                        t <= 0;
                        acc <= '0;
                    end
                end
            endcase
        end
    end

endmodule
