// =============================================================================
// Example: cdc_pulse_sync instantiation
// =============================================================================
// This example crosses a single-cycle interrupt strobe from a 125 MHz CPU
// clock domain to a 50 MHz peripheral clock domain.
//
// The pulse synchronizer uses toggle-based encoding so the pulse cannot be
// missed, even if the source clock is faster than the destination clock.
//
// Limitation: consecutive pulses must be separated by at least ~4 destination
// clock cycles (80 ns at 50 MHz). For bursts, use a FIFO instead.
// =============================================================================

module example_pulse_sync (
    input  logic clk_cpu,      // 125 MHz CPU clock
    input  logic rst_cpu_n,
    input  logic irq_pulse,    // 1-cycle interrupt pulse in CPU domain

    input  logic clk_periph,   // 50 MHz peripheral clock
    input  logic rst_periph_n,
    output logic irq_periph    // 1-cycle interrupt pulse in peripheral domain
);

    cdc_pulse_sync u_irq_sync (
        .clk_src   (clk_cpu),
        .rst_src_n (rst_cpu_n),
        .pulse_src (irq_pulse),
        .clk_dst   (clk_periph),
        .rst_dst_n (rst_periph_n),
        .pulse_dst (irq_periph)
    );

endmodule
