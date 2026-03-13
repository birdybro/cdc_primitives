// =============================================================================
// Module  : cdc_sync3
// Language: Verilog-2001
//
// Description:
//   3-stage flip-flop synchronizer for single-bit CDC. Provides higher MTBF
//   than the 2-stage synchronizer.
//
// CDC Principle:
//   Same as cdc_sync2 but with a third flip-flop. Use at high frequencies
//   (>500 MHz) or in safety-critical applications.
//
// Safety:
//   - Safe ONLY for single-bit signals.
//   - Apply ASYNC_REG constraints in synthesis tools.
//
// Use Cases:
//   - High-frequency designs (>500 MHz)
//   - Safety-critical applications requiring very high MTBF
//
// Limitations:
//   - 3-cycle latency in the destination domain.
//   - Not suitable for fast-changing or multi-bit signals.
//
// Example Instantiation:
//   cdc_sync3 #(.RESET_VAL(1'b0)) u_sync3 (
//       .clk_dst   (clk_dst),
//       .rst_dst_n (rst_dst_n),
//       .data_src  (flag_src),
//       .data_dst  (flag_dst)
//   );
// =============================================================================

module cdc_sync3 #(
    parameter RESET_VAL = 1'b0  // Reset value for synchronizer flip-flops
) (
    input  wire clk_dst,    // Destination domain clock
    input  wire rst_dst_n,  // Destination domain asynchronous reset (active low)
    input  wire data_src,   // Single-bit input from source clock domain
    output wire data_dst    // Single-bit output synchronized to destination domain
);

    // Three-stage synchronizer chain.
    (* ASYNC_REG = "TRUE" *) reg [2:0] sync_ff;

    always @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n)
            sync_ff <= {3{RESET_VAL}};
        else
            sync_ff <= {sync_ff[1:0], data_src};
    end

    assign data_dst = sync_ff[2];

endmodule
