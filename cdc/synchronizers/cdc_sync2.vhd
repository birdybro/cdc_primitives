-- =============================================================================
-- Module  : cdc_sync2
-- Language: VHDL-2008
--
-- Description:
--   2-stage flip-flop synchronizer for single-bit clock domain crossing (CDC).
--
-- CDC Principle:
--   Two flip-flops in series in the destination domain reduce metastability
--   probability exponentially. MTBF is typically sufficient for most designs.
--
-- Safety:
--   - Safe ONLY for single-bit signals.
--   - Signal must be quasi-static between transitions, or use a
--     pulse/toggle synchronizer.
--   - Apply ASYNC_REG constraints in synthesis tools.
--
-- Use Cases:
--   - Control/status bits, enable/valid flags crossing clock domains.
--   - Building block for pulse, toggle, and reset synchronizers.
--
-- Limitations:
--   - 2-cycle latency in the destination domain.
--   - Not suitable for fast-changing or multi-bit signals.
--
-- Example Instantiation:
--   u_sync : entity work.cdc_sync2
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

entity cdc_sync2 is
    generic (
        RESET_VAL : std_logic := '0'  -- Reset value for synchronizer flip-flops
    );
    port (
        clk_dst   : in  std_logic;  -- Destination domain clock
        rst_dst_n : in  std_logic;  -- Destination domain asynchronous reset (active low)
        data_src  : in  std_logic;  -- Single-bit input from source clock domain
        data_dst  : out std_logic   -- Single-bit output synchronized to destination domain
    );
end entity cdc_sync2;

architecture rtl of cdc_sync2 is

    -- Two-stage synchronizer chain.
    -- ASYNC_REG attribute prevents optimization across stages and guides
    -- place-and-route to co-locate the FFs for minimum routing delay.
    signal sync_ff : std_logic_vector(1 downto 0) := (others => RESET_VAL);
    attribute ASYNC_REG : string;
    attribute ASYNC_REG of sync_ff : signal is "TRUE";

begin

    process(clk_dst, rst_dst_n)
    begin
        if rst_dst_n = '0' then
            sync_ff <= (others => RESET_VAL);
        elsif rising_edge(clk_dst) then
            sync_ff <= sync_ff(0) & data_src;
        end if;
    end process;

    data_dst <= sync_ff(1);

end architecture rtl;
