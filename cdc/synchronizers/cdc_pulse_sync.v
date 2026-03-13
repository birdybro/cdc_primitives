// =============================================================================
// Module  : cdc_pulse_sync
// Language: Verilog-2001
//
// Description:
//   Pulse synchronizer for crossing a single-cycle pulse from the source
//   clock domain to the destination clock domain.
//
// CDC Principle (Toggle-Based):
//   1. Source domain: Toggle FF on each input pulse (persistent level change).
//   2. 2-stage FF sync: Synchronize toggle to destination domain.
//   3. Destination domain: XOR edge detection regenerates single-cycle pulse.
//
// Safety:
//   - Safe: only persistent toggle crosses CDC boundary.
//   - Minimum inter-pulse spacing ~4 destination clock cycles.
//
// Use Cases:
//   - Crossing strobes, triggers, and interrupts between clock domains.
//
// Limitations:
//   - Pulses too close together may be lost.
//   - 2-3 cycle latency in destination domain.
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
    input  wire clk_src,    // Source domain clock
    input  wire rst_src_n,  // Source domain reset (active low)
    input  wire pulse_src,  // Single-cycle input pulse in source domain

    // Destination domain
    input  wire clk_dst,    // Destination domain clock
    input  wire rst_dst_n,  // Destination domain reset (active low)
    output wire pulse_dst   // Single-cycle output pulse in destination domain
);

    // Step 1: Pulse-to-toggle in source domain.
    reg toggle_src;

    always @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n)
            toggle_src <= 1'b0;
        else if (pulse_src)
            toggle_src <= ~toggle_src;
    end

    // Step 2: 2-stage synchronizer.
    (* ASYNC_REG = "TRUE" *) reg [1:0] sync_ff;

    // Step 3: Edge detection.
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

    assign pulse_dst = sync_ff[1] ^ toggle_dst_prev;

endmodule
