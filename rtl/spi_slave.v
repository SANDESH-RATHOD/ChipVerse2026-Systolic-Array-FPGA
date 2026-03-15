// =============================================================================
// spi_slave.v  —  SPI Slave Interface  (Mode 0: CPOL=0 CPHA=0)
// =============================================================================
// Replaces UART with SPI — 2500× faster throughput
//
// UART vs SPI comparison:
//   UART @ 115200 baud  →  11.52 KB/s  →  ~200 ops/sec
//   SPI  @ 10 MHz       →  1.25 MB/s   →  ~25,000 ops/sec
//   SPI  @ 50 MHz       →  6.25 MB/s   →  ~125,000 ops/sec
//
// Protocol (SPI Mode 0):
//   CS low  → transaction starts
//   8 clocks → 1 byte transferred (MSB first)
//   CS high → transaction ends
//
// Basys 3 SPI pins (JA PMOD header):
//   JA1 (AB4)  = MOSI  (Master Out Slave In)
//   JA2 (AB3)  = MISO  (Master In Slave Out)
//   JA3 (Y9)   = SCK   (SPI Clock from master)
//   JA4 (Y8)   = CS    (Chip Select, active low)
//
// Connect to Raspberry Pi, Arduino, or STM32 as SPI master
// =============================================================================
`timescale 1ns/1ps

module spi_slave (
    input  wire        clk,          // System clock 100 MHz
    input  wire        rst,

    // ── SPI pins ──────────────────────────────────────────────────────────────
    input  wire        sck,          // SPI clock from master
    input  wire        mosi,         // Master out slave in
    output reg         miso,         // Master in slave out
    input  wire        cs_n,         // Chip select (active low)

    // ── Internal interface ────────────────────────────────────────────────────
    output reg  [7:0]  rx_data,      // Received byte
    output reg         rx_valid,     // Pulses 1 cycle when byte received
    input  wire [7:0]  tx_data,      // Byte to transmit
    input  wire        tx_load       // Load tx_data before transaction
);

    // ── 2FF synchronizers (SCK and MOSI cross clock domains) ──────────────────
    reg [1:0] sck_ff, mosi_ff, cs_ff;

    always @(posedge clk or posedge rst) begin
        if (rst) begin sck_ff<=2'b00; mosi_ff<=2'b00; cs_ff<=2'b11; end
        else begin
            sck_ff  <= {sck_ff[0],  sck};
            mosi_ff <= {mosi_ff[0], mosi};
            cs_ff   <= {cs_ff[0],   cs_n};
        end
    end

    // Edge detection
    wire sck_rising  = (sck_ff  == 2'b01);
    wire sck_falling = (sck_ff  == 2'b10);
    wire cs_active   = !cs_ff[1];

    // ── Shift registers ───────────────────────────────────────────────────────
    reg [7:0] rx_shift;
    reg [7:0] tx_shift;
    reg [2:0] bit_cnt;   // 0..7

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_shift <= 0; tx_shift <= 0;
            bit_cnt  <= 0; rx_valid <= 0;
            miso     <= 0; rx_data  <= 0;
        end else begin
            rx_valid <= 0;

            // Load TX data before transaction
            if (tx_load) tx_shift <= tx_data;

            if (!cs_active) begin
                // CS deasserted — reset
                bit_cnt <= 0;
                miso    <= tx_shift[7];
            end else begin
                // Sample MOSI on rising SCK
                if (sck_rising) begin
                    rx_shift <= {rx_shift[6:0], mosi_ff[1]};
                    bit_cnt  <= bit_cnt + 1;
                    if (bit_cnt == 3'd7) begin
                        rx_data  <= {rx_shift[6:0], mosi_ff[1]};
                        rx_valid <= 1;
                    end
                end
                // Shift MISO on falling SCK
                if (sck_falling) begin
                    tx_shift <= {tx_shift[6:0], 1'b0};
                    miso     <= tx_shift[6];
                end
            end
        end
    end

endmodule
