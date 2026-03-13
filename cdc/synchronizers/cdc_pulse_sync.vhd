-- =============================================================================
-- Module  : cdc_pulse_sync
-- Language: VHDL-2008
--
-- Description:
--   Pulse synchronizer for crossing a single-cycle pulse from the source
--   clock domain to the destination clock domain.
--
-- CDC Principle (Toggle-Based):
--   1. Source domain: Toggle FF on each input pulse (persistent level change).
--   2. 2-stage FF sync: Synchronize toggle to destination domain.
--   3. Destination domain: XOR edge detection regenerates single-cycle pulse.
--
-- Safety:
--   - Safe: only persistent toggle crosses CDC boundary.
--   - Minimum inter-pulse spacing ~4 destination clock cycles.
--
-- Use Cases:
--   - Crossing strobes, triggers, and interrupts between clock domains.
--
-- Limitations:
--   - Pulses too close together may be lost.
--   - 2-3 cycle latency in destination domain.
--
-- Example Instantiation:
--   u_pulse_sync : entity work.cdc_pulse_sync
--       port map (
--           clk_src   => clk_src,
--           rst_src_n => rst_src_n,
--           pulse_src => strobe_src,
--           clk_dst   => clk_dst,
--           rst_dst_n => rst_dst_n,
--           pulse_dst => strobe_dst
--       );
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity cdc_pulse_sync is
    port (
        -- Source domain
        clk_src   : in  std_logic;  -- Source domain clock
        rst_src_n : in  std_logic;  -- Source domain reset (active low)
        pulse_src : in  std_logic;  -- Single-cycle input pulse in source domain
        -- Destination domain
        clk_dst   : in  std_logic;  -- Destination domain clock
        rst_dst_n : in  std_logic;  -- Destination domain reset (active low)
        pulse_dst : out std_logic   -- Single-cycle output pulse in destination domain
    );
end entity cdc_pulse_sync;

architecture rtl of cdc_pulse_sync is

    -- Step 1: Toggle in source domain
    signal toggle_src : std_logic := '0';

    -- Step 2: 2-stage synchronizer in destination domain
    signal sync_ff : std_logic_vector(1 downto 0) := "00";
    attribute ASYNC_REG : string;
    attribute ASYNC_REG of sync_ff : signal is "TRUE";

    -- Step 3: Previous value for edge detection
    signal toggle_dst_prev : std_logic := '0';

begin

    -- Step 1: Convert pulse to toggle
    process(clk_src, rst_src_n)
    begin
        if rst_src_n = '0' then
            toggle_src <= '0';
        elsif rising_edge(clk_src) then
            if pulse_src = '1' then
                toggle_src <= not toggle_src;
            end if;
        end if;
    end process;

    -- Steps 2 & 3: Synchronize and edge-detect
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

    pulse_dst <= sync_ff(1) xor toggle_dst_prev;

end architecture rtl;
