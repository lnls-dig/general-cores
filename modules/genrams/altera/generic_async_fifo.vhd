-------------------------------------------------------------------------------
-- Title      : Parametrizable asynchronous FIFO (Altera version)
-- Project    : Generics RAMs and FIFOs collection
-------------------------------------------------------------------------------
-- File       : generic_async_fifo.vhd
-- Author     : Tomasz Wlostowski
-- Company    : CERN BE-CO-HT
-- Created    : 2011-01-25
-- Last update: 2011-01-25
-- Platform   : 
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Dual-clock asynchronous FIFO. 
-- - configurable data width and size
-- - "show ahead" mode
-- - configurable full/empty/almost full/almost empty/word count signals
-- Todo:
-- - optimize almost empty / almost full flags generation for speed
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

library altera_mf;
use altera_mf.all;

use work.genram_pkg.all;

entity generic_async_fifo is

  generic (
    g_data_width : natural;
    g_size       : natural;
    g_show_ahead : boolean := false;

    -- Read-side flag selection
    g_with_rd_empty        : boolean := true;  -- with empty flag
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
    wr_almost_empty_o : out std_logic;
    wr_almost_full_o  : out std_logic;
    wr_count_o        : out std_logic_vector(f_log2_size(g_size)-1 downto 0);

    -- read port
    clk_rd_i : in  std_logic;
    q_o      : out std_logic_vector(g_data_width-1 downto 0);
    rd_i     : in  std_logic;

    rd_empty_o        : out std_logic;
    rd_full_o         : out std_logic;
    rd_almost_empty_o : out std_logic;
    rd_almost_full_o  : out std_logic;
    rd_count_o        : out std_logic_vector(f_log2_size(g_size)-1 downto 0)
    );

end generic_async_fifo;

architecture syn of generic_async_fifo is

  component dcfifo
    generic (
      lpm_numwords       : natural;
      lpm_showahead      : string;
      lpm_type           : string;
      lpm_width          : natural;
      lpm_widthu         : natural;
      overflow_checking  : string;
      rdsync_delaypipe   : natural;
      underflow_checking : string;
      use_eab            : string;
      write_aclr_synch   : string;
      wrsync_delaypipe   : natural
      );
    port (
      wrclk   : in  std_logic;
      rdempty : out std_logic;
      wrempty : out std_logic;
      rdreq   : in  std_logic;
      aclr    : in  std_logic;
      rdfull  : out std_logic;
      wrfull  : out std_logic;
      rdclk   : in  std_logic;
      q       : out std_logic_vector (g_data_width-1 downto 0);
      wrreq   : in  std_logic;
      data    : in  std_logic_vector (g_data_width-1 downto 0);
      wrusedw : out std_logic_vector (f_log2_size(g_size)-1downto 0);
      rdusedw : out std_logic_vector (f_log2_size(g_size)-1 downto 0)
      );
  end component;

  function f_bool_2_string (x : boolean) return string is
  begin
    if(x) then
      return "ON";
    else
      return "OFF";
    end if;
  end f_bool_2_string;

  signal rdempty : std_logic;
  signal wrempty : std_logic;
  signal aclr    : std_logic;
  signal rdfull  : std_logic;
  signal wrfull  : std_logic;
  signal wrusedw : std_logic_vector (f_log2_size(g_size)-1 downto 0);
  signal rdusedw : std_logic_vector (f_log2_size(g_size)-1 downto 0);
  
begin  -- syn

  aclr <= not rst_n_i;

  dcfifo_inst : dcfifo
    generic map (
      lpm_numwords       => g_size,
      lpm_showahead      => f_bool_2_string(g_show_ahead),
      lpm_type           => "dcfifo",
      lpm_width          => g_data_width,
      lpm_widthu         => f_log2_size(g_size),
      overflow_checking  => "ON",
      rdsync_delaypipe   => 5,          -- 2 sync stages
      underflow_checking => "ON",
      use_eab            => "ON",
      write_aclr_synch   => "ON",
      wrsync_delaypipe   => 5           -- 2 sync stages
      )
    port map (
      wrclk   => clk_wr_i,
      rdempty => rdempty,
      wrempty => wrempty,
      rdreq   => rd_i,
      aclr    => aclr,
      rdfull  => rdfull,
      wrfull  => wrfull,
      rdclk   => clk_rd_i,
      q       => q_o,
      wrreq   => we_i,
      data    => d_i,
      wrusedw => wrusedw,
      rdusedw => rdusedw);

  gen_with_wr_count : if(g_with_wr_count) generate
    wr_count_o <= wrusedw;
  end generate gen_with_wr_count;

  gen_with_rd_count : if(g_with_rd_count) generate
    rd_count_o <= rdusedw;
  end generate gen_with_rd_count;

  gen_with_wr_empty : if(g_with_wr_empty) generate
    wr_empty_o <= wrempty;
  end generate gen_with_wr_empty;

  gen_with_rd_empty : if(g_with_rd_empty) generate
    rd_empty_o <= rdempty;
  end generate gen_with_rd_empty;

  gen_with_wr_full : if(g_with_wr_full) generate
    wr_full_o <= wrfull;
  end generate gen_with_wr_full;

  gen_with_rd_full : if(g_with_rd_full) generate
    rd_full_o <= rdfull;
  end generate gen_with_rd_full;

  gen_with_wr_almost_empty : if(g_with_wr_almost_empty) generate
    wr_almost_empty_o <= '1' when unsigned(wrusedw) < to_unsigned(g_almost_empty_threshold, wrusedw'length) else '0';
  end generate gen_with_wr_almost_empty;

  gen_with_rd_almost_empty : if(g_with_rd_almost_empty) generate
    rd_almost_empty_o <= '1' when unsigned(rdusedw) < to_unsigned(g_almost_empty_threshold, rdusedw'length) else '0';
  end generate gen_with_rd_almost_empty;

  gen_with_wr_almost_full : if(g_with_wr_almost_full) generate
    wr_almost_full_o <= '1' when unsigned(wrusedw) > to_unsigned(g_almost_full_threshold, wrusedw'length) else '0';
  end generate gen_with_wr_almost_full;

  gen_with_rd_almost_full : if(g_with_rd_almost_full) generate
    rd_almost_full_o <= '1' when unsigned(rdusedw) > to_unsigned(g_almost_full_threshold,rdusedw'length) else '0';
  end generate gen_with_rd_almost_full;

end syn;
