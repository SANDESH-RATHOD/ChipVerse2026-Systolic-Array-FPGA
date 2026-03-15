// =============================================================================
// skew_buffer.v  —  Input Skew Buffer for 4×4 Systolic Array
// =============================================================================
// Delays row inputs so all PEs receive valid data at the same time.
//
// a0 → no delay    (fed at cycle 0)
// a1 → 1 FF delay  (fed at cycle 1)
// a2 → 2 FF delay  (fed at cycle 2)
// a3 → 3 FF delay  (fed at cycle 3)
//
// Same skewing applied to w inputs (columns).
//
// With skewing: total cycles needed = (SIZE-1) + SIZE = 7 for 4×4
// Without skewing: needed = 10 cycles for equal accumulation
// =============================================================================

`timescale 1ns/1ps

module skew_buffer (
    input  wire        clk,
    input  wire        rst,

    // Raw inputs
    input  wire signed [7:0] a0_in, a1_in, a2_in, a3_in,
    input  wire signed [7:0] w0_in, w1_in, w2_in, w3_in,

    // Skewed outputs → connect directly to systolic array
    output wire signed [7:0] a0_out, a1_out, a2_out, a3_out,
    output wire signed [7:0] w0_out, w1_out, w2_out, w3_out
);

    // ── A skew registers ──────────────────────────────────────────────────────
    // a0: 0 delays
    assign a0_out = a0_in;

    // a1: 1 delay
    reg signed [7:0] a1_d1;
    always @(posedge clk or posedge rst)
        if (rst) a1_d1 <= 0; else a1_d1 <= a1_in;
    assign a1_out = a1_d1;

    // a2: 2 delays
    reg signed [7:0] a2_d1, a2_d2;
    always @(posedge clk or posedge rst) begin
        if (rst) begin a2_d1<=0; a2_d2<=0; end
        else begin a2_d1 <= a2_in; a2_d2 <= a2_d1; end
    end
    assign a2_out = a2_d2;

    // a3: 3 delays
    reg signed [7:0] a3_d1, a3_d2, a3_d3;
    always @(posedge clk or posedge rst) begin
        if (rst) begin a3_d1<=0; a3_d2<=0; a3_d3<=0; end
        else begin a3_d1<=a3_in; a3_d2<=a3_d1; a3_d3<=a3_d2; end
    end
    assign a3_out = a3_d3;

    // ── W skew registers (same pattern for columns) ───────────────────────────
    assign w0_out = w0_in;

    reg signed [7:0] w1_d1;
    always @(posedge clk or posedge rst)
        if (rst) w1_d1 <= 0; else w1_d1 <= w1_in;
    assign w1_out = w1_d1;

    reg signed [7:0] w2_d1, w2_d2;
    always @(posedge clk or posedge rst) begin
        if (rst) begin w2_d1<=0; w2_d2<=0; end
        else begin w2_d1<=w2_in; w2_d2<=w2_d1; end
    end
    assign w2_out = w2_d2;

    reg signed [7:0] w3_d1, w3_d2, w3_d3;
    always @(posedge clk or posedge rst) begin
        if (rst) begin w3_d1<=0; w3_d2<=0; w3_d3<=0; end
        else begin w3_d1<=w3_in; w3_d2<=w3_d1; w3_d3<=w3_d2; end
    end
    assign w3_out = w3_d3;

endmodule
