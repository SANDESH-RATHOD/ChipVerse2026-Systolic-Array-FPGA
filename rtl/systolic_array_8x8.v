// =============================================================================
// systolic_array_8x8.v  —  Fixed 8×8 Systolic Array
// =============================================================================
// FIX: ACC_WIDTH 17→19  (max 262143 > 127*127*15 = 241935, no overflow)
//      Output port widths updated to [ACC_WIDTH-1:0] = [18:0]
// =============================================================================
`timescale 1ns/1ps

module systolic_array_8x8 #(
    parameter SIZE       = 8,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 19              // FIX: was 17
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        en,
    input  wire signed [7:0] a0,a1,a2,a3,a4,a5,a6,a7,
    input  wire signed [7:0] w0,w1,w2,w3,w4,w5,w6,w7,
    output signed [ACC_WIDTH-1:0] out00,out01,out02,out03,out04,out05,out06,out07,
    output signed [ACC_WIDTH-1:0] out10,out11,out12,out13,out14,out15,out16,out17,
    output signed [ACC_WIDTH-1:0] out20,out21,out22,out23,out24,out25,out26,out27,
    output signed [ACC_WIDTH-1:0] out30,out31,out32,out33,out34,out35,out36,out37,
    output signed [ACC_WIDTH-1:0] out40,out41,out42,out43,out44,out45,out46,out47,
    output signed [ACC_WIDTH-1:0] out50,out51,out52,out53,out54,out55,out56,out57,
    output signed [ACC_WIDTH-1:0] out60,out61,out62,out63,out64,out65,out66,out67,
    output signed [ACC_WIDTH-1:0] out70,out71,out72,out73,out74,out75,out76,out77
);

    wire signed [7:0]           a   [0:7][0:8];
    wire signed [7:0]           w   [0:8][0:7];
    wire signed [ACC_WIDTH-1:0] acc [0:7][0:7];

    assign a[0][0]=a0;assign a[1][0]=a1;assign a[2][0]=a2;assign a[3][0]=a3;
    assign a[4][0]=a4;assign a[5][0]=a5;assign a[6][0]=a6;assign a[7][0]=a7;
    assign w[0][0]=w0;assign w[0][1]=w1;assign w[0][2]=w2;assign w[0][3]=w3;
    assign w[0][4]=w4;assign w[0][5]=w5;assign w[0][6]=w6;assign w[0][7]=w7;

    genvar r, c;
    generate
        for (r=0; r<SIZE; r=r+1) begin : row
            for (c=0; c<SIZE; c=c+1) begin : col
                PE #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH(ACC_WIDTH)
                ) pe_inst (
                    .clk(clk),.rst(rst),.en(en),
                    .a_in(a[r][c]),.w_in(w[r][c]),
                    .a_out(a[r][c+1]),.w_out(w[r+1][c]),
                    .acc(acc[r][c])
                );
            end
        end
    endgenerate

    assign out00=acc[0][0];assign out01=acc[0][1];assign out02=acc[0][2];assign out03=acc[0][3];
    assign out04=acc[0][4];assign out05=acc[0][5];assign out06=acc[0][6];assign out07=acc[0][7];
    assign out10=acc[1][0];assign out11=acc[1][1];assign out12=acc[1][2];assign out13=acc[1][3];
    assign out14=acc[1][4];assign out15=acc[1][5];assign out16=acc[1][6];assign out17=acc[1][7];
    assign out20=acc[2][0];assign out21=acc[2][1];assign out22=acc[2][2];assign out23=acc[2][3];
    assign out24=acc[2][4];assign out25=acc[2][5];assign out26=acc[2][6];assign out27=acc[2][7];
    assign out30=acc[3][0];assign out31=acc[3][1];assign out32=acc[3][2];assign out33=acc[3][3];
    assign out34=acc[3][4];assign out35=acc[3][5];assign out36=acc[3][6];assign out37=acc[3][7];
    assign out40=acc[4][0];assign out41=acc[4][1];assign out42=acc[4][2];assign out43=acc[4][3];
    assign out44=acc[4][4];assign out45=acc[4][5];assign out46=acc[4][6];assign out47=acc[4][7];
    assign out50=acc[5][0];assign out51=acc[5][1];assign out52=acc[5][2];assign out53=acc[5][3];
    assign out54=acc[5][4];assign out55=acc[5][5];assign out56=acc[5][6];assign out57=acc[5][7];
    assign out60=acc[6][0];assign out61=acc[6][1];assign out62=acc[6][2];assign out63=acc[6][3];
    assign out64=acc[6][4];assign out65=acc[6][5];assign out66=acc[6][6];assign out67=acc[6][7];
    assign out70=acc[7][0];assign out71=acc[7][1];assign out72=acc[7][2];assign out73=acc[7][3];
    assign out74=acc[7][4];assign out75=acc[7][5];assign out76=acc[7][6];assign out77=acc[7][7];

endmodule
