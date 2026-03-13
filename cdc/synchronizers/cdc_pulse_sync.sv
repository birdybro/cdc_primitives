// =============================================================================
// Module  : cdc_pulse_sync
// Language: SystemVerilog
//
// Description:
//   Pulse synchronizer for crossing a single-cycle pulse from the source
//   clock domain to the destination clock domain.
//
// CDC Principle (Toggle-Based Pulse Synchronization):
//   A single-cycle pulse may be shorter than one destination clock period and
//   could be invisible to a simple synchronizer. This module uses a three-step
//   toggle-based approach:
//
//   Step 1 – Pulse-to-Toggle (source domain):
//     A flip-flop toggles on each input pulse, converting the short pulse to
//     a persistent level change that cannot be missed by the synchronizer.
//
//   Step 2 – 2-Stage Synchronization:
//     The toggle signal is synchronized to the destination domain using a
//     standard 2-stage flip-flop chain, eliminating metastability.
//
//   Step 3 – Toggle-to-Pulse (destination domain):
//     An XOR of the current and previous synchronized toggle detects each
//     toggle edge and regenerates a single-cycle pulse in the destination domain.
//
// Safety:
//   - Safe because only a persistent toggle (not the original pulse) crosses
//     the clock boundary.
//   - Pulses must be separated by at least the round-trip synchronization
//     latency: approximately 4 destination clock cycles (2 sync + 1 edge
//     detect + 1 margin) to prevent pulse merging.
//
// Use Cases:
//   - Crossing a single-cycle strobe or trigger between clock domains
//   - Interrupt signals between clock domains
//   - Event notification across clock domain boundaries
//
// Limitations:
//   - Minimum inter-pulse spacing: ~4 destination clock cycles; pulses closer
//     together may be lost.
//   - 2–3 destination clock cycles of latency.
//   - Does not detect pulse loss (no overflow flag).
//
// Timing Assumptions:
//   - One pulse in = one pulse out, assuming minimum spacing is met.
//   - Does not preserve data associated with the pulse (use cdc_data_sync for
//     data transfer).
//
// Example Instantiation:
//   cdc_pulse_sync u_pulse_sync (
//       .clk_src   (clk_src),
//       .rst_src_n (rst_src_n),
//       .pulse_src (strobe_src),
//       .clk_dst   (clk_dst),
//       .rst_dst_n (rst_dst_n),
//       .pulse_dst (strobe_dst)
//   );
// =============================================================================

module cdc_pulse_sync (
    // Source domain
    input  logic clk_src,    // Source domain clock
    input  logic rst_src_n,  // Source domain reset (active low)
    input  logic pulse_src,  // Single-cycle input pulse in source domain

    // Destination domain
    input  logic clk_dst,    // Destination domain clock
    input  logic rst_dst_n,  // Destination domain reset (active low)
    output logic pulse_dst   // Single-cycle output pulse in destination domain
);

    // --------------------------------------------------------------------------
    // Step 1: Convert pulse to toggle in the source domain.
    // The toggle persists between pulses so it cannot be missed.
    // --------------------------------------------------------------------------
    logic toggle_src;

    always_ff @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n)
            toggle_src <= 1'b0;
        else if (pulse_src)
            toggle_src <= ~toggle_src;
    end

    // --------------------------------------------------------------------------
    // Step 2: 2-stage synchronizer to move toggle into destination domain.
    // --------------------------------------------------------------------------
    (* ASYNC_REG = "TRUE" *) logic [1:0] sync_ff;

    // --------------------------------------------------------------------------
    // Step 3: Edge detection to regenerate a single-cycle pulse.
    // --------------------------------------------------------------------------
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

    // Pulse output: high for exactly one destination clock cycle per event.
    assign pulse_dst = sync_ff[1] ^ toggle_dst_prev;

endmodule
