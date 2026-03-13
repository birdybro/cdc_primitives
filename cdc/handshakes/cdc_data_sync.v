// =============================================================================
// Module  : cdc_data_sync
// Language: Verilog-2001
//
// Description:
//   Bundled-data synchronizer. Safely transfers multi-bit data across clock
//   domains using a 4-phase req/ack handshake to qualify the data crossing.
//
// CDC Principle (Bundled Data):
//   Only single-bit REQ/ACK signals cross the boundary via 2FF synchronizers.
//   Data is held stable in a hold register from REQ assertion until ACK receipt.
//   Destination captures data when it sees the rising edge of synchronized REQ.
//   By then data has been stable >= 2 destination clock cycles (safe capture).
//
// Safety:
//   - Data path (src_data_hold -> dst_data_o) must be constrained with
//     'set_max_delay -datapath_only' in the synthesis/STA tool.
//   - src_data_i must remain stable while src_valid_i is high.
//
// Use Cases:
//   - Configuration register updates, status word transfers.
//
// Limitations:
//   - Low throughput (~4-8 round-trip cycles per transfer).
//   - Not for streaming data; use cdc_async_fifo instead.
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
    parameter DATA_WIDTH = 8  // Width of the data bus
) (
    // Source clock domain
    input  wire                  clk_src,      // Source clock
    input  wire                  rst_src_n,    // Source reset (active low)
    input  wire [DATA_WIDTH-1:0] src_data_i,   // Data to transfer (hold stable while src_valid_i)
    input  wire                  src_valid_i,  // Strobe to initiate transfer
    output wire                  src_ready_o,  // High when module is idle

    // Destination clock domain
    input  wire                  clk_dst,      // Destination clock
    input  wire                  rst_dst_n,    // Destination reset (active low)
    output reg  [DATA_WIDTH-1:0] dst_data_o,   // Captured data
    output reg                   dst_valid_o,  // One-cycle pulse: new data available
    input  wire                  dst_ready_i   // Destination ready (tie to 1 for auto-ack)
);

    // --------------------------------------------------------------------------
    // Source domain
    // --------------------------------------------------------------------------
    reg                  src_req;
    reg [DATA_WIDTH-1:0] src_data_hold;

    (* ASYNC_REG = "TRUE" *) reg [1:0] ack_sync;

    always @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n) begin
            src_req       <= 1'b0;
            src_data_hold <= {DATA_WIDTH{1'b0}};
            ack_sync      <= 2'b00;
        end else begin
            ack_sync <= {ack_sync[0], dst_ack};

            if (src_valid_i && src_ready_o) begin
                src_data_hold <= src_data_i;
                src_req       <= 1'b1;
            end else if (ack_sync[1]) begin
                src_req <= 1'b0;
            end
        end
    end

    assign src_ready_o = ~src_req;

    // --------------------------------------------------------------------------
    // Destination domain
    // --------------------------------------------------------------------------
    (* ASYNC_REG = "TRUE" *) reg [1:0] req_sync;

    reg req_prev;
    reg dst_ack;

    always @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            req_sync   <= 2'b00;
            req_prev   <= 1'b0;
            dst_data_o <= {DATA_WIDTH{1'b0}};
            dst_valid_o <= 1'b0;
            dst_ack    <= 1'b0;
        end else begin
            req_sync <= {req_sync[0], src_req};
            req_prev <= req_sync[1];

            // Capture data and assert valid on the rising edge of synchronized REQ.
            // Both signals update in the same clock cycle so they are always synchronous.
            if (req_sync[1] && !req_prev) begin
                dst_data_o  <= src_data_hold;  // CDC data path: constrain with set_max_delay
                dst_valid_o <= 1'b1;
            end else begin
                dst_valid_o <= 1'b0;
            end

            if (req_sync[1] && dst_ready_i)
                dst_ack <= 1'b1;
            else if (!req_sync[1])
                dst_ack <= 1'b0;
        end
    end

endmodule
