--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   gc_ds182x_readout
--
-- description: one wire temperature & unique id interface for
-- DS1822 and DS1820.
--
--------------------------------------------------------------------------------
-- Copyright CERN 2013-2018
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

--=================================================================================================
--                                       Libraries & Packages
--=================================================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;


--=================================================================================================
--                                Entity declaration for fmc_masterFIP_core
--=================================================================================================
entity gc_ds182x_readout is
  generic (
    g_CLOCK_FREQ_KHZ   : integer := 40000;           -- clk_i frequency in KHz
    g_USE_INTERNAL_PPS : boolean := false);
  port (
    clk_i     : in    std_logic;
    rst_n_i   : in    std_logic;
    pps_p_i   : in    std_logic;                     -- pulse per second (for temperature read)
    onewire_b : inout std_logic;                     -- IO to be connected to the chip(DS1820/DS1822)
    id_o      : out   std_logic_vector(63 downto 0); -- id_o value
    temper_o  : out   std_logic_vector(15 downto 0); -- temperature value (refreshed every second)
    temp_ok_o : out   std_logic;                     -- temperature was read and is correct.
    id_read_o : out   std_logic;                     -- id_o value is valid
    id_ok_o   : out   std_logic);                    -- Same as id_read_o, but not reset with rst_n_i
end gc_ds182x_readout;


--=================================================================================================
--                                    architecture declaration
--=================================================================================================
architecture arch of gc_ds182x_readout is

  constant SLOT_1US : natural := g_CLOCK_FREQ_KHZ/1000;
  -- time slot constants according to specs https://www.maximintegrated.com/en/app-notes/index.mvp/id/162
  constant SLOT_CNT_START   : natural := 0;

  --  When the bit is written
  constant SLOT_CNT_SET     : natural := 2 * SLOT_1US;

  --  When the bit is read
  constant SLOT_CNT_RD      : natural := 12 * SLOT_1US;

  --  When the onewire is not driven anymore.
  constant SLOT_CNT_STOP    : natural := 60 * SLOT_1US;

  --  End of the cycle
  constant SLOT_CNT_END     : natural := 62 * SLOT_1US;

  --  Number of cycles for a reset (until reaching 0)
  constant SLOT_CNT_RESET   : natural := 500 * SLOT_1US;

  constant READ_ID_HEADER     : std_logic_vector(7 downto 0) := X"33";
  constant CONVERT_HEADER     : std_logic_vector(7 downto 0) := X"44";
  constant READ_TEMPER_HEADER : std_logic_vector(7 downto 0) := X"BE";
  constant SKIP_HEADER         : std_logic_vector(7 downto 0) := X"CC";

  constant ID_LEFT         : integer              := 71;
  constant ID_RIGHT        : integer              := 8;
  constant TEMPER_LEFT     : integer              := 15;
  constant TEMPER_RIGHT    : integer              := 0;
  constant TEMPER_DONE_BIT : std_logic            := '0';  -- The serial line is asserted to this value by the
                                                           -- DS1820/DS1822 when the temperature conversion is ready
  constant TEMPER_LGTH     : natural := 72;
  constant ID_LGTH         : natural := 64;

  type op_fsm_t is (READ_ID_OP, CONV_OP1, SKIP_ROM_OP1, READ_TEMP_OP, WAIT_PPS, SKIP_ROM_OP2);
  type cm_fsm_t is (RESET_PULSE, PRESENCE_PULSE, WR_CM, RD_CM, IDLE_CM);

  signal bit_cnt, bit_top  : natural range 0 to 127;
  signal slot_cnt : natural range 0 to SLOT_CNT_RESET;
  signal start_slot : std_logic;

  signal end_p     : std_logic;
  signal state_op  : op_fsm_t;
  signal state_cm  : cm_fsm_t;

  --  Set for RESET/PRESENCE slots that lasts > 480uS
  signal long_slot : std_logic;

  signal crc_vec, header   : std_logic_vector(7 downto 0);
  signal cm_only   : std_logic;

  signal onewire_oe, onewire_in    : std_logic;
  signal shift_header              : std_logic;
  signal cm_reg                    : std_logic_vector(71 downto 0);
  signal shifted_header            : std_logic_vector(7 downto 0);
  signal cmd_done, cmd_init, cmd_start : std_logic;

  signal pps_counter : unsigned(31 downto 0);
  signal pps         : std_logic;


--=================================================================================================
--                                       architecture begin
--=================================================================================================
begin

  gen_external_pps : if not g_USE_INTERNAL_PPS generate
    --  Delay to ease routing.
    process (clk_i)
    begin
      if rising_edge(clk_i) then
        pps <= pps_p_i;
      end if;
    end process;
  end generate gen_external_pps;

  gen_internal_pps : if g_USE_INTERNAL_PPS generate
    p_pps_gen : process(clk_i)
    begin
      if rising_edge(clk_i) then
        if rst_n_i = '0' then
          pps         <= '0';
          pps_counter <= (others => '0');
        else
          if pps_counter = g_CLOCK_FREQ_KHZ*1000-1 then
            pps         <= '1';
            pps_counter <= (others => '0');
          else
            pps         <= '0';
            pps_counter <= pps_counter + 1;
          end if;
        end if;
      end if;
    end process;
  end generate gen_internal_pps;


---------------------------------------------------------------------------------------------------
--                                         operations FSM                                        --
---------------------------------------------------------------------------------------------------
  op_fsm_transitions : process(clk_i)
  begin
    if rising_edge(clk_i) then
      cmd_start <= '0';
      cmd_init  <= '0';

      if rst_n_i = '0' then
        state_op  <= READ_ID_OP;
        id_o      <= (others => '0');
        temper_o  <= (others => '0');
        id_read_o <= '0';
        temp_ok_o <= '0';
        cmd_init <= '1';
      else
        case state_op is
          when READ_ID_OP =>
            --  Read the ROM (unique ID).  This is done once after reset.
            header  <= READ_ID_HEADER;
            bit_top <= ID_LGTH;
            cm_only <= '0';

            if cmd_done = '1' then
              if crc_vec = x"00" then
                --  ID is ok, keep it.
                state_op  <= CONV_OP1;
                id_o      <= cm_reg(ID_LEFT downto ID_RIGHT);
                id_read_o <= '1';
                id_ok_o   <= '1';

                --  Start conversion.
                header  <= CONVERT_HEADER;
                cm_only <= '1';

                cmd_start <= '1';
                cmd_init  <= '0';
              else
                --  Try again.
                null;
              end if;
            end if;
          
          when CONV_OP1 =>
            if cmd_done = '1' then
              --  Conversion can take at most 750ms
              state_op <= WAIT_PPS;
            end if;
          
          when WAIT_PPS =>
            if pps = '1' then
              -- Skip rom to directly reads the registers.
              header  <= SKIP_HEADER;
              cm_only <= '1';
              cmd_init <= '1';

              state_op <= SKIP_ROM_OP1;
            end if;

          when SKIP_ROM_OP1 =>
            if cmd_done = '1' then
              --  Read registers
              header  <= READ_TEMPER_HEADER;
              bit_top <= TEMPER_LGTH;
              cm_only <= '0';
              cmd_start <= '1';

              state_op <= READ_TEMP_OP;
            end if;
          
          when READ_TEMP_OP =>
            if cmd_done = '1' then
              temper_o <= cm_reg(TEMPER_LEFT downto TEMPER_RIGHT);
              if crc_vec = x"00" then
                temp_ok_o <= '1';
              else
                temp_ok_o <= '0';
              end if;

              -- Skip rom to directly reads the registers.
              header  <= SKIP_HEADER;
              cm_only <= '1';
              cmd_init <= '1';

              state_op <= SKIP_ROM_OP2;
            end if;

          when SKIP_ROM_OP2 =>
            if cmd_done = '1' then
              --  Start conversion.
              header  <= CONVERT_HEADER;
              cm_only <= '1';
              cmd_start <= '1';
              
              state_op <= CONV_OP1;
            end if;
        end case;
      end if;
    end if;
  end process;

-------------------------------------------------------------------------------------------
--                                      commands FSM                                     --
-------------------------------------------------------------------------------------------
  cm_fsm_transitions : process(clk_i)
  begin
    if rising_edge(clk_i) then
      shift_header     <= '0';
      onewire_oe       <= '0';
      long_slot        <= '0';
      onewire_oe       <= '0';
      start_slot       <= '0';
      cmd_done   <= '0';

      if rst_n_i = '0' then
        state_cm   <= IDLE_CM;
        cm_reg     <= (others => '0');
      else
        case state_cm is
          when IDLE_CM =>
            bit_cnt        <= 0;
            if cmd_init = '1' then
              state_cm       <= RESET_PULSE;
              start_slot     <= '1';
            elsif cmd_start = '1' then
              state_cm       <= WR_CM;
              shifted_header <= header;
              start_slot     <= '1';
            end if;

          when RESET_PULSE =>
            --  Reset pulse: set to 0
            long_slot   <= '1';
            --  Set to 0.
            onewire_oe  <= '1';
            crc_vec     <= (others => '0');
            shifted_header <= header;
            if end_p = '1' then
              state_cm <= PRESENCE_PULSE;
            end if;

          when PRESENCE_PULSE =>
            --  Presence pulse.
            long_slot   <= '1';
            --  Do not drive
            onewire_oe  <= '0';

            if end_p = '1' then
              state_cm <= WR_CM;
            end if;

          when WR_CM =>
            --  Shift at end of slot.
            --  Low during init pulse.
            if slot_cnt < SLOT_CNT_SET then
              onewire_oe  <= '1';
            elsif slot_cnt >= SLOT_CNT_STOP then
              onewire_oe <=  '0';
            else
              onewire_oe <= not shifted_header(0);
            end if;

            if end_p = '1' then
              --  End of slot
              if bit_cnt = 7 then
                --  End of command.
                bit_cnt <= 0;
                if cm_only = '0' then
                  state_cm <= RD_CM;
                else
                  state_cm <= IDLE_CM;
                  cmd_done <= '1';
                end if;
              else
                --  Next bit
                shifted_header <= '0' & shifted_header(7 downto 1);
                bit_cnt <= bit_cnt + 1;
              end if;
            end if;

          when RD_CM =>
            --  Low during init pulse.
            if slot_cnt < SLOT_CNT_SET then
              onewire_oe  <= '1';
            else
              onewire_oe  <= '0';
              if slot_cnt = SLOT_CNT_RD then
                --  Sample
                cm_reg <= onewire_in & cm_reg (cm_reg'left downto 1);
                --  Update CRC
                crc_vec(0)          <= onewire_in xor crc_vec(7);
                crc_vec(3 downto 1) <= crc_vec(2 downto 0);
                crc_vec(4)          <= (onewire_in xor crc_vec(7)) xor crc_vec(3);
                crc_vec(5)          <= (onewire_in xor crc_vec(7)) xor crc_vec(4);
                crc_vec(7 downto 6) <= crc_vec(6 downto 5);
      
                bit_cnt <= bit_cnt + 1;
              end if;
            end if;

            if end_p = '1' then
              --  End of slot
              if bit_cnt = bit_top then
                --  End of command
                state_cm <= IDLE_CM;
                cmd_done <= '1';
              end if;
            end if;
        end case;
      end if;
    end if;
  end process;

-------------------------------------------------------------------------------------------
--                                       time slots                                      --
-------------------------------------------------------------------------------------------
  -- Generates time slots
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' or start_slot = '1' then
        slot_cnt   <= 0;
        end_p    <= '0';
      else
        -- Slot counter
        if end_p = '1' then
          slot_cnt <= 0;
          end_p <= '0';
        elsif (long_slot = '1' and slot_cnt = SLOT_CNT_RESET)
           or (long_slot = '0' and slot_cnt = SLOT_CNT_END)
        then
          --  End of slot, start next one.
          end_p <= '1';
        else
          slot_cnt <= slot_cnt + 1;
          end_p <= '0';
        end if;
      end if;
    end if;
  end process;

-------------------------------------------------------------------------------------------
--                                         serdes                                        --
-------------------------------------------------------------------------------------------

  -- Serial data line in tri-state, when not writing data out
  onewire_b <= '0' when onewire_oe = '1' else 'Z';

  -- Data serializer shift register
  ShiftReg_p : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        onewire_in     <= '0';
      else
        -- Samples serial input
        onewire_in <= onewire_b;
      end if;
    end if;
  end process;
end arch;
