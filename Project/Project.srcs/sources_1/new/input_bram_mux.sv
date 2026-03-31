`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/30/2026 04:15:19 PM
// Design Name: 
// Module Name: input_bram_mux
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


module input_bram_mux #(
    parameter int ADDR_W = 14,
    parameter int DATA_W = 17
)(
    input  logic              clk,
    input  logic              reset,

    output logic              bram_ena,
    output logic [0:0]        bram_wea,
    output logic [ADDR_W-1:0] bram_addra,
    output logic [DATA_W-1:0] bram_dina,
    input  logic [DATA_W-1:0] bram_douta,
    
    output logic              bram_enb,
    output logic [0:0]        bram_web,
    output logic [ADDR_W-1:0] bram_addrb,
    output logic [DATA_W-1:0] bram_dinb,
    input  logic [DATA_W-1:0] bram_doutb,

    // UART
    input  logic              a_en_1,
    input  logic              a_we_1,
    input  logic [ADDR_W-1:0] a_addr_1,
    input  logic [DATA_W-1:0] a_din_1,
    output logic [DATA_W-1:0] a_dout_1,
    input  logic              b_en_1,
    input  logic [ADDR_W-1:0] b_addr_1,
    output logic [DATA_W-1:0] b_dout_1,
    input  logic              status_1,

    // Victor
    input  logic              a_en_2,
    input  logic              a_we_2,
    input  logic [ADDR_W-1:0] a_addr_2,
    input  logic [DATA_W-1:0] a_din_2,
    output logic [DATA_W-1:0] a_dout_2,
    input  logic              b_en_2,
    input  logic [ADDR_W-1:0] b_addr_2,
    output logic [DATA_W-1:0] b_dout_2,
    input  logic              status_2,

    // Jonathan
    input  logic              a_en_3,
    input  logic              a_we_3,
    input  logic [ADDR_W-1:0] a_addr_3,
    input  logic [DATA_W-1:0] a_din_3,
    output logic [DATA_W-1:0] a_dout_3,
    input  logic              b_en_3,
    input  logic [ADDR_W-1:0] b_addr_3,
    output logic [DATA_W-1:0] b_dout_3,
    input  logic              status_3
);

    logic [2:0] status_array;
    logic [2:0] status_array_delayed;

    function automatic logic sel1(
        input logic s0, s1, s2,
        input logic [2:0] st
    );
    begin
        sel1 = (s0 & st[0]) |
               (s1 & st[1]) |
               (s2 & st[2]);
    end
    endfunction

    function automatic [ADDR_W-1:0] sel_addr(
        input logic [ADDR_W-1:0] s0,
        input logic [ADDR_W-1:0] s1,
        input logic [ADDR_W-1:0] s2,
        input logic [2:0] st
    );
    begin
        sel_addr = ({ADDR_W{st[0]}} & s0) |
                   ({ADDR_W{st[1]}} & s1) |
                   ({ADDR_W{st[2]}} & s2);
    end
    endfunction

    function automatic [DATA_W-1:0] sel_data(
        input logic [DATA_W-1:0] s0,
        input logic [DATA_W-1:0] s1,
        input logic [DATA_W-1:0] s2,
        input logic [2:0] st
    );
    begin
        sel_data = ({DATA_W{st[0]}} & s0) |
                   ({DATA_W{st[1]}} & s1) |
                   ({DATA_W{st[2]}} & s2);
    end
    endfunction

    assign status_array = {status_3, status_2, status_1};
    assign bram_ena = sel1(a_en_1, a_en_2, a_en_3, status_array);
    assign bram_wea[0]= sel1(a_we_1, a_we_2, a_we_3, status_array);
    assign bram_addra = sel_addr(a_addr_1, a_addr_2, a_addr_3, status_array);
    assign bram_dina = sel_data(a_din_1, a_din_2, a_din_3, status_array);

    assign bram_enb   = sel1(b_en_1, b_en_2, b_en_3, status_array);
    assign bram_web[0]= 1'b0;
    assign bram_addrb = sel_addr(b_addr_1, b_addr_2, b_addr_3, status_array);
    assign bram_dinb  = '0;

    always @(posedge clk) begin
        if (reset)
            status_array_delayed <= 3'b000;
        else
            status_array_delayed <= status_array;
    end
    
    assign a_dout_1 = status_array_delayed[0] ? bram_douta : '0;
    assign a_dout_2 = status_array_delayed[1] ? bram_douta : '0;
    assign a_dout_3 = status_array_delayed[2] ? bram_douta : '0;
    
    assign b_dout_1 = status_array_delayed[0] ? bram_doutb : '0;
    assign b_dout_2 = status_array_delayed[1] ? bram_doutb : '0;
    assign b_dout_3 = status_array_delayed[2] ? bram_doutb : '0;

endmodule
