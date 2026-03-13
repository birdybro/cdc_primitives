// =============================================================================
// Example: cdc_data_sync instantiation
// =============================================================================
// This example transfers a 32-bit configuration register from a slow 50 MHz
// configuration bus domain to a fast 250 MHz processing core domain.
//
// The configuration data is written once per configuration update (low
// bandwidth). The bundled-data synchronizer ensures the entire 32-bit word
// is captured atomically in the destination domain.
//
// STA constraint required (add to constraints file):
//   set_max_delay -datapath_only -from [get_cells *u_cfg_sync/src_data_hold*] \
//                                -to   [get_cells *u_cfg_sync/dst_data_reg*]
// =============================================================================

module example_data_sync (
    // Configuration bus domain (50 MHz)
    input  logic        clk_cfg,
    input  logic        rst_cfg_n,
    input  logic [31:0] cfg_data,      // 32-bit config word
    input  logic        cfg_valid,     // Pulse when cfg_data is ready to send
    output logic        cfg_ready,     // High when module is idle / ready

    // Processing core domain (250 MHz)
    input  logic        clk_core,
    input  logic        rst_core_n,
    output logic [31:0] core_cfg_data, // Received config word
    output logic        core_cfg_valid // One-cycle pulse when new config arrives
);

    // Bundled-data CDC synchronizer
    // dst_ready_i is tied to 1 for auto-acknowledgement (core always accepts config)
    cdc_data_sync #(
        .DATA_WIDTH (32)
    ) u_cfg_sync (
        .clk_src     (clk_cfg),
        .rst_src_n   (rst_cfg_n),
        .src_data_i  (cfg_data),
        .src_valid_i (cfg_valid),
        .src_ready_o (cfg_ready),
        .clk_dst     (clk_core),
        .rst_dst_n   (rst_core_n),
        .dst_data_o  (core_cfg_data),
        .dst_valid_o (core_cfg_valid),
        .dst_ready_i (1'b1)            // Auto-acknowledge: core always accepts
    );

endmodule
