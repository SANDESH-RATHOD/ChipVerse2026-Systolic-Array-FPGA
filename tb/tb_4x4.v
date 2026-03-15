// =============================================================================
// tb_4x4.v  —  Fixed 4×4 Testbench
// =============================================================================
// FIX: output wire widths [16:0]→[18:0] to match ACC_WIDTH=19; check comparison [17:0]→[18:0]
// Compile:
//   iverilog -g2012 -o sim_4x4 tb/tb_4x4.v rtl/systolic_array_4x4.v rtl/pe.v
// Run:
//   vvp sim_4x4
//   vvp sim_4x4 +a0=1 +a1=2 +a2=3 +a3=4 +w0=1 +w1=2 +w2=3 +w3=4
// Expected: 16/16 PASSED
// =============================================================================
`timescale 1ns/1ps

module tb_systolic;

reg clk, rst;
reg signed [7:0] a0,a1,a2,a3;
reg signed [7:0] w0,w1,w2,w3;

wire signed [18:0] out00,out01,out02,out03;   // FIX: was [16:0]
wire signed [18:0] out10,out11,out12,out13;
wire signed [18:0] out20,out21,out22,out23;
wire signed [18:0] out30,out31,out32,out33;

systolic_array_4x4 dut(
    .clk(clk),.rst(rst),.en(1'b1),
    .a0(a0),.a1(a1),.a2(a2),.a3(a3),
    .w0(w0),.w1(w1),.w2(w2),.w3(w3),
    .out00(out00),.out01(out01),.out02(out02),.out03(out03),
    .out10(out10),.out11(out11),.out12(out12),.out13(out13),
    .out20(out20),.out21(out21),.out22(out22),.out23(out23),
    .out30(out30),.out31(out31),.out32(out32),.out33(out33)
);

always #5 clk = ~clk;

integer ia0,ia1,ia2,ia3,iw0,iw1,iw2,iw3;
integer pass, fail;

task check;
    input signed [18:0] got;
    input integer expected;
    input integer r, c;
    begin
        if (got === expected[18:0]) begin
            $display("  PASS [%0d][%0d] = %0d", r, c, got);
            pass = pass + 1;
        end else begin
            $display("  FAIL [%0d][%0d]: got=%0d  expected=%0d", r, c, got, expected);
            fail = fail + 1;
        end
    end
endtask

integer e00,e01,e02,e03,e10,e11,e12,e13;
integer e20,e21,e22,e23,e30,e31,e32,e33;

initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, tb_systolic);

    ia0=1;ia1=2;ia2=3;ia3=4;
    iw0=1;iw1=2;iw2=3;iw3=4;

    if ($value$plusargs("a0=%d",ia0));if ($value$plusargs("a1=%d",ia1));
    if ($value$plusargs("a2=%d",ia2));if ($value$plusargs("a3=%d",ia3));
    if ($value$plusargs("w0=%d",iw0));if ($value$plusargs("w1=%d",iw1));
    if ($value$plusargs("w2=%d",iw2));if ($value$plusargs("w3=%d",iw3));

    pass=0; fail=0;
    clk=0; rst=1;
    a0=0;a1=0;a2=0;a3=0;
    w0=0;w1=0;w2=0;w3=0;
    #10; rst=0;

    a0=ia0[7:0];a1=ia1[7:0];
    a2=ia2[7:0];a3=ia3[7:0];
    w0=iw0[7:0];w1=iw1[7:0];
    w2=iw2[7:0];w3=iw3[7:0];

    $display("============================================");
    $display("  4x4 SYSTOLIC ARRAY — Fixed");
    $display("============================================");
    $display("  a = [%0d, %0d, %0d, %0d]",ia0,ia1,ia2,ia3);
    $display("  w = [%0d, %0d, %0d, %0d]",iw0,iw1,iw2,iw3);
    $display("============================================");

    repeat(10) @(posedge clk); #1;

    $display("\n  OUTPUT MATRIX:");
    $display("  +----------------------------------+");
    $display("  | %6d  %6d  %6d  %6d  |",out00,out01,out02,out03);
    $display("  | %6d  %6d  %6d  %6d  |",out10,out11,out12,out13);
    $display("  | %6d  %6d  %6d  %6d  |",out20,out21,out22,out23);
    $display("  | %6d  %6d  %6d  %6d  |",out30,out31,out32,out33);
    $display("  +----------------------------------+");

    e00=10*ia0*iw0;e01=9*ia0*iw1;e02=8*ia0*iw2;e03=7*ia0*iw3;
    e10=9*ia1*iw0; e11=9*ia1*iw1;e12=8*ia1*iw2;e13=7*ia1*iw3;
    e20=8*ia2*iw0; e21=8*ia2*iw1;e22=8*ia2*iw2;e23=7*ia2*iw3;
    e30=7*ia3*iw0; e31=7*ia3*iw1;e32=7*ia3*iw2;e33=7*ia3*iw3;

    $display("\n  VERIFICATION:");
    check(out00,e00,0,0);check(out01,e01,0,1);
    check(out02,e02,0,2);check(out03,e03,0,3);
    check(out10,e10,1,0);check(out11,e11,1,1);
    check(out12,e12,1,2);check(out13,e13,1,3);
    check(out20,e20,2,0);check(out21,e21,2,1);
    check(out22,e22,2,2);check(out23,e23,2,3);
    check(out30,e30,3,0);check(out31,e31,3,1);
    check(out32,e32,3,2);check(out33,e33,3,3);

    $display("\n============================================");
    $display("  %0d/16 PASSED | %0d FAILED",pass,fail);
    $display("============================================");
    $finish;
end
endmodule
