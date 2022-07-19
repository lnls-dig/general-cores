-------------------------------------------------------------------------------
-- Title      : Multiplexer with round-robin arbitration
-- Project    : General Cores Collection library
-------------------------------------------------------------------------------
-- File       : gc_arbitrated_mux.vhd
-- Author     : Tomasz Wlostowski
-- Company    : CERN
-- Created    : 2011-08-24
-- Last update: 2020-09-18
-- Platform   : FPGA-generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: An N-channel time-division multiplexer with round robin
-- arbitration.
-------------------------------------------------------------------------------
--
-- Copyright (c) 2011 CERN / BE-CO-HT
--
-- Copyright and related rights are licensed under the Solderpad Hardware
-- License, Version 0.51 (the "License") (which enables you, at your option,
-- to treat this file as licensed under the Apache License 2.0); you may not
-- use this file except in compliance with the License. You may obtain a copy
-- of the License at http://solderpad.org/licenses/SHL-0.51.
-- Unless required by applicable law or agreed to in writing, software,
-- hardware and materials distributed under this License is distributed on an
-- "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
-- or implied. See the License for the specific language governing permissions
-- and limitations under the License.
--
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2011-08-24  1.0      twlostow        Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gencores_pkg.all;

entity gc_arbitrated_mux is
  
  generic (
    -- number of arbitrated inputs
    g_num_inputs : integer;
    -- data width
    g_width      : integer);

  port (
    clk_i   : in std_logic;
    rst_n_i : in std_logic;

    -- data (all inputs joined together)
    d_i       : in  std_logic_vector(g_num_inputs * g_width-1 downto 0);
    -- 1: data word on input N is valid. Can be asserted only if corresponding
    -- d_req_o(N) == 1
    d_valid_i : in  std_logic_vector(g_num_inputs-1 downto 0);

    -- 1: input N is ready to accept next data word
    d_req_o   : out std_logic_vector(g_num_inputs-1 downto 0);

    -- Mux output
    q_o          : out std_logic_vector(g_width-1 downto 0);
    -- 1: q_o contains valid data word
    q_valid_o    : out std_logic;

    -- Index of the input, to which came the currently outputted data word.
    q_input_id_o : out std_logic_vector(f_log2_ceil(g_num_inputs)-1 downto 0)
    );

end gc_arbitrated_mux;  

architecture rtl of gc_arbitrated_mux is

  function f_onehot_decode
    (x : std_logic_vector) return integer is
  begin
    for i in 0 to x'length-1 loop
      if(x(i) = '1') then
        return i;
      end if;
    end loop;  -- i
    return 0;
  end f_onehot_decode;


  type t_data_array is array(0 to g_num_inputs-1) of std_logic_vector(g_width-1 downto 0);

  signal req_masked, req, grant : std_logic_vector(g_num_inputs-1 downto 0);
  signal dregs      : t_data_array;
  
  
  
begin  -- rtl


  gen_inputs : for i in 0 to g_num_inputs-1 generate

    p_input_reg : process(clk_i)
    begin
      if rising_edge(clk_i) then
        if rst_n_i = '0' then
          req(i) <= '0';
        else
          if(grant(i) = '1') then
            req(i) <= '0';
          elsif(d_valid_i(i) = '1') then
            dregs(i) <= d_i(g_width * (i+1) - 1 downto g_width * i);
            req(i)   <= '1';
          end if;
        end if;
      end if;
    end process;

    d_req_o(i) <= not req(i);
  end generate gen_inputs;

  req_masked <= req and not grant;
  p_arbitrate : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        q_valid_o <= '0';
        grant     <= (others => '0');
      else
        
        f_rr_arbitrate(req_masked , grant, grant);

        if(unsigned(grant) /= 0) then
          q_o          <= dregs(f_onehot_decode(grant));
          q_input_id_o <= std_logic_vector(to_unsigned(f_onehot_decode(grant), f_log2_ceil(g_num_inputs)));
          q_valid_o <= '1';
        else
          q_o <= (others => 'X');
          q_input_id_o <= (others => 'X');
          q_valid_o <= '0';
        end if;
      end if;
    end if;
  end process;
  
end rtl;


