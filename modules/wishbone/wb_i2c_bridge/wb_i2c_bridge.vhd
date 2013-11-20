--==============================================================================
-- CERN (BE-CO-HT)
-- VME Board Control Protocol (VBCP) to Wishbone bridge for VME64x crates
--==============================================================================
--
-- author: Theodor Stana (t.stana@cern.ch)
--
-- date of creation: 2013-02-15
--
-- version: 1.0
--
-- description:
--    This module implements an I2C to Wishbone bridge for VME64x crates,
--    following the protocol defined in [1]. It uses a low-level I2C slave module
--    reacting to transfers initiated by an I2C master, in this case, a VME64x
--    system monitor (SysMon) [2].
--
--    The I2C slave module sets its done_p_o pin high when the I2C address received
--    from the SysMon corresponds to the slave address and every time a byte has
--    been received or sent correctly. The done_p_o pin of the slave module is
--    de-asserted when the slave performs a transfer.
--
--    The bridge module employs a state machine that checks for low-to-high
--    transitions in the slave done_p_o pin and shifts bytes in and out over I2C
--    to implement the protocol defined in [1].
--
-- dependencies:
--    none.
--
-- references:
--    [1] ELMA SNMP Specification
--        http://www.ohwr.org/documents/227
--    [2] System Monitor's Users Manual
--        http://www.ohwr.org/documents/226
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

entity wb_i2c_bridge is
  port
  (
    -- Clock, reset
    clk_i      : in  std_logic;
    rst_n_i    : in  std_logic;

    -- I2C lines
    sda_en_o   : out std_logic;
    sda_i      : in  std_logic;
    sda_o      : out std_logic;
    scl_en_o   : out std_logic;
    scl_i      : in  std_logic;
    scl_o      : out std_logic;

    -- I2C address
    i2c_addr_i : in  std_logic_vector(6 downto 0);

    -- Transfer In Progress (TIP) and Error outputs
    -- TIP : '1' when the I2C slave detects a matching I2C address, thus a
    --           transfer is in progress
    --       '0' when idle
    -- ERR : '1' when the SysMon attempts to access an invalid WB slave
    --       '0' when idle
    tip_o  : out std_logic;
    err_o  : out std_logic;

    -- Wishbone master signals
    wbm_stb_o  : out std_logic;
    wbm_cyc_o  : out std_logic;
    wbm_sel_o  : out std_logic_vector(3 downto 0);
    wbm_we_o   : out std_logic;
    wbm_dat_i  : in  std_logic_vector(31 downto 0);
    wbm_dat_o  : out std_logic_vector(31 downto 0);
    wbm_adr_o  : out std_logic_vector(31 downto 0);
    wbm_ack_i  : in  std_logic;
    wbm_rty_i  : in  std_logic;
    wbm_err_i  : in  std_logic
  );
end entity wb_i2c_bridge;

architecture behav of wb_i2c_bridge is

  --============================================================================
  -- Type declarations
  --============================================================================
  type t_state is
    (
      IDLE,            -- idle state
      SYSMON_WB_ADR,   -- get the WB register address
      SIM_WB_TRANSF,   -- simulate a WB transfer with the received address
      OPER,            -- operation to perform on the WB register
      SYSMON_RD_WB,    -- perform a WB read transfer, for sending word to the SysMon
      SYSMON_RD,       -- send the word to the SysMon during read transfer
      SYSMON_WR,       -- read the word sent by the SysMon during write transfer
      SYSMON_WR_WB     -- perform a WB write transfer, storing the received word
    );

  --============================================================================
  -- Signal declarations
  --============================================================================
  -- Slave component signals
  signal i2c_ack    : std_logic;
  signal op         : std_logic;
  signal start_op   : std_logic;
  signal tx_byte    : std_logic_vector(7 downto 0);
  signal rx_byte    : std_logic_vector(7 downto 0);
  signal done       : std_logic;
  signal done_d0    : std_logic;
  signal stat       : std_logic_vector(1 downto 0);

  -- Wishbone temporary signals
  signal wb_dat_out : std_logic_vector(31 downto 0);
  signal wb_dat_in  : std_logic_vector(31 downto 0);
  signal wb_adr     : std_logic_vector(15 downto 0);
  signal wb_cyc     : std_logic;
  signal wb_stb     : std_logic;
  signal wb_we      : std_logic;
  signal wb_ack     : std_logic;
  signal wb_err     : std_logic;
  signal wb_rty     : std_logic;

  -- FSM control signals
  signal state        : t_state;
  signal dat_byte_cnt : unsigned(1 downto 0);
  signal adr_byte_cnt : unsigned(0 downto 0);

begin

  --============================================================================
  -- Slave component instantiation and connection
  --============================================================================
  cmp_i2c_slave: gc_i2c_slave
    port map
    (
      clk_i      => clk_i,
      rst_n_i    => rst_n_i,

      -- I2C lines
      scl_i      => scl_i,
      scl_o      => scl_o,
      scl_en_o   => scl_en_o,
      sda_i      => sda_i,
      sda_o      => sda_o,
      sda_en_o   => sda_en_o,

      -- Slave address
      i2c_addr_i => i2c_addr_i,

      -- ACK input, should be set after done_p_o = '1'
      -- '0' - ACK
      -- '1' - NACK
      i2c_ack_i  => i2c_ack,

      -- I2C bus operation, set after address detection
      -- '0' - write
      -- '1' - read
      op_o       => op,

      -- Byte to send, should be loaded while done_p_o = '1'
      tx_byte_i  => tx_byte,

      -- Received byte, valid after done_p_o = '1'
      rx_byte_o  => rx_byte,

      -- Done signal, valid when
      -- * received address matches i2c_addr_i, signaling valid op_o;
      -- * a byte was received, signaling valid rx_byte_o and an ACK/NACK should be
      -- sent to master;
      -- * sent a byte, should set tx_byte_i.
      done_p_o   => done,

      stat_o     => stat
    );

  --============================================================================
  -- I2C to Wishbone bridge FSM logic
  --============================================================================
  -- First, assign Wishbone outputs
  wbm_dat_o <= wb_dat_out;
  wbm_adr_o <= x"0000" & wb_adr;
  wbm_cyc_o <= wb_cyc;
  wbm_stb_o <= wb_stb;
  wbm_we_o  <= wb_we;
  wbm_sel_o <= (others => '1');

  -- Next, assign some Wishbone inputs to internal signals
  wb_ack    <= wbm_ack_i;
  wb_err    <= wbm_err_i;
  wb_rty    <= wbm_rty_i;

  -- Then, assign the I2C byte to TX to the first byte of the internal WB input
  -- data signal; shifting is handled inside the FSM.
  tx_byte   <= wb_dat_in(7 downto 0);


  -- Finally, the FSM logic
  p_fsm: process (clk_i) is
  begin
    if rising_edge(clk_i) then
      if (rst_n_i = '0') then
        state        <= IDLE;
        wb_adr       <= (others => '0');
        wb_dat_out   <= (others => '0');
        wb_dat_in    <= (others => '0');
        wb_cyc       <= '0';
        wb_stb       <= '0';
        wb_we        <= '0';
        start_op     <= '0';
        i2c_ack      <= '0';
        tip_o        <= '0';
        err_o        <= '0';
        adr_byte_cnt <= (others => '0');
        dat_byte_cnt <= (others => '0');

      else
        case state is
          ---------------------------------------------------------------------
          -- IDLE
          ---------------------------------------------------------------------
          -- After the slave acknowledges its I2C address, the register address
          -- bytes have to be shifted in. The start-of-transfer operation
          -- is also stored here, to check versus the third I2C transfer in
          -- the protocol. At this point, since the SysMon writes the WB
          -- address, start_op will be '0' (write).
          ---------------------------------------------------------------------
          when IDLE =>
            err_o   <= '0';
            tip_o   <= '0';
            i2c_ack <= '0';
            dat_byte_cnt <= (others => '0');
            if (done = '1') and (stat = c_i2cs_addr_good) then
              tip_o    <= '1';
              i2c_ack  <= '1';
              state    <= SYSMON_WB_ADR;
              start_op <= op;
            end if;

          ---------------------------------------------------------------------
          -- SYSMON_WB_ADR
          ---------------------------------------------------------------------
          -- Shift in the two address bytes sent by the SysMon and ACK each of
          -- them. The second byte's ACK is also controlled by the next state.
          ---------------------------------------------------------------------
          when SYSMON_WB_ADR =>
            if (done = '1') then
              if (stat = c_i2cs_rd_done) then
                wb_adr       <= wb_adr(7 downto 0) & rx_byte;
                i2c_ack      <= '1';
                adr_byte_cnt <= adr_byte_cnt + 1;
                if (adr_byte_cnt = 1) then
                  state <= SIM_WB_TRANSF;
                end if;
              else
                i2c_ack <= '0';
                state   <= IDLE;
              end if;
            end if;

          ---------------------------------------------------------------------
          -- SIM_WB_TRANSF
          ---------------------------------------------------------------------
          -- Simulate a Wishbone transfer with the received address and go
          -- to operation state if we get a WB ACK, or back to idle if we get
          -- a WB error. In the latter case, an NACK is sent to the SysMon.
          ---------------------------------------------------------------------
          when SIM_WB_TRANSF =>
            wb_cyc <= '1';
            wb_stb <= '1';
            if (wb_ack = '1') then
              i2c_ack <= '1';
              wb_cyc  <= '0';
              wb_stb  <= '0';
              state   <= OPER;
            elsif (wb_err = '1') then
              err_o   <= '1';
              i2c_ack <= '0';
              wb_cyc  <= '0';
              wb_stb  <= '0';
              state   <= IDLE;
            end if;

          ---------------------------------------------------------------------
          -- OPER
          ---------------------------------------------------------------------
          -- This is the third I2C transfer occuring in the protocol. At this
          -- point, the first byte of a SysMon write transfer is sent, or a
          -- restart, I2C slave address and read bit are sent to signal a
          -- SysMon read transfer.
          --
          -- So, here we shift in the received byte in case of a SysMon write
          -- transfer and then check the OP signal. This is set by the slave
          -- while it is in its I2C address read state and will be different
          -- from the starting case if a read transfer ('1') occurs.
          --
          -- If a read transfer follows, the data byte counter and WB data
          -- output are cleared to avoid conflicts with future transfers.
          ---------------------------------------------------------------------
          when OPER =>
            if (done = '1') then
              if (stat = c_i2cs_rd_done) then
                wb_dat_out   <= rx_byte & wb_dat_out(31 downto 8);
                dat_byte_cnt <= dat_byte_cnt + 1;
                i2c_ack      <= '1';
                state        <= SYSMON_WR;
              elsif (stat = c_i2cs_addr_good) and (op /= start_op) then
                i2c_ack <= '1';
                state   <= SYSMON_RD_WB;
              else
                i2c_ack <= '0';
                state   <= IDLE;
              end if;
            end if;

          ---------------------------------------------------------------------
          -- SYSMON_WR
          ---------------------------------------------------------------------
          -- During write transfers, each byte is shifted in, until all bytes
          -- in the transfer have been sent. When this has occured, a Wishbone
          -- write transfer is initiated in the next state.
          ---------------------------------------------------------------------
          when SYSMON_WR =>
            if (done = '1') then
              if (stat = c_i2cs_rd_done) then
                wb_dat_out   <= rx_byte & wb_dat_out(31 downto 8);
                dat_byte_cnt <= dat_byte_cnt + 1;
                i2c_ack      <= '1';
                if (dat_byte_cnt = 3) then
                  state <= SYSMON_WR_WB;
                end if;
              else
                i2c_ack <= '0';
                state   <= IDLE;
              end if;
            end if;

          ---------------------------------------------------------------------
          -- SYSMON_WR_WB
          ---------------------------------------------------------------------
          -- Perform a write transfer over Wishbone bus with the received
          -- data word.
          ---------------------------------------------------------------------
          when SYSMON_WR_WB =>
            wb_cyc <= '1';
            wb_stb <= '1';
            wb_we  <= '1';
            if (wb_ack = '1') then -- or (wb_err = '1') then
              wb_cyc <= '0';
              wb_stb <= '0';
              wb_we  <= '0';
              state  <= SYSMON_WR; --IDLE;
            elsif (wb_err = '1') then
              err_o   <= '1';
              state   <= IDLE;
            end if;

          ---------------------------------------------------------------------
          -- SYSMON_RD_WB
          ---------------------------------------------------------------------
          -- This state is reached from the operation state; here, we perform
          -- a read transfer on the Wishbone bus to prepare the data that
          -- should be sent to the SysMon. If the WB address is incorrect, we
          -- go back to the IDLE state.
          ---------------------------------------------------------------------
          when SYSMON_RD_WB =>
            wb_cyc <= '1';
            wb_stb <= '1';
            if (wb_ack = '1') then
              wb_dat_in <= wbm_dat_i;
              wb_cyc    <= '0';
              wb_stb    <= '0';
              state     <= SYSMON_RD;
            elsif (wb_err = '1') then
              err_o  <= '1';
              wb_cyc <= '0';
              wb_stb <= '0';
              state  <= IDLE;
            end if;

          ---------------------------------------------------------------------
          -- SYSMON_RD
          ---------------------------------------------------------------------
          -- Shift out the bytes over I2C and go back to IDLE state.
          ---------------------------------------------------------------------
          when SYSMON_RD =>
            if (done = '1') then
              if (stat = c_i2cs_wr_done) then
                wb_dat_in    <= x"00" & wb_dat_in(31 downto 8);
                dat_byte_cnt <= dat_byte_cnt + 1;
                i2c_ack      <= '1';
                if (dat_byte_cnt = 3) then
                  state <= IDLE;
                end if;
              else
                i2c_ack <= '0';
                state   <= IDLE;
              end if;
            end if;

          ---------------------------------------------------------------------
          -- Any other state: go back to idle.
          ---------------------------------------------------------------------
          when others =>
            state <= IDLE;

        end case;
      end if;
    end if;
  end process p_fsm;

end behav;
