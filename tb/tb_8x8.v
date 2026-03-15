// =============================================================================
// tb_systolic_8x8.v  —  8x8 Testbench (updated for ACC_WIDTH=17, 2-stage pipeline)
// =============================================================================
// Compile:
//   iverilog -g2012 -o sim_sa8 tb/tb_systolic_8x8.v rtl/systolic_array_8x8.v rtl/pe.v
// Run:
//   vvp sim_sa8
//   vvp sim_sa8 +a0=1 +a1=2 +a2=3 +a3=4 +a4=5 +a5=6 +a6=7 +a7=8 \
//               +w0=1 +w1=2 +w2=3 +w3=4 +w4=5 +w5=6 +w6=7 +w7=8
// =============================================================================
`timescale 1ns/1ps

module tb_systolic_8x8;

reg clk, rst;
reg signed [7:0] a0,a1,a2,a3,a4,a5,a6,a7;
reg signed [7:0] w0,w1,w2,w3,w4,w5,w6,w7;

wire signed [18:0] out00,out01,out02,out03,out04,out05,out06,out07;
wire signed [18:0] out10,out11,out12,out13,out14,out15,out16,out17;
wire signed [18:0] out20,out21,out22,out23,out24,out25,out26,out27;
wire signed [18:0] out30,out31,out32,out33,out34,out35,out36,out37;
wire signed [18:0] out40,out41,out42,out43,out44,out45,out46,out47;
wire signed [18:0] out50,out51,out52,out53,out54,out55,out56,out57;
wire signed [18:0] out60,out61,out62,out63,out64,out65,out66,out67;
wire signed [18:0] out70,out71,out72,out73,out74,out75,out76,out77;

systolic_array_8x8 dut(
    .clk(clk),.rst(rst),.en(1'b1),
    .a0(a0),.a1(a1),.a2(a2),.a3(a3),
    .a4(a4),.a5(a5),.a6(a6),.a7(a7),
    .w0(w0),.w1(w1),.w2(w2),.w3(w3),
    .w4(w4),.w5(w5),.w6(w6),.w7(w7),
    .out00(out00),.out01(out01),.out02(out02),.out03(out03),
    .out04(out04),.out05(out05),.out06(out06),.out07(out07),
    .out10(out10),.out11(out11),.out12(out12),.out13(out13),
    .out14(out14),.out15(out15),.out16(out16),.out17(out17),
    .out20(out20),.out21(out21),.out22(out22),.out23(out23),
    .out24(out24),.out25(out25),.out26(out26),.out27(out27),
    .out30(out30),.out31(out31),.out32(out32),.out33(out33),
    .out34(out34),.out35(out35),.out36(out36),.out37(out37),
    .out40(out40),.out41(out41),.out42(out42),.out43(out43),
    .out44(out44),.out45(out45),.out46(out46),.out47(out47),
    .out50(out50),.out51(out51),.out52(out52),.out53(out53),
    .out54(out54),.out55(out55),.out56(out56),.out57(out57),
    .out60(out60),.out61(out61),.out62(out62),.out63(out63),
    .out64(out64),.out65(out65),.out66(out66),.out67(out67),
    .out70(out70),.out71(out71),.out72(out72),.out73(out73),
    .out74(out74),.out75(out75),.out76(out76),.out77(out77)
);

always #5 clk = ~clk;

integer ia0,ia1,ia2,ia3,ia4,ia5,ia6,ia7;
integer iw0,iw1,iw2,iw3,iw4,iw5,iw6,iw7;
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

function integer expected_val;
    input integer r, c, av, wv;
    integer N, cyc;
    begin
        N   = 15;
        cyc = N - ((r > c) ? r : c);
        expected_val = cyc * av * wv;
    end
endfunction

reg signed [18:0] out [0:7][0:7];
always @(*) begin
    out[0][0]=out00;out[0][1]=out01;out[0][2]=out02;out[0][3]=out03;
    out[0][4]=out04;out[0][5]=out05;out[0][6]=out06;out[0][7]=out07;
    out[1][0]=out10;out[1][1]=out11;out[1][2]=out12;out[1][3]=out13;
    out[1][4]=out14;out[1][5]=out15;out[1][6]=out16;out[1][7]=out17;
    out[2][0]=out20;out[2][1]=out21;out[2][2]=out22;out[2][3]=out23;
    out[2][4]=out24;out[2][5]=out25;out[2][6]=out26;out[2][7]=out27;
    out[3][0]=out30;out[3][1]=out31;out[3][2]=out32;out[3][3]=out33;
    out[3][4]=out34;out[3][5]=out35;out[3][6]=out36;out[3][7]=out37;
    out[4][0]=out40;out[4][1]=out41;out[4][2]=out42;out[4][3]=out43;
    out[4][4]=out44;out[4][5]=out45;out[4][6]=out46;out[4][7]=out47;
    out[5][0]=out50;out[5][1]=out51;out[5][2]=out52;out[5][3]=out53;
    out[5][4]=out54;out[5][5]=out55;out[5][6]=out56;out[5][7]=out57;
    out[6][0]=out60;out[6][1]=out61;out[6][2]=out62;out[6][3]=out63;
    out[6][4]=out64;out[6][5]=out65;out[6][6]=out66;out[6][7]=out67;
    out[7][0]=out70;out[7][1]=out71;out[7][2]=out72;out[7][3]=out73;
    out[7][4]=out74;out[7][5]=out75;out[7][6]=out76;out[7][7]=out77;
end

integer r, c;

initial begin
    $dumpfile("wave_8x8.vcd");
    $dumpvars(0, tb_systolic_8x8);

    ia0=1;ia1=2;ia2=3;ia3=4;ia4=5;ia5=6;ia6=7;ia7=8;
    iw0=1;iw1=2;iw2=3;iw3=4;iw4=5;iw5=6;iw6=7;iw7=8;

    if ($value$plusargs("a0=%d",ia0));if ($value$plusargs("a1=%d",ia1));
    if ($value$plusargs("a2=%d",ia2));if ($value$plusargs("a3=%d",ia3));
    if ($value$plusargs("a4=%d",ia4));if ($value$plusargs("a5=%d",ia5));
    if ($value$plusargs("a6=%d",ia6));if ($value$plusargs("a7=%d",ia7));
    if ($value$plusargs("w0=%d",iw0));if ($value$plusargs("w1=%d",iw1));
    if ($value$plusargs("w2=%d",iw2));if ($value$plusargs("w3=%d",iw3));
    if ($value$plusargs("w4=%d",iw4));if ($value$plusargs("w5=%d",iw5));
    if ($value$plusargs("w6=%d",iw6));if ($value$plusargs("w7=%d",iw7));

    pass=0; fail=0;
    clk=0; rst=1;
    a0=0;a1=0;a2=0;a3=0;a4=0;a5=0;a6=0;a7=0;
    w0=0;w1=0;w2=0;w3=0;w4=0;w5=0;w6=0;w7=0;
    #10; rst=0;

    a0=ia0[7:0];a1=ia1[7:0];a2=ia2[7:0];a3=ia3[7:0];
    a4=ia4[7:0];a5=ia5[7:0];a6=ia6[7:0];a7=ia7[7:0];
    w0=iw0[7:0];w1=iw1[7:0];w2=iw2[7:0];w3=iw3[7:0];
    w4=iw4[7:0];w5=iw5[7:0];w6=iw6[7:0];w7=iw7[7:0];

    $display("============================================");
    $display("  8x8 SYSTOLIC ARRAY - Combined Best");
    $display("  ACC_WIDTH=17, DSP48, single-cycle PE");
    $display("============================================");
    $display("  a = [%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d]",
             ia0,ia1,ia2,ia3,ia4,ia5,ia6,ia7);
    $display("  w = [%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d]",
             iw0,iw1,iw2,iw3,iw4,iw5,iw6,iw7);
    $display("============================================");

    // Single-cycle PE — exactly 15 cycles (2x8-1)
    repeat(15) @(posedge clk); #1;

    $display("\n  OUTPUT MATRIX (8x8):");
    $display("  +--------------------------------------------------------+");
    for (r=0; r<8; r=r+1)
        $display("  | %6d %6d %6d %6d %6d %6d %6d %6d |",
            out[r][0],out[r][1],out[r][2],out[r][3],
            out[r][4],out[r][5],out[r][6],out[r][7]);
    $display("  +--------------------------------------------------------+");

    $display("\n  VERIFICATION:");
    for (r=0; r<8; r=r+1) begin
        for (c=0; c<8; c=c+1) begin
            begin : vb
                integer av,wv,exp;
                case(r) 0:av=ia0;1:av=ia1;2:av=ia2;3:av=ia3;
                        4:av=ia4;5:av=ia5;6:av=ia6;7:av=ia7;
                        default:av=0; endcase
                case(c) 0:wv=iw0;1:wv=iw1;2:wv=iw2;3:wv=iw3;
                        4:wv=iw4;5:wv=iw5;6:wv=iw6;7:wv=iw7;
                        default:wv=0; endcase
                exp = expected_val(r,c,av,wv);
                check(out[r][c],exp,r,c);
            end
        end
    end

    $display("\n============================================");
    $display("  %0d/64 PASSED | %0d FAILED",pass,fail);
    $display("============================================");
    $finish;
end

endmodule
