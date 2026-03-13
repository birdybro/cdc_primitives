-- =============================================================================
-- Module  : cdc_sync3
-- Language: VHDL-2008
--
-- Description:
--   3-stage flip-flop synchronizer for single-bit CDC. Provides higher MTBF
--   than the 2-stage synchronizer.
--
-- CDC Principle:
--   Same as cdc_sync2 but with a third flip-flop. Use at high frequencies
--   (>500 MHz) or in safety-critical applications.
--
-- Safety:
--   - Safe ONLY for single-bit signals.
--   - Apply ASYNC_REG constraints in synthesis tools.
--
-- Use Cases:
--   - High-frequency designs (>500 MHz)
--   - Safety-critical applications requiring very high MTBF
--
-- Limitations:
--   - 3-cycle latency in the destination domain.
--   - Not suitable for fast-changing or multi-bit signals.
--
-- Example Instantiation:
--   u_sync3 : entity work.cdc_sync3
--       generic map (RESET_VAL => '0')
--       port map (
--           clk_dst   => clk_dst,
--           rst_dst_n => rst_dst_n,
--           data_src  => flag_src,
--           data_dst  => flag_dst
--       );
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity cdc_sync3 is
    generic (
        RESET_VAL : std_logic := '0'  -- Reset value for synchronizer flip-flops
    );
    port (
        clk_dst   : in  std_logic;  -- Destination domain clock
        rst_dst_n : in  std_logic;  -- Destination domain asynchronous reset (active low)
        data_src  : in  std_logic;  -- Single-bit input from source clock domain
        data_dst  : out std_logic   -- Single-bit output synchronized to destination domain
    );
end entity cdc_sync3;

architecture rtl of cdc_sync3 is

    signal sync_ff : std_logic_vector(2 downto 0) := (others => RESET_VAL);
    attribute ASYNC_REG : string;
    attribute ASYNC_REG of sync_ff : signal is "TRUE";

begin

    process(clk_dst, rst_dst_n)
    begin
        if rst_dst_n = '0' then
            sync_ff <= (others => RESET_VAL);
        elsif rising_edge(clk_dst) then
            sync_ff <= sync_ff(1 downto 0) & data_src;
        end if;
    end process;

    data_dst <= sync_ff(2);

end architecture rtl;
