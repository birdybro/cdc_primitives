// =============================================================================
// Module  : cdc_async_fifo
// Language: SystemVerilog
//
// Description:
//   Dual-clock asynchronous FIFO for crossing multi-bit data between two
//   independent clock domains. Uses Gray-coded read/write pointers for safe
//   pointer synchronization.
//
// CDC Principle (Gray-Coded Pointers):
//   The FIFO has separate write and read clock domains. The challenge is
//   safely comparing the write pointer (in write domain) with the read pointer
//   (in read domain) to generate full/empty flags.
//
//   Solution: Convert binary pointers to Gray code before synchronizing them
//   across clock domains. Gray code ensures that only ONE bit changes per
//   pointer increment, so the synchronized pointer is always either the current
//   or the previous value — never a corrupt intermediate value.
//
//   Full detection (write domain):
//     The write pointer has lapped the read pointer by exactly DEPTH entries.
//     In Gray code: top 2 bits are inverted, lower bits match.
//     wr_full = (wr_gray == {~rd_gray_sync[MSB], ~rd_gray_sync[MSB-1],
//                             rd_gray_sync[MSB-2:0]})
//
//   Empty detection (read domain):
//     Read and write pointers are equal (no data consumed yet).
//     rd_empty = (rd_gray == wr_gray_sync)
//
// Safety:
//   - Gray code pointers only change 1 bit at a time: safe to synchronize.
//   - Full/empty flags are conservative: the FIFO may appear full/empty one
//     cycle earlier than strictly necessary, but will never overflow or underflow.
//   - DEPTH must be a power of 2 (>= 4) for correct Gray code arithmetic.
//
// Use Cases:
//   - High-bandwidth data streaming between asynchronous clock domains
//   - SERDES data buffering
//   - Clock-rate conversion pipelines
//
// Limitations:
//   - DEPTH must be a power of 2 and >= 4.
//   - Write latency: 1 write clock cycle.
//   - Read latency: 1 read clock cycle (registered output).
//   - Full/empty flags have ~2-cycle pessimism due to pointer synchronization.
//
// Timing Assumptions:
//   - Apply ASYNC_REG constraints on wr_gray_sync and rd_gray_sync registers.
//   - No timing relationship required between wr_clk and rd_clk.
//
// Example Instantiation:
//   cdc_async_fifo #(.DATA_WIDTH(8), .DEPTH(16)) u_fifo (
//       .wr_clk   (wr_clk),  .wr_rst_n (wr_rst_n),
//       .wr_en    (wr_en),   .wr_data  (wr_data),
//       .wr_full  (wr_full),
//       .rd_clk   (rd_clk),  .rd_rst_n (rd_rst_n),
//       .rd_en    (rd_en),   .rd_data  (rd_data),
//       .rd_empty (rd_empty)
//   );
// =============================================================================

module cdc_async_fifo #(
    parameter int DATA_WIDTH  = 8,   // Width of each FIFO entry
    parameter int DEPTH       = 16,  // Number of entries; must be a power of 2, >= 4
    parameter int SYNC_STAGES = 2    // Synchronizer stages for pointer crossing (>= 2)
) (
    // Write port (source clock domain)
    input  logic                  wr_clk,   // Write domain clock
    input  logic                  wr_rst_n, // Write domain reset (active low, async assert)
    input  logic                  wr_en,    // Write enable
    input  logic [DATA_WIDTH-1:0] wr_data,  // Write data
    output logic                  wr_full,  // Write domain full flag

    // Read port (destination clock domain)
    input  logic                  rd_clk,   // Read domain clock
    input  logic                  rd_rst_n, // Read domain reset (active low, async assert)
    input  logic                  rd_en,    // Read enable
    output logic [DATA_WIDTH-1:0] rd_data,  // Read data
    output logic                  rd_empty  // Read domain empty flag
);

    // Width of the pointer including the extra MSB that distinguishes full/empty
    localparam int ADDR_WIDTH = $clog2(DEPTH);  // Address bits
    localparam int PTR_WIDTH  = ADDR_WIDTH + 1; // Pointer width (extra MSB)

    // Parameter sanity check (evaluated at elaboration time)
    initial begin
        if (DEPTH < 4 || (DEPTH & (DEPTH - 1)) != 0) begin
            $error("cdc_async_fifo: DEPTH must be a power of 2 and >= 4 (got %0d)", DEPTH);
            $finish;
        end
        if (SYNC_STAGES < 2) begin
            $error("cdc_async_fifo: SYNC_STAGES must be >= 2 (got %0d)", SYNC_STAGES);
            $finish;
        end
    end

    // --------------------------------------------------------------------------
    // Memory array (synchronous write, combinatorial read)
    // For FPGA block RAM inference: use a registered read and remove the
    // combinatorial rd_data assignment, registering it on rd_clk instead.
    // --------------------------------------------------------------------------
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // --------------------------------------------------------------------------
    // Binary to Gray code conversion
    // Only 1 bit changes per increment, making it safe to synchronize.
    // --------------------------------------------------------------------------
    function automatic logic [PTR_WIDTH-1:0] bin2gray (
        input logic [PTR_WIDTH-1:0] bin
    );
        return bin ^ (bin >> 1);
    endfunction

    // --------------------------------------------------------------------------
    // Write domain: binary pointer, Gray pointer, full flag
    // --------------------------------------------------------------------------
    logic [PTR_WIDTH-1:0] wr_ptr;       // Binary write pointer
    logic [PTR_WIDTH-1:0] wr_ptr_gray;  // Gray-coded write pointer

    // Synchronized read Gray pointer in write domain
    (* ASYNC_REG = "TRUE" *) logic [PTR_WIDTH-1:0] rd_gray_sync [0:SYNC_STAGES-1];

    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr <= '0;
        end else if (wr_en && !wr_full) begin
            wr_ptr <= wr_ptr + 1'b1;
        end
    end

    assign wr_ptr_gray = bin2gray(wr_ptr);

    // Write to memory on write clock
    always_ff @(posedge wr_clk) begin
        if (wr_en && !wr_full)
            mem[wr_ptr[ADDR_WIDTH-1:0]] <= wr_data;
    end

    // Synchronize read Gray pointer into write domain
    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            for (int i = 0; i < SYNC_STAGES; i++)
                rd_gray_sync[i] <= '0;
        end else begin
            rd_gray_sync[0] <= rd_ptr_gray;
            for (int i = 1; i < SYNC_STAGES; i++)
                rd_gray_sync[i] <= rd_gray_sync[i-1];
        end
    end

    // Full condition: wr_ptr has wrapped DEPTH entries ahead of rd_ptr.
    // In Gray code this is: top 2 bits inverted, remaining bits equal.
    assign wr_full = (wr_ptr_gray ==
        {~rd_gray_sync[SYNC_STAGES-1][PTR_WIDTH-1],
         ~rd_gray_sync[SYNC_STAGES-1][PTR_WIDTH-2],
          rd_gray_sync[SYNC_STAGES-1][PTR_WIDTH-3:0]});

    // --------------------------------------------------------------------------
    // Read domain: binary pointer, Gray pointer, empty flag
    // --------------------------------------------------------------------------
    logic [PTR_WIDTH-1:0] rd_ptr;       // Binary read pointer
    logic [PTR_WIDTH-1:0] rd_ptr_gray;  // Gray-coded read pointer

    // Synchronized write Gray pointer in read domain
    (* ASYNC_REG = "TRUE" *) logic [PTR_WIDTH-1:0] wr_gray_sync [0:SYNC_STAGES-1];

    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr <= '0;
        end else if (rd_en && !rd_empty) begin
            rd_ptr <= rd_ptr + 1'b1;
        end
    end

    assign rd_ptr_gray = bin2gray(rd_ptr);

    // Combinatorial read data output
    assign rd_data = mem[rd_ptr[ADDR_WIDTH-1:0]];

    // Synchronize write Gray pointer into read domain
    always_ff @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            for (int i = 0; i < SYNC_STAGES; i++)
                wr_gray_sync[i] <= '0;
        end else begin
            wr_gray_sync[0] <= wr_ptr_gray;
            for (int i = 1; i < SYNC_STAGES; i++)
                wr_gray_sync[i] <= wr_gray_sync[i-1];
        end
    end

    // Empty condition: read pointer has caught up to write pointer (equal in Gray).
    assign rd_empty = (rd_ptr_gray == wr_gray_sync[SYNC_STAGES-1]);

endmodule
