// =============================================================================
// Module  : cdc_sync2
// Language: Verilog-2001
//
// Description:
//   2-stage flip-flop synchronizer for single-bit clock domain crossing (CDC).
//
// CDC Principle:
//   Two flip-flops in series in the destination domain reduce metastability
//   probability exponentially. MTBF is typically sufficient for most designs.
//
// Safety:
//   - Safe ONLY for single-bit signals.
//   - Signal must be quasi-static between transitions, or use a
//     pulse/toggle synchronizer.
//   - Apply ASYNC_REG constraints in synthesis tools.
//
// Use Cases:
//   - Control/status bits, enable/valid flags crossing clock domains.
//   - Building block for pulse, toggle, and reset synchronizers.
//
// Limitations:
//   - 2-cycle latency in the destination domain.
//   - Not suitable for fast-changing or multi-bit signals.
//
// Example Instantiation:
//   cdc_sync2 #(.RESET_VAL(1'b0)) u_sync (
//       .clk_dst   (clk_dst),
//       .rst_dst_n (rst_dst_n),
//       .data_src  (flag_src),
//       .data_dst  (flag_dst)
//   );
// =============================================================================

module cdc_sync2 #(
    parameter RESET_VAL = 1'b0  // Reset value for synchronizer flip-flops
) (
    input  wire clk_dst,    // Destination domain clock
    input  wire rst_dst_n,  // Destination domain asynchronous reset (active low)
    input  wire data_src,   // Single-bit input from source clock domain
    output wire data_dst    // Single-bit output synchronized to destination domain
);

    // Two-stage synchronizer chain.
    // ASYNC_REG attribute prevents optimization across stages and guides
    // place-and-route to co-locate the FFs for minimum routing delay.
    (* ASYNC_REG = "TRUE" *) reg [1:0] sync_ff;

    always @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n)
            sync_ff <= {2{RESET_VAL}};
        else
            sync_ff <= {sync_ff[0], data_src};
    end

    assign data_dst = sync_ff[1];

endmodule
