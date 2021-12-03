--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   secded_ecc
--
-- description: SECDED RAM controller
--
--------------------------------------------------------------------------------
-- Copyright CERN 2020-2021
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

package secded_32b_pkg is
  subtype data_word_t is std_logic_vector (31 downto 0);
  subtype syndrome_word_t is std_logic_vector (6 downto 0);

  --  Compute the syndrome for DATA.
  function f_calc_syndrome (data : data_word_t) return syndrome_word_t;

  function f_ecc_errors (syndrome : syndrome_word_t) return std_logic;

  function f_ecc_one_error (syndrome : syndrome_word_t) return std_logic;

  function f_fix_error (syndrome : syndrome_word_t;
                        data : std_logic_vector (38 downto 0)) return std_logic_vector;
end secded_32b_pkg;

package body secded_32b_pkg is
  function f_xor (x : std_logic_vector) return std_logic is
    variable result : std_logic := '0';
  begin
    for i in x'range loop
      result := result xor x(i);
    end loop;
    return result;
  end f_xor;

  function f_or (x : std_logic_vector) return std_logic is
    variable result : std_logic := '0';
  begin
    for i in x'range loop
      result := result or x(i);
    end loop;
    return result;
  end f_or;

  type syndrome_mask_array is array(0 to 6) of data_word_t;
  constant syndrome_masks : syndrome_mask_array := (
    0 => "11000001010010000100000011111111",
    1 => "00100001001001001111111110010000",
    2 => "01101100111111110000100000001000",
    3 => "11111111000000011010010001000100",
    4 => "00010110111100001001001010100110",
    5 => "00010000000111110111000101100001",
    6 => "10001010100000100000111100011011"
  );

  type array_syndrome is array (0 to 38) of syndrome_word_t;
  constant syn_correction_mask : array_syndrome := (
    0  => "1100001",
    1  => "1010001",
    2  => "0011001",
    3  => "1000101",
    4  => "1000011",
    5  => "0110001",
    6  => "0101001",
    7  => "0010011",
    8  => "1100010",
    9  => "1010010",
    10 => "1001010",
    11 => "1000110",
    12 => "0110010",
    13 => "0101010",
    14 => "0100011",
    15 => "0011010",
    16 => "0101100",
    17 => "1100100",
    18 => "0100110",
    19 => "0100101",
    20 => "0110100",
    21 => "0010110",
    22 => "0010101",
    23 => "1010100",
    24 => "0001011",
    25 => "1011000",
    26 => "0011100",
    27 => "1001100",
    28 => "0111000",
    29 => "0001110",
    30 => "0001101",
    31 => "1001001",
    32 => "0000001",
    33 => "0000010",
    34 => "0000100",
    35 => "0001000",
    36 => "0010000",
    37 => "0100000",
    38 => "1000000");

  function f_calc_syndrome (data : data_word_t) return syndrome_word_t
  is
    variable result : syndrome_word_t;
  begin
    for i in result'range loop
      result (i) := f_xor (data and syndrome_masks (i));
    end loop;
    return result;
  end f_calc_syndrome;

  function f_ecc_errors (syndrome : syndrome_word_t) return std_logic is
  begin
    if Is_x (syndrome (0)) then
      -- report "memory wrong" severity error;
      return 'X';
    end if;
    return f_or (syndrome);
  end f_ecc_errors;

  function f_ecc_one_error (syndrome : syndrome_word_t) return std_logic is
  begin
    if Is_x (syndrome (0)) then
      return '0';
    end if;
    return f_ecc_errors (syndrome) and f_xor (syndrome);
  end f_ecc_one_error;

  function f_fix_error (syndrome : syndrome_word_t;
                        data     : std_logic_vector (38 downto 0)) return std_logic_vector
  is
    variable result         : std_logic_vector (38 downto 0) := (others => '1');
    variable mask           : syndrome_word_t;
    variable corrected_word : std_logic_vector (38 downto 0);
  begin
    for i in 0 to 38 loop
      mask := syn_correction_mask(i);
      for k in mask'range loop
        if mask (k) = '1' then
          result(i) := result(i) and syndrome(k);
        end if;
      end loop;
    end loop;

    if f_or (result(31 downto 0)) = '1' then
      corrected_word := data (38 downto 32) & (result (31 downto 0) xor data(31 downto 0));
    elsif f_or (result(38 downto 32)) = '1' then
      corrected_word := result xor data;
    else
      corrected_word := "0000000" & x"00000000";
    end if;

    return corrected_word;
  end f_fix_error;
end secded_32b_pkg;