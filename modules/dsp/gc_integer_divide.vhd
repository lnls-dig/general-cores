--------------------------------------------------------------------------------
-- CERN SY-RF-FB
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   gc_integer_divide
--
-- author:      Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
--
-- description: Sequential integer division/remainder unit. Support signed
--              and unsigned integers.
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

entity gc_integer_divide is
  generic (
    g_BITS : integer := 32);
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;

    is_rem_i    : in  std_logic;
    is_signed_i : in  std_logic;
    a_i         : in  std_logic_vector(g_BITS-1 downto 0);
    b_i         : in  std_logic_vector(g_BITS-1 downto 0);
    q_o         : out std_logic_vector(g_BITS-1 downto 0);
    start_i     : in  std_logic;
    ready_o     : out  std_logic;
    done_o      : out std_logic
    );

end gc_integer_divide;

architecture rtl of gc_integer_divide is

  signal state : integer range 0 to 63;  --unsigned(5 downto 0);

  signal q, r, n, d               : unsigned(g_BITS-1 downto 0);
  signal n_sign, d_sign           : std_logic;
  signal alu_result               : unsigned(g_BITS downto 0);
  signal alu_op1, alu_op2, r_next : unsigned(g_BITS-1 downto 0);
  signal alu_sub                  : std_logic;
  signal is_rem, is_div_by_zero   : std_logic;


  signal done, busy, alu_ge, alu_eq, start_divide : std_logic;

  function f_trunc_int(x : integer; tv : integer) return integer is
  begin
    if x < 0 then
      return 0;
    elsif x > tv then
      return tv;
    else
      return x;
    end if;
  end f_trunc_int;


begin

  r_next <= r(g_BITS-2 downto 0) & n(f_trunc_int(g_BITS - 1 - (state-3), g_BITS-1));

  p_alu_ops : process(state, n, d, q, r, r_next)
  begin
    case state is
      when 0 =>
        alu_op1 <= (others => 'X');
        alu_op2 <= (others => 'X');
      when 1 =>
        alu_op1 <= (others => '0');
        alu_op2 <= n;
      when 2 =>
        alu_op1 <= (others => '0');
        alu_op2 <= d;
      when g_BITS + 3 =>
        alu_op1 <= (others => '0');
        alu_op2 <= q;
      when g_BITS + 4 =>
        alu_op1 <= (others => '0');
        alu_op2 <= r;
      when others =>
        alu_op1 <= r_next;
        alu_op2 <= d;
    end case;
  end process;


  p_alu : process(alu_sub, alu_op1, alu_op2)
  begin
    if alu_sub = '1' then
      alu_result <= ('0'&alu_op1) - ('0'& alu_op2);
    else
      alu_result <= ('0'&alu_op1) + ('0'& alu_op2);
    end if;
  end process;


  p_flags : process(alu_result, state, done, is_rem, busy, start_i)
  begin
    alu_ge <= not alu_result(g_BITS);
    if alu_result = 0 then
      alu_eq <= '1';
    else
      alu_eq <= '0';
    end if;

    if state = g_BITS + 5 and is_rem = '1' then
      done <= '1';
    elsif state = g_BITS + 4 and is_rem = '0' then
      done <= '1';
    else
      done <= '0';
    end if;

    if state /= 0 and done = '0' then
      busy <= '1';
    else
      busy <= '0';
    end if;

    start_divide <= start_i and not busy;

  end process;

  done_o <= done;
  ready_o <= not busy;
--  busy_o <= busy;

  p_alu_select_op : process(state, n_sign, d_sign)
  begin
    case state is
      when 1 =>
        alu_sub <= n_sign;
      when 2 =>
        alu_sub <= d_sign;
      when g_BITS + 3 =>
        alu_sub <= n_sign xor d_sign;
      when g_BITS + 4 =>
        alu_sub <= n_sign;
      when others =>
        alu_sub <= '1';
    end case;
  end process;

  p_state_counter : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' or done = '1' then
        state <= 0;
      elsif state /= 0 or start_divide = '1' then
        state <= state + 1;
      end if;
    end if;
  end process;


  p_main : process(clk_i)
  begin
    if rising_edge(clk_i) then
      case state is
        when 0 =>
          if start_divide = '1' then
            is_div_by_zero <= '0';
            q              <= (others => '0');
            r              <= (others => '0');

            is_rem <= is_rem_i;

            n <= unsigned(a_i);
            d <= unsigned(b_i);

            if is_signed_i = '0' then
              n_sign <= '0';
              d_sign <= '0';
            else
              n_sign <= a_i(g_BITS-1);
              d_sign <= b_i(g_BITS-1);
            end if;
          end if;

        when 1 =>
          n <= alu_result(g_BITS-1 downto 0);

        when 2 =>
          d              <= alu_result(g_BITS-1 downto 0);
          is_div_by_zero <= alu_eq and not (is_rem_i or is_signed_i);

        when g_BITS + 3 =>
          q_o <= std_logic_vector(alu_result(g_BITS-1 downto 0));

        when g_BITS + 4 =>
          q_o <= std_logic_vector(alu_result(g_BITS-1 downto 0));

        when others =>  -- 3..g_BITS+2 (g_BITS) divider iterations
          q <= q(g_BITS-2 downto 0) & alu_ge;

          if alu_ge = '1' then
            r <= resize(alu_result, r'length);
          else
            r <= r_next;
          end if;
      end case;
    end if;
  end process;

end rtl;
