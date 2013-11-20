--==============================================================================
-- CERN (BE-CO-HT)
-- I2C slave core
--==============================================================================
--
-- author: Theodor Stana (t.stana@cern.ch)
--
-- date of creation: 2013-03-13
--
-- version: 1.0
--
-- description:
--
--    Simple I2C slave interface, providing the basic low-level functionality
--    of the I2C protocol.
--
--    The gc_i2c_slave module waits for a master to initiate a transfer via
--    a start condition. The address is sent next and if the address matches
--    the slave address set via the i2c_addr_i input, the done_p_o output
--    is set. Based on the eighth bit of the first I2C transfer byte, the module
--    then starts shifting in or out each byte in the transfer, setting the
--    done_p_o output after each received/sent byte.
--
--    For master write (slave read) transfers, the received byte can be read at
--    the rx_byte_o output when the done_p_o pin is high. For master read (slave
--    write) transfers, the slave sends the byte at the tx_byte_i input, which
--    should be set when the done_p_o output is high, either after I2C address
--    reception, or a successful send of a previous byte.
--
-- dependencies:
--    none.
--
-- references:
--    [1] The I2C bus specification, version 2.1, NXP Semiconductor, Jan. 2000
--        http://www.nxp.com/documents/other/39340011.pdf
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
--    2013-03-13   Theodor Stana     t.stana@cern.ch     File created
--==============================================================================
-- TODO:
--    - Stop condition
--==============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gencores_pkg.all;

entity gc_i2c_slave is
  port
  (
    -- Clock, reset ports
    clk_i      : in  std_logic;
    rst_n_i    : in  std_logic;

    -- I2C lines
    scl_i      : in  std_logic;
    scl_o      : out std_logic;
    scl_en_o   : out std_logic;
    sda_i      : in  std_logic;
    sda_o      : out std_logic;
    sda_en_o   : out std_logic;

    -- Slave address
    i2c_addr_i : in  std_logic_vector(6 downto 0);

    -- ACK input, should be set after done_p_o = '1'
    -- (note that the bit is reversed wrt I2C ACK bit)
    -- '1' - ACK
    -- '0' - NACK
    i2c_ack_i  : in  std_logic;

    -- I2C bus operation, set after address detection
    -- '0' - write
    -- '1' - read
    op_o       : out std_logic;

    -- Byte to send, should be loaded while done_p_o = '1'
    tx_byte_i  : in  std_logic_vector(7 downto 0);

    -- Received byte, valid after done_p_o = '1'
    rx_byte_o  : out std_logic_vector(7 downto 0);

    -- Done pulse signal, valid when
    -- * received address matches i2c_addr_i, signaling valid op_o;
    -- * a byte was received, signaling valid rx_byte_o and an ACK/NACK should be
    -- sent to master;
    -- * sent a byte, should set tx_byte_i.
    done_p_o   : out std_logic;

    -- I2C transfer state
    -- "00" - Idle
    -- "01" - Got address, matches i2c_addr_i
    -- "10" - Read done, waiting ACK/NACK
    -- "11" - Write done, waiting next byte
    stat_o     : out std_logic_vector(1 downto 0)
  );
end entity gc_i2c_slave;


architecture behav of gc_i2c_slave is

  --============================================================================
  -- Type declarations
  --============================================================================
  type t_state is
    (
      IDLE,            -- idle
      STA,             -- start condition received
      ADDR,            -- shift in I2C address bits
      ADDR_ACK,        -- ACK/NACK to I2C address
      RD,              -- shift in byte to read
      RD_ACK,          -- ACK/NACK to received byte
      WR_LOAD_TXSR,    -- load byte to send via I2C
      WR,              -- shift out byte
      WR_ACK           -- get ACK/NACK from master
    );

  --============================================================================
  -- Signal declarations
  --============================================================================
  -- Deglitched signals and delays for SCL and SDA lines
  signal scl_deglitched     : std_logic;
  signal scl_deglitched_d0  : std_logic;
  signal sda_deglitched    : std_logic;
  signal sda_deglitched_d0 : std_logic;
  signal scl_r_edge_p      : std_logic;
  signal scl_f_edge_p      : std_logic;
  signal sda_f_edge_p      : std_logic;
  signal sda_r_edge_p      : std_logic;

  -- FSM
  signal state : t_state;

  -- FSM tick
  signal tick_p   : std_logic;
  signal tick_cnt : std_logic_vector(5 downto 0);

  -- RX and TX shift registers
  signal txsr : std_logic_vector(7 downto 0);
  signal rxsr : std_logic_vector(7 downto 0);

  -- Bit counter on RX & TX
  signal bit_cnt : unsigned(2 downto 0);

  -- Watchdog counter signals
  signal watchdog_cnt    : unsigned(26 downto 0);
  signal watchdog_rst    : std_logic;
  signal rst_fr_watchdog : std_logic;

--==============================================================================
--  architecture begin
--==============================================================================
begin

  --============================================================================
  -- I/O logic
  --============================================================================
  -- No clock stretching implemented, always disable SCL line
  scl_o     <= '0';
  scl_en_o  <= '0';

  -- SDA line driven low; SDA_EN line controls when the tristate buffer is enabled
  sda_o     <= '0';

  -- Assign RX byte output
  rx_byte_o <= rxsr;

  --============================================================================
  -- Deglitching logic
  --============================================================================
  -- Generate deglitched SCL signal with 54-ns max. glitch width
  cmp_scl_deglitch : gc_glitch_filt
    generic map
    (
      g_len => 7
    )
    port map
    (
      clk_i   => clk_i,
      rst_n_i => rst_n_i,
      dat_i   => scl_i,
      dat_o   => scl_deglitched
    );

  -- and create a delayed version of this signal, together with one-tick-long
  -- falling-edge detection signal
  p_scl_degl_d0 : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if (rst_n_i = '0') then
        scl_deglitched_d0  <= '0';
        scl_f_edge_p       <= '0';
        scl_r_edge_p       <= '0';
      else
        scl_deglitched_d0 <= scl_deglitched;
        scl_f_edge_p      <= (not scl_deglitched) and scl_deglitched_d0;
        scl_r_edge_p      <= scl_deglitched and (not scl_deglitched_d0);
      end if;
    end if;
  end process p_scl_degl_d0;

  -- Generate deglitched SDA signal with 54-ns max. glitch width
  cmp_sda_deglitch : gc_glitch_filt
    generic map
    (
      g_len => 7
    )
    port map
    (
      clk_i   => clk_i,
      rst_n_i => rst_n_i,
      dat_i   => sda_i,
      dat_o   => sda_deglitched
    );

  -- and create a delayed version of this signal, together with one-tick-long
  -- falling- and rising-edge detection signals
  p_sda_deglitched_d0 : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if (rst_n_i = '0') then
        sda_deglitched_d0  <= '0';
        sda_f_edge_p       <= '0';
        sda_r_edge_p       <= '0';
      else
        sda_deglitched_d0 <= sda_deglitched;
        sda_f_edge_p      <= (not sda_deglitched) and sda_deglitched_d0;
        sda_r_edge_p      <= sda_deglitched and (not sda_deglitched_d0);
      end if;
    end if;
  end process p_sda_deglitched_d0;

  --============================================================================
  -- Tick generation
  --============================================================================
--  p_tick : process (clk_i) is
--  begin
--    if rising_edge(clk_i) then
--      if (rst_n_i = '0') then
--        tick_cnt <= '0';
--        tick_p   <= '0';
--      elsif (scl_f_edge_p = '1') then
--        tick_en <= '1';
--      else
--        if (tick_en = '1') then
--          tick_cnt <= tick_cnt + 1;
--          tick_p   <= '0';
--          if (tick_cnt = (tick_cnt'range => '1')) then
--            tick_p  <= '1';
--            tick_en <= '0';
--          end if;
--        else
--          tick_p <= '0';
--        end if;
--      end if;
--    end if;
--  end process p_tick;

  --============================================================================
  -- FSM logic
  --============================================================================
  p_fsm: process (clk_i) is
  begin
    if rising_edge(clk_i) then
      if (rst_n_i = '0') or (rst_fr_watchdog = '1') then
        state        <= IDLE;
        watchdog_rst <= '1';
        bit_cnt      <= (others => '0');
        rxsr         <= (others => '0');
        txsr         <= (others => '0');
        sda_en_o     <= '0';
        done_p_o     <= '0';
        op_o         <= '0';
        stat_o       <= c_i2cs_idle;

      -- I2C start condition
      elsif (sda_f_edge_p = '1') and (scl_deglitched = '1') then
        state        <= ADDR;
        bit_cnt      <= (others => '0');
        watchdog_rst <= '0';

      -- I2C stop condition
      elsif (sda_r_edge_p = '1') and (scl_deglitched = '1') then
        state    <= IDLE;
        done_p_o <= '1';
        stat_o   <= c_i2cs_idle;

      -- state machine logic
      else
        case state is
          ---------------------------------------------------------------------
          -- IDLE
          ---------------------------------------------------------------------
          -- When idle, outputs and bit counters are cleared, while waiting
          -- for a start condition.
          ---------------------------------------------------------------------
          when IDLE =>
            bit_cnt      <= (others => '0');
            sda_en_o     <= '0';
            done_p_o     <= '0';
            watchdog_rst <= '1';
            stat_o       <= c_i2cs_idle;

--          ---------------------------------------------------------------------
--          -- STA
--          ---------------------------------------------------------------------
--          -- When a start condition is received, the bit counter gets cleared
--          -- to prepare for receiving the address byte. On the falling edge of
--          -- SCL, we go into the address state.
--          ---------------------------------------------------------------------
--          when STA =>
--            bit_cnt <= (others => '0');
--            if (scl_f_edge_p = '1') then
--              state <= ADDR;
--            end if;

          ---------------------------------------------------------------------
          -- ADDR
          ---------------------------------------------------------------------
          -- Shift in the seven address bits and the R/W bit, and go to address
          -- acknowledgement. When the eighth bit has been shifted in, check
          -- if address is ours and signal to external module. Then, go to
          -- ADDR_ACK state.
          ---------------------------------------------------------------------
          when ADDR =>
            -- Shifting in is done on rising edge of SCL
            if (scl_r_edge_p = '1') then
              rxsr    <= rxsr(6 downto 0) & sda_deglitched;
              bit_cnt <= bit_cnt + 1;

              -- Shifted in 8 bits, go to ADDR_ACK. Check to see if received
              -- address is ours and set op_o if so.
              if (bit_cnt = 7) then
                state <= ADDR_ACK;
                if (rxsr(6 downto 0) = i2c_addr_i) then
                  op_o     <= sda_deglitched;
                  done_p_o <= '1';
                  stat_o   <= c_i2cs_addr_good;
                end if;
              end if;
            end if;

          ---------------------------------------------------------------------
          -- ADDR_ACK
          ---------------------------------------------------------------------
          -- Here, we check to see if the address is ours and ACK/NACK
          -- accordingly. The next action is dependent upon the state of the
          -- R/W bit received via I2C.
          ---------------------------------------------------------------------
          when ADDR_ACK =>
            -- Clear done pulse
            done_p_o <= '0';

            -- we write the ACK bit, so enable output
            sda_en_o <= i2c_ack_i;

            -- If the received address is ours, send the ACK set by external
            -- module and, on the falling edge of SCL, go to appropriate state
            -- based on R/W bit.
            if (rxsr(7 downto 1) = i2c_addr_i) then
              if (scl_f_edge_p = '1') then
                sda_en_o <= '0';
                if (rxsr(0) = '0') then
                  state <= RD;
                else
                  state <= WR_LOAD_TXSR;
                end if;
              end if;
            -- If received address is not ours, NACK and go back to IDLE
            else
              sda_en_o <= '0';
              state    <= IDLE;
            end if;

          ---------------------------------------------------------------------
          -- RD
          ---------------------------------------------------------------------
          -- Shift in bits sent by the master.
          ---------------------------------------------------------------------
          when RD =>
            -- Shifting occurs on falling edge of SCL
            if (scl_f_edge_p = '1') then
              rxsr    <= rxsr(6 downto 0) & sda_deglitched;
              bit_cnt <= bit_cnt + 1;

              -- Received 8 bits, go to RD_ACK and signal external module
              if (bit_cnt = 7) then
                state    <= RD_ACK;
                done_p_o <= '1';
                stat_o   <= c_i2cs_rd_done;
              end if;
            end if;

          ---------------------------------------------------------------------
          -- RD_ACK
          ---------------------------------------------------------------------
          -- Send ACK/NACK, as received from external command
          ---------------------------------------------------------------------
          when RD_ACK =>
            -- Clear done pulse
            done_p_o <= '0';

            -- we write the ACK bit, so enable output and send the ACK bit
            sda_en_o <= i2c_ack_i;

            -- based on the ACK received by external command, we read the next
            -- bit (ACK) or go back to idle state (NACK)
            if (scl_f_edge_p = '1') then
              sda_en_o <= '0';
              if (i2c_ack_i = '1') then
                state <= RD;
              else
                state <= IDLE;
              end if;
            end if;

          ---------------------------------------------------------------------
          -- WR_LOAD_TXSR
          ---------------------------------------------------------------------
          -- Load TXSR with the input value.
          ---------------------------------------------------------------------
          when WR_LOAD_TXSR =>
            txsr  <= tx_byte_i;
            state <= WR;

          ---------------------------------------------------------------------
          -- WR
          ---------------------------------------------------------------------
          -- Shift out the eight bits of TXSR.
          ---------------------------------------------------------------------
          when WR =>
            -- slave writes, so enable output
            sda_en_o  <= txsr(7);

            -- Shift TXSR on falling edge of SCL
            if (scl_f_edge_p = '1') then
              txsr    <= txsr(6 downto 0) & '0';
              bit_cnt <= bit_cnt + 1;

              --  Eight bits sent, disable SDA end go to WR_ACK
              if (bit_cnt = 7) then
                sda_en_o <= '0';
                state    <= WR_ACK;
                done_p_o <= '1';
                stat_o   <= c_i2cs_wr_done;
              end if;
            end if;

          ---------------------------------------------------------------------
          -- WR_ACK
          ---------------------------------------------------------------------
          -- The master drives the ACK bit here, so on the falling edge of
          -- SCL, we check the ack bit. A '0' (ACK) means more bits should be sent,
          -- so we load the next value of the TXSR. A '1' (NACK) means the
          -- master is done reading and a STO follows, so we go back to IDLE
          -- state.
          ---------------------------------------------------------------------
          when WR_ACK =>
            done_p_o <= '0';
            if (scl_f_edge_p = '1') then
              if (sda_deglitched = '0') then
                state <= WR_LOAD_TXSR;
              else
                state <= IDLE;
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

  --============================================================================
  -- Watchdog counter process
  --  Resets the FSM after one second. The watchdog_rst signal is controlled by
  --  the FSM and resets the watchdog if the I2C master still controls the
  --  slave, signaled by the SCL line going low. If for one second the master
  --  does not toggle the SCL line, the FSM gets reset.
  --============================================================================
  p_watchdog: process(clk_i)
  begin
    if rising_edge(clk_i) then
      if (rst_n_i = '0') or (watchdog_rst = '1') then
        watchdog_cnt    <= (others => '0');
        rst_fr_watchdog <= '0';
      else
        watchdog_cnt    <= watchdog_cnt + 1;
        rst_fr_watchdog <= '0';
        if (watchdog_cnt = 124999999) then
          watchdog_cnt    <= (others => '0');
          rst_fr_watchdog <= '1';
        end if;
      end if;
    end if;
  end process p_watchdog;

end architecture behav;
--==============================================================================
--  architecture end
--==============================================================================
