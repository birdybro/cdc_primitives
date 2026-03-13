// =============================================================================
// Module  : cdc_toggle_sync
// Language: Verilog-2001
//
// Description:
//   Toggle-event synchronizer. Synchronizes a toggle signal from the source
//   clock domain to the destination domain and generates a single-cycle pulse
//   on each toggle edge.
//
// CDC Principle:
//   The toggle signal is persistent and synchronized with a 2-stage FF chain.
//   Edge detection generates a single-cycle output pulse per toggle event.
//
// Safety:
//   - Safe for CDC: toggle is persistent, 2FF handles metastability.
//   - Events must be >= 3 destination clock cycles apart.
//
// Use Cases:
//   - Infrequent event signaling across clock domains.
//   - Building block for cdc_pulse_sync.
//
// Limitations:
//   - Consecutive events must be >= 3 destination clock cycles apart.
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
    input  wire clk_dst,     // Destination domain clock
    input  wire rst_dst_n,   // Destination domain reset (active low)
    // Cross-domain input
    input  wire toggle_src,  // Toggle signal from source clock domain
    // Destination domain outputs
    output wire toggle_dst,  // Synchronized toggle in destination domain
    output wire pulse_dst    // One-cycle pulse on each toggle transition
);

    // Two-stage synchronizer for the toggle signal.
    (* ASYNC_REG = "TRUE" *) reg [1:0] sync_ff;

    // Previous value for edge detection.
    reg toggle_dst_prev;

    always @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            sync_ff         <= 2'b00;
            toggle_dst_prev <= 1'b0;
        end else begin
            sync_ff         <= {sync_ff[0], toggle_src};
            toggle_dst_prev <= sync_ff[1];
        end
    end

    assign toggle_dst = sync_ff[1];
    assign pulse_dst  = sync_ff[1] ^ toggle_dst_prev;

endmodule
