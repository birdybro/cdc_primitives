// =============================================================================
// Module  : cdc_handshake
// Language: Verilog-2001
//
// Description:
//   4-phase request/acknowledge handshake synchronizer for CDC.
//   REQ and ACK each cross the clock boundary through 2-stage synchronizers.
//
// CDC Principle (4-Phase):
//   Phase 1: src asserts req. REQ synchronizes to dst.
//   Phase 2: dst detects req, processes, asserts ack. ACK synchronizes to src.
//   Phase 3: src detects ack, deasserts req.
//   Phase 4: dst detects req low, deasserts ack.
//
// Safety:
//   - Safe: only single-bit REQ and ACK cross the boundary via 2FF syncs.
//
// Use Cases:
//   - Low-bandwidth control signaling between clock domains.
//   - Handshake for bundled-data transfers (cdc_data_sync).
//
// Limitations:
//   - Low throughput (~4x round-trip latency per transaction).
//
// Example Instantiation:
//   cdc_handshake u_hs (
//       .clk_src   (clk_src),   .rst_src_n (rst_src_n),
//       .src_req_i (my_req),    .src_ack_o (my_ack),
//       .clk_dst   (clk_dst),   .rst_dst_n (rst_dst_n),
//       .dst_req_o (dst_req),   .dst_ack_i (dst_ack)
//   );
// =============================================================================

module cdc_handshake (
    // Source domain
    input  wire clk_src,    // Source domain clock
    input  wire rst_src_n,  // Source domain reset (active low)
    input  wire src_req_i,  // Request from source (hold high for one transaction)
    output wire src_ack_o,  // Acknowledge to source

    // Destination domain
    input  wire clk_dst,    // Destination domain clock
    input  wire rst_dst_n,  // Destination domain reset (active low)
    output wire dst_req_o,  // Synchronized request in destination domain
    input  wire dst_ack_i   // Acknowledge from destination logic
);

    // Synchronize REQ to destination domain
    (* ASYNC_REG = "TRUE" *) reg [1:0] req_sync;

    always @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n)
            req_sync <= 2'b00;
        else
            req_sync <= {req_sync[0], src_req_i};
    end

    assign dst_req_o = req_sync[1];

    // Synchronize ACK back to source domain
    (* ASYNC_REG = "TRUE" *) reg [1:0] ack_sync;

    always @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n)
            ack_sync <= 2'b00;
        else
            ack_sync <= {ack_sync[0], dst_ack_i};
    end

    assign src_ack_o = ack_sync[1];

endmodule
