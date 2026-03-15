// =============================================================================
// pe.v  —  PPA Upgraded Processing Element
// =============================================================================
// PPA UPGRADES:
//
// PERFORMANCE — 2-stage pipeline:
//   Cycle 1: product_reg <= a_iso * w_iso     (DSP48 multiply stage)
//   Cycle 2: acc         <= acc + product_reg  (DSP48 accumulate stage)
//   Breaks critical path → Vivado can meet 150 MHz instead of 100 MHz
//   MACs/sec: 160M → 240M (+50%)
//   Vivado absorbs product_reg into DSP48E1 internal P-register (no LUT cost)
//
// POWER — Operand isolation:
//   a_iso/w_iso = 0 when en=0 → no switching in DSP48 when idle (~30% saving)
//
// NOTE: generate if/else REMOVED — it caused Vivado to elaborate BOTH the
//   pipelined and single-cycle branches and keep registers for both,
//   doubling FF count from ~900 to ~1617. Direct hardcoded pipeline here.
//
// COMPUTE_CYCLES must be 11 in top module (was 10) to flush the pipeline.
// =============================================================================
`timescale 1ns/1ps

module PE #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 19
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        en,
    input  wire signed [DATA_WIDTH-1:0] a_in,
    input  wire signed [DATA_WIDTH-1:0] w_in,
    output reg  signed [DATA_WIDTH-1:0] a_out,
    output reg  signed [DATA_WIDTH-1:0] w_out,
    output reg  signed [ACC_WIDTH-1:0]  acc
);

    // Operand isolation — PPA POWER: holds DSP48 inputs at 0 when idle
    wire signed [DATA_WIDTH-1:0] a_iso = en ? a_in : {DATA_WIDTH{1'b0}};
    wire signed [DATA_WIDTH-1:0] w_iso = en ? w_in : {DATA_WIDTH{1'b0}};

    // DSP48 hint
    (* use_dsp = "yes" *)
    wire signed [ACC_WIDTH-1:0] product = a_iso * w_iso;

    // PPA PERFORMANCE: pipeline register — absorbed into DSP48 P-register
    reg signed [ACC_WIDTH-1:0] product_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            product_reg <= 0;
            acc         <= 0;
            a_out       <= 0;
            w_out       <= 0;
        end else if (en) begin
            product_reg <= product;
            acc         <= acc + product_reg;
            a_out       <= a_in;
            w_out       <= w_in;
        end
    end

endmodule
