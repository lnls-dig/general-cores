--------------------------------------------------------------------------------
-- GSI
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   enc_8b10b
--
-- author(s):   Mathias Kreider, Vladimir Cherkashyn
--
-- description: 8b/10b Encoder
--     This module provides 8bit-to-10bit encoding. It accepts 8-bit parallel
--     data input and generates 10-bit encoded data output in accordance with
--     the 8b/10b standard. IO latency is one clock cycle.
--
--     This approach uses a mix of LUTs and stacked ifs, unlike the suggested
--     approach that only used gates. This uses more logic cells, but also runs
--     about twice as fast. The reverse vector function is used because all code
--     tables are provided in literature as LSB first. This way, the sourcecode
--     is easier to compare.
--
--------------------------------------------------------------------------------
-- Copyright GSI 2009-2020
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

library work;
use work.gencores_pkg.all;

entity gc_enc_8b10b is

  generic
    (
      g_USE_INTERNAL_RUNNING_DISPARITY : boolean := TRUE);
  port
    (
      clk_i     : in  std_logic;  -- byte clock, trigger on rising edge
      rst_n_i   : in  std_logic;  -- reset, assert HI
      ctrl_i    : in  std_logic;  -- control char, assert HI
      in_8b_i   : in  std_logic_vector(7 downto 0);  -- 8bit input
      err_o     : out std_logic;  -- HI if ctrl_i is HI and input is not a valid control byte
      dispar_i  : in  std_logic := '0';
      dispar_o  : out std_logic;  -- running disparity: HI = +1, LO = 0
      out_10b_o : out std_logic_vector(9 downto 0)   -- 10bit codeword output
      );
end gc_enc_8b10b;

architecture rtl of gc_enc_8b10b is

  --=============================================================================
  -- LOOKUP TABLES
  --=============================================================================

  constant c_RD_MINUS : std_logic := '0';
  constant c_RD_PLUS  : std_logic := '1';

  -- type for 5b/6b Code Table
  type t_enc_5b_6b is array(integer range <>) of std_logic_vector(5 downto 0);
  -- type for 5b/6b Code Table
  type t_enc_3b_4b is array(integer range <>) of std_logic_vector(3 downto 0);

  -- 5b/6b Code Table
  constant c_ENC_5B_6B_TABLE : t_enc_5b_6b (0 to 31) :=

    ("100111",   -- D00
     "011101",   -- D01
     "101101",   -- D02
     "110001",   -- D03
     "110101",   -- D04
     "101001",   -- D05
     "011001",   -- D06
     "111000",   -- D07
     "111001",   -- D08
     "100101",   -- D09
     "010101",   -- D10
     "110100",   -- D11
     "001101",   -- D12
     "101100",   -- D13
     "011100",   -- D14
     "010111",   -- D15
     "011011",   -- D16
     "100011",   -- D17
     "010011",   -- D18
     "110010",   -- D19
     "001011",   -- D20
     "101010",   -- D21
     "011010",   -- D22
     "111010",   -- D23
     "110011",   -- D24
     "100110",   -- D25
     "010110",   -- D26
     "110110",   -- D27
     "001110",   -- D28
     "101110",   -- D29
     "011110",   -- D30
     "101011");  -- D31

  -- 5b/6b Disparity Table
  constant c_DISPAR_6B : std_logic_vector(0 to 31) :=
    (
      "11101000100000011000000110010111");

  -- 3b/4b Code Table
  constant c_ENC_3B_4B_TABLE : t_enc_3b_4b (0 to 7) :=
    ("1011",   -- Dx0
     "1001",   -- Dx1
     "0101",   -- Dx2
     "1100",   -- Dx3
     "1101",   -- Dx4
     "1010",   -- Dx5
     "0110",   -- Dx6
     "1110");  -- DxP7

  -- 3b/4b Disparity Table
  constant c_DISPAR_4B : std_logic_vector(0 to 7) :=
    (
      "10001001");

  --=============================================================================
  -- INTERNAL SIGNALS
  --=============================================================================

  signal s_ind5b     : integer := 0;                  -- LUT 5b index
  signal s_ind3b     : integer := 0;                  -- LUT 3b index
  signal s_val6bit   : std_logic_vector(5 downto 0);  -- 6bit code
  signal s_val6bit_n : std_logic_vector(5 downto 0);  -- 6bit code inverted
  signal s_val4bit   : std_logic_vector(3 downto 0);  -- 4bit code
  signal s_val4bit_n : std_logic_vector(3 downto 0);  -- 4bit code inverted

  -- code disparity 6b code: HI = uneven number of bits, LO = even, neutral disp
  signal s_dP6bit : std_logic := '0';
  -- code disparity 4b code: HI = uneven number of bits, LO = even, neutral disp
  signal s_dP4bit : std_logic := '0';


  -- output 10b signal buffer
  signal s_out_10b, s_out_10b_reg : std_logic_vector(9 downto 0) := (others => '0');
  signal s_in_8b_reg              : std_logic_vector(7 downto 0);  -- input 8b signal buffer
  signal s_err, s_err_reg         : std_logic;  -- output err signal buffer
  signal s_ctrl_reg               : std_logic;  -- output dispar, ctrl signal buffers

  signal s_dpTrack : std_logic := c_RD_MINUS;  -- current disparity: Hi = +1, LO = 0

  signal s_RunDisp      : std_logic;  -- running disparity register
  signal s_RunDisp_reg  : std_logic;  -- running disparity register
  signal s_RunDisp_comb : std_logic;  -- running disparity register

begin

  s_RunDisp <= s_RunDisp_reg when g_USE_INTERNAL_RUNNING_DISPARITY else dispar_i;
  dispar_o  <= s_RunDisp_comb;

  --=============================================================================
  -- CONCURRENT COMMANDS
  --=============================================================================

  -- use 3bit at 7-5 as index for 4bit code and disparity table \n
  s_ind3b     <= to_integer(unsigned(s_in_8b_reg(7 downto 5)));
  s_val4bit   <= c_ENC_3B_4B_TABLE(s_ind3b);
  s_dP4bit    <= c_DISPAR_4B(s_ind3b);
  s_val4bit_n <= not (s_val4bit);

  -- use 5bit at 4-0 as index for 6bit code and disparity table
  s_ind5b     <= to_integer(unsigned(s_in_8b_reg(4 downto 0)));
  s_val6bit   <= c_ENC_5B_6B_TABLE(s_ind5b);
  s_dP6bit    <= c_DISPAR_6B(s_ind5b);
  s_val6bit_n <= not (s_val6bit);

  -- output wires
  err_o     <= s_err_reg;
  out_10b_o <= s_out_10b_reg;

  --=============================================================================
  -- ENCODING
  --=============================================================================

  -- Process encodes 8bit value to 10bit codeword depending on current disparity
  p_encoding : process (s_RunDisp, s_ctrl_reg, s_dP4bit, s_dP6bit, s_in_8b_reg,
                        s_val4bit, s_val4bit_n, s_val6bit, s_val6bit_n)

    -- buffers ctrl code during selection
    variable v_ctrl_code : std_logic_vector(9 downto 0) := (others => '0');

  begin

    v_ctrl_code := (others => '0');
    s_err       <= '0';

    --========================================================================
    -- TRANSMISSION CONTROL CODES
    --========================================================================
    if s_ctrl_reg = '1' then  -- Control Char selected

      -- control byte directly selects control code
      case s_in_8b_reg is
        when "00011100" => v_ctrl_code := f_reverse_vector("0011110100");
        when "00111100" => v_ctrl_code := f_reverse_vector("0011111001");
        when "01011100" => v_ctrl_code := f_reverse_vector("0011110101");
        when "01111100" => v_ctrl_code := f_reverse_vector("0011110011");
        when "10011100" => v_ctrl_code := f_reverse_vector("0011110010");
        when "10111100" => v_ctrl_code := f_reverse_vector("0011111010");
        when "11011100" => v_ctrl_code := f_reverse_vector("0011110110");
        when "11111100" => v_ctrl_code := f_reverse_vector("0011111000");

        when "11110111" => v_ctrl_code := f_reverse_vector("1110101000");
        when "11111011" => v_ctrl_code := f_reverse_vector("1101101000");
        when "11111101" => v_ctrl_code := f_reverse_vector("1011101000");
        when "11111110" => v_ctrl_code := f_reverse_vector("0111101000");
        when others     => s_err       <= '1';

      end case;

      -- select the right disparity and assign to output
      if (s_RunDisp = c_RD_MINUS) then
        s_out_10b <= v_ctrl_code;
      else
        s_out_10b <= not(v_ctrl_code);
      end if;

    else
      --====================================================================
      -- DATA CODES
      --====================================================================

      s_out_10b <= f_reverse_vector(s_val6bit & s_val4bit);

      if s_RunDisp = c_RD_MINUS then
        if s_dP4bit = s_dP6bit then
          if s_dP6bit = '1' then
            s_out_10b(9 downto 6) <= f_reverse_vector(s_val4bit_n);
          end if;
        else
          if s_dP4bit = '1' then
            if ((s_val6bit(2 downto 0) = "011") and
                (s_val4bit(3 downto 1) = "111")) then
              s_out_10b(9 downto 6) <= "1110";
            end if;
          else
            if (s_val4bit = "1100") then
              s_out_10b(9 downto 6) <= f_reverse_vector(s_val4bit_n);
            end if;
          end if;
        end if;

      else

        if s_dP6bit = '1' then
          s_out_10b(5 downto 0) <= f_reverse_vector(s_val6bit_n);
        else
          if (s_val6bit = "111000") then
            s_out_10b(5 downto 0) <= f_reverse_vector(s_val6bit_n);
          end if;

          if s_dP4bit = '1' then
            if ((s_val6bit(2 downto 0) = "100") and
                (s_val4bit(3 downto 1) = "111")) then
              s_out_10b(9 downto 6) <= "0001";
            else
              s_out_10b(9 downto 6) <= f_reverse_vector(s_val4bit_n);
            end if;
          else
            if (s_val4bit = "1100") then
              s_out_10b(9 downto 6) <= f_reverse_vector(s_val4bit_n);
            end if;
          end if;
        end if;

      end if;

    end if;
  end process p_encoding;

  p_disp_fsm_next : process(s_RunDisp, s_ctrl_reg, s_dP4bit, s_dP6bit,
                            s_in_8b_reg)
  begin
    s_RunDisp_comb <= s_RunDisp;

    if s_RunDisp = c_RD_MINUS then
      if (s_ctrl_reg xor s_dP6bit xor s_dP4bit) /= '0' then
        s_RunDisp_comb <= c_RD_PLUS;
      end if;
    else  -- RD_PLUS
      if (s_ctrl_reg xor s_dP6bit xor s_dP4bit) /= '0' then
        s_RunDisp_comb <= c_RD_MINUS;
      end if;
    end if;

    if (s_in_8b_reg(1 downto 0) /= "00" and s_ctrl_reg = '1') then
      s_RunDisp_comb <= s_RunDisp;
    end if;
  end process p_disp_fsm_next;

  p_disp_fsm_seq : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if(rst_n_i = '0') then
        s_RunDisp_reg <= c_RD_MINUS;
      else
        s_RunDisp_reg <= s_RunDisp_comb;
      end if;
    end if;
  end process p_disp_fsm_seq;

  s_ctrl_reg  <= ctrl_i;
  s_in_8b_reg <= in_8b_i;

  p_inout_buffers : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if(rst_n_i = '0') then
        s_err_reg     <= '0';
        s_out_10b_reg <= B"0000_000000";
      else
        s_err_reg     <= s_err;
        s_out_10b_reg <= s_out_10b;
      end if;
    end if;
  end process p_inout_buffers;

end architecture rtl;
