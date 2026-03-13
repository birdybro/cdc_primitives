-- =============================================================================
-- Module  : cdc_reset_sync
-- Language: VHDL-2008
--
-- Description:
--   Reset synchronizer with asynchronous assertion and synchronous deassertion.
--   Generates a clean, glitch-free reset in a target clock domain.
--
-- CDC Principle (Async Assert / Sync Deassert):
--   Assertion:   rst_async_n = '0' immediately clears all FFs (async).
--   Deassertion: After rst_async_n = '1', SYNC_STAGES clean clock edges
--                are required before rst_sync_n is released, preventing
--                metastability on the reset release edge.
--
-- Safety:
--   - Async assert ensures immediate reset propagation.
--   - Sync deassert eliminates metastability on reset release.
--
-- Use Cases:
--   - Domain-local reset generation from global asynchronous reset.
--   - Post-PLL lock reset release.
--
-- Limitations:
--   - Clock must be running during reset deassertion.
--   - SYNC_STAGES must be >= 2.
--
-- Example Instantiation:
--   u_rst_sync : entity work.cdc_reset_sync
--       generic map (SYNC_STAGES => 2)
--       port map (
--           clk         => clk,
--           rst_async_n => por_rst_n,
--           rst_sync_n  => local_rst_n
--       );
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity cdc_reset_sync is
    generic (
        SYNC_STAGES : positive := 2  -- Number of synchronizer stages (>= 2)
    );
    port (
        clk         : in  std_logic;  -- Target clock domain clock
        rst_async_n : in  std_logic;  -- Asynchronous reset input (active low)
        rst_sync_n  : out std_logic   -- Synchronized reset output (active low)
    );
end entity cdc_reset_sync;

architecture rtl of cdc_reset_sync is

    signal sync_chain : std_logic_vector(SYNC_STAGES-1 downto 0) := (others => '0');
    attribute ASYNC_REG : string;
    attribute ASYNC_REG of sync_chain : signal is "TRUE";

begin

    process(clk, rst_async_n)
    begin
        if rst_async_n = '0' then
            -- Asynchronous assertion: immediately drive all stages to 0
            sync_chain <= (others => '0');
        elsif rising_edge(clk) then
            -- Synchronous deassertion: shift a '1' from LSB toward MSB
            sync_chain <= sync_chain(SYNC_STAGES-2 downto 0) & '1';
        end if;
    end process;

    rst_sync_n <= sync_chain(SYNC_STAGES-1);

end architecture rtl;
