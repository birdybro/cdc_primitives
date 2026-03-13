// =============================================================================
// Module  : cdc_data_sync
// Language: SystemVerilog
//
// Description:
//   Bundled-data synchronizer. Safely transfers multi-bit data from the source
//   clock domain to the destination clock domain using a 4-phase req/ack
//   handshake to qualify the data crossing.
//
// CDC Principle (Bundled Data):
//   Multi-bit signals cannot be directly synchronized with a simple FF chain
//   because multiple bits may change simultaneously, leading to corrupted
//   capture if any bit is in transition. This module solves this by:
//
//   1. Source presents stable data and asserts src_valid_i. The data is latched
//      into an internal hold register, and an internal REQ signal is raised.
//   2. REQ is synchronized to the destination domain (2 dst_clk stages).
//   3. Destination detects the rising edge of the synchronized REQ and captures
//      the data from the hold register. Because REQ has been through 2 FF
//      stages, the data has been stable for at least 2 destination clock cycles,
//      ensuring no ongoing metastability on the data bus.
//   4. Destination pulses dst_valid_o for one cycle and asserts dst_ack_i when
//      ready. ACK is synchronized back to the source domain (2 src_clk stages).
//   5. Source sees src_ready_o go high, releases the hold, and the cycle ends.
//
// Safety:
//   - Data is NOT synchronized through flip-flop chains; only the REQ/ACK
//     single-bit signals cross the boundary through synchronizers.
//   - Data must be held stable from src_valid_i assertion until src_ready_o.
//   - The data path (src_data_hold → dst_data_o capture) should be constrained
//     with 'set_max_delay -datapath_only' in the synthesis/STA tool to prevent
//     false timing violations on the intentional CDC multi-cycle path.
//
// Use Cases:
//   - Configuration register updates across clock domains
//   - Low-bandwidth multi-bit status/control word transfers
//   - Any scenario where data must be reliably moved once per handshake
//
// Limitations:
//   - Low throughput: one transfer per ~4–8 round-trip cycles.
//   - Data must remain stable throughout the handshake.
//   - Not suitable for streaming data (use cdc_async_fifo for high bandwidth).
//
// Timing Assumptions:
//   - src_data_i must be stable while src_valid_i is high (until src_ready_o).
//   - Add 'set_max_delay -datapath_only' constraints on the data bus
//     from src_data_hold[] to the dst_data_o capture register.
//
// Example Instantiation:
//   cdc_data_sync #(.DATA_WIDTH(16)) u_data_sync (
//       .clk_src     (clk_src),    .rst_src_n  (rst_src_n),
//       .src_data_i  (my_data),    .src_valid_i(data_valid),
//       .src_ready_o (src_ready),
//       .clk_dst     (clk_dst),    .rst_dst_n  (rst_dst_n),
//       .dst_data_o  (dst_data),   .dst_valid_o(dst_valid),
//       .dst_ready_i (dst_ready)
//   );
// =============================================================================

module cdc_data_sync #(
    parameter int DATA_WIDTH = 8  // Width of the data bus
) (
    // Source clock domain
    input  logic                  clk_src,      // Source clock
    input  logic                  rst_src_n,    // Source reset (active low)
    input  logic [DATA_WIDTH-1:0] src_data_i,   // Data to transfer (hold stable while src_valid_i)
    input  logic                  src_valid_i,  // Strobe to initiate transfer (1 = new data ready)
    output logic                  src_ready_o,  // High when module is idle and can accept a transfer

    // Destination clock domain
    input  logic                  clk_dst,      // Destination clock
    input  logic                  rst_dst_n,    // Destination reset (active low)
    output logic [DATA_WIDTH-1:0] dst_data_o,   // Captured data in destination domain
    output logic                  dst_valid_o,  // One-cycle pulse: new data is available
    input  logic                  dst_ready_i   // Destination ready to accept (tie to 1 for auto-ack)
);

    // --------------------------------------------------------------------------
    // Source domain
    // --------------------------------------------------------------------------

    // Internal REQ flag: set on valid+ready, cleared when ACK arrives.
    logic src_req;

    // Hold register: latches src_data_i when a transfer begins and holds it
    // stable for the entire handshake, satisfying the bundled-data contract.
    logic [DATA_WIDTH-1:0] src_data_hold;

    // ACK synchronizer (destination → source, 2-stage)
    (* ASYNC_REG = "TRUE" *) logic [1:0] ack_sync;

    always_ff @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n) begin
            src_req       <= 1'b0;
            src_data_hold <= '0;
            ack_sync      <= 2'b00;
        end else begin
            // Synchronize ACK into source domain
            ack_sync <= {ack_sync[0], dst_ack};

            if (src_valid_i && src_ready_o) begin
                // Latch data and assert REQ to start handshake
                src_data_hold <= src_data_i;
                src_req       <= 1'b1;
            end else if (ack_sync[1]) begin
                // ACK received from destination: deassert REQ
                src_req <= 1'b0;
            end
        end
    end

    // Module is ready when no transfer is in progress
    assign src_ready_o = ~src_req;

    // --------------------------------------------------------------------------
    // Destination domain
    // --------------------------------------------------------------------------

    // REQ synchronizer (source → destination, 2-stage)
    (* ASYNC_REG = "TRUE" *) logic [1:0] req_sync;

    logic req_prev;   // Previous cycle's synchronized REQ (for edge detection)
    logic dst_ack;    // Internal ACK level (feeds into ack_sync in source domain)

    always_ff @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            req_sync   <= 2'b00;
            req_prev   <= 1'b0;
            dst_data_o <= '0;
            dst_valid_o <= 1'b0;
            dst_ack    <= 1'b0;
        end else begin
            // Synchronize REQ into destination domain
            req_sync <= {req_sync[0], src_req};
            req_prev <= req_sync[1];

            // On the rising edge of synchronized REQ, capture data AND assert
            // valid in the same clock cycle so they are always synchronous.
            // src_data_hold has been stable for >= 2 dst_clk cycles by now,
            // so the capture is safe from the CDC perspective.
            if (req_sync[1] && !req_prev) begin
                dst_data_o  <= src_data_hold;  // CDC data path: constrain with set_max_delay
                dst_valid_o <= 1'b1;
            end else begin
                dst_valid_o <= 1'b0;
            end

            // Assert ACK once REQ is seen and destination is ready.
            // Hold ACK until REQ falls (completing the 4-phase cycle).
            if (req_sync[1] && dst_ready_i)
                dst_ack <= 1'b1;
            else if (!req_sync[1])
                dst_ack <= 1'b0;
        end
    end

endmodule
