-----------------------------------------------------------------------------
-- Title      : SPI Bus Master
-- Project    : Simple VME64x FMC Carrier (SVEC)
-------------------------------------------------------------------------------
-- File       : spi_master.vhd
-- Author     : Tomasz Wlostowski
-- Company    : CERN
-- Created    : 2011-08-24
-- Last update: 2013-01-25
-- Platform   : FPGA-generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Just a simple SPI master (bus-less). 
-------------------------------------------------------------------------------
--
-- Copyright (c) 2011-2013 CERN / BE-CO-HT
--
-- This source file is free software; you can redistribute it   
-- and/or modify it under the terms of the GNU Lesser General   
-- Public License as published by the Free Software Foundation; 
-- either version 2.1 of the License, or (at your option) any   
-- later version.                                               
--
-- This source is distributed in the hope that it will be       
-- useful, but WITHOUT ANY WARRANTY; without even the implied   
-- warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      
-- PURPOSE.  See the GNU Lesser General Public License for more 
-- details.                                                     
--
-- You should have received a copy of the GNU Lesser General    
-- Public License along with this source; if not, download it   
-- from http://www.gnu.org/licenses/lgpl-2.1.html
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_master is
  generic(
    -- clock division ratio (SCLK = clk_sys_i / (2 ** g_div_ratio_log2).
    g_div_ratio_log2 : integer := 2;
    -- number of data bits per transfer
    g_num_data_bits  : integer := 2);
  port (
    clk_sys_i : in std_logic;
    rst_n_i   : in std_logic;

    -- state of the Chip select line (1 = CS active). External control
    -- allows for multi-transfer commands (SPI master itself does not
    -- control the state of spi_cs_n_o)
    cs_i : in std_logic;

    -- 1: start next transfer (using CPOL, DATA and SEL from the inputs below)
    start_i    : in  std_logic;

    -- Clock polarity: 1: slave clocks in the data on rising SCLK edge, 0: ...
    -- on falling SCLK edge
    cpol_i     : in  std_logic;

    -- TX Data input 
    data_i     : in  std_logic_vector(g_num_data_bits - 1 downto 0);

    -- 1: data_o contains the result of last read operation. Core is ready to initiate
    -- another transfer.
    ready_o    : out std_logic;

    -- data read from selected slave, valid when ready_o == 1.
    data_o     : out std_logic_vector(g_num_data_bits - 1 downto 0);

    -- these are obvious
    spi_cs_n_o : out std_logic;
    spi_sclk_o : out std_logic;
    spi_mosi_o : out std_logic;
    spi_miso_i : in  std_logic
    );

end spi_master;

architecture behavioral of spi_master is

  signal divider       : unsigned(11 downto 0);
  signal tick : std_logic;

  signal sreg    : std_logic_vector(g_num_data_bits-1 downto 0);
  signal rx_sreg : std_logic_vector(g_num_data_bits-1 downto 0);

  type   t_state is (IDLE, TX_CS, TX_DAT1, TX_DAT2, TX_SCK1, TX_SCK2, TX_CS2, TX_GAP);
  signal state : t_state;
  signal sclk  : std_logic;

  signal counter : unsigned(4 downto 0);
  
begin  -- rtl

  -- Simple clock divder. Produces a 'tick' signal which defines the timing for
  -- the main state machine transitions.
  p_divide_spi_clock: process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        divider <= (others => '0');
      else
        if(start_i = '1' or tick = '1') then
          divider <= (others => '0');
        else
          divider <= divider + 1;
        end if;
      end if;
    end if;
  end process;

  tick <= divider(g_div_ratio_log2); 

  -- Main state machine. Executes SPI transfers
  p_main_fsm: process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        state           <= IDLE;
        sclk            <= '0';
        sreg            <= (others => '0');
        rx_sreg         <= (others => '0');
        spi_mosi_o      <= '0';
        data_o          <= (others => '0');
        counter         <= (others => '0');
      else
        case state is
          -- Waits for start of transfer command
          when IDLE =>
            sclk    <= '0';
            counter <= (others => '0');
            if(start_i = '1') then
              sreg            <= data_i;
              state           <= TX_CS;
              spi_mosi_o      <= data_i(sreg'high);
            end if;

          -- Generates a gap between the externally asserted Chip Select and
          -- the beginning of data transfer
          when TX_CS =>
            if tick = '1' then
              state <= TX_DAT1;
            end if;

          -- Outputs subsequent bits to MOSI line.
          when TX_DAT1 =>
            if(tick = '1') then
              spi_mosi_o <= sreg(sreg'high);
              sreg       <= sreg(sreg'high-1 downto 0) & '0';
              state      <= TX_SCK1;
            end if;

          -- Flips the SCLK (active edge)
          when TX_SCK1 =>
            if(tick = '1') then
              sclk    <= not sclk;
              counter <= counter + 1;
              state   <= TX_DAT2;
            end if;

          -- Shifts in bits read from the slave
          when TX_DAT2 =>

            if(tick = '1') then
              rx_sreg <= rx_sreg(rx_sreg'high-1 downto 0) & spi_miso_i;
              state   <= TX_SCK2;
            end if;

          -- Flips the SCLK (inactive edge). Checks if all bits have been
          -- transferred.
          when TX_SCK2 =>
            if(tick = '1') then
              sclk <= not sclk;
              if(counter = g_num_data_bits) then
                state <= TX_CS2;
              else
                state <= TX_DAT1;
              end if;
            end if;

          -- Generates a gap for de-assertoin of CS line
          when TX_CS2 =>
            if(tick = '1') then
              state           <= TX_GAP;
              data_o          <= rx_sreg;
            end if;

          when TX_GAP =>
            if (tick = '1') then
              state <= IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;

  ready_o    <= '1' when (state = IDLE and start_i = '0') else '0';

  -- SCLK polarity control
  spi_sclk_o <= sclk xor cpol_i;
  spi_cs_n_o <= not cs_i;
  
end behavioral;

