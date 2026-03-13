// =============================================================================
// Example: cdc_sync2 instantiation
// =============================================================================
// This example shows how to use the 2-stage flip-flop synchronizer to cross
// a single-bit control flag from a 100 MHz source domain to a 200 MHz
// destination domain.
//
// Key rule: flag_src must be quasi-static (stable for >> 1 dst clock cycle).
//           For pulsed signals, use cdc_pulse_sync instead.
// =============================================================================

module example_sync2 (
    input  logic clk_100m,    // 100 MHz source clock
    input  logic rst_100m_n,  // Source domain reset
    input  logic flag_src,    // Flag generated in 100 MHz domain

    input  logic clk_200m,    // 200 MHz destination clock
    input  logic rst_200m_n,  // Destination domain reset
    output logic flag_dst     // Flag synchronized to 200 MHz domain
);

    // Instantiate the 2-stage synchronizer.
    // RESET_VAL = 0 means the synchronized flag initializes to 0 after reset.
    cdc_sync2 #(
        .RESET_VAL (1'b0)
    ) u_flag_sync (
        .clk_dst   (clk_200m),
        .rst_dst_n (rst_200m_n),
        .data_src  (flag_src),
        .data_dst  (flag_dst)
    );

endmodule
