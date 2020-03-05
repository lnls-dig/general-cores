--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   gencores_pkg
--
-- description: Package incorporating simple VHDL modules and functions,
-- which are used in OHWR projects.
--
--------------------------------------------------------------------------------
-- Copyright CERN 2009-2018
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

package gencores_pkg is

  --============================================================================
  -- Procedures and functions
  --============================================================================

  procedure f_rr_arbitrate (
    signal req       : in  std_logic_vector;
    signal pre_grant : in  std_logic_vector;
    signal grant     : out std_logic_vector);

  function f_onehot_decode(x : std_logic_vector; size : integer) return std_logic_vector;

  function f_big_ripple(a, b : std_logic_vector; c : std_logic) return std_logic_vector;

  function f_gray_encode(x : std_logic_vector) return std_logic_vector;
  function f_gray_decode(x : std_logic_vector; step : natural) return std_logic_vector;

  function f_log2_ceil(N : natural) return positive;
  -- kept for backwards compatibility, same as f_log2_ceil()
  function log2_ceil(N : natural) return positive;

  function f_bool2int (b : boolean) return natural;
  function f_int2bool (n : natural) return boolean;

  --  Convert a boolean to std_logic ('1' for True, '0' for False).
  function f_to_std_logic(b : boolean) return std_logic;

  -- Reduce-OR an std_logic_vector to std_logic
  function f_reduce_or (x : std_logic_vector) return std_logic;

  -- Character/String to std_logic_vector
  function f_to_std_logic_vector (c : character) return std_logic_vector;
  function f_to_std_logic_vector (s : string) return std_logic_vector;

  -- Functions for short-hand if assignments
  function f_pick (cond : boolean; if_1 : std_logic; if_0 : std_logic)
    return std_logic;
  function f_pick (cond : boolean; if_1 : std_logic_vector; if_0 : std_logic_vector)
    return std_logic_vector;
  function f_pick (cond : std_logic; if_1 : std_logic; if_0 : std_logic)
    return std_logic;
  function f_pick (cond : std_logic; if_1 : std_logic_vector; if_0 : std_logic_vector)
    return std_logic_vector;

  -- Functions to convert characters and strings to upper/lower case
  function to_upper(c : character) return character;
  function to_lower(c : character) return character;
  function to_upper(s : string) return string;
  function to_lower(s : string) return string;

  -- Bit reversal function
  function f_reverse_vector (a : in std_logic_vector) return std_logic_vector;

  --============================================================================
  -- Component instantiations
  --============================================================================

  ------------------------------------------------------------------------------
  -- Pulse extender
  ------------------------------------------------------------------------------
  component gc_extend_pulse
    generic (
      g_width : natural);
    port (
      clk_i      : in  std_logic;
      rst_n_i    : in  std_logic;
      pulse_i    : in  std_logic;
      extended_o : out std_logic);
  end component;

  component gc_dyn_extend_pulse is
    generic (
      g_len_width : natural := 10);
  port (
    clk_i      : in  std_logic;
    rst_n_i    : in  std_logic;
    pulse_i    : in  std_logic;
    len_i      : in std_logic_vector(g_len_width-1 downto 0);
    extended_o : out std_logic := '0');
  end component;

  ------------------------------------------------------------------------------
  -- CRC generator
  ------------------------------------------------------------------------------
  component gc_crc_gen
    generic (
      g_polynomial              : std_logic_vector       := x"04C11DB7";
      g_init_value              : std_logic_vector       := x"ffffffff";
      g_residue                 : std_logic_vector       := x"38fb2284";
      g_data_width              : integer range 2 to 256 := 16;
      g_half_width              : integer range 2 to 256 := 8;
      g_sync_reset              : integer range 0 to 1   := 1;
      g_dual_width              : integer range 0 to 1   := 0;
      g_registered_match_output : boolean                := true;
      g_registered_crc_output   : boolean                := true);
    port (
      clk_i     : in  std_logic;
      rst_i     : in  std_logic;
      en_i      : in  std_logic;
      half_i    : in  std_logic;
      restart_i : in  std_logic := '0';
      data_i    : in  std_logic_vector(g_data_width - 1 downto 0);
      match_o   : out std_logic;
      crc_o     : out std_logic_vector(g_polynomial'length - 1 downto 0));
  end component;

  ------------------------------------------------------------------------------
  -- Moving average
  ------------------------------------------------------------------------------
  component gc_moving_average
    generic (
      g_data_width : natural;
      g_avg_log2   : natural range 1 to 8);
    port (
      rst_n_i    : in  std_logic;
      clk_i      : in  std_logic;
      din_i      : in  std_logic_vector(g_data_width-1 downto 0);
      dout_o     : out std_logic_vector(g_data_width+g_avg_log2-1 downto 0);
      dout_stb_o : out std_logic);
  end component;

  ------------------------------------------------------------------------------
  -- Delay line
  ------------------------------------------------------------------------------
  component gc_delay_line
    generic (
      g_delay : integer;
      g_width : integer);
    port (
      clk_i   : in  std_logic;
      rst_n_i : in  std_logic;
      d_i     : in  std_logic_vector(g_width -1 downto 0);
      q_o     : out std_logic_vector(g_width -1 downto 0);
      ready_o : out std_logic);
  end component;

  ------------------------------------------------------------------------------
  -- PI controller
  ------------------------------------------------------------------------------
  component gc_dual_pi_controller
    generic (
      g_error_bits          : integer;
      g_dacval_bits         : integer;
      g_output_bias         : integer;
      g_integrator_fracbits : integer;
      g_integrator_overbits : integer;
      g_coef_bits           : integer);
    port (
      clk_sys_i         : in  std_logic;
      rst_n_sysclk_i    : in  std_logic;
      phase_err_i       : in  std_logic_vector(g_error_bits-1 downto 0);
      phase_err_stb_p_i : in  std_logic;
      freq_err_i        : in  std_logic_vector(g_error_bits-1 downto 0);
      freq_err_stb_p_i  : in  std_logic;
      mode_sel_i        : in  std_logic;
      dac_val_o         : out std_logic_vector(g_dacval_bits-1 downto 0);
      dac_val_stb_p_o   : out std_logic;
      pll_pcr_enable_i  : in  std_logic;
      pll_pcr_force_f_i : in  std_logic;
      pll_fbgr_f_kp_i   : in  std_logic_vector(g_coef_bits-1 downto 0);
      pll_fbgr_f_ki_i   : in  std_logic_vector(g_coef_bits-1 downto 0);
      pll_pbgr_p_kp_i   : in  std_logic_vector(g_coef_bits-1 downto 0);
      pll_pbgr_p_ki_i   : in  std_logic_vector(g_coef_bits-1 downto 0));
  end component;

  ------------------------------------------------------------------------------
  -- Serial 16-bit DAC interface (SPI/QSPI/MICROWIRE compatible)
  ------------------------------------------------------------------------------
  component gc_serial_dac
    generic (
      g_num_data_bits  : integer;
      g_num_extra_bits : integer;
      g_num_cs_select  : integer;
      g_sclk_polarity  : integer);
    port (
      clk_i         : in  std_logic;
      rst_n_i       : in  std_logic;
      value_i       : in  std_logic_vector(g_num_data_bits-1 downto 0);
      cs_sel_i      : in  std_logic_vector(g_num_cs_select-1 downto 0);
      load_i        : in  std_logic;
      sclk_divsel_i : in  std_logic_vector(2 downto 0);
      dac_cs_n_o    : out std_logic_vector(g_num_cs_select-1 downto 0);
      dac_sclk_o    : out std_logic;
      dac_sdata_o   : out std_logic;
      busy_o        : out std_logic);
  end component;

  ------------------------------------------------------------------------------
  -- Comparator
  ------------------------------------------------------------------------------
  component gc_comparator is
    generic (
      g_IN_WIDTH : natural := 32);
    port (
      clk_i     : in  std_logic;
      rst_n_i   : in  std_logic                               := '1';
      pol_inv_i : in  std_logic                               := '0';
      enable_i  : in  std_logic                               := '1';
      inp_i     : in  std_logic_vector(g_IN_WIDTH-1 downto 0);
      inn_i     : in  std_logic_vector(g_IN_WIDTH-1 downto 0);
      hys_i     : in  std_logic_vector(g_IN_WIDTH-1 downto 0) := (others => '0');
      out_o     : out std_logic;
      out_p_o   : out std_logic);
  end component gc_comparator;

  ------------------------------------------------------------------------------
  -- Synchronisation FF chain
  ------------------------------------------------------------------------------
  component gc_sync_ffs
    generic (
      g_sync_edge : string := "positive");
    port (
      clk_i    : in  std_logic;
      rst_n_i  : in  std_logic;
      data_i   : in  std_logic;
      synced_o : out std_logic;
      npulse_o : out std_logic;
      ppulse_o : out std_logic);
  end component;

  component gc_sync is
    generic (
      g_sync_edge : string := "positive");
    port (
        clk_i     : in  std_logic;
        rst_n_a_i : in  std_logic;
        d_i       : in  std_logic;
        q_o       : out std_logic);
  end component gc_sync;

  component gc_sync_edge is
    generic (
      g_edge : string := "positive");
    port (
        clk_i     : in  std_logic;
        rst_n_a_i : in  std_logic;
        data_i    : in  std_logic;
        synced_o  : out std_logic;
        pulse_o   : out std_logic);
  end component gc_sync_edge;

  ------------------------------------------------------------------------------
  -- Edge detectors
  ------------------------------------------------------------------------------
  component gc_negedge is
    port (
      clk_i   : in  std_logic;
      rst_n_i : in  std_logic;
      data_i  : in  std_logic;
      pulse_o : out std_logic);
  end component gc_negedge;

  component gc_posedge is
    port (
      clk_i   : in  std_logic;
      rst_n_i : in  std_logic;
      data_i  : in  std_logic;
      pulse_o : out std_logic);
  end component gc_posedge;

  ------------------------------------------------------------------------------
  -- Pulse synchroniser
  ------------------------------------------------------------------------------
  component gc_pulse_synchronizer
    port (
      clk_in_i  : in  std_logic;
      clk_out_i : in  std_logic;
      rst_n_i   : in  std_logic;
      d_ready_o : out std_logic;
      d_p_i     : in  std_logic;
      q_p_o     : out std_logic);
  end component;

  ------------------------------------------------------------------------------
  -- Pulse synchroniser (with reset from both clock domains)
  ------------------------------------------------------------------------------
  component gc_pulse_synchronizer2 is
    port (
      clk_in_i    : in  std_logic;
      rst_in_n_i  : in  std_logic;
      clk_out_i   : in  std_logic;
      rst_out_n_i : in  std_logic;
      d_ready_o   : out std_logic;
      d_ack_p_o   : out std_logic;
      d_p_i       : in  std_logic;
      q_p_o       : out std_logic);
  end component;

  ------------------------------------------------------------------------------
  -- Word synchroniser
  ------------------------------------------------------------------------------
  component gc_sync_word_wr is
    generic (
      g_AUTO_WR : boolean  := FALSE;
      g_WIDTH   : positive := 8);
    port (
      clk_in_i    : in  std_logic;
      rst_in_n_i  : in  std_logic;
      clk_out_i   : in  std_logic;
      rst_out_n_i : in  std_logic;
      data_i      : in  std_logic_vector (g_WIDTH - 1 downto 0);
      wr_i        : in  std_logic := '0';
      busy_o      : out std_logic;
      ack_o       : out std_logic;
      data_o      : out std_logic_vector (g_WIDTH - 1 downto 0);
      wr_o        : out std_logic);
  end component gc_sync_word_wr;

  ------------------------------------------------------------------------------
  -- Frequency meters
  ------------------------------------------------------------------------------
  component gc_frequency_meter
    generic (
      g_WITH_INTERNAL_TIMEBASE : boolean := TRUE;
      g_CLK_SYS_FREQ           : integer;
      g_SYNC_OUT               : boolean := FALSE;
      g_COUNTER_BITS           : integer);
    port (
      clk_sys_i    : in  std_logic;
      clk_in_i     : in  std_logic;
      rst_n_i      : in  std_logic;
      pps_p1_i     : in  std_logic;
      freq_o       : out std_logic_vector(g_COUNTER_BITS-1 downto 0);
      freq_valid_o : out std_logic);
  end component;

  component gc_multichannel_frequency_meter is
    generic (
      g_with_internal_timebase : boolean;
      g_clk_sys_freq           : integer;
      g_counter_bits           : integer;
      g_channels               : integer);
    port (
      clk_sys_i     : in  std_logic;
      clk_in_i      : in  std_logic_vector(g_channels -1 downto 0);
      rst_n_i       : in  std_logic;
      pps_p1_i      : in  std_logic;
      channel_sel_i : in  std_logic_vector(3 downto 0);
      freq_o        : out std_logic_vector(g_counter_bits-1 downto 0);
      freq_valid_o  : out std_logic);
  end component gc_multichannel_frequency_meter;

  ------------------------------------------------------------------------------
  -- Time-division multiplexer with round robin arbitration
  ------------------------------------------------------------------------------
  component gc_arbitrated_mux
    generic (
      g_num_inputs : integer;
      g_width      : integer);
    port (
      clk_i        : in  std_logic;
      rst_n_i      : in  std_logic;
      d_i          : in  std_logic_vector(g_num_inputs * g_width-1 downto 0);
      d_valid_i    : in  std_logic_vector(g_num_inputs-1 downto 0);
      d_req_o      : out std_logic_vector(g_num_inputs-1 downto 0);
      q_o          : out std_logic_vector(g_width-1 downto 0);
      q_valid_o    : out std_logic;
      q_input_id_o : out std_logic_vector(f_log2_ceil(g_num_inputs)-1 downto 0));
  end component;

  ------------------------------------------------------------------------------
  -- Power-On reset generator
  ------------------------------------------------------------------------------
  component gc_reset is
    generic(
      g_clocks    : natural := 1;
      g_logdelay  : natural := 10;
      g_syncdepth : natural := 3);
    port(
      free_clk_i : in  std_logic;
      locked_i   : in  std_logic := '1';  -- All the PLL locked signals ANDed together
      clks_i     : in  std_logic_vector(g_clocks-1 downto 0);
      rstn_o     : out std_logic_vector(g_clocks-1 downto 0));
  end component;

  ------------------------------------------------------------------------------
  -- Multiple clock domain reset generator and synchronizer with
  -- Asynchronous Assert and Syncrhonous Deassert (AASD)
  ------------------------------------------------------------------------------
  component gc_reset_multi_aasd is
    generic (
      g_CLOCKS  : natural;
      g_RST_LEN : natural);
    port (
      arst_i  : in  std_logic := '1';
      clks_i  : in  std_logic_vector(g_CLOCKS-1 downto 0);
      rst_n_o : out std_logic_vector(g_CLOCKS-1 downto 0));
  end component gc_reset_multi_aasd;

  ------------------------------------------------------------------------------
  -- Power-On reset generator of synchronous single reset from multiple
  -- asynchronous input reset signals
  ------------------------------------------------------------------------------
  component gc_single_reset_gen is
    generic(
      g_out_reg_depth     : natural :=2;
      g_rst_in_num        : natural :=2);
    port (
      clk_i               : in std_logic;
      rst_signals_n_a_i   : in std_logic_vector(g_rst_in_num-1 downto 0);
      rst_n_o             : out std_logic
    );
  end component;


  ------------------------------------------------------------------------------
  -- Round robin arbiter
  ------------------------------------------------------------------------------
  component gc_rr_arbiter
    generic (
      g_size : integer);
    port (
      clk_i        : in  std_logic;
      rst_n_i      : in  std_logic;
      req_i        : in  std_logic_vector(g_size-1 downto 0);
      grant_o      : out std_logic_vector(g_size-1 downto 0);
      grant_comb_o : out std_logic_vector(g_size-1 downto 0));
  end component;

  ------------------------------------------------------------------------------
  -- Pack or unpack words
  ------------------------------------------------------------------------------
  component gc_word_packer
    generic (
      g_input_width  : integer;
      g_output_width : integer);
    port (
      clk_i     : in  std_logic;
      rst_n_i   : in  std_logic;
      d_i       : in  std_logic_vector(g_input_width-1 downto 0);
      d_valid_i : in  std_logic;
      d_req_o   : out std_logic;
      flush_i   : in  std_logic := '0';
      q_o       : out std_logic_vector(g_output_width-1 downto 0);
      q_valid_o : out std_logic;
      q_req_i   : in  std_logic);
  end component;

  ------------------------------------------------------------------------------
  -- Adder
  ------------------------------------------------------------------------------
  component gc_big_adder is
    generic(
      g_data_bits : natural := 64;
      g_parts     : natural := 4);
    port(
      clk_i   : in  std_logic;
      stall_i : in  std_logic := '0';
      a_i     : in  std_logic_vector(g_data_bits-1 downto 0);
      b_i     : in  std_logic_vector(g_data_bits-1 downto 0);
      c_i     : in  std_logic := '0';
      c1_o    : out std_logic;
      x2_o    : out std_logic_vector(g_data_bits-1 downto 0);
      c2_o    : out std_logic);
  end component;

  ------------------------------------------------------------------------------
  -- I2C slave
  ------------------------------------------------------------------------------
  constant c_i2cs_idle      : std_logic_vector(1 downto 0) := "00";
  constant c_i2cs_addr_good : std_logic_vector(1 downto 0) := "01";
  constant c_i2cs_rd_done   : std_logic_vector(1 downto 0) := "10";
  constant c_i2cs_wr_done   : std_logic_vector(1 downto 0) := "11";

  component gc_i2c_slave is
    generic
      (
        -- Length of glitch filter
        -- 0 - SCL and SDA lines are passed only through synchronizer
        -- 1 - one clk_i glitches filtered
        -- 2 - two clk_i glitches filtered
        g_gf_len : natural := 0;
        -- Automatically ACK reception upon address match.
        g_auto_addr_ack : boolean := FALSE
        );
    port
      (
        -- Clock, reset ports
        clk_i   : in std_logic;
        rst_n_i : in std_logic;

        -- I2C lines
        scl_i    : in  std_logic;
        scl_o    : out std_logic;
        scl_en_o : out std_logic;
        sda_i    : in  std_logic;
        sda_o    : out std_logic;
        sda_en_o : out std_logic;

        -- Slave address
        i2c_addr_i : in std_logic_vector(6 downto 0);

        -- ACK input, should be set after done_p_o = '1'
        -- (note that the bit is reversed wrt I2C ACK bit)
        -- '1' - ACK
        -- '0' - NACK
        ack_i : in std_logic;

        -- Byte to send, should be loaded while done_p_o = '1'
        tx_byte_i : in std_logic_vector(7 downto 0);

        -- Received byte, valid after done_p_o = '1'
        rx_byte_o : out std_logic_vector(7 downto 0);

        -- Pulse outputs signaling various I2C actions
        -- Start and stop conditions
        i2c_sta_p_o   : out std_logic;
        i2c_sto_p_o   : out std_logic;
        -- Received address corresponds addr_i
        addr_good_p_o : out std_logic;
        -- Read and write done
        r_done_p_o    : out std_logic;
        w_done_p_o    : out std_logic;

        -- I2C bus operation, set after address detection
        -- '0' - write
        -- '1' - read
        op_o : out std_logic
        );
  end component gc_i2c_slave;

  ------------------------------------------------------------------------------
  -- Glitch filter
  ------------------------------------------------------------------------------
  component gc_glitch_filt is
    generic
      (
        -- Length of glitch filter:
        -- g_len = 1 => data width should be > 1 clk_i cycle
        -- g_len = 2 => data width should be > 2 clk_i cycle
        -- etc.
        g_len : natural := 4
        );
    port
      (
        clk_i   : in std_logic;
        rst_n_i : in std_logic;

        -- Data input
        dat_i : in std_logic;

        -- Data output
        -- latency: g_len+1 clk_i cycles
        dat_o : out std_logic
        );
  end component gc_glitch_filt;

  ------------------------------------------------------------------------------
  -- Dynamic glitch filter
  ------------------------------------------------------------------------------
  component gc_dyn_glitch_filt is
    generic
      (
        -- Number of bit of the glitch filter length input
        g_len_width : natural := 8
        );
    port
      (
        clk_i   : in std_logic;
        rst_n_i : in std_logic;

        -- Glitch filter length
        len_i : in std_logic_vector(g_len_width-1 downto 0);

        -- Data input
        dat_i : in std_logic;

        -- Data output
        -- latency: g_len+1 clk_i cycles
        dat_o : out std_logic
        );
  end component gc_dyn_glitch_filt;

  ------------------------------------------------------------------------------
  -- FSM Watchdog Timer
  ------------------------------------------------------------------------------
  component gc_fsm_watchdog is
    generic
      (
        -- Maximum value of watchdog timer in clk_i cycles
        g_wdt_max : positive := 65535
        );
    port
      (
        -- Clock and active-low reset line
        clk_i   : in std_logic;
        rst_n_i : in std_logic;

        -- Active-high watchdog timer reset line, synchronous to clk_i
        wdt_rst_i : in std_logic;

        -- Active-high reset output, synchronous to clk_i
        fsm_rst_o : out std_logic
        );
  end component gc_fsm_watchdog;

  ------------------------------------------------------------------------------
  -- Bicolor LED controller
  ------------------------------------------------------------------------------
  constant c_led_red       : std_logic_vector(1 downto 0) := "10";
  constant c_led_green     : std_logic_vector(1 downto 0) := "01";
  constant c_led_red_green : std_logic_vector(1 downto 0) := "11";
  constant c_led_off       : std_logic_vector(1 downto 0) := "00";

  component gc_bicolor_led_ctrl
    generic(
      g_nb_column    : natural := 4;
      g_nb_line      : natural := 2;
      g_clk_freq     : natural := 125000000;  -- in Hz
      g_refresh_rate : natural := 250         -- in Hz
      );
    port
      (
        rst_n_i         : in  std_logic;
        clk_i           : in  std_logic;
        led_intensity_i : in  std_logic_vector(6 downto 0);
        led_state_i     : in  std_logic_vector((g_nb_line * g_nb_column * 2) - 1 downto 0);
        column_o        : out std_logic_vector(g_nb_column - 1 downto 0);
        line_o          : out std_logic_vector(g_nb_line - 1 downto 0);
        line_oen_o      : out std_logic_vector(g_nb_line - 1 downto 0)
        );
  end component;

  component gc_sync_register is
    generic (
      g_width : integer);
    port (
      clk_i     : in  std_logic;
      rst_n_a_i : in  std_logic;
      d_i       : in  std_logic_vector(g_width-1 downto 0);
      q_o       : out std_logic_vector(g_width-1 downto 0));
  end component gc_sync_register;

  component gc_async_signals_input_stage is
    generic (
      g_signal_num                 : integer;
      g_extended_pulse_width       : integer;
      g_dglitch_filter_len         : integer);
    port (
      clk_i                        : in std_logic;
      rst_n_i                      : in std_logic;
      signals_a_i                  : in  std_logic_vector(g_signal_num-1 downto 0);
      config_active_i              : in  std_logic_vector(g_signal_num-1 downto 0);
      signals_o                    : out std_logic_vector(g_signal_num-1 downto 0);
      signals_p1_o                 : out std_logic_vector(g_signal_num-1 downto 0);
      signals_pN_o                 : out std_logic_vector(g_signal_num-1 downto 0));
  end component;


  ------------------------------------------------------------------------------
  -- Priority encoder
  ------------------------------------------------------------------------------
  component gc_prio_encoder is
  generic (
    g_width : integer);
  port (
    d_i     : in  std_logic_vector(g_width-1 downto 0);
    therm_o : out std_logic_vector(g_width-1 downto 0));
  end component;

  ------------------------------------------------------------------------------
  -- Delay generator
  ------------------------------------------------------------------------------
  component gc_delay_gen is
  generic(
    g_delay_cycles : in natural;
    g_data_width   : in natural);

  port(clk_i   : in  std_logic;
       rst_n_i : in  std_logic;
       d_i     : in  std_logic_vector(g_data_width - 1 downto 0);
       q_o     : out std_logic_vector(g_data_width - 1 downto 0));
  end component;

  ------------------------------------------------------------------------------
  -- One-wire interface to DS1820 and DS1822
  ------------------------------------------------------------------------------

  -- Deprecated! Kept only for backward compatibility.
  -- Please use gc_ds1282x_readout instead
  component gc_ds182x_interface is
    generic (
      freq               : integer := 40;
      g_USE_INTERNAL_PPS : boolean := false);
    port (
      clk_i     : in    std_logic;
      rst_n_i   : in    std_logic;
      pps_p_i   : in    std_logic;
      onewire_b : inout std_logic;
      id_o      : out   std_logic_vector(63 downto 0);
      temper_o  : out   std_logic_vector(15 downto 0);
      id_read_o : out   std_logic;
      id_ok_o   : out   std_logic);
  end component gc_ds182x_interface;

  component gc_ds182x_readout is
    generic (
      g_CLOCK_FREQ_KHZ   : integer := 40000;
      g_USE_INTERNAL_PPS : boolean := false);
    port (
      clk_i     : in    std_logic;
      rst_n_i   : in    std_logic;
      pps_p_i   : in    std_logic;
      onewire_b : inout std_logic;
      id_o      : out   std_logic_vector(63 downto 0);
      temper_o  : out   std_logic_vector(15 downto 0);
      id_read_o : out   std_logic;
      id_ok_o   : out   std_logic);
  end component gc_ds182x_readout;

  component gc_dec_8b10b is
    port (
      clk_i       : in  std_logic;
      rst_n_i     : in  std_logic;
      in_10b_i    : in  std_logic_vector(9 downto 0);
      ctrl_o      : out std_logic;
      code_err_o  : out std_logic;
      rdisp_err_o : out std_logic;
      out_8b_o    : out std_logic_vector(7 downto 0));
  end component gc_dec_8b10b;

  ------------------------------------------------------------------------------
  -- SFP I2C Adapter
  ------------------------------------------------------------------------------

  component gc_sfp_i2c_adapter is
    port (
      clk_i           : in  std_logic;
      rst_n_i         : in  std_logic;
      scl_i           : in  std_logic;
      sda_i           : in  std_logic;
      sda_en_o        : out std_logic;
      sfp_det_valid_i : in  std_logic;
      sfp_data_i      : in  std_logic_vector (127 downto 0));
  end component gc_sfp_i2c_adapter;

  ------------------------------------------------------------------------------
  -- Asynchronous counter inc/dec pulses
  ------------------------------------------------------------------------------
  component gc_async_counter_diff is
    generic (
      g_bits         : integer := 8;
      g_output_clock : string  := "inc");
    port (
      rst_n_i : in std_logic;
      clk_inc_i : in std_logic;
      clk_dec_i : in std_logic;
      inc_i : in std_logic;
      dec_i : in std_logic;
      counter_o : out std_logic_vector(g_bits downto 0));
  end component gc_async_counter_diff;

end package;

package body gencores_pkg is

  ------------------------------------------------------------------------------
  -- Simple round-robin arbiter:
  --  req = requests (1 = pending request),
  --  pre_grant = previous grant vector (1 cycle delay)
  --  grant = new grant vector
  ------------------------------------------------------------------------------
  procedure f_rr_arbitrate (
    signal req       : in  std_logic_vector;
    signal pre_grant : in  std_logic_vector;
    signal grant     : out std_logic_vector)is

    variable reqs  : std_logic_vector(req'length - 1 downto 0);
    variable gnts  : std_logic_vector(req'length - 1 downto 0);
    variable gnt   : std_logic_vector(req'length - 1 downto 0);
    variable gntM  : std_logic_vector(req'length - 1 downto 0);
    variable zeros : std_logic_vector(req'length - 1 downto 0);

  begin
    zeros := (others => '0');

    -- bit twiddling magic :
    gnt  := req and std_logic_vector(unsigned(not req) + 1);
    reqs := req and not (std_logic_vector(unsigned(pre_grant) - 1) or pre_grant);
    gnts := reqs and std_logic_vector(unsigned(not reqs)+1);

    if(reqs = zeros) then
      gntM := gnt;
    else
      gntM := gnts;
    end if;

    if((req and pre_grant) = zeros) then
      grant <= gntM;
    else
      grant <= pre_grant;
    end if;

  end f_rr_arbitrate;

  function f_onehot_decode(x : std_logic_vector; size : integer) return std_logic_vector is
  begin
    for j in 0 to x'left loop
      if x(j) /= '0' then
        return std_logic_vector(to_unsigned(j, size));
      end if;
    end loop;  -- i
    return std_logic_vector(to_unsigned(0, size));
  end f_onehot_decode;



  ------------------------------------------------------------------------------
  -- Carry ripple
  ------------------------------------------------------------------------------
  function f_big_ripple(a, b : std_logic_vector; c : std_logic) return std_logic_vector is
    constant len        : natural := a'length;
    variable aw, bw, rw : std_logic_vector(len+1 downto 0);
    variable x          : std_logic_vector(len downto 0);
  begin
    aw := "0" & a & c;
    bw := "0" & b & c;
    rw := std_logic_vector(unsigned(aw) + unsigned(bw));
    x  := rw(len+1 downto 1);
    return x;
  end f_big_ripple;


  ------------------------------------------------------------------------------
  -- Gray encoder
  ------------------------------------------------------------------------------
  function f_gray_encode(x : std_logic_vector) return std_logic_vector is
    variable o : std_logic_vector(x'length downto 0);
  begin
    o := (x & '0') xor ('0' & x);
    return o(x'length downto 1);
  end f_gray_encode;

  ------------------------------------------------------------------------------
  -- Gray decoder
  --  call with step=1
  ------------------------------------------------------------------------------
  function f_gray_decode(x : std_logic_vector; step : natural) return std_logic_vector is
    constant len : natural                          := x'length;
    alias y      : std_logic_vector(len-1 downto 0) is x;
    variable z   : std_logic_vector(len-1 downto 0) := (others => '0');
  begin
    if step >= len then
      return y;
    else
      z(len-step-1 downto 0) := y(len-1 downto step);
      return f_gray_decode(y xor z, step+step);
    end if;
  end f_gray_decode;

  ------------------------------------------------------------------------------
  -- Returns log of 2 of a natural number
  ------------------------------------------------------------------------------
  function f_log2_ceil(N : natural) return positive is
  begin
    if N <= 2 then
      return 1;
    elsif N mod 2 = 0 then
      return 1 + f_log2_ceil(N/2);
    else
      return 1 + f_log2_ceil((N+1)/2);
    end if;
  end;

  -- kept for backwards compatibility
  function log2_ceil(N : natural) return positive is
  begin
    return f_log2_ceil(N);
  end;

  ------------------------------------------------------------------------------
  -- Converts a boolean to natural integer (false -> 0, true -> 1)
  ------------------------------------------------------------------------------
  function f_bool2int (b : boolean) return natural is
  begin
    if b then
      return 1;
    else
      return 0;
    end if;
  end;

  ------------------------------------------------------------------------------
  -- Converts a natural integer to boolean (0 -> false, any positive -> true)
  ------------------------------------------------------------------------------
  function f_int2bool (n : natural) return boolean is
  begin
    if n = 0 then
      return false;
    else
      return true;
    end if;
  end;

  function f_to_std_logic(b : boolean) return std_logic is
  begin
    if b then
      return '1';
    else
      return '0';
    end if;
  end f_to_std_logic;

  ------------------------------------------------------------------------------
  -- Perform reduction-OR on an std_logic_vector, return std_logic
  ------------------------------------------------------------------------------
  function f_reduce_or (x : std_logic_vector) return std_logic is
    variable rv : std_logic;
  begin
    rv := '0';
    for n in x'range loop
      rv := rv or x(n);
    end loop;
    return rv;
  end f_reduce_or;

  ------------------------------------------------------------------------------
  -- Convert a character to an 8-bit std_logic_vector
  ------------------------------------------------------------------------------
  function f_to_std_logic_vector (c : character) return std_logic_vector
  is
    variable rv : std_logic_vector(7 downto 0);
  begin
    rv := std_logic_vector(to_unsigned(character'pos(c), 8));
    return rv;
  end function f_to_std_logic_vector;

  ------------------------------------------------------------------------------
  -- Convert a string of characters to a std_logic_vector of bytes.
  -- NOTE: right-most character is stored at rv(7 downto 0).
  ------------------------------------------------------------------------------
  function f_to_std_logic_vector (s : string) return std_logic_vector
  is
    variable rv : std_logic_vector(s'length*8-1 downto 0);
    variable k  : natural;
  begin
    for i in s'range loop
      -- calculate offset within rv
      k := 8*(4-i);

      -- do the character conversion and write to proper offset
      rv(k+7 downto k) := f_to_std_logic_vector(s(i));
    end loop;
    return rv;
  end function f_to_std_logic_vector;

  ------------------------------------------------------------------------------
  -- Functions for short-hand if assignments
  ------------------------------------------------------------------------------
  function f_pick (cond : std_logic; if_1 : std_logic; if_0 : std_logic)
    return std_logic
  is
  begin
    if cond = '1' then
      return if_1;
    else
      return if_0;
    end if;
  end function f_pick;

  function f_pick (cond : std_logic; if_1 : std_logic_vector; if_0 : std_logic_vector)
    return std_logic_vector
  is
  begin
    if cond = '1' then
      return if_1;
    else
      return if_0;
    end if;
  end function f_pick;

  function f_pick (cond : boolean; if_1 : std_logic; if_0 : std_logic)
    return std_logic
  is
  begin
    return f_pick (f_to_std_logic(cond), if_1, if_0);
  end function f_pick;

  function f_pick (cond : boolean; if_1 : std_logic_vector; if_0 : std_logic_vector)
    return std_logic_vector
  is
  begin
    return f_pick (f_to_std_logic(cond), if_1, if_0);
  end function f_pick;

  ------------------------------------------------------------------------------
  -- Functions to convert characters and strings to upper/lower case
  ------------------------------------------------------------------------------

  function to_upper(c : character) return character is
    variable i : integer;
  begin
    i := character'pos(c);
    if (i > 96 and i < 123) then
      i := i - 32;
    end if;
    return character'val(i);
  end function to_upper;

  function to_lower(c : character) return character is
    variable i : integer;
  begin
    i := character'pos(c);
    if (i > 64 and i < 91) then
      i := i + 32;
    end if;
    return character'val(i);
  end function to_lower;

  function to_upper(s : string) return string is
    variable uppercase : string (s'range);
  begin
    for i in s'range loop
      uppercase(i) := to_upper(s(i));
    end loop;
    return uppercase;
  end to_upper;

  function to_lower(s : string) return string is
    variable lowercase : string (s'range);
  begin
    for i in s'range loop
      lowercase(i) := to_lower(s(i));
    end loop;
    return lowercase;
  end to_lower;

  ------------------------------------------------------------------------------
  -- Vector bit reversal
  ------------------------------------------------------------------------------

  function f_reverse_vector (a : in std_logic_vector) return std_logic_vector is
    variable v_result : std_logic_vector(a'reverse_range);
  begin
    for i in a'range loop
      v_result(i) := a(i);
    end loop;
    return v_result;
  end function f_reverse_vector;

end gencores_pkg;
