// =============================================================================
// Example: cdc_sync3 instantiation
// =============================================================================
// This example shows the 3-stage synchronizer for a high-frequency (500 MHz)
// design where additional metastability resolution time is needed.
//
// The extra FF stage provides ~e^(Tclk/tau) more metastability rejection
// compared to cdc_sync2, at the cost of one additional cycle of latency.
// =============================================================================

module example_sync3 (
    input  logic clk_src,    // Source clock (e.g., 250 MHz)
    input  logic rst_src_n,
    input  logic status_src, // Slow-moving status bit in source domain

    input  logic clk_500m,   // 500 MHz destination clock
    input  logic rst_500m_n,
    output logic status_dst  // Status synchronized to 500 MHz domain
);

    // Use 3-stage synchronizer for high-frequency destination clock.
    cdc_sync3 #(
        .RESET_VAL (1'b0)
    ) u_status_sync (
        .clk_dst   (clk_500m),
        .rst_dst_n (rst_500m_n),
        .data_src  (status_src),
        .data_dst  (status_dst)
    );

endmodule
