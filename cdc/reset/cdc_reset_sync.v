// =============================================================================
// Module  : cdc_reset_sync
// Language: Verilog-2001
//
// Description:
//   Reset synchronizer with asynchronous assertion and synchronous deassertion.
//   Generates a clean, glitch-free reset in a target clock domain.
//
// CDC Principle (Async Assert / Sync Deassert):
//   Assertion:   rst_async_n low immediately drives all FFs low (async clear).
//   Deassertion: After rst_async_n goes high, SYNC_STAGES clean clock edges
//                are required before rst_sync_n is released, preventing
//                metastability on the reset deassertion edge.
//
// Safety:
//   - Async assert: no glitch, no dependency on clock.
//   - Sync deassert: eliminates metastability on reset release.
//
// Use Cases:
//   - Generating domain-local resets from a global asynchronous reset.
//   - Power-on reset distribution, post-PLL lock reset release.
//
// Limitations:
//   - Clock must be running during reset deassertion.
//   - SYNC_STAGES must be >= 2.
//
// Example Instantiation:
//   cdc_reset_sync #(.SYNC_STAGES(2)) u_rst_sync (
//       .clk         (clk),
//       .rst_async_n (por_rst_n),
//       .rst_sync_n  (local_rst_n)
//   );
// =============================================================================

module cdc_reset_sync #(
    parameter SYNC_STAGES = 2  // Number of synchronizer stages (>= 2)
) (
    input  wire clk,          // Target clock domain clock
    input  wire rst_async_n,  // Asynchronous reset input (active low)
    output wire rst_sync_n    // Synchronized reset output (active low)
);

    (* ASYNC_REG = "TRUE" *) reg [SYNC_STAGES-1:0] sync_chain;

    always @(posedge clk or negedge rst_async_n) begin
        if (!rst_async_n)
            sync_chain <= {SYNC_STAGES{1'b0}};
        else
            sync_chain <= {sync_chain[SYNC_STAGES-2:0], 1'b1};
    end

    assign rst_sync_n = sync_chain[SYNC_STAGES-1];

endmodule
