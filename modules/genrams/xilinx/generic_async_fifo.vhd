-------------------------------------------------------------------------------
-- Title      : Parametrizable asynchronous FIFO (Xilinx version)
-- Project    : Generics RAMs and FIFOs collection
-------------------------------------------------------------------------------
-- File       : generic_sync_fifo.vhd
-- Author     : Tomasz Wlostowski
-- Company    : CERN BE-CO-HT
-- Created    : 2011-01-25
-- Last update: 2011-03-25
-- Platform   : 
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Dual-clock asynchronous FIFO. 
-- - configurable data width and size
-- - "show ahead" mode
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

library fifo_generator_v6_1;
use fifo_generator_v6_1.all;

library XilinxCoreLib;
use XilinxCoreLib.all;

use work.genram_pkg.all;


entity generic_async_fifo is

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


  component fifo_generator_v6_1_xst
    generic (
      c_has_int_clk                  : integer;
      c_rd_freq                      : integer;
      c_wr_response_latency          : integer;
      c_has_srst                     : integer;
      c_enable_rst_sync              : integer;
      c_has_rd_data_count            : integer;
      c_din_width                    : integer;
      c_has_wr_data_count            : integer;
      c_full_flags_rst_val           : integer;
      c_implementation_type          : integer;
      c_family                       : string;
      c_use_embedded_reg             : integer;
      c_has_wr_rst                   : integer;
      c_wr_freq                      : integer;
      c_use_dout_rst                 : integer;
      c_underflow_low                : integer;
      c_has_meminit_file             : integer;
      c_has_overflow                 : integer;
      c_preload_latency              : integer;
      c_dout_width                   : integer;
      c_msgon_val                    : integer;
      c_rd_depth                     : integer;
      c_default_value                : string;
      c_mif_file_name                : string;
      c_error_injection_type         : integer;
      c_has_underflow                : integer;
      c_has_rd_rst                   : integer;
      c_has_almost_full              : integer;
      c_has_rst                      : integer;
      c_data_count_width             : integer;
      c_has_wr_ack                   : integer;
      c_use_ecc                      : integer;
      c_wr_ack_low                   : integer;
      c_common_clock                 : integer;
      c_rd_pntr_width                : integer;
      c_use_fwft_data_count          : integer;
      c_has_almost_empty             : integer;
      c_rd_data_count_width          : integer;
      c_enable_rlocs                 : integer;
      c_wr_pntr_width                : integer;
      c_overflow_low                 : integer;
      c_prog_empty_type              : integer;
      c_optimization_mode            : integer;
      c_wr_data_count_width          : integer;
      c_preload_regs                 : integer;
      c_dout_rst_val                 : string;
      c_has_data_count               : integer;
      c_prog_full_thresh_negate_val  : integer;
      c_wr_depth                     : integer;
      c_prog_empty_thresh_negate_val : integer;
      c_prog_empty_thresh_assert_val : integer;
      c_has_valid                    : integer;
      c_init_wr_pntr_val             : integer;
      c_prog_full_thresh_assert_val  : integer;
      c_use_fifo16_flags             : integer;
      c_has_backup                   : integer;
      c_valid_low                    : integer;
      c_prim_fifo_type               : string;
      c_count_type                   : integer;
      c_prog_full_type               : integer;
      c_memory_type                  : integer);
    port (
      clk                      : in  std_logic;
      backup                   : in  std_logic;
      backup_marker            : in  std_logic;
      din                      : in  std_logic_vector(g_data_width-1 downto 0);
      prog_empty_thresh        : in  std_logic_vector(f_log2_size(g_size-1) downto 0);
      prog_empty_thresh_assert : in  std_logic_vector(f_log2_size(g_size-1) downto 0);
      prog_empty_thresh_negate : in  std_logic_vector(f_log2_size(g_size-1) downto 0);
      prog_full_thresh         : in  std_logic_vector(f_log2_size(g_size-1) downto 0);
      prog_full_thresh_assert  : in  std_logic_vector(f_log2_size(g_size-1) downto 0);
      prog_full_thresh_negate  : in  std_logic_vector(f_log2_size(g_size-1) downto 0);
      rd_clk                   : in  std_logic;
      rd_en                    : in  std_logic;
      rd_rst                   : in  std_logic;
      rst                      : in  std_logic;
      srst                     : in  std_logic;
      int_clk                  : in  std_logic;
      wr_clk                   : in  std_logic;
      wr_en                    : in  std_logic;
      wr_rst                   : in  std_logic;
      injectdbiterr            : in  std_logic;
      injectsbiterr            : in  std_logic;
      almost_empty             : out std_logic;
      almost_full              : out std_logic;
      data_count               : out std_logic_vector(f_log2_size(g_size-1) downto 0);
      dout                     : out std_logic_vector(g_data_width-1 downto 0);
      empty                    : out std_logic;
      full                     : out std_logic;
      overflow                 : out std_logic;
      prog_empty               : out std_logic;
      prog_full                : out std_logic;
      valid                    : out std_logic;
      rd_data_count            : out std_logic_vector(f_log2_size(g_size-1) downto 0);
      underflow                : out std_logic;
      wr_ack                   : out std_logic;
      wr_data_count            : out std_logic_vector(f_log2_size(g_size-1) downto 0);
      sbiterr                  : out std_logic;
      dbiterr                  : out std_logic);
  end component;

  function f_bool_2_string (x : boolean) return string is
  begin
    if(x) then
      return "ON";
    else
      return "OFF";
    end if;
  end f_bool_2_string;

  function f_bool_2_int (x : boolean) return integer is
  begin
    if(x) then
      return 1;
    else
      return 0;
    end if;
  end f_bool_2_int;

  signal empty         : std_logic;
  signal almost_empty  : std_logic;
  signal almost_full   : std_logic;
  signal sclr          : std_logic;
  signal full          : std_logic;
  signal s_dummy_zeros : std_logic_vector(f_log2_size(g_size)-1 downto 0);

  signal wrusedw : std_logic_vector (f_log2_size(g_size)-1 downto 0);
  signal rdusedw : std_logic_vector (f_log2_size(g_size)-1 downto 0);

  signal rd_full_d0, rd_full_d1 : std_logic;
  signal wr_empty_d0, wr_empty_d1 : std_logic;
  signal rd_almost_full_d0, rd_almost_full_d1 : std_logic;
  signal wr_almost_empty_d0, wr_almost_empty_d1 : std_logic;
  
begin  -- syn

  s_dummy_zeros <= (others => '0');

  sclr <= not rst_n_i;

  wrapped_gen : fifo_generator_v6_1_xst
    generic map (
      c_common_clock       => 0,
      c_count_type         => 0,
      c_data_count_width   => f_log2_size(g_size),
      c_default_value      => "BlankString",
      c_din_width          => g_data_width,
      c_dout_rst_val       => "0",
      c_dout_width         => g_data_width,
      c_enable_rlocs       => 0,
      c_family             => "spartan6",
      c_full_flags_rst_val => 1,

      c_has_almost_empty  => 0,
      c_has_almost_full   => 0,
      c_has_backup        => 0,
      c_has_data_count    => 0,
      c_has_int_clk       => 0,
      c_has_meminit_file  => 0,
      c_has_overflow      => 0,
      c_has_rd_data_count => f_bool_2_int(g_with_rd_count),
      c_has_rd_rst        => 0,
      c_has_rst           => 1,
      c_has_srst          => 0,
      c_has_underflow     => 0,
      c_has_valid         => 0,
      c_has_wr_ack        => 0,
      c_has_wr_data_count => f_bool_2_int(g_with_wr_count),
      c_has_wr_rst        => 0,

      c_implementation_type => 2,
      c_init_wr_pntr_val    => 0,
      c_memory_type         => 1,
      c_mif_file_name       => "BlankString",
      c_optimization_mode   => 0,
      c_overflow_low        => 0,
      c_preload_latency     => 1,
      c_preload_regs        => 0,
      c_prim_fifo_type      => "1kx18",

      c_prog_empty_thresh_assert_val => g_almost_empty_threshold,
      c_prog_empty_thresh_negate_val => g_almost_empty_threshold+1,
      c_prog_empty_type              => f_bool_2_int(g_with_rd_almost_empty or g_with_wr_almost_empty),
      c_prog_full_thresh_assert_val  => g_almost_full_threshold,
      c_prog_full_thresh_negate_val  => g_almost_full_threshold-1,
      c_prog_full_type               => f_bool_2_int(g_with_rd_almost_full or g_with_wr_almost_full),

      c_rd_data_count_width => f_log2_size(g_size),
      c_rd_depth            => g_size,
      c_rd_freq             => 1,
      c_rd_pntr_width       => f_log2_size(g_size),
      c_underflow_low       => 0,
      c_use_dout_rst        => 1,
      c_use_ecc             => 0,
      c_use_embedded_reg    => 0,
      c_use_fifo16_flags    => 0,
      C_USE_FWFT_DATA_COUNT => 0,

      c_wr_ack_low          => 0,
      c_wr_data_count_width => f_log2_size(g_size),
      c_wr_depth            => g_size,
      c_wr_freq             => 1,
      c_wr_pntr_width       => f_log2_size(g_size),
      c_wr_response_latency => 1,

      c_valid_low       => 0,
      c_enable_rst_sync => 1,

      c_msgon_val            => 1,
      c_error_injection_type => 0


      )
    port map (
      clk           => '0',
      backup        => '0',
      backup_marker => '0',
      din           => d_i,

      prog_empty_thresh        => s_dummy_zeros,
      prog_empty_thresh_assert => s_dummy_zeros,
      prog_empty_thresh_negate => s_dummy_zeros,
      prog_full_thresh         => s_dummy_zeros,
      prog_full_thresh_assert  => s_dummy_zeros,
      prog_full_thresh_negate  => s_dummy_zeros,

      rd_clk        => clk_rd_i,
      rd_en         => rd_i,
      rd_rst        => '0',
      rst           => sclr,
      srst          => '0',
      int_clk       => '0',
      wr_clk        => clk_wr_i,
      wr_en         => we_i,
      wr_rst        => '0',
      injectdbiterr => '0',
      injectsbiterr => '0',
      almost_empty  => open,
      almost_full   => open,
      data_count    => open,
      dout          => q_o,
      empty         => empty,
      full          => full,
      overflow      => open,
      prog_empty    => almost_empty,
      prog_full     => almost_full,
      valid         => open,
      rd_data_count => rdusedw,
      underflow     => open,
      wr_ack        => open,
      wr_data_count => wrusedw,
      sbiterr       => open,
      dbiterr       => open);


  gen_with_wr_count : if(g_with_wr_count) generate
    wr_count_o <= wrusedw;
  end generate gen_with_wr_count;

  gen_with_rd_count : if(g_with_rd_count) generate
    rd_count_o <= rdusedw;
  end generate gen_with_rd_count;

  gen_with_wr_empty : if(g_with_wr_empty) generate
    process(clk_wr_i)                   -- xilinx doesn't provide flags for
                                        -- both clock domains
    begin
      if rising_edge(clk_wr_i) then
        wr_empty_d0 <= empty;
        wr_empty_d1 <= wr_empty_d0;
        wr_empty_o  <= wr_empty_d1;
      end if;
    end process;
  end generate gen_with_wr_empty;

  gen_with_rd_empty : if(g_with_rd_empty) generate
    rd_empty_o <= empty;
  end generate gen_with_rd_empty;

  gen_with_wr_full : if(g_with_wr_full) generate
    wr_full_o <= full;
  end generate gen_with_wr_full;

  gen_with_rd_full : if(g_with_rd_full) generate
    process(clk_rd_i)
    begin
      if rising_edge(clk_rd_i) then
        rd_full_d0 <= full;
        rd_full_d1 <= rd_full_d0;
        rd_full_o  <= rd_full_d1;
      end if;
    end process;
  end generate gen_with_rd_full;

  gen_with_wr_almost_empty : if(g_with_wr_almost_empty) generate
    process(clk_wr_i)                   -- xilinx doesn't provide flags for
    begin
      if rising_edge(clk_wr_i) then
        wr_almost_empty_d0 <= almost_empty;
        wr_almost_empty_d1 <= wr_almost_empty_d0;
        wr_almost_empty_o  <= wr_almost_empty_d1;
      end if;
    end process;
  end generate gen_with_wr_almost_empty;

  gen_with_rd_almost_empty : if(g_with_rd_almost_empty) generate
    rd_almost_empty_o <= almost_empty;
  end generate gen_with_rd_almost_empty;

  gen_with_wr_almost_full : if(g_with_wr_almost_full) generate
    wr_almost_full_o <= almost_full;
  end generate gen_with_wr_almost_full;

  gen_with_rd_almost_full : if(g_with_rd_almost_full) generate
    process(clk_rd_i)
    begin
      if rising_edge(clk_rd_i) then
        rd_almost_full_d0 <= full;
        rd_almost_full_d1 <= rd_almost_full_d0;
        rd_almost_full_o  <= rd_almost_full_d1;
      end if;
    end process;
  end generate gen_with_rd_almost_full;


end syn;
