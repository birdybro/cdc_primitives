-- =============================================================================
-- Module  : cdc_data_sync
-- Language: VHDL-2008
--
-- Description:
--   Bundled-data synchronizer. Safely transfers multi-bit data across clock
--   domains using a 4-phase req/ack handshake to qualify the data crossing.
--
-- CDC Principle (Bundled Data):
--   Only single-bit REQ/ACK signals cross the boundary via 2FF synchronizers.
--   Data is held stable in a hold register; destination captures when
--   synchronized REQ rises. Data stable >= 2 dst clk cycles at capture time.
--
-- Safety:
--   - Data path must be constrained with 'set_max_delay -datapath_only'.
--   - src_data_i must remain stable while src_valid_i is high.
--
-- Use Cases:
--   - Configuration register updates, status word transfers.
--
-- Limitations:
--   - Low throughput (~4-8 round-trip cycles per transfer).
--
-- Example Instantiation:
--   u_data_sync : entity work.cdc_data_sync
--       generic map (DATA_WIDTH => 16)
--       port map (
--           clk_src     => clk_src,    rst_src_n  => rst_src_n,
--           src_data_i  => my_data,    src_valid_i => data_valid,
--           src_ready_o => src_ready,
--           clk_dst     => clk_dst,    rst_dst_n  => rst_dst_n,
--           dst_data_o  => dst_data,   dst_valid_o => dst_valid,
--           dst_ready_i => dst_ready
--       );
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity cdc_data_sync is
    generic (
        DATA_WIDTH : positive := 8  -- Width of the data bus
    );
    port (
        -- Source clock domain
        clk_src     : in  std_logic;                                    -- Source clock
        rst_src_n   : in  std_logic;                                    -- Source reset (active low)
        src_data_i  : in  std_logic_vector(DATA_WIDTH-1 downto 0);     -- Data to transfer
        src_valid_i : in  std_logic;                                    -- Initiate transfer
        src_ready_o : out std_logic;                                    -- Module idle / ready
        -- Destination clock domain
        clk_dst     : in  std_logic;                                    -- Destination clock
        rst_dst_n   : in  std_logic;                                    -- Destination reset (active low)
        dst_data_o  : out std_logic_vector(DATA_WIDTH-1 downto 0);     -- Captured data
        dst_valid_o : out std_logic;                                    -- One-cycle valid pulse
        dst_ready_i : in  std_logic                                     -- Destination ready (tie '1' for auto-ack)
    );
end entity cdc_data_sync;

architecture rtl of cdc_data_sync is

    -- Source domain
    signal src_req       : std_logic := '0';
    signal src_data_hold : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal ack_sync      : std_logic_vector(1 downto 0) := "00";

    -- Destination domain
    signal req_sync      : std_logic_vector(1 downto 0) := "00";
    signal req_prev      : std_logic := '0';
    signal dst_ack       : std_logic := '0';
    signal dst_data_reg  : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

    attribute ASYNC_REG : string;
    attribute ASYNC_REG of ack_sync : signal is "TRUE";
    attribute ASYNC_REG of req_sync : signal is "TRUE";

begin

    -- --------------------------------------------------------------------------
    -- Source domain
    -- --------------------------------------------------------------------------
    process(clk_src, rst_src_n)
    begin
        if rst_src_n = '0' then
            src_req       <= '0';
            src_data_hold <= (others => '0');
            ack_sync      <= "00";
        elsif rising_edge(clk_src) then
            ack_sync <= ack_sync(0) & dst_ack;

            if src_valid_i = '1' and src_req = '0' then
                src_data_hold <= src_data_i;
                src_req       <= '1';
            elsif ack_sync(1) = '1' then
                src_req <= '0';
            end if;
        end if;
    end process;

    src_ready_o <= not src_req;

    -- --------------------------------------------------------------------------
    -- Destination domain
    -- --------------------------------------------------------------------------
    process(clk_dst, rst_dst_n)
    begin
        if rst_dst_n = '0' then
            req_sync     <= "00";
            req_prev     <= '0';
            dst_data_reg <= (others => '0');
            dst_valid_o  <= '0';
            dst_ack      <= '0';
        elsif rising_edge(clk_dst) then
            req_sync <= req_sync(0) & src_req;
            req_prev <= req_sync(1);

            -- Capture data and assert valid on the rising edge of synchronized REQ.
            -- Both signals update in the same clock cycle so they are always synchronous.
            -- (CDC data path: constrain with set_max_delay -datapath_only)
            if req_sync(1) = '1' and req_prev = '0' then
                dst_data_reg <= src_data_hold;
                dst_valid_o  <= '1';
            else
                dst_valid_o  <= '0';
            end if;

            if req_sync(1) = '1' and dst_ready_i = '1' then
                dst_ack <= '1';
            elsif req_sync(1) = '0' then
                dst_ack <= '0';
            end if;
        end if;
    end process;

    dst_data_o <= dst_data_reg;

end architecture rtl;
