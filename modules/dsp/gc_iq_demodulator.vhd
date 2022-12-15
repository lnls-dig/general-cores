--------------------------------------------------------------------------------
-- CERN SY-RF-FB
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   gc_iq_demodulator
--
-- author:      Gregoire Hagmann <gregoire.hagmann@cern.ch>
--
-- description: Fs/4 IQ demodulator.
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

library work;

entity gc_iq_demodulator is
  generic (
    -- number of data bits
    g_N : positive := 16
    );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;

    sync_p1_i : in std_logic;

    -- ADC data input, 2's complement
    adc_data_i : in std_logic_vector(g_N-1 downto 0);

    -- I/Q Fs/4 Output
    i_o : out std_logic_vector(g_N downto 0);
    q_o : out std_logic_vector(g_N downto 0)
    );
end gc_iq_demodulator;


architecture rtl of gc_iq_demodulator is

  type t_IQ_STATE is (S_0, S_PI2, S_PI, S_3PI2);


  signal iacc, qacc : signed(g_N downto 0);
  signal state      : t_IQ_STATE;

begin

  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' then
        state <= S_0;
        iacc  <= (others => '0');
        qacc  <= (others => '0');
      elsif sync_p1_i = '1' then
        state <= S_PI2;
        iacc  <= resize(signed(adc_data_i), g_N + 1);
        qacc  <= (others => '0');
      else
        case state is
          when S_0 =>
            state <= S_PI2;
            iacc  <= resize(signed(adc_data_i), g_N + 1);
            qacc  <= (others => '0');
          when S_PI2 =>
            state <= S_PI;
            iacc  <= (others => '0');
            qacc  <= resize(-signed(adc_data_i), g_N + 1);
          when S_PI =>
            state <= S_3PI2;
            iacc  <= resize(-signed(adc_data_i), g_N + 1);
            qacc  <= (others => '0');
          when S_3PI2 =>
            state <= S_0;
            iacc  <= (others => '0');
            qacc  <= resize(signed(adc_data_i), g_N + 1);
        end case;
      end if;
    end if;
  end process;

  i_o <= std_logic_vector(iacc);
  q_o <= std_logic_vector(qacc);

end rtl;
