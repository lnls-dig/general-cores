----------------------------------------------------------------------------
----                                                                    ----
----                                                                    ----
---- This file is part of the srl_fifo project                          ----
---- http://www.opencores.org/cores/srl_fifo                            ----
----                                                                    ----
---- Description                                                        ----
---- Implementation of srl_fifo IP core according to                    ----
---- srl_fifo IP core specification document.                           ----
----                                                                    ----
---- To Do:                                                             ----
----    NA                                                              ----
----                                                                    ----
---- Author(s):                                                         ----
----   Andrew Mulcock, amulcock@opencores.org                           ----
----                                                                    ----
---- Modified for WR Project by Tomasz Wlostowski                       ----
----------------------------------------------------------------------------
----                                                                    ----
---- Copyright (C) 2008 Authors and OPENCORES.ORG                       ----
----                                                                    ----
---- This source file may be used and distributed without               ----
---- restriction provided that this copyright statement is not          ----
---- removed from the file and that any derivative work contains        ----
---- the original copyright notice and the associated disclaimer.       ----
----                                                                    ----
---- This source file is free software; you can redistribute it         ----
---- and/or modify it under the terms of the GNU Lesser General         ----
---- Public License as published by the Free Software Foundation;       ----
---- either version 2.1 of the License, or (at your option) any         ----
---- later version.                                                     ----
----                                                                    ----
---- This source is distributed in the hope that it will be             ----
---- useful, but WITHOUT ANY WARRANTY; without even the implied         ----
---- warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR            ----
---- PURPOSE. See the GNU Lesser General Public License for more        ----
---- details.                                                           ----
----                                                                    ----
---- You should have received a copy of the GNU Lesser General          ----
---- Public License along with this source; if not, download it         ----
---- from http://www.opencores.org/lgpl.shtml                           ----
----                                                                    ----
----------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.NUMERIC_STD.all;

use work.genram_pkg.all;

entity generic_shiftreg_fifo is
  generic (
    g_data_width : integer;
    g_size       : integer
    );          
  port (
    rst_n_i : in std_logic := '1';
    clk_i   : in std_logic;

    d_i  : in  std_logic_vector(g_data_width-1 downto 0);
    we_i : in  std_logic;
    q_o  : out std_logic_vector(g_data_width-1 downto 0);
    rd_i : in  std_logic;

    full_o        : out std_logic;
    almost_full_o : out std_logic;
    q_valid_o     : out std_logic
    );

end generic_shiftreg_fifo;

architecture rtl of generic_shiftreg_fifo is

  constant c_srl_length : integer := g_size;  -- set to srl 'type' 16 or 32 bit length

  type t_srl_array is array (c_srl_length - 1 downto 0) of std_logic_vector (g_data_width - 1 downto 0);

  signal fifo_store : t_srl_array;
  signal pointer    : integer range 0 to c_srl_length - 1;

  signal pointer_zero        : std_logic;
  signal pointer_full        : std_logic;
  signal pointer_almost_full : std_logic;
  signal empty               : std_logic := '1';
  signal valid_count         : std_logic;
  signal do_write            : std_logic;
begin

-- Valid write, high when valid to write data to the store.

  do_write <= '1' when (rd_i = '1' and we_i = '1')
              or (we_i = '1' and pointer_full = '0') else '0';

-- data store SRL's
  p_data_srl : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0'then
        for i in 0 to c_srl_length-1 loop
          fifo_store(i) <= (others => '0');
        end loop;  -- i
      elsif do_write = '1' then
        fifo_store <= fifo_store(fifo_store'left - 1 downto 0) & d_i;
      end if;
    end if;
  end process;

  q_o <= fifo_store(pointer);

  p_empty_logic : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        empty <= '1';
      elsif empty = '1' and we_i = '1' then
        empty <= '0';
      elsif pointer_zero = '1' and rd_i = '1' and we_i = '0' then
        empty <= '1';
      end if;
    end if;
  end process;

--      W       R       Action
--      0       0       pointer <= pointer
--      0       1       pointer <= pointer - 1  Read, but no write, so less data in counter
--      1       0       pointer <= pointer + 1  Write, but no read, so more data in fifo
--      1       1       pointer <= pointer              Read and write, so same number of words in fifo
--
  
  valid_count <= '1' when (
    (we_i = '1' and rd_i = '0' and pointer_full = '0' and empty = '0')
    or
    (we_i = '0' and rd_i = '1' and pointer_zero = '0')
    ) else '0';

  p_gen_address : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if valid_count = '1' then
        if we_i = '1' then
          pointer <= pointer + 1;
        else
          pointer <= pointer - 1;
        end if;
      end if;
    end if;
  end process;

  -- Detect when pointer is zero and maximum
  pointer_zero        <= '1' when pointer = 0                                      else '0';
  pointer_full        <= '1' when pointer = c_srl_length - 1                       else '0';
  pointer_almost_full <= '1' when pointer_full = '1' or pointer = c_srl_length - 2 else '0';


  -- assign internal signals to outputs
  full_o        <= pointer_full;
  almost_full_o <= pointer_almost_full;
  q_valid_o     <= not empty;
end rtl;
