---------------------------------------------------------------------------------------------------
--                                                                                                |
--                one wire temperature & unique id interface for DS1822 and DS1820                |
--                                                                                                |
---------------------------------------------------------------------------------------------------
-- File         gc_ds182x_interface.vhd                                                           |
--                                                                                                |
-- Description  Interface with the serial ID + Thermometer DS1822, DS1820                         |
--              Notes: Started from the DS2401 interface.                                         |
--                                                                                                |
-- Authors      Pablo Antonio Alvarez Sanchez                                                     |
---------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------
--                               GNU LESSER GENERAL PUBLIC LICENSE                                |
--                              ------------------------------------                              |
-- This source file is free software; you can redistribute it and/or modify it under the terms of |
-- the GNU Lesser General Public License as published by the Free Software Foundation; either     |
-- version 2.1 of the License, or (at your option) any later version.                             |
-- This source is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;       |
-- without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.      |
-- See the GNU Lesser General Public License for more details.                                    |
-- You should have received a copy of the GNU Lesser General Public License along with this       |
-- source; if not, download it from http://www.gnu.org/licenses/lgpl-2.1.html                     |
---------------------------------------------------------------------------------------------------

--=================================================================================================
--                                       Libraries & Packages
--=================================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;


--=================================================================================================
--                                Entity declaration for fmc_masterFIP_core
--=================================================================================================
entity gc_ds182x_interface is
  generic
    (freq      : integer := 40);                      -- clk frequency in MHz
  port
    (clk_i     : in    std_logic;
     rst_n_i   : in    std_logic;
     pps_p_i   : in    std_logic;                     -- pulse per second (for temperature read)
     onewire_b : inout std_logic;                     -- IO to be connected to the chip(DS1820/DS1822)
     id_o      : out   std_logic_vector(63 downto 0); -- id_o value
     temper_o  : out   std_logic_vector(15 downto 0); -- temperature value (refreshed every second)
     id_read_o : out   std_logic;                     -- id_o value is valid_o
     id_ok_o   : out   std_logic);                    -- Same as id_read_o, but not reset with rst_n_i
end gc_ds182x_interface;


--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture rtl of gc_ds182x_interface is

  -- time slot constants according to specs https://www.maximintegrated.com/en/app-notes/index.mvp/id/162
  constant SLOT_CNT_START         : unsigned(15 downto 0) := to_unsigned(0*freq/40, 16);
  constant SLOT_CNT_START_PLUSONE : unsigned(15 downto 0) := SLOT_CNT_START + 1;
  constant SLOT_CNT_SET     : unsigned(15 downto 0) := to_unsigned(60*freq/40, 16);
  constant SLOT_CNT_RD      : unsigned(15 downto 0) := to_unsigned(600*freq/40, 16);
  constant SLOT_CNT_STOP    : unsigned(15 downto 0) := to_unsigned(3600*freq/40, 16);
  constant SLOT_CNT_PRESTOP : unsigned(15 downto 0) := to_unsigned((3600-60)*freq/40, 16);

  constant READ_ID_HEADER     : std_logic_vector(7 downto 0) := X"33";
  constant CONVERT_HEADER     : std_logic_vector(7 downto 0) := X"44";
  constant READ_TEMPER_HEADER : std_logic_vector(7 downto 0) := X"BE";
  constant SKIPHEADER         : std_logic_vector(7 downto 0) := X"CC";

  constant ID_LEFT         : integer   :=  71;
  constant ID_RIGHT        : integer   :=  8;
  constant TEMPER_LEFT     : integer   :=  15;
  constant TEMPER_RIGHT    : integer   :=  0;
  constant TEMPER_DONE_BIT : std_logic := '0'; -- The serial line is asserted to this value by the
                                               -- DS1820/DS1822 when the temperature conversion is ready
  constant TEMPER_LGTH     : unsigned(7 downto 0) := to_unsigned(72, 8);
  constant ID_LGTH         : unsigned(7 downto 0) := to_unsigned(64, 8);

  type op_fsm_t is (READ_ID_OP, SKIP_ROM_OP1, CONV_OP1, CONV_OP2, SKIP_ROM_OP2, READ_TEMP_OP);
  type cm_fsm_t is (RST_CM, PREP_WR_CM, WR_CM, PREP_RD_CM, RD_CM, IDLE_CM);
  
  signal bit_top, bit_cnt                                  : unsigned(7 downto 0);
  signal do_read_bit, do_write_bit, do_rst                 : std_logic;
  signal slot_cnt                                          : unsigned(15 downto 0);
  signal start_p, end_p, set_value, read_value, init_pulse : std_logic;
  signal state_op, nxt_state_op                            : op_fsm_t;
  signal state_cm, nxt_state_cm                            : cm_fsm_t;

  signal crc_vec, header                                   : std_logic_vector(7 downto 0);
  signal crc_ok, init, pre_read_p, i_id_read               : std_logic;
  signal load_temper, load_id, cm_only, pps_p_d            : std_logic;

  signal serial_id_out, nx_serial_id_out, nx_serial_id_oe  : std_logic;
  signal i_serial_id_oe, serial_idr                        : std_logic;
  signal end_wr_cm, end_rd_cm, inc_bit_cnt, rst_bit_cnt    : std_logic;
  signal shift_header, id_cm_reg                           : std_logic;
  signal cm_reg                                            : std_logic_vector(71 downto 0);
  signal shifted_header                                    : std_logic_vector(7 downto 0);
  signal pre_init_p                                        : std_logic;

--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  -- Serial data line in tri-state, when not writing data out
  onewire_b <= serial_id_out when i_serial_id_oe = '1' else 'Z';

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  -- pps_p_i 1 clock tick delay
  pps_p_iDelay: process (clk_i)
  begin
    if rising_edge(clk_i) then
      pps_p_d <= pps_p_i;
    end if;
  end process;



---------------------------------------------------------------------------------------------------
--                                         operations FSM                                        --
---------------------------------------------------------------------------------------------------
  op_fsm_transitions: process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        state_op <= READ_ID_OP;
      else
        state_op <= nxt_state_op;
      end if;
    end if;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  op_fsm_states: process(state_op, pps_p_i, crc_ok)
  begin
    nxt_state_op <= READ_ID_OP;
    case state_op is

      when READ_ID_OP =>
        if pps_p_i = '1' and crc_ok = '1' then
          nxt_state_op <= CONV_OP1;
        else
          nxt_state_op <= state_op;
        end if;

      when CONV_OP1 =>
        if pps_p_i = '1' then
          nxt_state_op <= SKIP_ROM_OP1;
        else
          nxt_state_op <= state_op;
        end if;

      when SKIP_ROM_OP1 =>
        if pps_p_i = '1' then
          nxt_state_op <= READ_TEMP_OP;
        else
          nxt_state_op <= state_op;
        end if;

      when READ_TEMP_OP =>
        if pps_p_i = '1' then
          nxt_state_op <= SKIP_ROM_OP2;
        else
          nxt_state_op <= state_op;
        end if;

      when SKIP_ROM_OP2 =>
        if pps_p_i = '1' then
          nxt_state_op <= CONV_OP2;
        else
          nxt_state_op <= state_op;
        end if;

      when CONV_OP2 =>
        if pps_p_i = '1' then
          nxt_state_op <= SKIP_ROM_OP1;
        else
          nxt_state_op <= state_op;
        end if;

    end case;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  op_fsm_outputs:process(state_op, state_cm, crc_ok, pps_p_i, cm_only)
  begin
    header      <= READ_ID_HEADER;
    bit_top      <= ID_LGTH;
    load_temper    <= '0';
    load_id      <= '0';
    cm_only <= '0';

    case state_op is

      when READ_ID_OP =>
        header <= READ_ID_HEADER;
        bit_top <= ID_LGTH;
        if state_cm = IDLE_CM then
          load_id <= crc_ok;
        end if;

      when CONV_OP1 =>
        header      <= CONVERT_HEADER;
        cm_only <= '1';

      when SKIP_ROM_OP1 =>
        header      <= SKIPHEADER;
        cm_only <= '1';

      when READ_TEMP_OP =>
        header <= READ_TEMPER_HEADER;
        bit_top <= TEMPER_LGTH;
        if state_cm = IDLE_CM then
          load_temper <= crc_ok and pps_p_i;
        end if;

      when SKIP_ROM_OP2 =>
        header      <= SKIPHEADER;
        cm_only <= '1';

      when CONV_OP2 =>
        header      <= CONVERT_HEADER;
        cm_only <= '1';

      when others => null;

    end case;
  end process;



---------------------------------------------------------------------------------------------------
--                                          commands FSM                                         --
---------------------------------------------------------------------------------------------------
  cm_fsm_transitions: process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        state_cm <= RST_CM;
      else
        state_cm <= nxt_state_cm;
      end if;
    end if;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  cm_fsm_states: process(state_cm, start_p, end_wr_cm, end_rd_cm, crc_ok, state_op, cm_only, pps_p_d)
  begin
    nxt_state_cm <= RST_CM;
    case state_cm is
      when RST_CM =>
        if start_p = '1' then
          nxt_state_cm <= PREP_WR_CM;
        else
          nxt_state_cm <= state_cm;
        end if;

      when PREP_WR_CM =>
        if start_p = '1' then
          nxt_state_cm <= WR_CM;
        else
          nxt_state_cm <= state_cm;
        end if;

      when WR_CM =>
        if end_wr_cm = '1' then
          if cm_only = '0' then
            nxt_state_cm <= PREP_RD_CM;
          else
            nxt_state_cm <= IDLE_CM;
          end if;
        else
          nxt_state_cm <= state_cm;
        end if;

      when PREP_RD_CM =>
        if start_p = '1' then
          nxt_state_cm <= RD_CM;
        else
          nxt_state_cm <= state_cm;
        end if;

      when RD_CM =>
        if end_rd_cm = '1' then
          nxt_state_cm <= IDLE_CM;
        else
          nxt_state_cm <= state_cm;
        end if;

      when IDLE_CM =>
        if state_op = READ_ID_OP then
          if crc_ok = '0' then
            nxt_state_cm <= RST_CM;
          else
            nxt_state_cm <= state_cm;
          end if;
        elsif state_op = READ_TEMP_OP then         -- At this moment I will send a Conv temper_o command
          if pps_p_d = '1' then
            nxt_state_cm <= PREP_WR_CM;
          else
            nxt_state_cm <= state_cm;
          end if;
        elsif (state_op = CONV_OP1) or (state_op = CONV_OP2) then  -- At this moment I will restart a temper_o read
          if pps_p_d = '1' then
            nxt_state_cm <= PREP_WR_CM;
          else
            nxt_state_cm <= state_cm;
          end if;
        elsif (state_op = SKIP_ROM_OP1) or (state_op = SKIP_ROM_OP2) then  -- At this moment I will restart
          if pps_p_d = '1' then
            nxt_state_cm <= RST_CM;
          else
            nxt_state_cm <= state_cm;
          end if;
        else
          nxt_state_cm <= state_cm;
        end if;
    end case;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  cm_fsm_outputs:process(state_cm, bit_cnt, pre_read_p, crc_vec, start_p,
                         shifted_header, init_pulse, read_value, pre_init_p)
  begin
    inc_bit_cnt     <= '0';
    nx_serial_id_out <= '0';
    shift_header   <= '0';
    id_cm_reg        <= '0';
    nx_serial_id_oe  <= '0';
    rst_bit_cnt   <= '0';
    init          <= '0';
    crc_ok         <= '0';
    case state_cm is
      when RST_CM =>
        rst_bit_cnt   <= '1';
        nx_serial_id_out <= '0';
        nx_serial_id_oe  <= '1';
        init          <= start_p;
      when PREP_WR_CM =>
        rst_bit_cnt   <= start_p;
        nx_serial_id_oe  <= '0';
        nx_serial_id_out <= '0';
      when WR_CM =>
        shift_header   <= start_p;
        inc_bit_cnt     <= start_p;
        rst_bit_cnt   <= '0';
        nx_serial_id_out <= shifted_header(0) and (not init_pulse);
        if bit_cnt < to_unsigned(7, bit_cnt'length) then
          nx_serial_id_oe <= not pre_init_p;
        else
          nx_serial_id_oe <= not pre_read_p;
        end if;
      when PREP_RD_CM =>
        rst_bit_cnt   <= start_p;
        nx_serial_id_oe  <= '0';
        nx_serial_id_out <= '0';
      when RD_CM =>
        inc_bit_cnt     <= start_p;
        rst_bit_cnt   <= '0';
        nx_serial_id_out <= not init_pulse;
        id_cm_reg        <= read_value;
        nx_serial_id_oe  <= init_pulse;
      when IDLE_CM =>
        if crc_vec = x"00" then
          crc_ok <= '1';
        else
          crc_ok <= '0';
        end if;
        init <= '1';
    end case;
  end process;



---------------------------------------------------------------------------------------------------
--                                           time slots                                          --
---------------------------------------------------------------------------------------------------
  -- Generates time slots
  -- Reset pulse
  -- Read time slot
  -- Write time slots
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        slot_cnt(slot_cnt'left)             <= '1';
        slot_cnt(slot_cnt'left -1 downto 0) <= (others => '0');
        start_p                             <= '0';
        end_p                               <= '0';
        set_value                           <= '0';
        read_value                          <= '0';
        init_pulse                          <= '0';
        pre_init_p                          <= '0';
        pre_read_p                          <= '0';
      else

        -- Slot counter
        if init = '1' then
          slot_cnt(slot_cnt'left)             <= '1';
          slot_cnt(slot_cnt'left - 1 downto 0) <= (others => '0');
        elsif slot_cnt = SLOT_CNT_STOP then
          slot_cnt <= (others => '0');
        else
          slot_cnt <= slot_cnt + 1;
        end if;

        -- Time slot start pulse
        if slot_cnt = SLOT_CNT_START then
          start_p <= '1';
        else
          start_p <= '0';
        end if;

        if ((slot_cnt > SLOT_CNT_START) and (slot_cnt < SLOT_CNT_SET)) then
          init_pulse <= '1';
        else
          init_pulse <= '0';
        end if;

        if ((slot_cnt > SLOT_CNT_PRESTOP) and (slot_cnt < SLOT_CNT_STOP)) then
          pre_init_p <= '1';
        else
          pre_init_p <= '0';
        end if;

        if (((slot_cnt > SLOT_CNT_PRESTOP) and (slot_cnt <= SLOT_CNT_STOP)) or
            (slot_cnt <= SLOT_CNT_START_PLUSONE)) then
          pre_read_p <= '1';
        else
          pre_read_p <= '0';
        end if;

        -- End of time slot pulse
        if slot_cnt = SLOT_CNT_START then
          end_p <= '1';
        else
          end_p <= '0';
        end if;

        -- Pulse to write value on serial link
        if slot_cnt = SLOT_CNT_SET then
          set_value <= '1';
        else
          set_value <= '0';
        end if;

        -- Pulse to read value on serial link
        if slot_cnt = SLOT_CNT_RD then
          read_value <= '1';
        else
          read_value <= '0';
        end if;
      end if;
    end if;
  end process;



---------------------------------------------------------------------------------------------------
--                                             serdes                                            --
---------------------------------------------------------------------------------------------------
  -- Data serializer bit counter
  BitCnt_p:process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        bit_cnt <= (others => '0');
      else
        if rst_bit_cnt = '1' then
          bit_cnt <= (others => '0');
        elsif inc_bit_cnt = '1' then
          bit_cnt <= bit_cnt + 1;
        end if;
      end if;
    end if;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  -- Data serializer shift register
  ShiftReg_p:process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        shifted_header <= READ_ID_HEADER;
        cm_reg         <= (others => '0');
        serial_idr     <= '0';
        serial_id_out  <= '0';
        i_serial_id_oe <= '0';
        id_o           <= (others => '0');
        i_id_read      <= '0';
        id_read_o      <= '0';
        crc_vec        <= (others => '0');
        temper_o       <= (others => '0');
      else
        -- Samples serial input
        serial_idr <= onewire_b;

        -- Shifts command out
        if init = '1' then
          shifted_header <= header;
        elsif shift_header = '1' then
          shifted_header(shifted_header'left-1 downto 0) <= shifted_header(shifted_header'left downto 1);
          shifted_header(shifted_header'left)            <= '0';
        end if;

        -- Computes CRC on read data (include the received CRC itself, if no errror crc_vec = X"00")
        if init = '1' then
          crc_vec             <= (others => '0');
        elsif id_cm_reg = '1' then
          crc_vec(0)          <= serial_idr xor crc_vec(7);
          crc_vec(3 downto 1) <= crc_vec(2 downto 0);
          crc_vec(4)          <= (serial_idr xor crc_vec(7)) xor crc_vec(3);
          crc_vec(5)          <= (serial_idr xor crc_vec(7)) xor crc_vec(4);
          crc_vec(7 downto 6) <= crc_vec(6 downto 5);
        end if;

        -- Stores incoming data
        if (id_cm_reg = '1') then
          cm_reg(cm_reg'left - 1 downto 0) <= cm_reg(cm_reg'left downto 1);
          cm_reg(cm_reg'left)              <= serial_idr;
        end if;

        -- Updates serial output data
        serial_id_out <= nx_serial_id_out;

        -- Updates serial output enable
        i_serial_id_oe <= nx_serial_id_oe;

        -- Stores id_o in register
        if (load_id = '1')then
          i_id_read <= '1';
          id_o      <= cm_reg(ID_LEFT downto ID_RIGHT);
        end if;

        -- Stores temperature in register
        if (load_temper = '1')then
          temper_o <= cm_reg(TEMPER_LEFT downto TEMPER_RIGHT);
        end if;

        -- Delays id_o read
        id_read_o <= i_id_read;
      end if;
    end if;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  -- Value on id_o port is valid_o
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if state_cm = IDLE_CM then
        id_ok_o <= crc_ok;
      end if;
    end if;
  end process;

--  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --  --
  -- Detects end of read or end of write command
  end_wr_cm  <= '1' when (bit_cnt = to_unsigned(7, bit_cnt'length)) and (inc_bit_cnt = '1') else '0';
  end_rd_cm  <= '1' when (bit_cnt = bit_top)                                                else '0';


end rtl;
--=================================================================================================
--                                        architecture end
--=================================================================================================
---------------------------------------------------------------------------------------------------
--                                      E N D   O F   F I L E
---------------------------------------------------------------------------------------------------
