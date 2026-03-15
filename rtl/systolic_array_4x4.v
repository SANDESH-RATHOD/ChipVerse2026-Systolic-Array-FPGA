// =============================================================================
// systolic_array_4x4.v  —  PPA Upgraded 4×4 Systolic Array
// =============================================================================
// PIPELINE parameter removed — PE is now always pipelined.
// Set COMPUTE_CYCLES=11 in top module.
// =============================================================================
`timescale 1ns/1ps

module systolic_array_4x4 (
    input  wire        clk,
    input  wire        rst,
    input  wire        en,
    input  wire signed [7:0] a0,a1,a2,a3,
    input  wire signed [7:0] w0,w1,w2,w3,
    output signed [18:0] out00,out01,out02,out03,
    output signed [18:0] out10,out11,out12,out13,
    output signed [18:0] out20,out21,out22,out23,
    output signed [18:0] out30,out31,out32,out33
);
    wire signed [7:0]  a   [0:3][0:4];
    wire signed [7:0]  w   [0:4][0:3];
    wire signed [18:0] acc [0:3][0:3];

    assign a[0][0]=a0; assign a[1][0]=a1;
    assign a[2][0]=a2; assign a[3][0]=a3;
    assign w[0][0]=w0; assign w[0][1]=w1;
    assign w[0][2]=w2; assign w[0][3]=w3;

    genvar r, c;
    generate
        for (r=0; r<4; r=r+1) begin : row
            for (c=0; c<4; c=c+1) begin : col
                PE #(
                    .DATA_WIDTH(8),
                    .ACC_WIDTH(19)
                ) pe_inst (
                    .clk(clk),.rst(rst),
                    .en(en),
                    .a_in(a[r][c]),.w_in(w[r][c]),
                    .a_out(a[r][c+1]),.w_out(w[r+1][c]),
                    .acc(acc[r][c])
                );
            end
        end
    endgenerate

    assign out00=acc[0][0]; assign out01=acc[0][1];
    assign out02=acc[0][2]; assign out03=acc[0][3];
    assign out10=acc[1][0]; assign out11=acc[1][1];
    assign out12=acc[1][2]; assign out13=acc[1][3];
    assign out20=acc[2][0]; assign out21=acc[2][1];
    assign out22=acc[2][2]; assign out23=acc[2][3];
    assign out30=acc[3][0]; assign out31=acc[3][1];
    assign out32=acc[3][2]; assign out33=acc[3][3];

endmodule
