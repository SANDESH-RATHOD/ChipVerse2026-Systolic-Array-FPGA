// =============================================================================
// top_8x8.v  —  Fixed 8×8 Full System  |  Basys 3
// =============================================================================
// FIXES:
//  1. bufA/bufB enlarged [0:15]→[0:63]  (8×8 = 64 results)
//  2. S_TX idx reg [3:0]→[5:0]          (need 0..63, not 0..15)
//  3. Buffer writes cover all 64 outputs (was only first 16)
//  4. relu_en and result_we separated by 1 cycle (was simultaneous, captured stale data)
//  5. spi_tx_data / spi_tx_load now driven in S_TX
//  6. led[7:4] assigned (was undriven)
//  7. 7-seg disp truncated to [17:0] (driver port width)
//  8. ACC_WIDTH wires updated to 19-bit matching fixed systolic_array_8x8
// =============================================================================
`timescale 1ns/1ps

module fpga_top_v3 #(
    parameter CLK_FREQ       = 100_000_000,
    parameter BAUD_RATE      = 115_200,
    parameter COMPUTE_CYCLES = 15,
    parameter N_RESULTS      = 64,
    parameter N_TX_BYTES     = 192
)(
    input  wire        clk,
    input  wire        btnC,
    input  wire        btnU,
    input  wire        btnD,
    input  wire        btnL,
    input  wire        btnR,
    input  wire [15:0] sw,
    output wire [15:0] led,
    output wire [6:0]  seg,
    output wire        dp,
    output wire [3:0]  an,
    input  wire        uart_rxd,
    output wire        uart_txd,
    input  wire        spi_sck,
    input  wire        spi_mosi,
    output wire        spi_miso,
    input  wire        spi_cs_n
);

    // ── Reset ─────────────────────────────────────────────────────────────────
    reg [2:0] rst_pipe;
    always @(posedge clk) rst_pipe <= {rst_pipe[1:0], btnC};
    wire sys_rst = rst_pipe[2];

    // ── Debounce ──────────────────────────────────────────────────────────────
    reg [20:0] db_cnt; reg db_tick;
    always @(posedge clk or posedge sys_rst) begin
        if (sys_rst) begin db_cnt<=0; db_tick<=0; end
        else begin
            db_tick <= (db_cnt==2_000_000);
            db_cnt  <= (db_cnt==2_000_000) ? 0 : db_cnt+1;
        end
    end
    reg [3:0] btn_prev, btn_pulse;
    always @(posedge clk or posedge sys_rst) begin
        if (sys_rst) begin btn_prev<=0; btn_pulse<=0; end
        else begin
            btn_pulse<=0;
            if (db_tick) begin
                btn_pulse<={btnU,btnD,btnL,btnR}&~btn_prev;
                btn_prev <={btnU,btnD,btnL,btnR};
            end
        end
    end
    wire pulse_u=btn_pulse[3], pulse_d=btn_pulse[2];
    wire pulse_l=btn_pulse[1], pulse_r=btn_pulse[0];

    // ── UART ──────────────────────────────────────────────────────────────────
    wire [7:0] uart_rx_data; wire uart_rx_valid;
    uart_rx #(.CLK_FREQ(CLK_FREQ),.BAUD_RATE(BAUD_RATE)) u_rx(
        .clk(clk),.rst(sys_rst),.rx(uart_rxd),
        .data(uart_rx_data),.valid(uart_rx_valid));
    reg [7:0] uart_tx_data; reg uart_tx_start; wire uart_tx_busy;
    uart_tx #(.CLK_FREQ(CLK_FREQ),.BAUD_RATE(BAUD_RATE)) u_tx(
        .clk(clk),.rst(sys_rst),.data(uart_tx_data),
        .start(uart_tx_start),.tx(uart_txd),.busy(uart_tx_busy));

    // ── SPI slave ─────────────────────────────────────────────────────────────
    wire [7:0] spi_rx_data; wire spi_rx_valid;
    reg  [7:0] spi_tx_data; reg  spi_tx_load;
    spi_slave u_spi(
        .clk(clk),.rst(sys_rst),
        .sck(spi_sck),.mosi(spi_mosi),
        .miso(spi_miso),.cs_n(spi_cs_n),
        .rx_data(spi_rx_data),.rx_valid(spi_rx_valid),
        .tx_data(spi_tx_data),.tx_load(spi_tx_load));

    wire [7:0] rx_data  = spi_rx_valid ? spi_rx_data  : uart_rx_data;
    wire       rx_valid = spi_rx_valid | uart_rx_valid;

    // ── BRAM ──────────────────────────────────────────────────────────────────
    reg  [7:0] bram_wr_addr; reg [7:0] bram_wr_data;
    reg  [2:0] bram_wr_sel;  reg       bram_wr_en;
    reg  [7:0] bram_rd_addr;
    wire signed [7:0] bram_w0,bram_w1,bram_w2,bram_w3;
    wire signed [7:0] bram_w4,bram_w5,bram_w6,bram_w7;
    weight_bram u_bram(
        .clk(clk),.rst(sys_rst),
        .wr_addr(bram_wr_addr),.wr_data(bram_wr_data),
        .wr_sel(bram_wr_sel),.wr_en(bram_wr_en),
        .rd_addr(bram_rd_addr),
        .w0(bram_w0),.w1(bram_w1),.w2(bram_w2),.w3(bram_w3),
        .w4(bram_w4),.w5(bram_w5),.w6(bram_w6),.w7(bram_w7));

    // ── Skew buffer (8-wide, inline) ──────────────────────────────────────────
    reg signed [7:0] a0_r,a1_r,a2_r,a3_r,a4_r,a5_r,a6_r,a7_r;
    reg signed [7:0] w0_r,w1_r,w2_r,w3_r,w4_r,w5_r,w6_r,w7_r;
    reg sa_rst, sa_en;

    wire signed [7:0] a0_s,a1_s,a2_s,a3_s,a4_s,a5_s,a6_s,a7_s;
    wire signed [7:0] w0_s,w1_s,w2_s,w3_s,w4_s,w5_s,w6_s,w7_s;

    assign a0_s=a0_r; assign w0_s=w0_r;
    reg signed [7:0] a1d1,w1d1;
    always @(posedge clk or posedge sa_rst) begin if(sa_rst)begin a1d1<=0;w1d1<=0;end else begin a1d1<=a1_r;w1d1<=w1_r;end end
    assign a1_s=a1d1; assign w1_s=w1d1;
    reg signed [7:0] a2d1,a2d2,w2d1,w2d2;
    always @(posedge clk or posedge sa_rst) begin if(sa_rst)begin a2d1<=0;a2d2<=0;w2d1<=0;w2d2<=0;end else begin a2d1<=a2_r;a2d2<=a2d1;w2d1<=w2_r;w2d2<=w2d1;end end
    assign a2_s=a2d2; assign w2_s=w2d2;
    reg signed [7:0] a3d1,a3d2,a3d3,w3d1,w3d2,w3d3;
    always @(posedge clk or posedge sa_rst) begin if(sa_rst)begin a3d1<=0;a3d2<=0;a3d3<=0;w3d1<=0;w3d2<=0;w3d3<=0;end else begin a3d1<=a3_r;a3d2<=a3d1;a3d3<=a3d2;w3d1<=w3_r;w3d2<=w3d1;w3d3<=w3d2;end end
    assign a3_s=a3d3; assign w3_s=w3d3;
    reg signed [7:0] a4d1,a4d2,a4d3,a4d4,w4d1,w4d2,w4d3,w4d4;
    always @(posedge clk or posedge sa_rst) begin if(sa_rst)begin a4d1<=0;a4d2<=0;a4d3<=0;a4d4<=0;w4d1<=0;w4d2<=0;w4d3<=0;w4d4<=0;end else begin a4d1<=a4_r;a4d2<=a4d1;a4d3<=a4d2;a4d4<=a4d3;w4d1<=w4_r;w4d2<=w4d1;w4d3<=w4d2;w4d4<=w4d3;end end
    assign a4_s=a4d4; assign w4_s=w4d4;
    reg signed [7:0] a5d1,a5d2,a5d3,a5d4,a5d5,w5d1,w5d2,w5d3,w5d4,w5d5;
    always @(posedge clk or posedge sa_rst) begin if(sa_rst)begin a5d1<=0;a5d2<=0;a5d3<=0;a5d4<=0;a5d5<=0;w5d1<=0;w5d2<=0;w5d3<=0;w5d4<=0;w5d5<=0;end else begin a5d1<=a5_r;a5d2<=a5d1;a5d3<=a5d2;a5d4<=a5d3;a5d5<=a5d4;w5d1<=w5_r;w5d2<=w5d1;w5d3<=w5d2;w5d4<=w5d3;w5d5<=w5d4;end end
    assign a5_s=a5d5; assign w5_s=w5d5;
    reg signed [7:0] a6d1,a6d2,a6d3,a6d4,a6d5,a6d6,w6d1,w6d2,w6d3,w6d4,w6d5,w6d6;
    always @(posedge clk or posedge sa_rst) begin if(sa_rst)begin a6d1<=0;a6d2<=0;a6d3<=0;a6d4<=0;a6d5<=0;a6d6<=0;w6d1<=0;w6d2<=0;w6d3<=0;w6d4<=0;w6d5<=0;w6d6<=0;end else begin a6d1<=a6_r;a6d2<=a6d1;a6d3<=a6d2;a6d4<=a6d3;a6d5<=a6d4;a6d6<=a6d5;w6d1<=w6_r;w6d2<=w6d1;w6d3<=w6d2;w6d4<=w6d3;w6d5<=w6d4;w6d6<=w6d5;end end
    assign a6_s=a6d6; assign w6_s=w6d6;
    reg signed [7:0] a7d1,a7d2,a7d3,a7d4,a7d5,a7d6,a7d7,w7d1,w7d2,w7d3,w7d4,w7d5,w7d6,w7d7;
    always @(posedge clk or posedge sa_rst) begin if(sa_rst)begin a7d1<=0;a7d2<=0;a7d3<=0;a7d4<=0;a7d5<=0;a7d6<=0;a7d7<=0;w7d1<=0;w7d2<=0;w7d3<=0;w7d4<=0;w7d5<=0;w7d6<=0;w7d7<=0;end else begin a7d1<=a7_r;a7d2<=a7d1;a7d3<=a7d2;a7d4<=a7d3;a7d5<=a7d4;a7d6<=a7d5;a7d7<=a7d6;w7d1<=w7_r;w7d2<=w7d1;w7d3<=w7d2;w7d4<=w7d3;w7d5<=w7d4;w7d6<=w7d5;w7d7<=w7d6;end end
    assign a7_s=a7d7; assign w7_s=w7d7;

    // ── 8×8 Systolic Array ────────────────────────────────────────────────────
    // FIX 8: 19-bit wires matching ACC_WIDTH=19
    wire signed [18:0] out00,out01,out02,out03,out04,out05,out06,out07;
    wire signed [18:0] out10,out11,out12,out13,out14,out15,out16,out17;
    wire signed [18:0] out20,out21,out22,out23,out24,out25,out26,out27;
    wire signed [18:0] out30,out31,out32,out33,out34,out35,out36,out37;
    wire signed [18:0] out40,out41,out42,out43,out44,out45,out46,out47;
    wire signed [18:0] out50,out51,out52,out53,out54,out55,out56,out57;
    wire signed [18:0] out60,out61,out62,out63,out64,out65,out66,out67;
    wire signed [18:0] out70,out71,out72,out73,out74,out75,out76,out77;

    systolic_array_8x8 u_sa(
        .clk(clk),.rst(sa_rst),.en(sa_en),
        .a0(a0_s),.a1(a1_s),.a2(a2_s),.a3(a3_s),
        .a4(a4_s),.a5(a5_s),.a6(a6_s),.a7(a7_s),
        .w0(w0_s),.w1(w1_s),.w2(w2_s),.w3(w3_s),
        .w4(w4_s),.w5(w5_s),.w6(w6_s),.w7(w7_s),
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
        .out74(out74),.out75(out75),.out76(out76),.out77(out77));

    // ── ReLU ──────────────────────────────────────────────────────────────────
    wire [1:0] relu_mode = sw[1:0];
    reg  relu_en;
    wire signed [18:0] r00,r01,r02,r03,r04,r05,r06,r07;
    wire signed [18:0] r10,r11,r12,r13,r14,r15,r16,r17;
    wire signed [18:0] r20,r21,r22,r23,r24,r25,r26,r27;
    wire signed [18:0] r30,r31,r32,r33,r34,r35,r36,r37;
    wire signed [18:0] r40,r41,r42,r43,r44,r45,r46,r47;
    wire signed [18:0] r50,r51,r52,r53,r54,r55,r56,r57;
    wire signed [18:0] r60,r61,r62,r63,r64,r65,r66,r67;
    wire signed [18:0] r70,r71,r72,r73,r74,r75,r76,r77;

    // FIX 3: Four relu_unit instances cover all 64 outputs (quadrant decomposition)
    relu_unit #(.ACC_WIDTH(19)) u_relu_q0(
        .clk(clk),.rst(sys_rst),.en(relu_en),.relu_mode(relu_mode),
        .in00(out00),.in01(out01),.in02(out02),.in03(out03),
        .in10(out10),.in11(out11),.in12(out12),.in13(out13),
        .in20(out20),.in21(out21),.in22(out22),.in23(out23),
        .in30(out30),.in31(out31),.in32(out32),.in33(out33),
        .out00(r00),.out01(r01),.out02(r02),.out03(r03),
        .out10(r10),.out11(r11),.out12(r12),.out13(r13),
        .out20(r20),.out21(r21),.out22(r22),.out23(r23),
        .out30(r30),.out31(r31),.out32(r32),.out33(r33));

    relu_unit #(.ACC_WIDTH(19)) u_relu_q1(
        .clk(clk),.rst(sys_rst),.en(relu_en),.relu_mode(relu_mode),
        .in00(out04),.in01(out05),.in02(out06),.in03(out07),
        .in10(out14),.in11(out15),.in12(out16),.in13(out17),
        .in20(out24),.in21(out25),.in22(out26),.in23(out27),
        .in30(out34),.in31(out35),.in32(out36),.in33(out37),
        .out00(r04),.out01(r05),.out02(r06),.out03(r07),
        .out10(r14),.out11(r15),.out12(r16),.out13(r17),
        .out20(r24),.out21(r25),.out22(r26),.out23(r27),
        .out30(r34),.out31(r35),.out32(r36),.out33(r37));

    relu_unit #(.ACC_WIDTH(19)) u_relu_q2(
        .clk(clk),.rst(sys_rst),.en(relu_en),.relu_mode(relu_mode),
        .in00(out40),.in01(out41),.in02(out42),.in03(out43),
        .in10(out50),.in11(out51),.in12(out52),.in13(out53),
        .in20(out60),.in21(out61),.in22(out62),.in23(out63),
        .in30(out70),.in31(out71),.in32(out72),.in33(out73),
        .out00(r40),.out01(r41),.out02(r42),.out03(r43),
        .out10(r50),.out11(r51),.out12(r52),.out13(r53),
        .out20(r60),.out21(r61),.out22(r62),.out23(r63),
        .out30(r70),.out31(r71),.out32(r72),.out33(r73));

    relu_unit #(.ACC_WIDTH(19)) u_relu_q3(
        .clk(clk),.rst(sys_rst),.en(relu_en),.relu_mode(relu_mode),
        .in00(out44),.in01(out45),.in02(out46),.in03(out47),
        .in10(out54),.in11(out55),.in12(out56),.in13(out57),
        .in20(out64),.in21(out65),.in22(out66),.in23(out67),
        .in30(out74),.in31(out75),.in32(out76),.in33(out77),
        .out00(r44),.out01(r45),.out02(r46),.out03(r47),
        .out10(r54),.out11(r55),.out12(r56),.out13(r57),
        .out20(r64),.out21(r65),.out22(r66),.out23(r67),
        .out30(r74),.out31(r75),.out32(r76),.out33(r77));

    // ── Ping-pong result buffers ───────────────────────────────────────────────
    // FIX 1: 64 entries each (was 16)
    reg signed [18:0] bufA [0:63];
    reg signed [18:0] bufB [0:63];
    reg               pp_sel;
    reg               result_we_a, result_we_b;

    // FIX 4: result_we is delayed 1 cycle after relu_en so ReLU output is ready
    reg relu_en_d;
    always @(posedge clk or posedge sys_rst) begin
        if (sys_rst) relu_en_d <= 0;
        else         relu_en_d <= relu_en;
    end

    always @(posedge clk) begin
        // FIX 1+3: all 64 results captured using relu_en_d
        if (result_we_a) begin
            bufA[0]<=r00;  bufA[1]<=r01;  bufA[2]<=r02;  bufA[3]<=r03;
            bufA[4]<=r04;  bufA[5]<=r05;  bufA[6]<=r06;  bufA[7]<=r07;
            bufA[8]<=r10;  bufA[9]<=r11;  bufA[10]<=r12; bufA[11]<=r13;
            bufA[12]<=r14; bufA[13]<=r15; bufA[14]<=r16; bufA[15]<=r17;
            bufA[16]<=r20; bufA[17]<=r21; bufA[18]<=r22; bufA[19]<=r23;
            bufA[20]<=r24; bufA[21]<=r25; bufA[22]<=r26; bufA[23]<=r27;
            bufA[24]<=r30; bufA[25]<=r31; bufA[26]<=r32; bufA[27]<=r33;
            bufA[28]<=r34; bufA[29]<=r35; bufA[30]<=r36; bufA[31]<=r37;
            bufA[32]<=r40; bufA[33]<=r41; bufA[34]<=r42; bufA[35]<=r43;
            bufA[36]<=r44; bufA[37]<=r45; bufA[38]<=r46; bufA[39]<=r47;
            bufA[40]<=r50; bufA[41]<=r51; bufA[42]<=r52; bufA[43]<=r53;
            bufA[44]<=r54; bufA[45]<=r55; bufA[46]<=r56; bufA[47]<=r57;
            bufA[48]<=r60; bufA[49]<=r61; bufA[50]<=r62; bufA[51]<=r63;
            bufA[52]<=r64; bufA[53]<=r65; bufA[54]<=r66; bufA[55]<=r67;
            bufA[56]<=r70; bufA[57]<=r71; bufA[58]<=r72; bufA[59]<=r73;
            bufA[60]<=r74; bufA[61]<=r75; bufA[62]<=r76; bufA[63]<=r77;
        end
        if (result_we_b) begin
            bufB[0]<=r00;  bufB[1]<=r01;  bufB[2]<=r02;  bufB[3]<=r03;
            bufB[4]<=r04;  bufB[5]<=r05;  bufB[6]<=r06;  bufB[7]<=r07;
            bufB[8]<=r10;  bufB[9]<=r11;  bufB[10]<=r12; bufB[11]<=r13;
            bufB[12]<=r14; bufB[13]<=r15; bufB[14]<=r16; bufB[15]<=r17;
            bufB[16]<=r20; bufB[17]<=r21; bufB[18]<=r22; bufB[19]<=r23;
            bufB[20]<=r24; bufB[21]<=r25; bufB[22]<=r26; bufB[23]<=r27;
            bufB[24]<=r30; bufB[25]<=r31; bufB[26]<=r32; bufB[27]<=r33;
            bufB[28]<=r34; bufB[29]<=r35; bufB[30]<=r36; bufB[31]<=r37;
            bufB[32]<=r40; bufB[33]<=r41; bufB[34]<=r42; bufB[35]<=r43;
            bufB[36]<=r44; bufB[37]<=r45; bufB[38]<=r46; bufB[39]<=r47;
            bufB[40]<=r50; bufB[41]<=r51; bufB[42]<=r52; bufB[43]<=r53;
            bufB[44]<=r54; bufB[45]<=r55; bufB[46]<=r56; bufB[47]<=r57;
            bufB[48]<=r60; bufB[49]<=r61; bufB[50]<=r62; bufB[51]<=r63;
            bufB[52]<=r64; bufB[53]<=r65; bufB[54]<=r66; bufB[55]<=r67;
            bufB[56]<=r70; bufB[57]<=r71; bufB[58]<=r72; bufB[59]<=r73;
            bufB[60]<=r74; bufB[61]<=r75; bufB[62]<=r76; bufB[63]<=r77;
        end
    end

    // ── FSM ───────────────────────────────────────────────────────────────────
    localparam [2:0]
        S_IDLE    = 3'd0,
        S_LOAD    = 3'd1,
        S_WR_BRAM = 3'd2,
        S_RUN     = 3'd3,
        S_TX      = 3'd4;

    localparam RUN_END = 2 + COMPUTE_CYCLES - 1;
    localparam TX_END  = N_TX_BYTES - 1;

    reg [2:0]  state;
    reg [7:0]  cnt;
    reg        done_flag;
    reg [7:0]  op_cmd;

    // TX decode wires — computed combinationally from cnt and buffers
    wire [5:0]          tx_idx  = cnt / 3;           // which result (0..63)
    wire [1:0]          tx_bsel = cnt - (tx_idx * 3); // which byte (0,1,2)
    wire signed [18:0]  tx_val  = pp_sel ? bufA[tx_idx] : bufB[tx_idx];

    always @(posedge clk or posedge sys_rst) begin
        if (sys_rst) begin
            state<=S_IDLE; cnt<=0; done_flag<=0; pp_sel<=0;
            sa_rst<=0; sa_en<=0; relu_en<=0;
            result_we_a<=0; result_we_b<=0;
            bram_wr_en<=0; op_cmd<=0;
            a0_r<=0;a1_r<=0;a2_r<=0;a3_r<=0;
            a4_r<=0;a5_r<=0;a6_r<=0;a7_r<=0;
            w0_r<=0;w1_r<=0;w2_r<=0;w3_r<=0;
            w4_r<=0;w5_r<=0;w6_r<=0;w7_r<=0;
            uart_tx_start<=0; uart_tx_data<=0;
            spi_tx_data<=0;   spi_tx_load<=0;   // FIX 5
            bram_wr_addr<=0;  bram_rd_addr<=0;
        end else begin
            sa_en<=0; sa_rst<=0; relu_en<=0;
            result_we_a<=0; result_we_b<=0;
            bram_wr_en<=0; uart_tx_start<=0;
            spi_tx_load<=0;                      // FIX 5: default deassert

            case (state)
                S_IDLE: begin
                    if (rx_valid) begin
                        op_cmd <= rx_data; cnt <= 0; state <= S_LOAD;
                    end else if (pulse_u) begin
                        cnt <= 0; done_flag<=0; state<=S_RUN;
                    end
                end

                S_LOAD: begin
                    if (rx_valid) begin
                        if (op_cmd == 8'hFF) begin
                            if (cnt==0) bram_wr_addr <= rx_data;
                            else begin
                                bram_wr_data <= rx_data;
                                bram_wr_sel  <= cnt[2:0] - 1;
                                bram_wr_en   <= 1;
                            end
                            if (cnt==8) begin cnt<=0; state<=S_IDLE; end
                            else cnt<=cnt+1;
                        end else begin
                            case(cnt)
                                8'd0: bram_rd_addr<=rx_data;
                                8'd1: a0_r<=$signed(rx_data);
                                8'd2: a1_r<=$signed(rx_data);
                                8'd3: a2_r<=$signed(rx_data);
                                8'd4: a3_r<=$signed(rx_data);
                                8'd5: a4_r<=$signed(rx_data);
                                8'd6: a5_r<=$signed(rx_data);
                                8'd7: a6_r<=$signed(rx_data);
                                8'd8: a7_r<=$signed(rx_data);
                                default:;
                            endcase
                            if(cnt==8) begin
                                w0_r<=bram_w0; w1_r<=bram_w1;
                                w2_r<=bram_w2; w3_r<=bram_w3;
                                w4_r<=bram_w4; w5_r<=bram_w5;
                                w6_r<=bram_w6; w7_r<=bram_w7;
                                cnt<=0; state<=S_RUN;
                            end else cnt<=cnt+1;
                        end
                    end
                end

                S_RUN: begin
                    cnt <= cnt+1;
                    if (cnt < 2) sa_rst<=1;
                    else         sa_en<=1;

                    if (cnt==RUN_END) begin
                        relu_en   <= 1;         // FIX 4: relu fires this cycle
                        done_flag <= 1;
                        pp_sel    <= ~pp_sel;
                        cnt       <= 0;
                        state     <= S_TX;
                        // result_we fires NEXT cycle via relu_en_d (see below)
                    end
                end

                S_TX: begin
                    // FIX 4: write buffer 1 cycle after relu_en (relu_en_d)
                    if (relu_en_d) begin
                        if (pp_sel) result_we_b<=1;   // pp_sel already flipped
                        else        result_we_a<=1;
                    end

                    if (!uart_tx_busy && !uart_tx_start) begin
                        // Decode which result and which byte within it
                        // tx_idx and tx_bsel are wires computed outside the always block
                        case(tx_bsel)
                            2'd0: uart_tx_data<={5'h0, tx_val[18:16]};
                            2'd1: uart_tx_data<=tx_val[15:8];
                            2'd2: uart_tx_data<=tx_val[7:0];
                            default: uart_tx_data<=8'hFF;
                        endcase
                        // FIX 5: load SPI shift register with same byte
                        spi_tx_data <= uart_tx_data;
                        spi_tx_load <= 1;
                        uart_tx_start<=1;
                        if(cnt==TX_END) begin cnt<=0; state<=S_IDLE; end
                        else cnt<=cnt+1;
                    end
                end

                default: begin state<=S_IDLE; cnt<=0; end
            endcase
        end
    end

    // ── PE selector ───────────────────────────────────────────────────────────
    reg [3:0] pe_sel;
    always @(posedge clk or posedge sys_rst) begin
        if(sys_rst) pe_sel<=0;
        else begin
            if(pulse_r) pe_sel<=(pe_sel==15)?0:pe_sel+1;
            if(pulse_l) pe_sel<=(pe_sel==0)?15:pe_sel-1;
        end
    end

    // ── LEDs ──────────────────────────────────────────────────────────────────
    assign led[15]   = done_flag;
    assign led[14]   = (state==S_RUN) && sa_en;
    assign led[13]   = rx_valid;
    assign led[12]   = (state==S_LOAD);
    assign led[11:8] = pe_sel;
    assign led[7:4]  = 4'b0;              // FIX 6: was undriven
    assign led[3:2]  = relu_mode;
    assign led[1:0]  = pp_sel ? 2'b10 : 2'b01;

    // ── 7-Segment ─────────────────────────────────────────────────────────────
    // FIX 7: truncate 19-bit result to 18-bit driver port
    wire signed [17:0] disp = pp_sel ? bufA[pe_sel][17:0] : bufB[pe_sel][17:0];
    seven_seg_driver u_seg(
        .clk(clk),.rst(sys_rst),.value(disp),
        .disp_sel(2'd0),.an(an),.seg(seg),.dp(dp));

endmodule
