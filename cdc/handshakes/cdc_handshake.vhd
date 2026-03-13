-- =============================================================================
-- Module  : cdc_handshake
-- Language: VHDL-2008
--
-- Description:
--   4-phase request/acknowledge handshake synchronizer for CDC.
--   REQ and ACK each cross the clock boundary through 2-stage synchronizers.
--
-- CDC Principle (4-Phase):
--   Phase 1: src asserts req. REQ synchronizes to dst.
--   Phase 2: dst detects req, processes, asserts ack. ACK synchronizes to src.
--   Phase 3: src detects ack, deasserts req.
--   Phase 4: dst detects req low, deasserts ack.
--
-- Safety:
--   - Safe: only single-bit REQ and ACK cross the boundary via 2FF syncs.
--
-- Use Cases:
--   - Low-bandwidth control signaling between clock domains.
--   - Handshake for bundled-data transfers (cdc_data_sync).
--
-- Limitations:
--   - Low throughput (~4x round-trip latency per transaction).
--
-- Example Instantiation:
--   u_hs : entity work.cdc_handshake
--       port map (
--           clk_src   => clk_src,   rst_src_n => rst_src_n,
--           src_req_i => my_req,    src_ack_o => my_ack,
--           clk_dst   => clk_dst,   rst_dst_n => rst_dst_n,
--           dst_req_o => dst_req,   dst_ack_i => dst_ack
--       );
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity cdc_handshake is
    port (
        -- Source domain
        clk_src   : in  std_logic;  -- Source domain clock
        rst_src_n : in  std_logic;  -- Source domain reset (active low)
        src_req_i : in  std_logic;  -- Request from source (hold high for one transaction)
        src_ack_o : out std_logic;  -- Acknowledge to source
        -- Destination domain
        clk_dst   : in  std_logic;  -- Destination domain clock
        rst_dst_n : in  std_logic;  -- Destination domain reset (active low)
        dst_req_o : out std_logic;  -- Synchronized request in destination domain
        dst_ack_i : in  std_logic   -- Acknowledge from destination logic
    );
end entity cdc_handshake;

architecture rtl of cdc_handshake is

    signal req_sync : std_logic_vector(1 downto 0) := "00";
    signal ack_sync : std_logic_vector(1 downto 0) := "00";

    attribute ASYNC_REG : string;
    attribute ASYNC_REG of req_sync : signal is "TRUE";
    attribute ASYNC_REG of ack_sync : signal is "TRUE";

begin

    -- Synchronize REQ to destination domain
    process(clk_dst, rst_dst_n)
    begin
        if rst_dst_n = '0' then
            req_sync <= "00";
        elsif rising_edge(clk_dst) then
            req_sync <= req_sync(0) & src_req_i;
        end if;
    end process;

    dst_req_o <= req_sync(1);

    -- Synchronize ACK back to source domain
    process(clk_src, rst_src_n)
    begin
        if rst_src_n = '0' then
            ack_sync <= "00";
        elsif rising_edge(clk_src) then
            ack_sync <= ack_sync(0) & dst_ack_i;
        end if;
    end process;

    src_ack_o <= ack_sync(1);

end architecture rtl;
