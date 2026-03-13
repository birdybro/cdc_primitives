// =============================================================================
// Example: cdc_async_fifo instantiation
// =============================================================================
// This example connects a 100 MHz producer to a 150 MHz consumer using an
// asynchronous FIFO. The FIFO decouples the two clock domains and absorbs
// short bursts from the faster producer.
//
// The producer writes 8-bit samples when wr_en is asserted and wr_full is low.
// The consumer reads samples when rd_en is asserted and rd_empty is low.
//
// ASYNC_REG constraints are handled inside the FIFO module via attributes.
// =============================================================================

module example_async_fifo (
    // Producer domain (100 MHz)
    input  logic       clk_prod,
    input  logic       rst_prod_n,
    input  logic       prod_valid,    // Producer has data
    input  logic [7:0] prod_data,     // Sample data
    output logic       prod_ready,    // Producer can write (FIFO not full)

    // Consumer domain (150 MHz)
    input  logic       clk_cons,
    input  logic       rst_cons_n,
    output logic [7:0] cons_data,     // Consumed sample
    output logic       cons_valid,    // Data available (FIFO not empty)
    input  logic       cons_ready     // Consumer ready to read
);

    logic wr_full;
    logic rd_empty;

    // Asynchronous FIFO: 8-bit data, 64-entry depth
    cdc_async_fifo #(
        .DATA_WIDTH  (8),
        .DEPTH       (64),
        .SYNC_STAGES (2)
    ) u_sample_fifo (
        .wr_clk   (clk_prod),
        .wr_rst_n (rst_prod_n),
        .wr_en    (prod_valid && !wr_full),
        .wr_data  (prod_data),
        .wr_full  (wr_full),

        .rd_clk   (clk_cons),
        .rd_rst_n (rst_cons_n),
        .rd_en    (cons_ready && !rd_empty),
        .rd_data  (cons_data),
        .rd_empty (rd_empty)
    );

    assign prod_ready = ~wr_full;
    assign cons_valid = ~rd_empty;

endmodule
