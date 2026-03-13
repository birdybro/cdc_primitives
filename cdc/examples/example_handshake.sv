// =============================================================================
// Example: cdc_handshake instantiation
// =============================================================================
// This example shows a 4-phase handshake between a 50 MHz "processor" domain
// that initiates DMA transfers and a 200 MHz "DMA engine" domain that executes
// them.
//
// The processor asserts dma_req and waits for dma_ack. The DMA engine sees the
// synchronized request, starts the DMA, and asserts its ack when done.
// =============================================================================

module example_handshake (
    // Processor domain (50 MHz)
    input  logic clk_cpu,
    input  logic rst_cpu_n,
    input  logic start_dma,     // CPU requests a DMA transfer
    output logic dma_done,      // High when DMA engine has acknowledged

    // DMA engine domain (200 MHz)
    input  logic clk_dma,
    input  logic rst_dma_n,
    output logic dma_req_dma,   // Synchronized DMA request in engine domain
    input  logic dma_ack_dma    // DMA engine asserts when transfer complete
);

    // Handshake signals
    logic cpu_req;   // Level-high while DMA is pending (CPU side)
    logic cpu_ack;   // Level-high when DMA engine has acknowledged

    // Simple state: set req when start_dma arrives, clear when ack is received.
    always_ff @(posedge clk_cpu or negedge rst_cpu_n) begin
        if (!rst_cpu_n)
            cpu_req <= 1'b0;
        else if (start_dma && !cpu_req)
            cpu_req <= 1'b1;          // Start new transfer
        else if (cpu_ack)
            cpu_req <= 1'b0;          // Transfer acknowledged; release request
    end

    assign dma_done = cpu_ack;

    // 4-phase handshake synchronizer
    cdc_handshake u_dma_hs (
        .clk_src   (clk_cpu),
        .rst_src_n (rst_cpu_n),
        .src_req_i (cpu_req),
        .src_ack_o (cpu_ack),
        .clk_dst   (clk_dma),
        .rst_dst_n (rst_dma_n),
        .dst_req_o (dma_req_dma),
        .dst_ack_i (dma_ack_dma)
    );

endmodule
