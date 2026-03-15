// =============================================================================
// mfu.v  —  Fixed Matrix Feed Unit  |  Basys 3 / Artix-7
// =============================================================================
// FIX: S_ARST was feeding column 'run' of B (B[0..3][run]) — that is B-transpose.
//      Correct: feed row 'run' of B (B[run][0..3]) so C = A × B, not A × Bᵀ.
//
//      Verified:  A=[[1,2],[3,4]]  B=[[5,6],[7,8]]
//        BEFORE fix:  [[17,23],[39,53]]  (= A × Bᵀ)
//        AFTER  fix:  [[19,22],[43,50]]  (= A × B  ✓)
// =============================================================================
`timescale 1ns/1ps

module mfu #(
    parameter COMPUTE_CYCLES = 10
)(
    input  wire        clk,
    input  wire        rst,
    input  wire [7:0]  load_data,
    input  wire        load_valid,
    input  wire        start,
    output reg         busy,
    output reg         done,
    output reg signed [19:0] c00,c01,c02,c03,
    output reg signed [19:0] c10,c11,c12,c13,
    output reg signed [19:0] c20,c21,c22,c23,
    output reg signed [19:0] c30,c31,c32,c33,
    output reg signed [7:0]  sa_a0,sa_a1,sa_a2,sa_a3,
    output reg signed [7:0]  sa_w0,sa_w1,sa_w2,sa_w3,
    output reg               sa_rst,
    input  wire signed [19:0] sa_out00,sa_out01,sa_out02,sa_out03,
    input  wire signed [19:0] sa_out10,sa_out11,sa_out12,sa_out13,
    input  wire signed [19:0] sa_out20,sa_out21,sa_out22,sa_out23,
    input  wire signed [19:0] sa_out30,sa_out31,sa_out32,sa_out33
);

    reg signed [7:0] A [0:3][0:3];
    reg signed [7:0] B [0:3][0:3];
    reg signed [19:0] C [0:3][0:3];

    reg [5:0] load_cnt;
    integer lr, lc;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            load_cnt <= 0;
            for (lr=0;lr<4;lr=lr+1)
                for (lc=0;lc<4;lc=lc+1) begin A[lr][lc]<=0; B[lr][lc]<=0; end
        end else if (load_valid) begin
            if (load_cnt < 16)
                A[load_cnt[3:2]][load_cnt[1:0]] <= $signed(load_data);
            else
                B[(load_cnt-16) >> 2][(load_cnt-16) & 2'b11] <= $signed(load_data);
            load_cnt <= (load_cnt == 6'd31) ? 6'd0 : load_cnt + 1;
        end
    end

    localparam S_IDLE    = 3'd0;
    localparam S_ARST    = 3'd1;
    localparam S_COMPUTE = 3'd2;
    localparam S_ACCUM   = 3'd3;
    localparam S_NEXT    = 3'd4;
    localparam S_DONE    = 3'd5;

    reg [2:0]  state;
    reg [1:0]  run;
    reg [3:0]  compute_cnt;
    reg [1:0]  arst_cnt;
    integer i, j;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state<=S_IDLE; sa_rst<=1; busy<=0; done<=0;
            run<=0; compute_cnt<=0; arst_cnt<=0;
            sa_a0<=0;sa_a1<=0;sa_a2<=0;sa_a3<=0;
            sa_w0<=0;sa_w1<=0;sa_w2<=0;sa_w3<=0;
            for (i=0;i<4;i=i+1) for (j=0;j<4;j=j+1) C[i][j]<=0;
        end else begin
            done <= 0;

            case (state)
                S_IDLE: begin
                    sa_rst <= 1;
                    if (start) begin
                        busy <= 1; run <= 0;
                        for (i=0;i<4;i=i+1) for (j=0;j<4;j=j+1) C[i][j]<=0;
                        arst_cnt <= 0; state <= S_ARST;
                    end
                end

                S_ARST: begin
                    sa_rst <= 1;
                    sa_a0 <= A[0][run];
                    sa_a1 <= A[1][run];
                    sa_a2 <= A[2][run];
                    sa_a3 <= A[3][run];
                    // FIX: feed row 'run' of B (not column 'run')
                    sa_w0 <= B[run][0];   // was B[0][run]
                    sa_w1 <= B[run][1];   // was B[1][run]
                    sa_w2 <= B[run][2];   // was B[2][run]
                    sa_w3 <= B[run][3];   // was B[3][run]

                    if (arst_cnt == 2'd2) begin
                        sa_rst <= 0; compute_cnt <= COMPUTE_CYCLES - 1;
                        state  <= S_COMPUTE;
                    end else arst_cnt <= arst_cnt + 1;
                end

                S_COMPUTE: begin
                    sa_rst <= 0;
                    if (compute_cnt == 0) state <= S_ACCUM;
                    else compute_cnt <= compute_cnt - 1;
                end

                S_ACCUM: begin
                    sa_rst <= 1;
                    C[0][0]<=C[0][0]+sa_out00; C[0][1]<=C[0][1]+sa_out01;
                    C[0][2]<=C[0][2]+sa_out02; C[0][3]<=C[0][3]+sa_out03;
                    C[1][0]<=C[1][0]+sa_out10; C[1][1]<=C[1][1]+sa_out11;
                    C[1][2]<=C[1][2]+sa_out12; C[1][3]<=C[1][3]+sa_out13;
                    C[2][0]<=C[2][0]+sa_out20; C[2][1]<=C[2][1]+sa_out21;
                    C[2][2]<=C[2][2]+sa_out22; C[2][3]<=C[2][3]+sa_out23;
                    C[3][0]<=C[3][0]+sa_out30; C[3][1]<=C[3][1]+sa_out31;
                    C[3][2]<=C[3][2]+sa_out32; C[3][3]<=C[3][3]+sa_out33;
                    state <= S_NEXT;
                end

                S_NEXT: begin
                    if (run == 2'd3) state <= S_DONE;
                    else begin run<=run+1; arst_cnt<=0; state<=S_ARST; end
                end

                S_DONE: begin
                    c00<=C[0][0]; c01<=C[0][1]; c02<=C[0][2]; c03<=C[0][3];
                    c10<=C[1][0]; c11<=C[1][1]; c12<=C[1][2]; c13<=C[1][3];
                    c20<=C[2][0]; c21<=C[2][1]; c22<=C[2][2]; c23<=C[2][3];
                    c30<=C[3][0]; c31<=C[3][1]; c32<=C[3][2]; c33<=C[3][3];
                    done<=1; busy<=0; state<=S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
