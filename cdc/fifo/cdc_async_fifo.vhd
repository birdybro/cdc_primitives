-- =============================================================================
-- Module  : cdc_async_fifo
-- Language: VHDL-2008
--
-- Description:
--   Dual-clock asynchronous FIFO using Gray-coded read/write pointers.
--   Safely transfers multi-bit data between two independent clock domains.
--
-- CDC Principle (Gray-Coded Pointers):
--   Gray code ensures only 1 bit changes per pointer increment, making
--   pointer synchronization safe across clock domains.
--   Full:  wr_gray == {~rd_gray_sync(MSB), ~rd_gray_sync(MSB-1), rd_gray_sync(rest)}
--   Empty: rd_gray == wr_gray_sync
--
-- Safety:
--   - Gray code pointer synchronization is the only CDC crossing.
--   - DEPTH must be a power of 2 and >= 4.
--   - Apply ASYNC_REG constraints on rd_gray_sync and wr_gray_sync.
--
-- Use Cases:
--   - High-bandwidth data streaming between asynchronous clock domains.
--
-- Limitations:
--   - DEPTH must be power of 2 >= 4.
--   - Full/empty flags have ~2-cycle pessimism.
--
-- Example Instantiation:
--   u_fifo : entity work.cdc_async_fifo
--       generic map (DATA_WIDTH => 8, DEPTH => 16)
--       port map (
--           wr_clk   => wr_clk,  wr_rst_n => wr_rst_n,
--           wr_en    => wr_en,   wr_data  => wr_data,
--           wr_full  => wr_full,
--           rd_clk   => rd_clk,  rd_rst_n => rd_rst_n,
--           rd_en    => rd_en,   rd_data  => rd_data,
--           rd_empty => rd_empty
--       );
-- =============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cdc_async_fifo is
    generic (
        DATA_WIDTH  : positive := 8;   -- Width of each FIFO entry
        DEPTH       : positive := 16;  -- Number of entries; must be power of 2, >= 4
        SYNC_STAGES : positive := 2    -- Synchronizer stages for pointer crossing (>= 2)
    );
    port (
        -- Write port
        wr_clk   : in  std_logic;                                  -- Write domain clock
        wr_rst_n : in  std_logic;                                  -- Write domain reset (active low)
        wr_en    : in  std_logic;                                  -- Write enable
        wr_data  : in  std_logic_vector(DATA_WIDTH-1 downto 0);   -- Write data
        wr_full  : out std_logic;                                  -- Full flag (write domain)

        -- Read port
        rd_clk   : in  std_logic;                                  -- Read domain clock
        rd_rst_n : in  std_logic;                                  -- Read domain reset (active low)
        rd_en    : in  std_logic;                                  -- Read enable
        rd_data  : out std_logic_vector(DATA_WIDTH-1 downto 0);   -- Read data (combinatorial)
        rd_empty : out std_logic                                   -- Empty flag (read domain)
    );
end entity cdc_async_fifo;

architecture rtl of cdc_async_fifo is

    -- Integer-only ceiling log2 function avoids floating-point precision issues.
    -- Returns the number of bits needed to represent DEPTH distinct values.
    function clog2(x : positive) return natural is
        variable n : natural   := 0;
        variable y : positive  := 1;
    begin
        while y < x loop
            n := n + 1;
            y := y * 2;
        end loop;
        return n;
    end function;

    -- Derived constants
    constant ADDR_WIDTH : integer := clog2(DEPTH);  -- Address bits (log2 of DEPTH)
    constant PTR_WIDTH  : integer := ADDR_WIDTH + 1; -- Pointer width (extra MSB)

    -- Memory type
    type mem_t is array (0 to DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal mem : mem_t;

    -- Pointer synchronizer array type
    type gray_sync_t is array (0 to SYNC_STAGES-1) of unsigned(PTR_WIDTH-1 downto 0);

    -- Write domain signals
    signal wr_ptr      : unsigned(PTR_WIDTH-1 downto 0) := (others => '0');
    signal wr_ptr_gray : unsigned(PTR_WIDTH-1 downto 0);
    signal rd_gray_sync : gray_sync_t := (others => (others => '0'));
    signal wr_full_i   : std_logic;

    -- Read domain signals
    signal rd_ptr      : unsigned(PTR_WIDTH-1 downto 0) := (others => '0');
    signal rd_ptr_gray : unsigned(PTR_WIDTH-1 downto 0);
    signal wr_gray_sync : gray_sync_t := (others => (others => '0'));
    signal rd_empty_i  : std_logic;

    attribute ASYNC_REG : string;
    attribute ASYNC_REG of rd_gray_sync : signal is "TRUE";
    attribute ASYNC_REG of wr_gray_sync : signal is "TRUE";

    -- Binary to Gray conversion function
    function bin2gray(bin : unsigned) return unsigned is
    begin
        return bin xor ('0' & bin(bin'high downto 1));
    end function;

begin

    -- --------------------------------------------------------------------------
    -- Write domain
    -- --------------------------------------------------------------------------
    process(wr_clk, wr_rst_n)
    begin
        if wr_rst_n = '0' then
            wr_ptr <= (others => '0');
        elsif rising_edge(wr_clk) then
            if wr_en = '1' and wr_full_i = '0' then
                wr_ptr <= wr_ptr + 1;
            end if;
        end if;
    end process;

    wr_ptr_gray <= bin2gray(wr_ptr);

    -- Synchronous write to memory
    process(wr_clk)
    begin
        if rising_edge(wr_clk) then
            if wr_en = '1' and wr_full_i = '0' then
                mem(to_integer(wr_ptr(ADDR_WIDTH-1 downto 0))) <= wr_data;
            end if;
        end if;
    end process;

    -- Synchronize read Gray pointer into write domain
    process(wr_clk, wr_rst_n)
    begin
        if wr_rst_n = '0' then
            rd_gray_sync <= (others => (others => '0'));
        elsif rising_edge(wr_clk) then
            rd_gray_sync(0) <= rd_ptr_gray;
            for i in 1 to SYNC_STAGES-1 loop
                rd_gray_sync(i) <= rd_gray_sync(i-1);
            end loop;
        end if;
    end process;

    -- Full: top 2 bits inverted, remaining bits equal (Gray code full condition)
    wr_full_i <= '1' when
        wr_ptr_gray = (
            (not rd_gray_sync(SYNC_STAGES-1)(PTR_WIDTH-1)) &
            (not rd_gray_sync(SYNC_STAGES-1)(PTR_WIDTH-2)) &
            rd_gray_sync(SYNC_STAGES-1)(PTR_WIDTH-3 downto 0)
        )
        else '0';

    wr_full <= wr_full_i;

    -- --------------------------------------------------------------------------
    -- Read domain
    -- --------------------------------------------------------------------------
    process(rd_clk, rd_rst_n)
    begin
        if rd_rst_n = '0' then
            rd_ptr <= (others => '0');
        elsif rising_edge(rd_clk) then
            if rd_en = '1' and rd_empty_i = '0' then
                rd_ptr <= rd_ptr + 1;
            end if;
        end if;
    end process;

    rd_ptr_gray <= bin2gray(rd_ptr);

    -- Combinatorial read data
    rd_data <= mem(to_integer(rd_ptr(ADDR_WIDTH-1 downto 0)));

    -- Synchronize write Gray pointer into read domain
    process(rd_clk, rd_rst_n)
    begin
        if rd_rst_n = '0' then
            wr_gray_sync <= (others => (others => '0'));
        elsif rising_edge(rd_clk) then
            wr_gray_sync(0) <= wr_ptr_gray;
            for i in 1 to SYNC_STAGES-1 loop
                wr_gray_sync(i) <= wr_gray_sync(i-1);
            end loop;
        end if;
    end process;

    -- Empty: pointers are equal in Gray code
    rd_empty_i <= '1' when rd_ptr_gray = wr_gray_sync(SYNC_STAGES-1) else '0';
    rd_empty   <= rd_empty_i;

end architecture rtl;
