// =============================================================================
// Example: cdc_reset_sync instantiation
// =============================================================================
// This example distributes a single power-on reset (POR) to three independent
// clock domains. Each domain gets its own reset synchronizer so that each
// domain's flip-flops exit reset synchronously with their own clock.
//
// Without reset synchronizers, each domain's FFs may come out of reset at
// unpredictable times, leading to glitches or X-propagation during simulation.
// =============================================================================

module example_reset_sync (
    input  logic por_rst_n,     // Asynchronous power-on reset (active low)

    input  logic clk_100m,      // 100 MHz clock domain
    output logic rst_100m_n,    // Synchronized reset for 100 MHz domain

    input  logic clk_200m,      // 200 MHz clock domain
    output logic rst_200m_n,    // Synchronized reset for 200 MHz domain

    input  logic clk_50m,       // 50 MHz clock domain
    output logic rst_50m_n      // Synchronized reset for 50 MHz domain
);

    // 100 MHz domain reset synchronizer (2 stages)
    cdc_reset_sync #(.SYNC_STAGES(2)) u_rst_100m (
        .clk         (clk_100m),
        .rst_async_n (por_rst_n),
        .rst_sync_n  (rst_100m_n)
    );

    // 200 MHz domain reset synchronizer (3 stages for extra metastability margin)
    cdc_reset_sync #(.SYNC_STAGES(3)) u_rst_200m (
        .clk         (clk_200m),
        .rst_async_n (por_rst_n),
        .rst_sync_n  (rst_200m_n)
    );

    // 50 MHz domain reset synchronizer (2 stages)
    cdc_reset_sync #(.SYNC_STAGES(2)) u_rst_50m (
        .clk         (clk_50m),
        .rst_async_n (por_rst_n),
        .rst_sync_n  (rst_50m_n)
    );

endmodule
