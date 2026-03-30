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
    output VSYNC,
    output led[15:0]
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
    localparam int FRAC = 8;
    localparam int N = 64;
    localparam int MEM_DEPTH = 12354;
    localparam int LED_BLINK_BIT = 24;
    
    logic [13:0] bram_addr;
    logic [W-1:0] bram_dout;
    blk_mem_gen_0 input_bram (
        .clka  (clk),
        .ena   (bram_ena),
        .wea   (bram_wea),
        .addra (bram_addra),
        .dina  (bram_dina),
    
        .clkb  (clk),
        .enb   (load_done),
        .addrb (bram_addr),
        .doutb (bram_dout)
    );
    
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
logic [15:0] wea_count;

always_ff @(posedge clk or posedge reset) begin
    if (reset)
        wea_count <= 16'd0;
    else if (out_wea)
        wea_count <= wea_count + 1'b1;
end

assign led[0] = wea_count[0];
assign led[1] = wea_count[1];
assign led[2] = wea_count[2];
assign led[3] = wea_count[3];
assign led[4] = wea_count[4];
assign led[5] = wea_count[5];
assign led[6] = wea_count[6];
assign led[7] = wea_count[7];
assign led[8] = wea_count[8];
assign led[9] = wea_count[9];
assign led[10] = wea_count[10];
assign led[11] = wea_count[11];
assign led[12] = wea_count[12];
assign led[13] = wea_count[13];
assign led[14] = wea_count[14];
assign led[15] = wea_count[15];

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
