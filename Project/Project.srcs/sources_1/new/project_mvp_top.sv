`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/17/2026 06:59:11 PM
// Design Name: 
// Module Name: project_mvp_top
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


module project_mvp_top(
    input clk,
    input reset,
    input en,
    input data_in,
    output [11:0] data_out,
    output HSYNC,
    output VSYNC
    );
    
    wire [7:0] data_out_rx;
    wire rx_state;
    uart_rx uart_rx_1(
        .clk        (clk),
        .reset      (reset),
        .data_in    (data_in),
        .data_out   (data_out_rx),
        .out_state  (rx_state)
    );
    
    wire bram_ena;
    wire [0:0] bram_wea;
    wire [13:0] bram_addra;
    wire [16:0] bram_dina;
    wire uart_done;
    uart_buf uart_buf_1(
        .clk         (clk),
        .reset       (reset),
        .write_en    (rx_state),
        .data_in     (data_out_rx),
        .bram_ena    (bram_ena),
        .bram_wea    (bram_wea),
        .bram_addra  (bram_addra),
        .bram_dina   (bram_dina),
        .uart_done   (uart_done)
    );
    
    reg load_done;
    always @(posedge clk) begin
        if (reset)
            load_done <= 1'b0;
        else if (uart_done)
            load_done <= 1'b1;
    end
    
    localparam int W = 17;
    // mux to input_bram
    logic              mux_bram_ena;
    logic [0:0]        mux_bram_wea;
    logic [13:0]       mux_bram_addra;
    logic [W-1:0]      mux_bram_dina;

    logic              mux_bram_enb;
    logic [13:0]       mux_bram_addrb;
    logic [W-1:0]      mux_bram_doutb;

    logic status_1;
    logic status_2;
    logic status_3;

    assign status_1 = ~load_done;
    assign status_2 = 1'b0;
    assign status_3 =  load_done;

    logic [13:0] bram_addr;
    logic [W-1:0] bram_dout;
    input_bram_mux #(
        .ADDR_W(14),
        .DATA_W(W)
    ) u_input_bram_mux (
        .clk        (clk),
        .reset      (reset),

        .bram_ena   (mux_bram_ena),
        .bram_wea   (mux_bram_wea),
        .bram_addra (mux_bram_addra),
        .bram_dina  (mux_bram_dina),

        .bram_enb   (mux_bram_enb),
        .bram_addrb (mux_bram_addrb),
        .bram_doutb (mux_bram_doutb),

        // UART
        .a_en_1     (bram_ena),
        .a_we_1     (bram_wea[0]),
        .a_addr_1   (bram_addra),
        .a_din_1    (bram_dina),
        .b_en_1     (1'b0),
        .b_addr_1   (14'd0),
        .b_dout_1   (),
        .status_1   (status_1),

        // Victor
        .a_en_2     (1'b0),
        .a_we_2     (1'b0),
        .a_addr_2   (14'd0),
        .a_din_2    ('0),
        .b_en_2     (1'b0),
        .b_addr_2   (14'd0),
        .b_dout_2   (),
        .status_2   (status_2),

        // Jonathan
        .a_en_3     (1'b0),
        .a_we_3     (1'b0),
        .a_addr_3   (14'd0),
        .a_din_3    ('0),
        .b_en_3     (load_done),
        .b_addr_3   (bram_addr),
        .b_dout_3   (bram_dout),
        .status_3   (status_3)
    );
    
    blk_mem_gen_0 input_bram (
        .clka  (clk),
        .ena   (mux_bram_ena),
        .wea   (mux_bram_wea),
        .addra (mux_bram_addra),
        .dina  (mux_bram_dina),

        .clkb  (clk),
        .enb   (mux_bram_enb),
        .addrb (mux_bram_addrb),
        .doutb (mux_bram_doutb)
    );
    
    localparam int FRAC = 8;
    localparam int N = 64;
    localparam int MEM_DEPTH = 12354;
    localparam int LED_BLINK_BIT = 24;
    
    logic [13:0] bram_addr_in;
    logic [W-1:0] bram_din;
    logic wea;
    logic led_pass;
    reconstruction_compute_64_1dsp #(
        .W(W),
        .FRAC(FRAC),
        .N(N),
        .MEM_DEPTH(MEM_DEPTH),
        .LED_BLINK_BIT(LED_BLINK_BIT)
    ) u_compute (
        .clk(clk),
        .rst(reset | ~load_done),
        .bram_dout(bram_dout),
        .bram_addr(bram_addr),
        .bram_addr_in(bram_addr_in),
        .bram_din(bram_din),
        .wea(wea),
        .led_pass(led_pass)
    );
    
    logic [15:0] vga_bram_addr_in;
    logic [3:0] vga_bram_din;
    logic out_wea;
    reconstruction_buf #(
        .W(17),
        .SRC_W(64),
        .DST_W(640),
        .A_BASE(8258)
    ) ir_buf (
        .in_bram_addr_in (bram_addr_in),
        .in_bram_din     (bram_din),
        .in_wea          (wea),
        .out_bram_addr_in(vga_bram_addr_in),
        .out_bram_din    (vga_bram_din),
        .out_wea         (out_wea)
    );

    wire clk_25M;
    wire clk_locked;
    clk_wiz_0 vga_clk (
        .reset(reset),
        .clk_in1(clk),
        .clk_out1(clk_25M),
        .locked(clk_locked)
    );
    
    wire [15:0] bram_addrb_vga;
    wire [3:0] bram_dout_vga;
    blk_mem_gen_1 output_bram (
        .clka  (clk),
        .ena   (1'b1),
        .wea   (out_wea),
        .addra (vga_bram_addr_in),
        .dina  (vga_bram_din),
    
        .clkb  (clk_25M),
        .enb   (en),
        .addrb (bram_addrb_vga),
        .doutb (bram_dout_vga)
    );
    
    vga_buf vga_buf_1(
        .clk           (clk_25M),
        .reset         (reset),
        .en            (en),
        .data_in       (bram_dout_vga),
        .data_out      (data_out),
        .HSYNC         (HSYNC),
        .VSYNC         (VSYNC),
        .bram_addrb    (bram_addrb_vga)
    );
endmodule
