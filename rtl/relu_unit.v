// =============================================================================
// relu_unit.v  —  ReLU Activation Unit  (4×4 version, ACC_WIDTH=19)
// =============================================================================
// Applies activation function to all 16 systolic array outputs.
//
// relu_mode (2-bit):
//   00 = bypass  — pass raw value unchanged
//   01 = ReLU    — max(0, x)
//   10 = ReLU6   — min(max(0,x), 6)
//   11 = sign    — x>=0 ? 1 : 0
//
// en=1 for one cycle to latch outputs.
// Outputs hold their value until next en pulse.
// =============================================================================
`timescale 1ns/1ps

module relu_unit #(
    parameter ACC_WIDTH = 19,
    parameter N_OUTPUTS = 16
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        en,
    input  wire [1:0]  relu_mode,
    input  wire signed [ACC_WIDTH-1:0] in00,in01,in02,in03,
    input  wire signed [ACC_WIDTH-1:0] in10,in11,in12,in13,
    input  wire signed [ACC_WIDTH-1:0] in20,in21,in22,in23,
    input  wire signed [ACC_WIDTH-1:0] in30,in31,in32,in33,
    output reg  signed [ACC_WIDTH-1:0] out00,out01,out02,out03,
    output reg  signed [ACC_WIDTH-1:0] out10,out11,out12,out13,
    output reg  signed [ACC_WIDTH-1:0] out20,out21,out22,out23,
    output reg  signed [ACC_WIDTH-1:0] out30,out31,out32,out33
);

    // ReLU6 threshold — clamp at 6
    localparam signed [ACC_WIDTH-1:0] RELU6_MAX = 19'sd6;

    function signed [ACC_WIDTH-1:0] activate;
        input signed [ACC_WIDTH-1:0] x;
        input [1:0] mode;
        begin
            case (mode)
                2'b00: activate = x;
                2'b01: activate = x[ACC_WIDTH-1] ? 0 : x;
                2'b10: activate = x[ACC_WIDTH-1] ? 0 : (x > RELU6_MAX ? RELU6_MAX : x);
                2'b11: activate = x[ACC_WIDTH-1] ? 0 : 1;
                default: activate = x;
            endcase
        end
    endfunction

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            out00<=0; out01<=0; out02<=0; out03<=0;
            out10<=0; out11<=0; out12<=0; out13<=0;
            out20<=0; out21<=0; out22<=0; out23<=0;
            out30<=0; out31<=0; out32<=0; out33<=0;
        end else if (en) begin
            out00<=activate(in00,relu_mode); out01<=activate(in01,relu_mode);
            out02<=activate(in02,relu_mode); out03<=activate(in03,relu_mode);
            out10<=activate(in10,relu_mode); out11<=activate(in11,relu_mode);
            out12<=activate(in12,relu_mode); out13<=activate(in13,relu_mode);
            out20<=activate(in20,relu_mode); out21<=activate(in21,relu_mode);
            out22<=activate(in22,relu_mode); out23<=activate(in23,relu_mode);
            out30<=activate(in30,relu_mode); out31<=activate(in31,relu_mode);
            out32<=activate(in32,relu_mode); out33<=activate(in33,relu_mode);
        end
    end

endmodule
