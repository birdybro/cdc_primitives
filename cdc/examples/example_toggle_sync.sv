// =============================================================================
// Example: cdc_toggle_sync instantiation
// =============================================================================
// This example uses the toggle synchronizer to signal a "packet received"
// event from a 25 MHz MAC clock domain to a 100 MHz CPU clock domain.
//
// The MAC toggles rx_event_toggle once per received packet. The toggle
// synchronizer detects each edge and generates a single-cycle pulse in the
// CPU domain to trigger processing.
// =============================================================================

module example_toggle_sync (
    input  logic clk_mac,        // 25 MHz MAC clock
    input  logic rst_mac_n,
    input  logic rx_event_toggle, // Toggled in MAC domain on each packet received

    input  logic clk_cpu,         // 100 MHz CPU clock
    input  logic rst_cpu_n,
    output logic rx_toggle_sync,  // Synchronized toggle output
    output logic rx_pulse_cpu     // 1-cycle pulse in CPU domain per packet
);

    cdc_toggle_sync u_rx_sync (
        .clk_dst    (clk_cpu),
        .rst_dst_n  (rst_cpu_n),
        .toggle_src (rx_event_toggle),
        .toggle_dst (rx_toggle_sync),
        .pulse_dst  (rx_pulse_cpu)
    );

endmodule
