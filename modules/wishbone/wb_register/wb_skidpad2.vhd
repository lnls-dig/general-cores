--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   xwb_skidpad2
--
-- Add registers in a wishbone flow to help timing closure while maintaining
-- full throughput.  WB PIPELINE ONLY.
--
-- Differences with other modules in this directory:
-- * wb_skidpad: wishbone interface, any data width
-- * xwb_register: any data/addr width, full throughput, pipeline only.
-- * xwb_register_link: any data/addr width, pipeline only.
-- Also, note that CYC is not handled (either connect to 1, to stb or to your
-- own logic).
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
use ieee.numeric_std.all;

entity wb_skidpad2 is
  generic (
    -- Number of bits in adr.
    g_adrbits   : natural   := 32;
    -- Number of bits in dat.
    g_datbits   : natural   := 32
  );
  port (
   clk_i        : std_logic;      
   rst_n_i      : std_logic;             

   --  The slave port (note: no dat_o, no ack).
   stb_i        : in  std_logic;
   adr_i        : in  std_logic_vector(g_adrbits-1 downto 0);
   dat_i        : in  std_logic_vector(g_datbits-1 downto 0);
   sel_i        : in  std_logic_vector((g_datbits/8)-1 downto 0);  
   we_i         : in  std_logic;
   stall_o      : out std_logic;

   --  The master port (note: no dat_i, no ack).
   stb_o        : out std_logic;
   adr_o        : out std_logic_vector(g_adrbits-1 downto 0);
   dat_o        : out std_logic_vector(g_datbits-1 downto 0);
   sel_o        : out std_logic_vector((g_datbits/8)-1 downto 0);  
   we_o         : out std_logic;
   stall_i      : in  std_logic
 );
end wb_skidpad2;

architecture rtl of wb_skidpad2 is
  signal r_full0, r_full1 : std_logic := '0';
  signal fill0, fill1 : std_logic;
  signal stall : std_logic;

  signal r_adr0, r_adr1 : std_logic_vector (g_adrbits - 1 downto 0);
  signal r_dat0, r_dat1 : std_logic_vector (g_datbits - 1 downto 0);
  signal r_sel0, r_sel1 : std_logic_vector ((g_datbits / 8) - 1 downto 0);
  signal r_we0, r_we1   : std_logic;
begin

  --  A tfr is possible if one of the position is full.
  stb_o <= r_full1 or r_full0;

  -- The skidpad is full if both positions are full.  Do not check for stall_i as it will create
  -- a combinational path.
  stall <= r_full1 and r_full0;
  stall_o <= stall;

  --  Write into position 0 iff: input valid skidpad not stalling.
  fill0 <= stb_i and not stall;
  --  Move from position 0 to 1 when possible:
  --  Position 0 is valid, and position 1 is empty and not read or full and read.
  fill1 <= r_full0 and (r_full1 xor stall_i);
  
  control : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_full0 <= '0';
      r_full1 <= '0';
    elsif rising_edge(clk_i) then
      r_full0 <= fill0 or (r_full1 and stall_i);
      r_full1 <= fill1 or (r_full1 and stall_i);
    end if;
  end process;
  
  bulk : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if fill0 = '1' then
        r_dat0 <= dat_i;
        r_adr0 <= adr_i;
        r_sel0 <= sel_i;
        r_we0 <= we_i;
      end if;
      if fill1 = '1' then
        r_dat1 <= r_dat0;
        r_adr1 <= r_adr0;
        r_sel1 <= r_sel0;
        r_we1 <= r_we0;
      end if;
    end if;
  end process;
  
  adr_o <= r_adr1 when r_full1 = '1' else r_adr0;
  dat_o <= r_dat1 when r_full1 = '1' else r_dat0;
  sel_o <= r_sel1 when r_full1 = '1' else r_sel0;
  we_o <= r_we1   when r_full1 = '1' else r_we0;
end rtl;
