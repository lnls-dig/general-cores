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
  subtype ecc_word_t is std_logic_vector (6 downto 0);

  --  Compute the ECC bits for DATA.
  --  The ECC is a xor of some DATA bits.
  function f_calc_ecc (data : data_word_t) return ecc_word_t;

  --  SYNDROME is the xor of read ECC and recomputed ECC.
  --  The xor should be 0, except in case of errors.
  --  Return '1' if there is a difference (so if SYNDROME is not 0)
  function f_ecc_errors (syndrome : ecc_word_t) return std_logic;

  --  Return '1' if only one bit of SYNDROME is 1, ie if there is only one error.
  --  (in that case it could be fixed).
  function f_ecc_one_error (syndrome : ecc_word_t) return std_logic;

  function f_fix_error (syndrome : ecc_word_t;
                        ecc : ecc_word_t;
                        data : data_word_t) return std_logic_vector;
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

  function f_calc_ecc (data : data_word_t) return ecc_word_t
  is
    variable result : ecc_word_t;
  begin
    for i in result'range loop
      result (i) := f_xor (data and syndrome_masks (i));
    end loop;
    return result;
  end f_calc_ecc;

  function f_ecc_errors (syndrome : ecc_word_t) return std_logic is
  begin
    if Is_x (syndrome (0)) then
      -- report "memory wrong" severity error;
      return 'X';
    end if;
    return f_or (syndrome);
  end f_ecc_errors;

  function f_ecc_one_error (syndrome : ecc_word_t) return std_logic is
  begin
    if Is_x (syndrome (0)) then
      return '0';
    end if;
    return f_ecc_errors (syndrome) and f_xor (syndrome);
  end f_ecc_one_error;

  function f_fix_error (syndrome : ecc_word_t;
                        ecc : ecc_word_t;
                        data : data_word_t) return std_logic_vector
  is
    variable result : data_word_t := (others => '1');
  begin
    --  Compute which data bits have been altered.
    --  If a data bit is altered, its corresponding ECC bits are altered too.
    --  So, conversely (and because there is only one error), the altered ECC bits
    --  designate the altered data bit.
    for i in 0 to 31 loop
      for k in 0 to 6 loop
        if syndrome_masks(k)(i) = '1' then
          result(i) := result(i) and syndrome(k);
        end if;
      end loop;
    end loop;

    --  Return the fixed ecc+data.
    return (syndrome xor ecc) & (result xor data);
  end f_fix_error;
end secded_32b_pkg;
