// =============================================================================
// Module  : cdc_toggle_sync
// Language: SystemVerilog
//
// Description:
//   Toggle-event synchronizer. Synchronizes a toggle signal from the source
//   clock domain to the destination domain and generates a single-cycle pulse
//   on each toggle edge.
//
// CDC Principle:
//   Instead of sending a short pulse (which might be missed if shorter than
//   one destination clock period), the source toggles a persistent signal each
//   time an event occurs. The toggle is synchronized with a 2-stage FF chain.
//   An XOR of the synchronized toggle with its previous value detects each
//   edge and generates a single-cycle output pulse in the destination domain.
//
// Safety:
//   - Safe for CDC because the toggle is persistent (does not need to be
//     captured within a specific clock window).
//   - The 2FF chain handles metastability on the toggle crossing.
//   - Events must be separated by at least 3 destination clock cycles for
//     reliable detection (2 sync cycles + 1 cycle for edge detection).
//
// Use Cases:
//   - Signaling infrequent events across clock domains
//   - When the source already provides a toggle signal
//   - Building block for cdc_pulse_sync (which adds the src toggle generation)
//
// Limitations:
//   - Consecutive events must be separated by >= 3 destination clock cycles.
//   - Back-to-back high-frequency events may be missed if spacing is too short.
//
// Timing Assumptions:
//   - toggle_src must be stable for at least one destination clock cycle before
//     each new transition.
//
// Example Instantiation:
//   cdc_toggle_sync u_tog_sync (
//       .clk_dst    (clk_dst),
//       .rst_dst_n  (rst_dst_n),
//       .toggle_src (my_toggle),
//       .toggle_dst (toggle_synced),
//       .pulse_dst  (event_pulse)
//   );
// =============================================================================

module cdc_toggle_sync (
    // Destination domain
    input  logic clk_dst,     // Destination domain clock
    input  logic rst_dst_n,   // Destination domain reset (active low)
    // Cross-domain input
    input  logic toggle_src,  // Toggle signal from source clock domain
    // Destination domain outputs
    output logic toggle_dst,  // Synchronized toggle in destination domain
    output logic pulse_dst    // One-cycle pulse on each toggle transition
);

    // Two-stage synchronizer for the toggle signal.
    (* ASYNC_REG = "TRUE" *) logic [1:0] sync_ff;

    // Previous value of synchronized toggle (for edge detection).
    logic toggle_dst_prev;

    always_ff @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            sync_ff          <= 2'b00;
            toggle_dst_prev  <= 1'b0;
        end else begin
            sync_ff          <= {sync_ff[0], toggle_src};
            toggle_dst_prev  <= sync_ff[1];
        end
    end

    // Synchronized toggle output
    assign toggle_dst = sync_ff[1];

    // Single-cycle pulse on any toggle edge (rising or falling)
    assign pulse_dst = sync_ff[1] ^ toggle_dst_prev;

endmodule
