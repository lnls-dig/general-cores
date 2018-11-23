--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   xwb_register
--
-- description: Simple Wishbone register. Supports both standard (aka "classic")
-- as well as pipelined mode.
--
-- IMPORTANT: Introducing this module can have unpredictable results in your
-- WB interface. Always check with a simulation that this module does not brake
-- your interfaces, especially if you set g_FULL_REG to FALSE.
--
--------------------------------------------------------------------------------
-- Copyright CERN 2014-2018
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

library work;
use work.wishbone_pkg.all;

entity xwb_register is
  generic (
    g_WB_MODE  : t_wishbone_interface_mode := PIPELINED;
    -- When set to false, do not register the slave
    -- to master signals (ACK, ERR, RTY, STALL).
    g_FULL_REG : boolean                   := TRUE);
  port (
    rst_n_i  : in  std_logic;
    clk_i    : in  std_logic;
    slave_i  : in  t_wishbone_slave_in;
    slave_o  : out t_wishbone_slave_out;
    master_i : in  t_wishbone_master_in;
    master_o : out t_wishbone_master_out);
end xwb_register;

architecture arch of xwb_register is

  type t_reg_fsm is (s_PASS, s_STALL, s_FLUSH);
  signal state : t_reg_fsm;

  signal s2m_reg : t_wishbone_slave_in;

begin

  g_reg_full : if g_FULL_REG = TRUE generate
    p_m2s : process(clk_i)
    begin
      if rising_edge(clk_i) then
        slave_o <= master_i;
      end if;
    end process p_m2s;
  end generate g_reg_full;

  g_reg_half : if g_FULL_REG = FALSE generate
    slave_o <= master_i;
  end generate g_reg_half;

  g_reg_classic : if g_WB_MODE = CLASSIC generate
    p_s2m : process(clk_i)
    begin
      if rising_edge(clk_i) then
        master_o <= slave_i;
      end if;
    end process p_s2m;
  end generate g_reg_classic;

  g_reg_pipelined : if g_WB_MODE = PIPELINED generate

    signal stall_int    : std_logic;
    signal slave_cyc_d1 : std_logic;
    signal slave_stb_d1 : std_logic;

  begin

    -- Some interfaces have the habit of asserting STALL whenever
    -- they are not ACK'ing, even when CYC=0. The most typical
    -- example is the xwb_crossbar, which asserts STALL when
    -- there are no active crossbar connections. Another one is
    -- the wb_slave_adapter.
    -- Checking against the CYC is not enough though, since a
    -- master can assert CYC for multiple WB cycles in order to
    -- perform a block read/write. In that case, we need to check
    -- against STB as well.
    -- This is to protect the FSM from locking in the s_STALL
    -- state in all of the above scenarios.
    stall_int <= slave_cyc_d1 and slave_stb_d1 and master_i.stall;

    p_s2m : process(clk_i)
    begin
      if rising_edge(clk_i) then
        if rst_n_i = '0' or slave_i.cyc = '0' then
          state        <= s_PASS;
          master_o     <= c_DUMMY_WB_MASTER_OUT;
          slave_cyc_d1 <= '0';
          slave_stb_d1 <= '0';
        else
          slave_cyc_d1 <= slave_i.cyc;
          slave_stb_d1 <= slave_i.stb;
          case state is
            when s_PASS =>
              if (stall_int = '0') then
                master_o <= slave_i;
              else
                s2m_reg <= slave_i;
                state   <= s_STALL;
              end if;
            when s_STALL =>
              if (stall_int = '0') then
                master_o <= s2m_reg;
                state    <= s_FLUSH;
              end if;
            when s_FLUSH =>
              if (stall_int = '0') then
                master_o <= slave_i;
                state    <= s_PASS;
              else
                s2m_reg <= slave_i;
                state   <= s_STALL;
              end if;
          end case;
        end if;
      end if;
    end process p_s2m;
  end generate g_reg_pipelined;

end architecture arch;
