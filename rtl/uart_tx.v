// =============================================================================
// uart_tx.v  —  UART Transmitter (8N1)
// Basys 3 / Artix-7  |  Default: 115200 baud @ 100 MHz
// =============================================================================
// Usage : Assert `start` for 1 cycle with `data` valid.
//         Wait for `busy` to deassert before sending next byte.
// =============================================================================

`timescale 1ns/1ps

module uart_tx #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 115_200
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] data,    // Byte to transmit
    input  wire       start,   // Pulse high for 1 cycle to begin TX
    output reg        tx,      // Serial output to PC (FTDI)
    output reg        busy     // High while transmitting
);

    // ── Timing ──────────────────────────────────────────────────────────────
    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    // ── States ──────────────────────────────────────────────────────────────
    localparam S_IDLE  = 2'd0;
    localparam S_START = 2'd1;
    localparam S_DATA  = 2'd2;
    localparam S_STOP  = 2'd3;

    // ── Internals ────────────────────────────────────────────────────────────
    reg [1:0]  state;
    reg [10:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  tx_shift;   // Shift register holds byte being sent

    // ── FSM ─────────────────────────────────────────────────────────────────
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state    <= S_IDLE;
            clk_cnt  <= 0;
            bit_idx  <= 0;
            tx       <= 1'b1;    // UART idle = high
            busy     <= 1'b0;
            tx_shift <= 8'h00;
        end else begin
            case (state)
                // ── Wait for start pulse ─────────────────────────────────────
                S_IDLE: begin
                    tx   <= 1'b1;
                    busy <= 1'b0;
                    if (start) begin
                        tx_shift <= data;
                        busy     <= 1'b1;
                        clk_cnt  <= 0;
                        state    <= S_START;
                    end
                end

                // ── Send start bit (low) ─────────────────────────────────────
                S_START: begin
                    tx <= 1'b0;
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 0;
                        bit_idx <= 0;
                        state   <= S_DATA;
                    end else
                        clk_cnt <= clk_cnt + 1;
                end

                // ── Clock out 8 data bits (LSB first) ───────────────────────
                S_DATA: begin
                    tx <= tx_shift[bit_idx];
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 0;
                        if (bit_idx == 3'd7) begin
                            state <= S_STOP;
                        end else
                            bit_idx <= bit_idx + 1;
                    end else
                        clk_cnt <= clk_cnt + 1;
                end

                // ── Send stop bit (high) ──────────────────────────────────────
                S_STOP: begin
                    tx <= 1'b1;
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        state   <= S_IDLE;
                        busy    <= 1'b0;
                        clk_cnt <= 0;
                    end else
                        clk_cnt <= clk_cnt + 1;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
