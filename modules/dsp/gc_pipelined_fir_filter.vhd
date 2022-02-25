--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   gc_pipelined_fir_filter
--
-- author:      Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
--
-- description: Fully pipelined FIR filter (transposed) structure. Infers
--              FPGA multiplier/MAC blocks. Programmable coefficients. Supports
--              symmetric impulse response optimization.
--
--------------------------------------------------------------------------------
-- Copyright CERN 2020
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

use work.gencores_pkg.all;
use work.genram_pkg.all;
use work.gc_dsp_pkg.all;

entity gc_pipelined_fir_filter is
  generic(
    -- number of coefficient bits
    g_COEF_BITS    : integer := 16;
    -- number of data bits
    g_DATA_BITS    : integer := 16;
    -- number of output bits
    g_OUTPUT_BITS  : integer := 16;
    -- MAC post-sum shift
    g_OUTPUT_SHIFT : integer := 16;
    -- when true, takes the 1st half of the coefficients and assumes
    -- the other half is symmetric to it. Saves 50% of multiplier resources.
    g_SYMMETRIC    : boolean := false;
    -- Order of the filter
    g_ORDER        : integer
    );

  port (
    clk_i : in std_logic;
    rst_i : in std_logic;

    coefs_i : in t_FIR_COEF_ARRAY;

    d_i       : in std_logic_vector(g_DATA_BITS-1 downto 0);
    d_valid_i : in std_logic;

    d_o       : out std_logic_vector(g_OUTPUT_BITS-1 downto 0);
    d_valid_o : out std_logic
    );

end gc_pipelined_fir_filter;


architecture rtl of gc_pipelined_fir_filter is

  constant c_ACC_BITS : integer := g_DATA_BITS + g_COEF_BITS + f_log2_size(g_ORDER) + 1;

  type t_postmul_array is array(g_ORDER-1 downto 0) of signed(g_DATA_BITS+g_COEF_BITS downto 0);

  function f_eval_num_taps(ncoefs : integer; is_symmetric : boolean) return integer is
  begin
    if is_symmetric then
      if ncoefs mod 2 = 0 then
        return ncoefs/2;
      else
        return ncoefs/2+1;
      end if;
    else
      return ncoefs;
    end if;
  end f_eval_num_taps;

  impure function f_convert_coef(n : integer) return signed is
  begin
    return coefs_i(n)(g_COEF_BITS-1 downto 0);
  end f_convert_coef;

  constant c_NUM_TAPS : integer := f_eval_num_taps(g_ORDER, g_SYMMETRIC);

  type t_chainsum_array is array(g_ORDER-1 downto 0) of signed(c_ACC_BITS-1 downto 0);

  signal d_reg : signed(g_DATA_BITS downto 0);

  signal premul_valid : std_logic;

  signal postmul       : t_postmul_array;
  signal postmul_valid : std_logic;

  signal acc_out_rounded : signed(g_OUTPUT_BITS downto 0);
  signal acc_out_valid   : std_logic;

  signal chain_sum       : t_chainsum_array;
  signal chain_sum_valid : std_logic_vector(g_ORDER-1 downto 0);

begin

  p_multipliers : process(clk_i)
  begin
    if rising_edge(clk_i) then
      d_reg         <= resize(signed(d_i), g_DATA_BITS+1);
      premul_valid  <= d_valid_i;
      postmul_valid <= premul_valid;
      for i in 0 to c_NUM_TAPS-1 loop
        postmul(i) <= d_reg * f_convert_coef(i);
      end loop;
    end if;
  end process;


  p_sum_pipe : process(clk_i)
  begin
    if rising_edge(clk_i) then

      chain_sum_valid <= chain_sum_valid(g_ORDER-2 downto 0) & postmul_valid;
      chain_sum(0)    <= resize(postmul(0), c_ACC_BITS);

      if not g_SYMMETRIC then

        for i in 1 to g_ORDER-1 loop
          chain_sum(i) <= chain_sum(i-1) + postmul(i);
        end loop;

      else
        if g_ORDER mod 2 = 0 then

          for i in 1 to c_NUM_TAPS-1 loop
            chain_sum(i) <= chain_sum(i-1) + postmul(i);
          end loop;

          for i in 0 to c_NUM_TAPS-1 loop
            chain_sum(i + c_NUM_TAPS) <= chain_sum(i + c_NUM_TAPS - 1) + postmul(c_NUM_TAPS - 1 - i);
          end loop;

        else

          for i in 1 to c_NUM_TAPS-1 loop
            chain_sum(i) <= chain_sum(i-1) + postmul(i);
          end loop;

          for i in 1 to c_NUM_TAPS-1 loop
            chain_sum(i + c_NUM_TAPS - 1) <= chain_sum(i + c_NUM_TAPS - 2) + postmul(c_NUM_TAPS - 1 - i);
          end loop;
        end if;
      end if;
    end if;
  end process;


  p_round_output : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if d_valid_i = '1' then
        if chain_sum(g_ORDER-1)(g_OUTPUT_SHIFT-1) = '1' then
          acc_out_rounded <= chain_sum(g_ORDER-1)(g_OUTPUT_BITS + g_OUTPUT_SHIFT - 1 downto g_OUTPUT_SHIFT-1) + 1;
        else
          acc_out_rounded <= chain_sum(g_ORDER-1)(g_OUTPUT_BITS + g_OUTPUT_SHIFT - 1 downto g_OUTPUT_SHIFT-1);
        end if;
        acc_out_valid <= chain_sum_valid(g_ORDER-1);

      else
        acc_out_valid <= '0';
      end if;
    end if;
  end process;

  d_o       <= std_logic_vector(acc_out_rounded(g_OUTPUT_BITS downto 1));
  d_valid_o <= acc_out_valid;

end rtl;


