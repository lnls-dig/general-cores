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

use work.gencores_pkg.all;

entity tb_gc_i2c_slave is
end entity tb_gc_i2c_slave;


architecture behav of tb_gc_i2c_slave is

  --============================================================================
  -- Type declarations
  --============================================================================
  type t_state_mst is
    (
      MST_IDLE,
      MST_W1, MST_W1_ACK,
      MST_W2, MST_W2_ACK,
      MST_W3, MST_W3_ACK,
      MST_R1, MST_R1_ACK,
      MST_R2,
      MST_R3,
      MST_SUCCESS,
      MST_ERR
    );


  type t_state_slv is
    (
      SLV_IDLE,
      SLV_DETOP,
      SLV_R1, SLV_R1_ACK,
      SLV_R2, SLV_R2_ACK,
      SLV_W1, SLV_W1_ACK,
      SLV_W2, SLV_W2_ACK
    );

  --============================================================================
  -- Constant declarations
  --============================================================================
  constant c_clk_per : time := 50 ns;
  constant c_reset_width : time := 31 ns;

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

  --============================================================================
  -- Signal declarations
  --============================================================================
  signal clk, rst_n  : std_logic := '0';
  signal rst         : std_logic;

  signal scl_to_slv  : std_logic;
  signal scl_fr_slv  : std_logic;
  signal scl_en_slv  : std_logic;
  signal sda_to_slv  : std_logic;
  signal sda_fr_slv  : std_logic;
  signal sda_en_slv  : std_logic;

  signal slv_ack     : std_logic;
  signal slv_op      : std_logic;

  signal scl_to_mst  : std_logic;
  signal scl_fr_mst  : std_logic;
  signal scl_en_mst  : std_logic;
  signal sda_to_mst  : std_logic;
  signal sda_fr_mst  : std_logic;
  signal sda_en_mst  : std_logic;

  signal addr        : std_logic_vector(6 downto 0);

  signal txb, rxb    : std_logic_vector(7 downto 0);
  signal rcvd        : std_logic_vector(7 downto 0);

  signal slv_r_done_p    : std_logic;
  signal slv_w_done_p    : std_logic;
  signal slv_addr_good_p : std_logic;
  signal slv_sta_p       : std_logic;
  signal slv_sto_p       : std_logic;

  signal mst_sta     : std_logic;
  signal mst_sto     : std_logic;
  signal mst_rd      : std_logic;
  signal mst_wr      : std_logic;
  signal mst_ack     : std_logic;

  signal mst_dat_in  : std_logic_vector(7 downto 0);
  signal mst_dat_out : std_logic_vector(7 downto 0);

  signal mst_cmd_ack : std_logic;
  signal ack_fr_slv  : std_logic;

  signal state_mst   : t_state_mst;
  signal state_slv   : t_state_slv;

  signal cnt         : unsigned(2 downto 0);
  signal once        : boolean;
  signal tmp         : std_logic_vector(7 downto 0);

--==============================================================================
--  architecture begin
--==============================================================================
begin

  -- CLOCK GENERATION
  p_clk: process
  begin
    clk <= not clk;
    wait for c_clk_per/2;
  end process p_clk;

  -- RESET GENERATION
  rst <= not rst_n;
  p_rst_n: process
  begin
    rst_n <= '0';
    wait for c_reset_width;
    rst_n <= '1';
    wait;
  end process p_rst_n;

  -- DUT INSTANTIATION
  DUT: gc_i2c_slave
    port map
    (
      clk_i         => clk,
      rst_n_i       => rst_n,

      scl_i         => scl_to_slv,
      scl_o         => scl_fr_slv,
      scl_en_o      => scl_en_slv,
      sda_i         => sda_to_slv,
      sda_o         => sda_fr_slv,
      sda_en_o      => sda_en_slv,

      addr_i        => addr,

      ack_i         => slv_ack,

      tx_byte_i     => txb,
      rx_byte_o     => rxb,

      sta_p_o       => slv_sta_p,
      sto_p_o       => slv_sto_p,
      addr_good_p_o => slv_addr_good_p,
      r_done_p_o    => slv_r_done_p,
      w_done_p_o    => slv_w_done_p,
      op_o          => slv_op
    );

  scl_to_slv <= scl_fr_mst when scl_en_mst = '0' else
                scl_fr_slv when scl_en_slv = '1' else
                '1';
  sda_to_slv <= sda_fr_slv when sda_en_slv = '1' else
                sda_fr_mst when sda_en_mst = '0' else
                '1';

  -- MASTER INSTANTIATION
  cmp_master: i2c_master_byte_ctrl
    port map
    (
      clk      => clk,
      rst      => rst,
      nReset   => rst_n,
      ena      => '1',

      clk_cnt  => x"00FA",

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
      scl_i    => scl_to_mst,
      scl_o    => scl_fr_mst,
      scl_oen  => scl_en_mst,
      sda_i    => sda_to_mst,
      sda_o    => sda_fr_mst,
      sda_oen  => sda_en_mst
    );

  -- BUS MODEL
  scl_to_mst <= scl_fr_mst when scl_en_mst = '0' else
                scl_fr_slv when scl_en_slv = '1' else
                '1';

  sda_to_mst <= sda_fr_slv when sda_en_slv = '1' else
                sda_fr_mst when sda_en_mst = '0' else
                '1';

  -- STIMULI
  addr <= "1011110";

  -- I2C SLAVE FSM
  p_slv_fsm: process (clk) is
  begin
    if rising_edge(clk) then
      if (rst_n = '0') then
        state_slv <= SLV_IDLE;
        slv_ack   <= '0';
        txb       <= (others => '0');
      else
        case state_slv is

          -- IDLE, wait for slave to do something
          when SLV_IDLE =>
            if (slv_addr_good_p = '1') then
              slv_ack   <= '1';
              state_slv <= SLV_DETOP;
            end if;

          -- master sent something to our slave, see what
          -- we have to do...
          when SLV_DETOP =>
            if (slv_op = '0') then
              state_slv <= SLV_R1;
            else
              state_slv <= SLV_W1;
            end if;

          -- SLV_R1
          -- when done = '1', the slave goes into
          -- WAIT_ACK state, so we must provide ACK.
          when SLV_R1 =>
            if (slv_r_done_p = '1') then
              state_slv <= SLV_R1_ACK;
              rcvd      <= rxb;
            end if;

          -- tell the slave to ACK, go back to IDLE
          when SLV_R1_ACK =>
            slv_ack   <= '1';
            state_slv <= SLV_R2;

          -- reading second byte from master, wait until
          -- done = '1', and go to R2_ACK state
          when SLV_R2 =>
            if (slv_r_done_p = '1') then
              state_slv <= SLV_R2_ACK;
              rcvd      <= rxb;
            end if;

          -- R2_ACK
          when SLV_R2_ACK =>
            slv_ack   <= '1';
            state_slv <= SLV_IDLE;

          -- loopback received byte
          when SLV_W1 =>
            txb <= rcvd;
            if (slv_w_done_p = '1') then
              state_slv <= SLV_W2;
            end if;

          -- loopback received byte
          when SLV_W2 =>
            txb <= rcvd;
            if (slv_w_done_p = '1') then
              state_slv <= SLV_IDLE;
            end if;

          when others =>
            state_slv <= SLV_IDLE;

        end case;

      end if;
    end if;
  end process p_slv_fsm;

  -- I2C MASTER FSM
  tmp <= mst_dat_out;

  p_mst_fsm: process (clk) is
  begin
    if rising_edge(clk) then
      if (rst_n = '0') then
        state_mst      <= MST_IDLE;
        mst_sta    <= '0';
        mst_wr     <= '0';
        mst_sto    <= '0';
        mst_rd     <= '0';
        mst_dat_in <= (others => '0');
        mst_ack    <= '1';
        cnt        <= (others => '0');
        once       <= true;
      else
        case state_mst is

          when MST_IDLE =>
            state_mst <= MST_W1;

          when MST_W1 =>
            mst_sta <= '1';
            mst_wr  <= '1';
            mst_dat_in <= addr & '0';
            if (mst_cmd_ack = '1') then
              mst_sta <= '0';
              mst_wr  <= '0';
              state_mst <= MST_W1_ACK;
            end if;

          when MST_W1_ACK =>
            cnt <= cnt + 1;
            if (cnt = 7) then
              if (ack_fr_slv = '0') then
                state_mst <= MST_W2;
              else
                state_mst <= MST_ERR;
              end if;
            end if;

          when MST_W2 =>
            mst_wr <= '1';
            mst_dat_in <= x"33";
            if (mst_cmd_ack = '1') then
              mst_wr <= '0';
              state_mst <= MST_W2_ACK;
            end if;

          when MST_W2_ACK =>
            cnt <= cnt + 1;
            if (cnt = 7) then
              if (ack_fr_slv = '0') then
                state_mst <= MST_W3;
              else
                state_mst <= MST_ERR;
              end if;
            end if;

          when MST_W3 =>
            mst_wr <= '1';
            mst_dat_in <= x"12";
            if (mst_cmd_ack = '1') then
              mst_wr  <= '0';
              mst_sto <= '0';
              state_mst <= MST_W3_ACK;
            end if;

          when MST_W3_ACK =>
            cnt <= cnt + 1;
            if (cnt = 7) then
              if (ack_fr_slv = '0') then
                state_mst <= MST_R1;
              else
                state_mst <= MST_ERR;
              end if;
            end if;

          when MST_R1 =>
            mst_sta <= '1';
            mst_wr  <= '1';
            mst_dat_in <= addr & '1';
            if (mst_cmd_ack = '1') then
              mst_sta <= '0';
              mst_wr  <= '0';
              state_mst <= MST_R1_ACK;
            end if;

          when MST_R1_ACK =>
            cnt <= cnt + 1;
            if (cnt = 7) then
              if (ack_fr_slv = '0') then
                state_mst <= MST_R2;
              else
                state_mst <= MST_ERR;
              end if;
            end if;

          when MST_R2 =>
            mst_rd <= '1';
            --mst_sto   <= '1';
            mst_ack <= '0';
            if (mst_cmd_ack = '1') then
              mst_rd  <= '0';
              mst_sto <= '0';
              if (tmp = x"12") then
                state_mst <= MST_R3;
              else
                state_mst <= MST_ERR;
              end if;
            end if;

          when MST_R3 =>
            mst_rd  <= '1';
            mst_sto <= '1';
            mst_ack <= '0';
            if (mst_cmd_ack = '1') then
              mst_rd  <= '0';
              mst_sto <= '0';
              if (tmp = x"12") then
                state_mst <= MST_SUCCESS;
              else
                state_mst <= MST_ERR;
              end if;
            end if;

          when MST_SUCCESS =>
            if (once) then
              report("Success!");
              once <= false;
            end if;

          when MST_ERR =>
            if (once) then
              report("Error!");
              once <= false;
            end if;

          when others =>
            state_mst <= MST_ERR;

        end case;
      end if;
    end if;
  end process p_mst_fsm;
end architecture behav;
--==============================================================================
--  architecture end
--==============================================================================
