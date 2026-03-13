// =============================================================================
// Module  : cdc_async_fifo
// Language: Verilog-2001
//
// Description:
//   Dual-clock asynchronous FIFO using Gray-coded read/write pointers.
//   Safely transfers multi-bit data between two independent clock domains.
//
// CDC Principle (Gray-Coded Pointers):
//   Gray code ensures only 1 bit changes per pointer increment, making
//   pointer synchronization safe across clock domains.
//   Full:  wr_gray == {~rd_gray_sync[MSB], ~rd_gray_sync[MSB-1], rd_gray_sync[rest]}
//   Empty: rd_gray == wr_gray_sync
//
// Safety:
//   - Gray code pointer synchronization is the only CDC crossing.
//   - DEPTH must be a power of 2 and >= 4.
//   - Apply ASYNC_REG constraints on rd_gray_sync and wr_gray_sync.
//
// Use Cases:
//   - High-bandwidth data streaming between asynchronous clock domains.
//
// Limitations:
//   - DEPTH must be power of 2 >= 4.
//   - Full/empty flags have ~2-cycle pessimism.
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
    parameter DATA_WIDTH  = 8,   // Width of each FIFO entry
    parameter DEPTH       = 16,  // Number of entries; must be power of 2, >= 4
    parameter SYNC_STAGES = 2    // Synchronizer stages for pointer crossing (>= 2)
) (
    // Write port
    input  wire                  wr_clk,   // Write domain clock
    input  wire                  wr_rst_n, // Write domain reset (active low)
    input  wire                  wr_en,    // Write enable
    input  wire [DATA_WIDTH-1:0] wr_data,  // Write data
    output wire                  wr_full,  // Write domain full flag

    // Read port
    input  wire                  rd_clk,   // Read domain clock
    input  wire                  rd_rst_n, // Read domain reset (active low)
    input  wire                  rd_en,    // Read enable
    output wire [DATA_WIDTH-1:0] rd_data,  // Read data (combinatorial)
    output wire                  rd_empty  // Read domain empty flag
);

    // Derived parameters
    localparam ADDR_WIDTH = $clog2(DEPTH);
    localparam PTR_WIDTH  = ADDR_WIDTH + 1;

    // --------------------------------------------------------------------------
    // Memory
    // --------------------------------------------------------------------------
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // --------------------------------------------------------------------------
    // Binary to Gray code: XOR with right-shifted self
    // --------------------------------------------------------------------------
    function [PTR_WIDTH-1:0] bin2gray;
        input [PTR_WIDTH-1:0] bin;
        bin2gray = bin ^ (bin >> 1);
    endfunction

    // --------------------------------------------------------------------------
    // Write domain
    // --------------------------------------------------------------------------
    reg [PTR_WIDTH-1:0] wr_ptr;
    wire [PTR_WIDTH-1:0] wr_ptr_gray;

    (* ASYNC_REG = "TRUE" *) reg [PTR_WIDTH-1:0] rd_gray_sync [0:SYNC_STAGES-1];

    integer i;

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n)
            wr_ptr <= {PTR_WIDTH{1'b0}};
        else if (wr_en && !wr_full)
            wr_ptr <= wr_ptr + 1'b1;
    end

    assign wr_ptr_gray = bin2gray(wr_ptr);

    always @(posedge wr_clk) begin
        if (wr_en && !wr_full)
            mem[wr_ptr[ADDR_WIDTH-1:0]] <= wr_data;
    end

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            for (i = 0; i < SYNC_STAGES; i = i + 1)
                rd_gray_sync[i] <= {PTR_WIDTH{1'b0}};
        end else begin
            rd_gray_sync[0] <= rd_ptr_gray;
            for (i = 1; i < SYNC_STAGES; i = i + 1)
                rd_gray_sync[i] <= rd_gray_sync[i-1];
        end
    end

    assign wr_full = (wr_ptr_gray ==
        {~rd_gray_sync[SYNC_STAGES-1][PTR_WIDTH-1],
         ~rd_gray_sync[SYNC_STAGES-1][PTR_WIDTH-2],
          rd_gray_sync[SYNC_STAGES-1][PTR_WIDTH-3:0]});

    // --------------------------------------------------------------------------
    // Read domain
    // --------------------------------------------------------------------------
    reg [PTR_WIDTH-1:0] rd_ptr;
    wire [PTR_WIDTH-1:0] rd_ptr_gray;

    (* ASYNC_REG = "TRUE" *) reg [PTR_WIDTH-1:0] wr_gray_sync [0:SYNC_STAGES-1];

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n)
            rd_ptr <= {PTR_WIDTH{1'b0}};
        else if (rd_en && !rd_empty)
            rd_ptr <= rd_ptr + 1'b1;
    end

    assign rd_ptr_gray = bin2gray(rd_ptr);
    assign rd_data     = mem[rd_ptr[ADDR_WIDTH-1:0]];

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            for (i = 0; i < SYNC_STAGES; i = i + 1)
                wr_gray_sync[i] <= {PTR_WIDTH{1'b0}};
        end else begin
            wr_gray_sync[0] <= wr_ptr_gray;
            for (i = 1; i < SYNC_STAGES; i = i + 1)
                wr_gray_sync[i] <= wr_gray_sync[i-1];
        end
    end

    assign rd_empty = (rd_ptr_gray == wr_gray_sync[SYNC_STAGES-1]);

endmodule
