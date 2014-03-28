-------------------------------------------------------------------------------
-- Title      : Parametrizable asynchronous FIFO (Generic version)
-- Project    : Generics RAMs and FIFOs collection
-------------------------------------------------------------------------------
-- File       : generic_async_fifo.vhd
-- Author     : Tomasz Wlostowski
-- Company    : CERN BE-CO-HT
-- Created    : 2011-01-25
-- Last update: 2013-07-29
-- Platform   :
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Dual-clock asynchronous FIFO.
-- - configurable data width and size
-- - configurable full/empty/almost full/almost empty/word count signals
-------------------------------------------------------------------------------
-- Copyright (c) 2011 CERN
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2011-01-25  1.0      twlostow        Created
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.genram_pkg.all;

entity inferred_async_fifo is

  generic (
    g_data_width : natural;
    g_size       : natural;
    g_show_ahead : boolean := false;

    -- Read-side flag selection
    g_with_rd_empty        : boolean := true;   -- with empty flag
    g_with_rd_full         : boolean := false;  -- with full flag
    g_with_rd_almost_empty : boolean := false;
    g_with_rd_almost_full  : boolean := false;
    g_with_rd_count        : boolean := false;  -- with words counter

    g_with_wr_empty        : boolean := false;
    g_with_wr_full         : boolean := true;
    g_with_wr_almost_empty : boolean := false;
    g_with_wr_almost_full  : boolean := false;
    g_with_wr_count        : boolean := false;

    g_almost_empty_threshold : integer;  -- threshold for almost empty flag
    g_almost_full_threshold  : integer   -- threshold for almost full flag
    );

  port (
    rst_n_i : in std_logic := '1';


    -- write port
    clk_wr_i : in std_logic;
    d_i      : in std_logic_vector(g_data_width-1 downto 0);
    we_i     : in std_logic;

    wr_empty_o        : out std_logic;
    wr_full_o         : out std_logic;
    wr_almost_empty_o : out std_logic; -- TODO: assign
    wr_almost_full_o  : out std_logic;
    wr_count_o        : out std_logic_vector(f_log2_size(g_size)-1 downto 0);

    -- read port
    clk_rd_i : in  std_logic;
    q_o      : out std_logic_vector(g_data_width-1 downto 0);
    rd_i     : in  std_logic;

    rd_empty_o        : out std_logic;
    rd_full_o         : out std_logic;
    rd_almost_empty_o : out std_logic;
    rd_almost_full_o  : out std_logic; -- TODO: assign
    rd_count_o        : out std_logic_vector(f_log2_size(g_size)-1 downto 0)
    );

end inferred_async_fifo;


architecture syn of inferred_async_fifo is

  function f_bin2gray(bin : unsigned) return unsigned is
  begin
    return bin(bin'left) & (bin(bin'left-1 downto 0) xor bin(bin'left downto 1));
  end f_bin2gray;

  function f_gray2bin(gray : unsigned) return unsigned is
    variable bin : unsigned(gray'left downto 0);
  begin
    -- gray to binary
    for i in 0 to gray'left loop
      bin(i) := '0';
      for j in i to gray'left loop
        bin(i) := bin(i) xor gray(j);
      end loop;  -- j
    end loop;  -- i
    return bin;
  end f_gray2bin;

  subtype t_counter is unsigned(f_log2_size(g_size) downto 0);

  type t_counter_block is record
    bin, bin_next, gray, gray_next : t_counter;
    bin_x, gray_x, gray_xm         : t_counter;
  end record;

  type   t_mem_type is array (0 to g_size-1) of std_logic_vector(g_data_width-1 downto 0);
  signal mem : t_mem_type;

  signal rcb, wcb                          : t_counter_block;

  attribute ASYNC_REG : string;
  attribute ASYNC_REG of wcb: signal is "TRUE";
  attribute ASYNC_REG of rcb: signal is "TRUE";

  signal full_int, empty_int               : std_logic;
  signal almost_full_int, almost_empty_int : std_logic;
  signal going_full                        : std_logic;

  signal wr_count, rd_count : t_counter;
  signal rd_int, we_int : std_logic;

  signal wr_empty_xm, wr_empty_x : std_logic;
  signal rd_full_xm, rd_full_x   : std_logic;

  signal almost_full_x, almost_full_xm   : std_logic;
  signal almost_empty_x, almost_empty_xm : std_logic;

begin  -- syn

  rd_int <= rd_i and not empty_int;
  we_int <= we_i and not full_int;

  p_mem_write : process(clk_wr_i)
  begin
    if rising_edge(clk_wr_i) then
      if(we_int = '1') then
        mem(to_integer(wcb.bin(wcb.bin'left-1 downto 0))) <= d_i;
      end if;
    end if;
  end process;

  p_mem_read : process(clk_rd_i)
  begin
    if rising_edge(clk_rd_i) then
      if(rd_int = '1') then
        q_o <= mem(to_integer(rcb.bin(rcb.bin'left-1 downto 0)));
      end if;
    end if;
  end process;

  wcb.bin_next  <= wcb.bin + 1;
  wcb.gray_next <= f_bin2gray(wcb.bin_next);

  p_write_ptr : process(clk_wr_i, rst_n_i)
  begin
    if rst_n_i = '0' then
      wcb.bin  <= (others => '0');
      wcb.gray <= (others => '0');
    elsif rising_edge(clk_wr_i) then
      if(we_int = '1') then
        wcb.bin  <= wcb.bin_next;
        wcb.gray <= wcb.gray_next;
      end if;
    end if;
  end process;

  rcb.bin_next  <= rcb.bin + 1;
  rcb.gray_next <= f_bin2gray(rcb.bin_next);

  p_read_ptr : process(clk_rd_i, rst_n_i)
  begin
    if rst_n_i = '0' then
      rcb.bin  <= (others => '0');
      rcb.gray <= (others => '0');
    elsif rising_edge(clk_rd_i) then
      if(rd_int = '1') then
        rcb.bin  <= rcb.bin_next;
        rcb.gray <= rcb.gray_next;
      end if;
    end if;
  end process;

  p_sync_read_ptr : process(clk_wr_i)
  begin
    if rising_edge(clk_wr_i) then
      rcb.gray_xm <= rcb.gray;
      rcb.gray_x  <= rcb.gray_xm;
    end if;
  end process;


  p_sync_write_ptr : process(clk_rd_i)
  begin
    if rising_edge(clk_rd_i) then
      wcb.gray_xm <= wcb.gray;
      wcb.gray_x  <= wcb.gray_xm;
    end if;
  end process;

  wcb.bin_x <= f_gray2bin(wcb.gray_x);
  rcb.bin_x <= f_gray2bin(rcb.gray_x);

  p_gen_empty : process(clk_rd_i, rst_n_i)
  begin
    if rst_n_i = '0' then
      empty_int <= '1';
    elsif rising_edge (clk_rd_i) then
      if(rcb.gray = wcb.gray_x or (rd_int = '1' and (wcb.gray_x = rcb.gray_next))) then
        empty_int <= '1';
      else
        empty_int <= '0';
      end if;
    end if;
  end process;

  p_sync_empty : process(clk_wr_i)
  begin
    if rising_edge(clk_wr_i) then
      wr_empty_xm <= empty_int;
      wr_empty_x  <= wr_empty_xm;
    end if;
  end process;

  rd_empty_o <= empty_int;
  wr_empty_o <= wr_empty_x;

  p_gen_going_full : process(we_int, wcb, rcb)
  begin
    if ((wcb.bin (wcb.bin'left-1 downto 0) = rcb.bin_x(rcb.bin_x'left-1 downto 0))
        and (wcb.bin(wcb.bin'left) /= rcb.bin_x(wcb.bin_x'left))) then
      going_full <= '1';
    elsif (we_int = '1'
           and (wcb.bin_next(wcb.bin'left-1 downto 0) = rcb.bin_x(rcb.bin_x'left-1 downto 0))
           and (wcb.bin_next(wcb.bin'left) /= rcb.bin_x(rcb.bin_x'left))) then
      going_full <= '1';
    else
      going_full <= '0';
    end if;
  end process;

  p_register_full : process(clk_wr_i, rst_n_i)
  begin
    if rst_n_i = '0' then
      full_int <= '0';
    elsif rising_edge (clk_wr_i) then
      full_int <= going_full;
    end if;
  end process;

  p_sync_full : process(clk_rd_i)
  begin
    if rising_edge(clk_rd_i) then
      rd_full_xm <= full_int;
      rd_full_x  <= rd_full_xm;
    end if;
  end process p_sync_full;

  wr_full_o <= full_int;
  rd_full_o <= rd_full_x;

  p_reg_almost_full : process(clk_wr_i, rst_n_i)
  begin
    if rst_n_i = '0' then
      almost_full_int <= '0';
    elsif rising_edge(clk_wr_i) then
      wr_count <= wcb.bin - rcb.bin_x;
      if (wr_count >= g_almost_full_threshold) then
        almost_full_int <= '1';
      else
        almost_full_int <= '0';
      end if;
    end if;
  end process;

  p_sync_almost_full : process(clk_rd_i)
  begin
    if rising_edge(clk_rd_i) then
      almost_full_xm <= almost_full_int;
      almost_full_x  <= almost_full_xm;
    end if;
  end process p_sync_almost_full;

  wr_almost_full_o  <= almost_full_int;
  rd_almost_full_o  <= almost_full_x;

  p_reg_almost_empty : process(clk_rd_i, rst_n_i)
  begin
    if rst_n_i = '0' then
      almost_empty_int <= '1';
    elsif rising_edge(clk_rd_i) then
      rd_count     <= wcb.bin_x - rcb.bin;
      if (rd_count <= g_almost_empty_threshold) then
        almost_empty_int <= '1';
      else
        almost_empty_int <= '0';
      end if;
    end if;
  end process;

  p_sync_almost_empty : process(clk_wr_i)
  begin
    if rising_edge(clk_wr_i) then
      almost_empty_xm <= almost_empty_int;
      almost_empty_x  <= almost_empty_xm;
    end if;
  end process p_sync_almost_empty;

  rd_almost_empty_o <= almost_empty_int;
  wr_almost_empty_o <= almost_empty_x;

  wr_count_o <= std_logic_vector(wr_count(f_log2_size(g_size)-1 downto 0));
  rd_count_o <= std_logic_vector(rd_count(f_log2_size(g_size)-1 downto 0));

end syn;
