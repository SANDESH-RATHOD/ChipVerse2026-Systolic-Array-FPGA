// =============================================================================
// weight_bram.v  —  Block RAM Weight Storage
// =============================================================================
// Stores weight matrices in Basys 3 Block RAM.
// Load once via UART, reuse for many computations.
//
// Architecture:
//   - 256 weight sets storable (addr 0..255)
//   - Each weight set = 8 values (w0..w7) × 8-bit = 64 bits
//   - Total: 256 × 64 = 16,384 bits = 0.5% of available BRAM
//
// UART Load Protocol (write mode):
//   Send: [ADDR(1 byte)] [w0..w7 (8 bytes)] = 9 bytes per weight set
//
// Inference Protocol (read mode):
//   Send: [ADDR(1 byte)] [a0..a7 (8 bytes)] = 9 bytes
//   FPGA loads weights from BRAM at ADDR, computes, returns results
//
// This means you load weights ONCE and can run inference thousands of times
// — exactly like a real TPU weight stationary dataflow
// =============================================================================
`timescale 1ns/1ps

module weight_bram #(
    parameter DATA_WIDTH  = 8,
    parameter ADDR_WIDTH  = 8,    // 256 weight sets
    parameter N_WEIGHTS   = 8     // weights per set (matches array width)
)(
    input  wire        clk,
    input  wire        rst,

    // ── Write port (load weights via UART) ───────────────────────────────────
    input  wire [ADDR_WIDTH-1:0] wr_addr,
    input  wire [DATA_WIDTH-1:0] wr_data,
    input  wire [2:0]            wr_sel,    // which weight (0..7)
    input  wire                  wr_en,

    // ── Read port (fetch weights for computation) ─────────────────────────────
    input  wire [ADDR_WIDTH-1:0] rd_addr,
    output reg  signed [DATA_WIDTH-1:0] w0,w1,w2,w3,w4,w5,w6,w7
);

    // ── BRAM declaration ──────────────────────────────────────────────────────
    // 256 entries × 64 bits (8 weights × 8 bits)
    reg [63:0] mem [0:255];

    integer i;
    initial begin
        for (i=0; i<256; i=i+1) mem[i] = 64'h0;
    end

    // ── Write port ────────────────────────────────────────────────────────────
    always @(posedge clk) begin
        if (wr_en) begin
            case (wr_sel)
                3'd0: mem[wr_addr][7:0]   <= wr_data;
                3'd1: mem[wr_addr][15:8]  <= wr_data;
                3'd2: mem[wr_addr][23:16] <= wr_data;
                3'd3: mem[wr_addr][31:24] <= wr_data;
                3'd4: mem[wr_addr][39:32] <= wr_data;
                3'd5: mem[wr_addr][47:40] <= wr_data;
                3'd6: mem[wr_addr][55:48] <= wr_data;
                3'd7: mem[wr_addr][63:56] <= wr_data;
            endcase
        end
    end

    // ── Read port (combinational — 1 cycle latency) ───────────────────────────
    always @(posedge clk) begin
        w0 <= $signed(mem[rd_addr][7:0]);
        w1 <= $signed(mem[rd_addr][15:8]);
        w2 <= $signed(mem[rd_addr][23:16]);
        w3 <= $signed(mem[rd_addr][31:24]);
        w4 <= $signed(mem[rd_addr][39:32]);
        w5 <= $signed(mem[rd_addr][47:40]);
        w6 <= $signed(mem[rd_addr][55:48]);
        w7 <= $signed(mem[rd_addr][63:56]);
    end

endmodule
