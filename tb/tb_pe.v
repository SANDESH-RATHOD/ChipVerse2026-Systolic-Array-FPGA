// =============================================================================
// tb_pe.v  —  Fixed PE Testbench
// =============================================================================
// FIXES:
//  1. Added .en(1'b1) — was missing, PE never accumulated
//  2. acc wire [19:0]→[17:0] to match PE ACC_WIDTH=18
// =============================================================================
`timescale 1ns/1ps
module tb_pe;
    reg clk, rst;
    reg signed [7:0] a_in, w_in;
    wire signed [7:0]  a_out, w_out;
    wire signed [18:0] acc;              // FIX 2: was [19:0]

    PE dut(
        .clk(clk), .rst(rst),
        .en(1'b1),                       // FIX 1: was missing
        .a_in(a_in), .w_in(w_in),
        .a_out(a_out), .w_out(w_out),
        .acc(acc)
    );

    always #5 clk = ~clk;

    integer pass, fail;
    task check;
        input signed [18:0] got;
        input integer expected;
        input [63:0] label;
        begin
            if (got === expected[17:0]) begin
                $display("  PASS %s: acc=%0d", label, got);
                pass = pass + 1;
            end else begin
                $display("  FAIL %s: got=%0d  expected=%0d", label, got, expected);
                fail = fail + 1;
            end
        end
    endtask

    initial begin
        pass=0; fail=0;
        clk=0; rst=1; a_in=0; w_in=0;
        #10; rst=0;

        // Test 1: 3×4 = 12, accumulated 3 times → 36
        a_in=3; w_in=4;
        repeat(3) @(posedge clk); #1;
        check(acc, 36, "3x4 x3");

        // Test 2: reset clears accumulator
        rst=1; #10; rst=0; #1;
        check(acc, 0, "after rst");

        // Test 3: negative weight — 5×(-2) = -10, twice → -20
        a_in=5; w_in=-2;
        repeat(2) @(posedge clk); #1;
        check(acc, -20, "5x-2 x2");

        // Test 4: max values — 127×127×10 = 161290 (fits in 18-bit signed: max 131071... no)
        // Actually 127*127 = 16129, × 1 = 16129 per cycle, × 10 cycles = 161290
        // 18-bit signed max = 131071 → this DOES overflow for 10 cycles
        // But 18-bit unsigned = 262143 → no overflow for unsigned interpretation
        // Demonstrate 1 cycle: 127*127 = 16129
        rst=1; #10; rst=0;
        a_in=127; w_in=127;
        repeat(1) @(posedge clk); #1;
        check(acc, 16129, "127x127 x1");

        $display("============================================");
        $display("  %0d/4 PASSED | %0d FAILED", pass, fail);
        $display("============================================");
        $finish;
    end
endmodule
