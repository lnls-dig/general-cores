-------------------------------------------------------------------------------
-- Title      : Interrupt generator for ZynqUS mpsoc
-- Project    : General Cores
-------------------------------------------------------------------------------
-- File       : mpsoc_int_gen.vhd
-- Company    : CERN
-- Platform   : FPGA-generics
-- Standard   : VHDL '93
-------------------------------------------------------------------------------
-- Copyright (c) 2023 CERN
--
-- Generate an interrupt by writting a value in a specific address (in the pcie
-- bridge) when a line goes high.
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
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mpsoc_int_gen is
  generic (
    --  default values for AXIPCIE_DMA0, DMA_CHANNEL_PCIE_INTERRUPT_ASSERT
    g_addr : std_logic_vector(31 downto 0) := x"FD0F_0070";
    g_data : std_logic_vector(31 downto 0) := x"0000_0008"
  ); 
  port (
    clk_i   : in std_logic;
    rst_n_i : in std_logic;

    --  A word is written each time this inputs goes high.
    irq_i   : in std_logic;
    
    --  AXI4-Full master
    S_AXI_awaddr : out std_logic_vector (48 downto 0);
    S_AXI_awburst : out std_logic_vector (1 downto 0);
    S_AXI_awcache : out std_logic_vector (3 downto 0);
    S_AXI_awid : out std_logic_vector (5 downto 0);
    S_AXI_awlen : out std_logic_vector (7 downto 0);
    S_AXI_awlock : out std_logic;
    S_AXI_awprot : out std_logic_vector (2 downto 0);
    S_AXI_awready : in std_logic;
    S_AXI_awsize : out std_logic_vector (2 downto 0);
    S_AXI_awuser : out std_logic;
    S_AXI_awvalid : out std_logic;
    
    S_AXI_wdata : out std_logic_vector (31 downto 0);
    S_AXI_wlast : out std_logic;
    S_AXI_wready : in std_logic;
    S_AXI_wstrb : out std_logic_vector (3 downto 0);
    S_AXI_wvalid : out std_logic;

    S_AXI_bid : in std_logic_vector (5 downto 0);
    S_AXI_bready : out std_logic;
    S_AXI_bresp : in std_logic_vector (1 downto 0);
    S_AXI_bvalid : in std_logic
  );
end mpsoc_int_gen;    

architecture arch of mpsoc_int_gen is
  type t_state is (S_IDLE, S_WAIT, S_DONE);
  signal state : t_state;
begin

  --  AW
  
  S_AXI_awaddr (31 downto 0) <= g_addr;
  S_AXI_awaddr (48 downto 32) <= (others => '0');

  --  No burst.
  S_AXI_awburst <= "01";
  S_AXI_awlen <= x"00";

  --  Word write
  S_AXI_awsize <= "010";

  --  Normal Non-cacheable Non-bufferable
  S_AXI_awcache <= "0010";

  --  Reuse the same id.
  S_AXI_awid <= "000000";
  
  S_AXI_awlock <= '0';

  --  Data, unsecure, privileged.
  S_AXI_awprot <= "001";
  
  S_AXI_awuser <= '0';

  -- S_AXI_awready : in std_logic;
  -- S_AXI_awvalid : out std_logic;

  --  W

  S_AXI_wdata (31 downto 0) <= g_data;
  S_AXI_wdata (S_AXI_wdata'left downto 32) <= (others => '0');
  S_AXI_wlast <= '1';
  S_AXI_wstrb(3 downto 0) <= "1111";
  S_AXI_wstrb(s_AXI_wstrb'left downto 4) <= (others => '0');

  process (clk_i)
  begin
    if rising_edge(clk_i) then

      S_AXI_bready <= '1';

      if rst_n_i = '0' then
        S_AXI_awvalid <= '0';
        S_AXI_wvalid <= '0';
        state <= S_IDLE;
      else
        case state is
          when S_IDLE =>
            if irq_i = '1' then
              --  Send the write.
              S_AXI_awvalid <= '1';
              S_AXI_wvalid <= '1';
              state <= S_WAIT;
            end if;
          when S_WAIT =>
            if S_AXI_awready = '1' then
              S_AXI_awvalid <= '0';
            end if;
            if S_AXI_wready = '1' then
              S_AXI_wvalid <= '0';
            end if;
            if S_AXI_bvalid = '1' then
              --  Got the anwser.
              state <= S_DONE;
            end if;
          when S_DONE =>
            if irq_i = '0' then
              --  Wait for irq release.
              state <= S_IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;
end arch;

            
  
