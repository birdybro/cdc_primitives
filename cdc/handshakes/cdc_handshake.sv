// =============================================================================
// Module  : cdc_handshake
// Language: SystemVerilog
//
// Description:
//   4-phase request/acknowledge handshake synchronizer for CDC.
//   Provides a reliable mechanism to signal a single event or transfer
//   completion across two asynchronous clock domains.
//
// CDC Principle (4-Phase Handshake):
//   Only single-bit REQ and ACK signals cross the clock boundary, each
//   protected by a 2-stage synchronizer:
//
//   Phase 1: Source asserts src_req_i (level high). REQ synchronizes to dst.
//   Phase 2: Destination detects dst_req_o high, processes, asserts dst_ack_i.
//            ACK synchronizes back to source.
//   Phase 3: Source detects src_ack_o high. Source deasserts src_req_i.
//   Phase 4: Destination detects dst_req_o low, deasserts dst_ack_i.
//   The cycle then repeats for the next transaction.
//
// Safety:
//   - Safe: only single-bit REQ and ACK cross the boundary via 2FF synchronizers.
//   - The 4-phase protocol ensures both sides complete their phases before
//     proceeding, preventing data loss or corruption.
//
// Use Cases:
//   - Low-bandwidth control signaling between clock domains
//   - Handshake for bundled-data transfer (see cdc_data_sync)
//   - Any scenario requiring a confirmed cross-domain event
//
// Limitations:
//   - Low throughput: one transaction per ~4× (worst-case domain latency) cycles.
//   - Not suitable for high-bandwidth transfers (use cdc_async_fifo instead).
//
// Port Protocol:
//   src_req_i: Assert and hold high for the duration of one transaction.
//              Deassert only after src_ack_o goes high.
//   src_ack_o: Goes high when destination has acknowledged. Deassert src_req_i.
//   dst_req_o: Goes high in destination domain when request is active.
//   dst_ack_i: Destination asserts high when processing is done. Hold high
//              until dst_req_o goes low, then deassert.
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
    input  logic clk_src,    // Source domain clock
    input  logic rst_src_n,  // Source domain reset (active low)
    input  logic src_req_i,  // Request from source (hold high for one transaction)
    output logic src_ack_o,  // Acknowledge to source (deassert req when high)

    // Destination domain
    input  logic clk_dst,    // Destination domain clock
    input  logic rst_dst_n,  // Destination domain reset (active low)
    output logic dst_req_o,  // Synchronized request in destination domain
    input  logic dst_ack_i   // Acknowledge from destination logic
);

    // --------------------------------------------------------------------------
    // Synchronize REQ from source domain to destination domain (2-stage)
    // --------------------------------------------------------------------------
    (* ASYNC_REG = "TRUE" *) logic [1:0] req_sync;

    always_ff @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n)
            req_sync <= 2'b00;
        else
            req_sync <= {req_sync[0], src_req_i};
    end

    assign dst_req_o = req_sync[1];

    // --------------------------------------------------------------------------
    // Synchronize ACK from destination domain back to source domain (2-stage)
    // --------------------------------------------------------------------------
    (* ASYNC_REG = "TRUE" *) logic [1:0] ack_sync;

    always_ff @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n)
            ack_sync <= 2'b00;
        else
            ack_sync <= {ack_sync[0], dst_ack_i};
    end

    assign src_ack_o = ack_sync[1];

endmodule
