// =============================================================================
// uart_rx.v  —  UART Receiver (8N1)
// Basys 3 / Artix-7  |  Default: 115200 baud @ 100 MHz
// =============================================================================
// Protocol : 8 data bits, No parity, 1 stop bit (8N1)
// Sampling : Centre-sample on each data bit
// Outputs  : data[7:0] valid on rising edge of `valid` (held 1 cycle)
// =============================================================================

`timescale 1ns/1ps

module uart_rx #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 115_200
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        rx,           // Serial input from PC (FTDI)
    output reg  [7:0]  data,         // Received byte
    output reg         valid         // Pulses high for 1 cycle when byte ready
);

    // ── Timing ──────────────────────────────────────────────────────────────
    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;   // 868 @ 115200
    localparam integer HALF_BIT     = CLKS_PER_BIT / 2;       // 434

    // ── States ──────────────────────────────────────────────────────────────
    localparam S_IDLE  = 2'd0;
    localparam S_START = 2'd1;
    localparam S_DATA  = 2'd2;
    localparam S_STOP  = 2'd3;

    // ── Internals ────────────────────────────────────────────────────────────
    reg [1:0]  state;
    reg [10:0] clk_cnt;   // Wide enough for CLKS_PER_BIT (868)
    reg [2:0]  bit_idx;
    reg [1:0]  rx_ff;     // 2-FF synchronizer against metastability

    wire rx_s = rx_ff[1]; // Synchronised RX

    // ── 2-FF Input Synchroniser ──────────────────────────────────────────────
    always @(posedge clk or posedge rst) begin
        if (rst) rx_ff <= 2'b11;
        else     rx_ff <= {rx_ff[0], rx};
    end

    // ── FSM ─────────────────────────────────────────────────────────────────
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state   <= S_IDLE;
            clk_cnt <= 0;
            bit_idx <= 0;
            data    <= 8'h00;
            valid   <= 1'b0;
        end else begin
            valid <= 1'b0; // Default: not valid

            case (state)
                // ── Wait for start bit (line goes low) ──────────────────────
                S_IDLE: begin
                    if (rx_s == 1'b0) begin
                        state   <= S_START;
                        clk_cnt <= 0;
                    end
                end

                // ── Confirm start bit at mid-point ──────────────────────────
                S_START: begin
                    if (clk_cnt == HALF_BIT - 1) begin
                        if (rx_s == 1'b0) begin   // Valid start bit
                            clk_cnt <= 0;
                            bit_idx <= 0;
                            state   <= S_DATA;
                        end else begin             // Glitch — ignore
                            state <= S_IDLE;
                        end
                    end else
                        clk_cnt <= clk_cnt + 1;
                end

                // ── Sample each data bit at its centre ──────────────────────
                S_DATA: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt        <= 0;
                        data[bit_idx]  <= rx_s;         // LSB first
                        if (bit_idx == 3'd7) begin
                            bit_idx <= 0;
                            state   <= S_STOP;
                        end else
                            bit_idx <= bit_idx + 1;
                    end else
                        clk_cnt <= clk_cnt + 1;
                end

                // ── Wait for stop bit then assert valid ─────────────────────
                S_STOP: begin
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        valid   <= 1'b1;
                        clk_cnt <= 0;
                        state   <= S_IDLE;
                    end else
                        clk_cnt <= clk_cnt + 1;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
