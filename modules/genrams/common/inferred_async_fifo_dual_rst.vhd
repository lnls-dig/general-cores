--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   inferred_async_fifo_dual_rst
--
-- description: Parametrizable asynchronous FIFO (Generic version).
-- Dual-clock asynchronous FIFO.
-- - configurable data width and size
-- - configurable full/empty/almost full/almost empty/word count signals
-- - dual sunchronous reset
--
--------------------------------------------------------------------------------
-- Copyright CERN 2011-2018
--------------------------------------------------------------------------------
-- Copyright and related rights are licensed under the Solderpad Hardware
-- License, Version 2.0 (the "License"); you may not use this file except
-- in compliance with the License. You may obtain a copy of the License at
-- http://solderpad.org/licenses/SHL-2.0.
-- Unless required by applicable law or agreed to in writing, software,
-- hardware and materials distributed under this License is distributed on an
-- "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
-- or implied. See the License for the specific language governing permissions
-- and limitations under the License.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.genram_pkg.all;
use work.gencores_pkg.all;

entity inferred_async_fifo_dual_rst is

  generic (
    g_data_width             : natural;
    g_size                   : natural;
    g_show_ahead             : boolean := FALSE;
    g_with_rd_empty          : boolean := TRUE;
    g_with_rd_full           : boolean := FALSE;
    g_with_rd_almost_empty   : boolean := FALSE;
    g_with_rd_almost_full    : boolean := FALSE;
    g_with_rd_count          : boolean := FALSE;
    g_with_wr_empty          : boolean := FALSE;
    g_with_wr_full           : boolean := TRUE;
    g_with_wr_almost_empty   : boolean := FALSE;
    g_with_wr_almost_full    : boolean := FALSE;
    g_with_wr_count          : boolean := FALSE;
    g_almost_empty_threshold : integer;
    g_almost_full_threshold  : integer);
  port (
    -- write port
    rst_wr_n_i        : in  std_logic := '1';
    clk_wr_i          : in  std_logic;
    d_i               : in  std_logic_vector(g_data_width-1 downto 0);
    we_i              : in  std_logic;
    wr_empty_o        : out std_logic;
    wr_full_o         : out std_logic;
    wr_almost_empty_o : out std_logic;
    wr_almost_full_o  : out std_logic;
    wr_count_o        : out std_logic_vector(f_log2_size(g_size)-1 downto 0);
    -- read port
    rst_rd_n_i        : in  std_logic := '1';
    clk_rd_i          : in  std_logic;
    q_o               : out std_logic_vector(g_data_width-1 downto 0);
    rd_i              : in  std_logic;
    rd_empty_o        : out std_logic;
    rd_full_o         : out std_logic;
    rd_almost_empty_o : out std_logic;
    rd_almost_full_o  : out std_logic;
    rd_count_o        : out std_logic_vector(f_log2_size(g_size)-1 downto 0)
    );

  attribute keep_hierarchy : string;
  attribute keep_hierarchy of
    inferred_async_fifo_dual_rst : entity is "true";

end inferred_async_fifo_dual_rst;


architecture arch of inferred_async_fifo_dual_rst is

  -- We use one more bit to be able to differentiate between an empty FIFO
  -- (where rcb = wcb) and a full FIFO (where rcb = wcb except from the most
  -- significant extra bit).
  -- This extra bit is not used of course for actual addressing of the memory.
  constant c_counter_bits : integer := f_log2_size(g_size) + 1;
  subtype t_counter is std_logic_vector(c_counter_bits-1 downto 0);

  -- bin: binary counter
  -- bin_next: bin + 1
  -- bin_x: cross-clock domain version of bin
  -- gray: gray code of bin
  -- gray_next: gray code of bin_next
  -- gray_x: gray code of bin_x
  --
  -- We use gray codes for safe cross-clock domain crossing of counters. Thus,
  -- a binary counter is converted to gray before crossing, and then it is
  -- converted back to binary after crossing.
  type t_counter_block is record
    bin, bin_next   : t_counter;
    gray, gray_next : t_counter;
    bin_x, gray_x   : t_counter;
  end record;

  type t_mem_type is array (0 to g_size-1) of std_logic_vector(g_data_width-1 downto 0);
  signal mem : t_mem_type := (others => (others => '0'));

  signal rcb, wcb : t_counter_block := (others =>(others => '0'));

  signal full_int, empty_int               : std_logic;
  signal almost_full_int, almost_empty_int : std_logic;
  signal going_full                        : std_logic;

  signal wr_count, rd_count : t_counter;
  signal rd_int, we_int     : std_logic;

  signal wr_empty_x : std_logic := '0';
  signal rd_full_x  : std_logic := '0';

  signal almost_full_x  : std_logic := '0';
  signal almost_empty_x : std_logic := '0';

  signal q_int : std_logic_vector(g_data_width-1 downto 0) := (others => '0');

begin  -- arch

  rd_int <= rd_i and not empty_int;
  we_int <= we_i and not full_int;

  p_mem_write : process(clk_wr_i)
  begin
    if rising_edge(clk_wr_i) then
      if we_int = '1' then
        mem(to_integer(unsigned(wcb.bin(wcb.bin'LEFT-1 downto 0)))) <= d_i;
      end if;
    end if;
  end process p_mem_write;

  p_mem_read : process(clk_rd_i)
  begin
    if rising_edge(clk_rd_i) then
      if(rd_int = '1' and g_show_ahead) then
        q_int <= mem(to_integer(unsigned(rcb.bin_next(rcb.bin_next'LEFT-1 downto 0))));
      elsif(rd_int = '1' or g_show_ahead) then
        q_int <= mem(to_integer(unsigned(rcb.bin(rcb.bin'LEFT-1 downto 0))));
      end if;
    end if;
  end process p_mem_read;

  q_o <= q_int;

  wcb.bin_next  <= std_logic_vector(unsigned(wcb.bin) + 1);
  wcb.gray_next <= f_gray_encode(wcb.bin_next);

  p_write_ptr : process(clk_wr_i)
  begin
    if rising_edge(clk_wr_i) then
      if rst_wr_n_i = '0' then
        wcb.bin  <= (others => '0');
        wcb.gray <= (others => '0');
      elsif we_int = '1' then
        wcb.bin  <= wcb.bin_next;
        wcb.gray <= wcb.gray_next;
      end if;
    end if;
  end process p_write_ptr;

  rcb.bin_next  <= std_logic_vector(unsigned(rcb.bin) + 1);
  rcb.gray_next <= f_gray_encode(rcb.bin_next);

  p_read_ptr : process(clk_rd_i)
  begin
    if rising_edge(clk_rd_i) then
      if rst_rd_n_i = '0' then
        rcb.bin  <= (others => '0');
        rcb.gray <= (others => '0');
      elsif rd_int = '1' then
        rcb.bin  <= rcb.bin_next;
        rcb.gray <= rcb.gray_next;
      end if;
    end if;
  end process p_read_ptr;

  U_Sync1 : gc_sync_register
    generic map (
      g_width => c_counter_bits)
    port map (
      clk_i     => clk_wr_i,
      rst_n_a_i => '1',
      d_i       => rcb.gray,
      q_o       => rcb.gray_x);

  U_Sync2 : gc_sync_register
    generic map (
      g_width => c_counter_bits)
    port map (
      clk_i     => clk_rd_i,
      rst_n_a_i => '1',
      d_i       => wcb.gray,
      q_o       => wcb.gray_x);

  wcb.bin_x <= f_gray_decode(wcb.gray_x, 1);
  rcb.bin_x <= f_gray_decode(rcb.gray_x, 1);

  p_gen_empty : process(clk_rd_i)
  begin
    if rising_edge (clk_rd_i) then
      if rst_rd_n_i = '0' then
        empty_int <= '1';
      elsif rcb.gray = wcb.gray_x or (rd_int = '1' and (wcb.gray_x = rcb.gray_next)) then
        empty_int <= '1';
      else
        empty_int <= '0';
      end if;
    end if;
  end process p_gen_empty;

  gen_with_wr_empty : if g_with_wr_empty = TRUE generate
    U_Sync_Empty : gc_sync_ffs
      generic map (
        g_sync_edge => "positive")
      port map (
        clk_i    => clk_wr_i,
        rst_n_i  => '1',
        data_i   => empty_int,
        synced_o => wr_empty_x);
  end generate gen_with_wr_empty;


  gen_with_rd_full : if g_with_rd_full = TRUE generate
    U_Sync_Full : gc_sync_ffs
      generic map (
        g_sync_edge => "positive")
      port map (
        clk_i    => clk_rd_i,
        rst_n_i  => '1',
        data_i   => full_int,
        synced_o => rd_full_x);
  end generate gen_with_rd_full;

  rd_empty_o <= empty_int;
  wr_empty_o <= wr_empty_x;

  p_gen_going_full : process(rcb, wcb, we_int)
  begin
    if ((wcb.bin (wcb.bin'LEFT-1 downto 0) = rcb.bin_x(rcb.bin_x'LEFT-1 downto 0))
        and (wcb.bin(wcb.bin'LEFT) /= rcb.bin_x(rcb.bin_x'LEFT))) then
      going_full <= '1';
    elsif (we_int = '1'
           and (wcb.bin_next(wcb.bin'LEFT-1 downto 0) = rcb.bin_x(rcb.bin_x'LEFT-1 downto 0))
           and (wcb.bin_next(wcb.bin'LEFT) /= rcb.bin_x(rcb.bin_x'LEFT))) then
      going_full <= '1';
    else
      going_full <= '0';
    end if;
  end process p_gen_going_full;

  p_register_full : process(clk_wr_i)
  begin
    if rising_edge (clk_wr_i) then
      if rst_wr_n_i = '0' then
        full_int <= '0';
      else
        full_int <= going_full;
      end if;
    end if;
  end process p_register_full;

  wr_full_o <= full_int;
  rd_full_o <= rd_full_x;

  p_reg_almost_full : process(clk_wr_i)
  begin
    if rising_edge(clk_wr_i) then
      if rst_wr_n_i = '0' then
        almost_full_int <= '0';
      else
        wr_count <= std_logic_vector(unsigned(wcb.bin) - unsigned(rcb.bin_x));
        if (unsigned(wr_count) < g_almost_full_threshold) then
          almost_full_int <= '0';
        else
          almost_full_int <= '1';
        end if;
      end if;
    end if;
  end process p_reg_almost_full;

  gen_with_rd_almost_full : if g_with_rd_almost_full = TRUE generate
    U_Sync_AlmostFull : gc_sync_ffs
      generic map (
        g_sync_edge => "positive")
      port map (
        clk_i    => clk_rd_i,
        rst_n_i  => '1',
        data_i   => almost_full_int,
        synced_o => almost_full_x);
  end generate gen_with_rd_almost_full;

  wr_almost_full_o <= almost_full_int;
  rd_almost_full_o <= almost_full_x;

  p_reg_almost_empty : process(clk_rd_i)
  begin
    if rising_edge(clk_rd_i) then
      if rst_rd_n_i = '0' then
        almost_empty_int <= '1';
      else
        rd_count <= std_logic_vector(unsigned(wcb.bin_x) - unsigned(rcb.bin));
        if (unsigned(rd_count) > g_almost_empty_threshold) then
          almost_empty_int <= '0';
        else
          almost_empty_int <= '1';
        end if;
      end if;
    end if;
  end process p_reg_almost_empty;

  gen_with_wr_almost_empty : if g_with_wr_almost_empty = TRUE generate
    U_Sync_AlmostEmpty : gc_sync_ffs
      generic map (
        g_sync_edge => "positive")
      port map (
        clk_i    => clk_wr_i,
        rst_n_i  => '1',
        data_i   => almost_empty_int,
        synced_o => almost_empty_x);
  end generate gen_with_wr_almost_empty;

  rd_almost_empty_o <= almost_empty_int;
  wr_almost_empty_o <= almost_empty_x;

  wr_count_o <= std_logic_vector(wr_count(f_log2_size(g_size)-1 downto 0));
  rd_count_o <= std_logic_vector(rd_count(f_log2_size(g_size)-1 downto 0));

end arch;
