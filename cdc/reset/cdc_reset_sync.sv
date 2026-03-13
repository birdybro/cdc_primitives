// =============================================================================
// Module  : cdc_reset_sync
// Language: SystemVerilog
//
// Description:
//   Reset synchronizer with asynchronous assertion and synchronous deassertion.
//   Generates a clean, glitch-free reset in a target clock domain from an
//   asynchronous reset source.
//
// CDC Principle (Async Assert / Sync Deassert):
//   This is a well-established technique for distributing resets across clock
//   domains safely:
//
//   Assertion (immediate):
//     When rst_async_n goes low, the output rst_sync_n is immediately driven
//     low (asynchronous), ensuring that all downstream flip-flops enter reset
//     without waiting for a clock edge. This prevents "reset race" conditions.
//
//   Deassertion (synchronized):
//     When rst_async_n goes high, the release is NOT immediate. Instead, it
//     must propagate through a chain of SYNC_STAGES flip-flops clocked by
//     clk. All flip-flops in the chain are preset to '1' asynchronously and
//     only release rst_sync_n after SYNC_STAGES clean clock edges, ensuring
//     the local reset deasserts synchronously with clk. This prevents
//     metastability on the reset release edge.
//
// Safety:
//   - Async assert ensures no combinatorial reset propagation delay.
//   - Sync deassert eliminates metastability when reset is released.
//   - All flip-flops driven by rst_sync_n will exit reset at the same clock edge.
//
// Use Cases:
//   - Generating domain-local resets from a global asynchronous reset source
//   - Power-on reset distribution to multiple clock domains
//   - Generating reset for logic after a PLL lock signal
//
// Limitations:
//   - Clock must be running during reset deassertion for synchronous release.
//   - SYNC_STAGES >= 2 is required (default 2).
//   - The metastability window is very small for the assertion path (since the
//     reset release goes through synchronizer FFs), but assertion itself is
//     asynchronous and purely combinatorial.
//
// Timing Assumptions:
//   - rst_async_n is assumed to meet hold/recovery time on the clock edge it
//     is released on. If not, the SYNC_STAGES chain provides sufficient
//     resolution time.
//
// Example Instantiation:
//   cdc_reset_sync #(.SYNC_STAGES(2)) u_rst_sync (
//       .clk         (clk),
//       .rst_async_n (por_rst_n),
//       .rst_sync_n  (local_rst_n)
//   );
// =============================================================================

module cdc_reset_sync #(
    parameter int SYNC_STAGES = 2  // Number of synchronizer stages (>= 2)
) (
    input  logic clk,          // Target clock domain clock
    input  logic rst_async_n,  // Asynchronous reset input (active low)
    output logic rst_sync_n    // Synchronized reset output (active low)
);

    // Synchronizer chain: all FFs are asynchronously cleared and preset to 1.
    // When rst_async_n goes low:  entire chain goes to 0 (async clear).
    // When rst_async_n goes high: chain shifts in 1s from the LSB.
    (* ASYNC_REG = "TRUE" *) logic [SYNC_STAGES-1:0] sync_chain;

    always_ff @(posedge clk or negedge rst_async_n) begin
        if (!rst_async_n)
            // Asynchronous assertion: immediately drive all stages to 0
            sync_chain <= '0;
        else
            // Synchronous deassertion: shift a 1 from LSB toward MSB
            sync_chain <= {sync_chain[SYNC_STAGES-2:0], 1'b1};
    end

    // Reset output is active until the chain is fully loaded with 1s
    assign rst_sync_n = sync_chain[SYNC_STAGES-1];

endmodule
