--==============================================================================
-- CERN (BE-CO-HT)
-- Testbench for old repeater design
--==============================================================================
--
-- author: Theodor Stana (t.stana@cern.ch)
--
-- date of creation: 2013-02-28
--
-- version: 1.0
--
-- description:
--
-- dependencies:
--
-- references:
--
--==============================================================================
-- GNU LESSER GENERAL PUBLIC LICENSE
--==============================================================================
-- This source file is free software; you can redistribute it and/or modify it
-- under the terms of the GNU Lesser General Public License as published by the
-- Free Software Foundation; either version 2.1 of the License, or (at your
-- option) any later version. This source is distributed in the hope that it
-- will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
-- of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU Lesser General Public License for more details. You should have
-- received a copy of the GNU Lesser General Public License along with this
-- source; if not, download it from http://www.gnu.org/licenses/lgpl-2.1.html
--==============================================================================
-- last changes:
--    2013-02-28   Theodor Stana     t.stana@cern.ch     File created
--==============================================================================
-- TODO: -
--==============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.wishbone_pkg.all;

entity tb_wb_i2c_bridge is
end entity tb_wb_i2c_bridge;


architecture behav of tb_wb_i2c_bridge is

  --============================================================================
  -- Type declarations
  --============================================================================
  type t_state is
    (
      IDLE,
      I2C_ADDR, I2C_ADDR_ACK,

      WB_ADDR_B0, WB_ADDR_B0_ACK,
      WB_ADDR_B1, WB_ADDR_B1_ACK,

      ST_OP,

      RD_RESTART, RD_RESTART_ACK,
      RD, RD_ACK,

      WR, WR_ACK,

      STO,

      SUCCESS,
      ERR
    );

  type t_reg is array(0 to 3) of std_logic_vector(31 downto 0);

  --============================================================================
  -- Constant declarations
  --============================================================================
  constant c_clk_per : time := 50 ns;
  constant c_reset_width : time := 112 ns;

  constant c_nr_masters : positive := 1;
  constant c_nr_slaves  : positive := 2;

  constant c_sval : unsigned := x"424c4f24";
  constant c_eval : unsigned := c_sval + x"A";

  --============================================================================
  -- Component declarations
  --============================================================================
  -- I2C master
  component i2c_master_byte_ctrl is
    port
    (
      clk    : in std_logic;
      rst    : in std_logic; -- synchronous active high reset (WISHBONE compatible)
      nReset : in std_logic;	-- asynchornous active low reset (FPGA compatible)
      ena    : in std_logic; -- core enable signal

      clk_cnt : in unsigned(15 downto 0);	-- 4x SCL

      -- input signals
      start,
      stop,
      read,
      write,
      ack_in : std_logic;
      din    : in std_logic_vector(7 downto 0);

      -- output signals
      cmd_ack  : out std_logic; -- command done
      ack_out  : out std_logic;
      i2c_busy : out std_logic; -- arbitration lost
      i2c_al   : out std_logic; -- i2c bus busy
      dout     : out std_logic_vector(7 downto 0);

      -- i2c lines
      scl_i   : in std_logic;  -- i2c clock line input
      scl_o   : out std_logic; -- i2c clock line output
      scl_oen : out std_logic; -- i2c clock line output enable, active low
      sda_i   : in std_logic;  -- i2c data line input
      sda_o   : out std_logic; -- i2c data line output
      sda_oen : out std_logic  -- i2c data line output enable, active low
    );
  end component i2c_master_byte_ctrl;

  -- I2C bus model
  component i2c_bus_model is
    generic
    (
      g_nr_masters : positive := 1;
      g_nr_slaves  : positive := 1
    );
    port
    (
      -- Input ports from master lines
      mscl_i : in  std_logic_vector(g_nr_masters-1 downto 0);
      msda_i : in  std_logic_vector(g_nr_masters-1 downto 0);

      -- Input ports from slave lines
      sscl_i : in  std_logic_vector(g_nr_slaves-1 downto 0);
      ssda_i : in  std_logic_vector(g_nr_slaves-1 downto 0);

      -- SCL and SDA line outputs
      scl_o  : out std_logic;
      sda_o  : out std_logic
    );
  end component i2c_bus_model;

  --============================================================================
  -- Signal declarations
  --============================================================================
  -- Clock, reset signals
  signal clk, rst_n    : std_logic := '0';
  signal rst           : std_logic;

  -- Slave-side I2C signals
  signal scl_to_slv    : std_logic;
  signal scl_fr_slv    : std_logic;
  signal scl_en_slv    : std_logic;
  signal sda_to_slv    : std_logic;
  signal sda_fr_slv    : std_logic;
  signal sda_en_slv    : std_logic;

  signal scl_to_slv_1  : std_logic;
  signal scl_fr_slv_1  : std_logic;
  signal scl_en_slv_1  : std_logic;
  signal sda_to_slv_1  : std_logic;
  signal sda_fr_slv_1  : std_logic;
  signal sda_en_slv_1  : std_logic;

  -- SCL and SDA signals from slaves
  signal sscl, ssda    : std_logic_vector(c_nr_slaves-1 downto 0);

  -- Master-side I2C signals
  signal scl_to_mst    : std_logic;
  signal scl_fr_mst    : std_logic;
  signal scl_en_mst    : std_logic;
  signal sda_to_mst    : std_logic;
  signal sda_fr_mst    : std_logic;
  signal sda_en_mst    : std_logic;

  -- SCL and SDA signals from master
  signal mscl, msda    : std_logic_vector(c_nr_masters-1 downto 0);

  -- I2C bus signals
  signal scl, sda      : std_logic;

  -- I2C address, done
  signal slv_addr      : std_logic_vector(6 downto 0);
  signal i2c_tip       : std_logic;
  signal i2c_err       : std_logic;
  signal i2c_tip_1     : std_logic;
  signal i2c_err_1     : std_logic;

  -- I2C master signals
  signal mst_sta       : std_logic;
  signal mst_sto       : std_logic;
  signal mst_rd        : std_logic;
  signal mst_wr        : std_logic;
  signal mst_ack       : std_logic;
  signal mst_dat_in    : std_logic_vector(7 downto 0);
  signal mst_dat_out   : std_logic_vector(7 downto 0);
  signal mst_cmd_ack   : std_logic;
  signal ack_fr_slv    : std_logic;

  -- Master FSM signals
  signal state         : t_state;
  signal mst_fsm_op    : std_logic;
  signal mst_fsm_start : std_logic;
  signal stim_cnt      : unsigned(31 downto 0);

  -- misc signals
  signal cnt           : unsigned(2 downto 0);
  signal once          : boolean;

  signal byte_cnt      : unsigned(1 downto 0);
  signal rcvd          : std_logic_vector(31 downto 0);
  signal read4         : std_logic;
  signal send          : std_logic_vector(31 downto 0);
  signal wrote         : std_logic;
  signal adr           : std_logic_vector(31 downto 0);

  -- Wishbone signals
  signal wb_stb        : std_logic;
  signal wb_cyc        : std_logic;
  signal wb_sel        : std_logic_vector(3 downto 0);
  signal wb_we         : std_logic;
  signal wb_dat_m2s    : std_logic_vector(31 downto 0);
  signal wb_dat_s2m    : std_logic_vector(31 downto 0);
  signal wb_adr        : std_logic_vector(31 downto 0);
  signal wb_ack        : std_logic;

  signal reg           : t_reg;

  signal wb_stb_1      : std_logic;
  signal wb_cyc_1      : std_logic;
  signal wb_sel_1      : std_logic_vector(3 downto 0);
  signal wb_we_1       : std_logic;
  signal wb_dat_m2s_1  : std_logic_vector(31 downto 0);
  signal wb_dat_s2m_1  : std_logic_vector(31 downto 0);
  signal wb_adr_1      : std_logic_vector(31 downto 0);
  signal wb_ack_1      : std_logic;

  signal reg_1         : t_reg;

--==============================================================================
--  architecture begin
--==============================================================================
begin

  --============================================================================
  -- Reset and clock generation
  --============================================================================
  -- clock
  p_clk: process
  begin
    clk <= not clk;
    wait for c_clk_per/2;
  end process p_clk;

  -- reset
  rst <= not rst_n;
  p_rst_n: process
  begin
    rst_n <= '0';
    wait for c_reset_width;
    rst_n <= '1';
    wait;
  end process p_rst_n;

  --============================================================================
  -- DUT instantiation
  --============================================================================
  ------------------------------------------------------------------------------
  -- SLAVE 1
  ------------------------------------------------------------------------------
  -- First, the instantiation itself
  DUT : wb_i2c_bridge
    port map
    (
      -- Clock, reset
      clk_i      => clk,
      rst_n_i    => rst_n,

      -- I2C lines
      scl_i      => scl,
      scl_o      => scl_fr_slv,
      scl_en_o   => scl_en_slv,
      sda_i      => sda,
      sda_o      => sda_fr_slv,
      sda_en_o   => sda_en_slv,

      -- I2C address and status
      i2c_addr_i => "1011110",
      tip_o      => i2c_tip,
      err_p_o    => i2c_err,

      -- Wishbone master signals
      wbm_stb_o  => wb_stb,
      wbm_cyc_o  => wb_cyc,
      wbm_sel_o  => wb_sel,
      wbm_we_o   => wb_we,
      wbm_dat_i  => wb_dat_s2m,
      wbm_dat_o  => wb_dat_m2s,
      wbm_adr_o  => wb_adr,
      wbm_ack_i  => wb_ack,
      wbm_rty_i  => '0',
      wbm_err_i  => '0'
    );

  -- Then, the tri-state buffer for the I2C lines
  sscl(0) <= scl_fr_slv when (scl_en_slv = '1') else
             '1';
  ssda(0) <= sda_fr_slv when (sda_en_slv = '1') else
             '1';

  ------------------------------------------------------------------------------
  -- SLAVE 2
  ------------------------------------------------------------------------------
  -- First, the instantiation itself
  DUT_1 : wb_i2c_bridge
    port map
    (
      -- Clock, reset
      clk_i      => clk,
      rst_n_i    => rst_n,

      -- I2C lines
      scl_i      => scl,
      scl_o      => scl_fr_slv_1,
      scl_en_o   => scl_en_slv_1,
      sda_i      => sda,
      sda_o      => sda_fr_slv_1,
      sda_en_o   => sda_en_slv_1,

      -- I2C address and status
      i2c_addr_i => "1011101",
      tip_o      => i2c_tip_1,
      err_p_o    => i2c_err_1,

      -- Wishbone master signals
      wbm_stb_o  => wb_stb_1,
      wbm_cyc_o  => wb_cyc_1,
      wbm_sel_o  => wb_sel_1,
      wbm_we_o   => wb_we_1,
      wbm_dat_i  => wb_dat_s2m_1,
      wbm_dat_o  => wb_dat_m2s_1,
      wbm_adr_o  => wb_adr_1,
      wbm_ack_i  => wb_ack_1,
      wbm_rty_i  => '0',
      wbm_err_i  => '0'
    );

  -- Then, the tri-state buffer for the I2C lines
  sscl(1) <= scl_fr_slv_1 when (scl_en_slv_1 = '1') else
             '1';
  ssda(1) <= sda_fr_slv_1 when (sda_en_slv_1 = '1') else
             '1';

  --============================================================================
  -- Master instantiation
  --============================================================================
  -- First, the component instantiation
  cmp_master: i2c_master_byte_ctrl
    port map
    (
      clk      => clk,
      rst      => rst,
      nReset   => rst_n,
      ena      => '1',

      clk_cnt  => x"0027",

      -- input signals
      start    => mst_sta,
      stop     => mst_sto,
      read     => mst_rd,
      write    => mst_wr,
      ack_in   => mst_ack,
      din      => mst_dat_in,

      -- output signals
      cmd_ack  => mst_cmd_ack,
      ack_out  => ack_fr_slv,
      i2c_busy => open,
      i2c_al   => open,
      dout     => mst_dat_out,

      -- i2c lines
      scl_i    => scl,
      scl_o    => scl_fr_mst,
      scl_oen  => scl_en_mst,
      sda_i    => sda,
      sda_o    => sda_fr_mst,
      sda_oen  => sda_en_mst
    );

  -- Then, the tri-state buffers on the line
  mscl(0) <= scl_fr_mst when (scl_en_mst = '0') else
             '1';
  msda(0) <= sda_fr_mst when (sda_en_mst = '0') else
             '1';

  --============================================================================
  -- Bus model instantiation and connection to master and slaves
  --============================================================================
  cmp_i2c_bus : i2c_bus_model
    generic map
    (
      g_nr_masters => c_nr_masters,
      g_nr_slaves  => c_nr_slaves
    )
    port map
    (
      mscl_i => mscl,
      msda_i => msda,
      sscl_i => sscl,
      ssda_i => ssda,
      scl_o  => scl,
      sda_o  => sda
    );

  --============================================================================
  -- I2C Master FSM
  --============================================================================
  -- This FSM controls the signals to the master component to implement the I2C
  -- protocol defined together with ELMA. The FSM is controlled by the
  -- stimuli process below
  p_mst_fsm : process (clk) is
  begin
    if rising_edge(clk) then
      if (rst_n = '0') then
        state      <= IDLE;
        mst_sta    <= '0';
        mst_wr     <= '0';
        mst_sto    <= '0';
        mst_rd     <= '0';
        mst_dat_in <= (others => '0');
        mst_ack    <= '0';
        cnt        <= (others => '0');
        once       <= true;
        byte_cnt   <= (others => '0');
        rcvd       <= (others => '0');
        wrote      <= '0';
        send       <= (others => '0');
      else
        case state is

          when IDLE =>
            if (mst_fsm_start = '1') then
              state <= I2C_ADDR;
              send  <= std_logic_vector(stim_cnt);
            end if;

          when I2C_ADDR =>
            mst_sta   <= '1';
            mst_wr    <= '1';
            mst_dat_in <= slv_addr & '0';
            if (mst_cmd_ack = '1') then
              mst_sta <= '0';
              mst_wr  <= '0';
              state   <= I2C_ADDR_ACK;
            end if;

          when I2C_ADDR_ACK =>
            cnt <= cnt + 1;
            if (cnt = 7) then
              if (ack_fr_slv = '0') then
                state <= WB_ADDR_B0;
              else
                state <= ERR;
              end if;
            end if;

          when WB_ADDR_B0 =>
            mst_wr <= '1';
            mst_dat_in <= adr(15 downto 8);
            if (mst_cmd_ack = '1') then
              mst_wr <= '0';
              state  <= WB_ADDR_B0_ACK;
            end if;

          when WB_ADDR_B0_ACK =>
            cnt <= cnt + 1;
            if (cnt = 7) then
              if (ack_fr_slv = '0') then
                state <= WB_ADDR_B1;
              else
                state <= ERR;
              end if;
            end if;

          when WB_ADDR_B1 =>
            mst_wr <= '1';
            mst_dat_in <= adr(7 downto 0);
            if (mst_cmd_ack = '1') then
              mst_wr <= '0';
              state  <= WB_ADDR_B1_ACK;
            end if;

          when WB_ADDR_B1_ACK =>
            cnt <= cnt + 1;
            if (cnt = 7) then
              if (ack_fr_slv = '0') then
                state <= ST_OP;
              else
                state <= ERR;
              end if;
            end if;

          when ST_OP =>
            if (mst_fsm_op = '1') then
              state <= RD_RESTART;
            else
              state <= WR;
            end if;

          when RD_RESTART =>
            mst_wr <= '1';
            mst_dat_in <= slv_addr & '1';
            mst_sta <= '1';
            if (mst_cmd_ack = '1') then
              mst_sta <= '0';
              mst_wr  <= '0';
              state <= RD_RESTART_ACK;
            end if;

          when RD_RESTART_ACK =>
            cnt <= cnt + 1;
            if (cnt = 7) then
              if (ack_fr_slv = '0') then
                state <= RD;
              else
                state <= ERR;
              end if;
            end if;

          when RD =>
            mst_rd <= '1';
            mst_ack <= '0';
            if (byte_cnt = 3) then
              mst_ack <= '1';
            end if;
            if (mst_cmd_ack = '1') then
              mst_rd <= '0';
              byte_cnt <= byte_cnt + 1;
              rcvd     <= mst_dat_out & rcvd(31 downto 8);
              mst_ack  <= '0';
              state    <= RD;
              if (byte_cnt = 3) then
                state  <= STO;
              end if;
            end if;

          when RD_ACK =>
            cnt <= cnt + 1;
            if (cnt = 7) then
              byte_cnt <= byte_cnt + 1;
              rcvd     <= mst_dat_out & rcvd(31 downto 8);
              mst_ack  <= '0';
              state    <= RD;
              if (byte_cnt = 3) then
                state  <= STO;
              end if;
            end if;

          when WR =>
            mst_wr <= '1';
            mst_dat_in <= send(7 downto 0);
            if (mst_cmd_ack = '1') then
              mst_wr <= '0';
              state  <= WR_ACK;
            end if;

          when WR_ACK =>
            cnt <= cnt + 1;
            if (cnt = 7) then
              if (ack_fr_slv = '0') then
                byte_cnt <= byte_cnt + 1;
                send     <= x"00" & send(31 downto 8);
                state    <= WR;
                if (byte_cnt = 3) then
                  state  <= STO;
                end if;
              else
                state <= ERR;
              end if;
            end if;

          when STO =>
            mst_sto <= '1';
            if (mst_cmd_ack = '1') then
              mst_sto <= '0';
              state   <= IDLE;
            end if;

          when ERR =>
            if (once) then
              report("Error!");
              once <= false;
            end if;

          when others =>
            state <= ERR;

        end case;
      end if;
    end if;
  end process p_mst_fsm;

  --============================================================================
  -- Wishbone slaves
  --============================================================================
  -- First slave
  p_wb_slv: process (clk) is
  begin
    if rising_edge(clk) then
      if (rst_n = '0') then
        reg <= (
               x"00000000",
               x"00000000",
               x"00000000",
               x"00000000"
             );
        wb_ack <= '0';
        wb_dat_s2m <= (others => '0');
      else
        wb_ack <= '0';
        if (wb_cyc = '1') and (wb_stb = '1') then
          wb_ack <= '1';
          wb_dat_s2m <= reg(to_integer(unsigned(wb_adr)));
          if (wb_we = '1') then
            reg(to_integer(unsigned(wb_adr))) <= wb_dat_m2s;
          end if;
        end if;
      end if;
    end if;
  end process p_wb_slv;

  -- Second slave
  p_wb_slv_1: process (clk) is
  begin
    if rising_edge(clk) then
      if (rst_n = '0') then
        reg_1 <= (
                   x"00000000",
                   x"00000000",
                   x"00000000",
                   x"00000000"
                 );
        wb_ack_1 <= '0';
        wb_dat_s2m_1 <= (others => '0');
      else
        wb_ack_1 <= '0';
        if (wb_cyc_1 = '1') and (wb_stb_1 = '1') then
          wb_ack_1 <= '1';
          wb_dat_s2m_1 <= reg_1(to_integer(unsigned(wb_adr_1)));
          if (wb_we_1 = '1') then
            reg_1(to_integer(unsigned(wb_adr_1))) <= wb_dat_m2s_1;
          end if;
        end if;
      end if;
    end if;
  end process p_wb_slv_1;

  --============================================================================
  -- A stimuli process to control the I2C FSM
  --============================================================================
  p_stim : process (rst_n, state)
  begin
    if (rst_n = '0') then
      stim_cnt      <= c_sval; --(others => '0');
      mst_fsm_start <= '0';
      mst_fsm_op    <= '0';
      slv_addr      <= "1011110";
      adr           <= (others => '0');
    elsif (state = IDLE) then
      stim_cnt      <= stim_cnt + 1;
      mst_fsm_start <= '1';
      adr(1 downto 0) <= std_logic_vector(stim_cnt(1 downto 0));
      if (stim_cnt(0) = '1') then
        slv_addr <= "1011110";
      else
        slv_addr <= "1011101";
      end if;
      case to_integer(stim_cnt) is
        when to_integer(c_sval) to to_integer(c_eval) =>
          mst_fsm_op <= '0';
        when others =>
          mst_fsm_op <= '1';
      end case;
    end if;
  end process p_stim;

end architecture behav;
--==============================================================================
--  architecture end
--==============================================================================
