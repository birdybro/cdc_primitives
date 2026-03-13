-- =============================================================================
-- Module  : cdc_toggle_sync
-- Language: VHDL-2008
--
-- Description:
--   Toggle-event synchronizer. Synchronizes a toggle signal from the source
--   clock domain to the destination domain and generates a single-cycle pulse
--   on each toggle edge.
--
-- CDC Principle:
--   The toggle signal is persistent and synchronized with a 2-stage FF chain.
--   Edge detection generates a single-cycle output pulse per toggle event.
--
-- Safety:
--   - Safe for CDC: toggle is persistent, 2FF handles metastability.
--   - Events must be >= 3 destination clock cycles apart.
--
-- Use Cases:
--   - Infrequent event signaling across clock domains.
--   - Building block for cdc_pulse_sync.
--
-- Limitations:
--   - Consecutive events must be >= 3 destination clock cycles apart.
--
-- Example Instantiation:
--   u_tog_sync : entity work.cdc_toggle_sync
--       port map (
--           clk_dst    => clk_dst,
--           rst_dst_n  => rst_dst_n,
--           toggle_src => my_toggle,
--           toggle_dst => toggle_synced,
--           pulse_dst  => event_pulse
--       );
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity cdc_toggle_sync is
    port (
        -- Destination domain
        clk_dst    : in  std_logic;  -- Destination domain clock
        rst_dst_n  : in  std_logic;  -- Destination domain reset (active low)
        -- Cross-domain input
        toggle_src : in  std_logic;  -- Toggle signal from source clock domain
        -- Destination domain outputs
        toggle_dst : out std_logic;  -- Synchronized toggle in destination domain
        pulse_dst  : out std_logic   -- One-cycle pulse on each toggle transition
    );
end entity cdc_toggle_sync;

architecture rtl of cdc_toggle_sync is

    signal sync_ff         : std_logic_vector(1 downto 0) := "00";
    signal toggle_dst_prev : std_logic := '0';

    attribute ASYNC_REG : string;
    attribute ASYNC_REG of sync_ff : signal is "TRUE";

begin

    process(clk_dst, rst_dst_n)
    begin
        if rst_dst_n = '0' then
            sync_ff         <= "00";
            toggle_dst_prev <= '0';
        elsif rising_edge(clk_dst) then
            sync_ff         <= sync_ff(0) & toggle_src;
            toggle_dst_prev <= sync_ff(1);
        end if;
    end process;

    toggle_dst <= sync_ff(1);
    pulse_dst  <= sync_ff(1) xor toggle_dst_prev;

end architecture rtl;
