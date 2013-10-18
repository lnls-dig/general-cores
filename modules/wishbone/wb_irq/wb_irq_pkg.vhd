--! @file wb_irq_pkg.vhd
--! @brief Wishbone IRQ Master
--!
--! Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
--!
--! Important details about its implementation
--! should go in these comments.
--!
--! @author Mathias Kreider <m.kreider@gsi.de>
--!
--------------------------------------------------------------------------------
--! This library is free software; you can redistribute it and/or
--! modify it under the terms of the GNU Lesser General Public
--! License as published by the Free Software Foundation; either
--! version 3 of the License, or (at your option) any later version.
--!
--! This library is distributed in the hope that it will be useful,
--! but WITHOUT ANY WARRANTY; without even the implied warranty of
--! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
--! Lesser General Public License for more details.
--!  
--! You should have received a copy of the GNU Lesser General Public
--! License along with this library. If not, see <http://www.gnu.org/licenses/>.
---------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.wishbone_pkg.all;

package wb_irq_pkg is
  
  type t_ivec_array_d is array(natural range <>) of t_wishbone_data;
 
  type t_ivec_ad is record
    address     : t_wishbone_address;
    value       : t_wishbone_data;
  end record t_ivec_ad;

  type t_ivec_array_ad is array(natural range <>) of t_ivec_ad;

  function f_bin_to_hot(x : natural; len : natural) return std_logic_vector;
  function or_all(slv_in : std_logic_vector)        return std_logic; 
  
  constant c_irq_hostbridge_ep_sdb : t_sdb_device := (
    abi_class     => x"0000", -- undocumented device
    abi_ver_major => x"01",
    abi_ver_minor => x"01",
    wbd_endian    => c_sdb_endian_big,
    wbd_width     => x"7", -- 8/16/32-bit port granularity
    sdb_component => (
    addr_first    => x"0000000000000000",
    addr_last     => x"00000000000000ff",
    product => (
    vendor_id     => x"0000000000000651", -- GSI
    device_id     => x"10050081",
    version       => x"00000001",
    date          => x"20120308",
    name          => "IRQ_HOSTBRIDGE_EP  ")));
  
  constant c_irq_ep_sdb : t_sdb_device := (
    abi_class     => x"0000", -- undocumented device           
    abi_ver_major => x"01",
    abi_ver_minor => x"01",
    wbd_endian    => c_sdb_endian_big,
    wbd_width     => x"7", -- 8/16/32-bit port granularity
    sdb_component => (
    addr_first    => x"0000000000000000",
    addr_last     => x"00000000000000ff",
    product => (
    vendor_id     => x"0000000000000651", -- GSI
    device_id     => x"10050082",
    version       => x"00000001",
    date          => x"20120308",
    name          => "IRQ_ENDPOINT       ")));
  
  constant c_irq_ctrl_sdb : t_sdb_device := (
    abi_class     => x"0000", -- undocumented device
    abi_ver_major => x"01",
    abi_ver_minor => x"01",
    wbd_endian    => c_sdb_endian_big,
    wbd_width     => x"7", -- 8/16/32-bit port granularity
    sdb_component => (
    addr_first    => x"0000000000000000",
    addr_last     => x"00000000000000ff",
    product => (
    vendor_id     => x"0000000000000651", -- GSI
    device_id     => x"10040083",
    version       => x"00000001",
    date          => x"20120308",
    name          => "IRQ_CTRL           ")));

  component wb_irq_master is
    port    (clk_i          : std_logic;
           rst_n_i        : std_logic; 
           
           master_o       : out t_wishbone_master_out;
           master_i       : in  t_wishbone_master_in;
           
           irq_i          : std_logic;
           adr_i          : t_wishbone_address;
           msg_i          : t_wishbone_data
  );
  end component;
  
  component wb_irq_slave is
  generic ( g_queues  : natural := 4;
            g_depth   : natural := 8;
            g_datbits : natural := 32;
            g_adrbits : natural := 32;
            g_selbits : natural := 4
  );
  port    (clk_i         : std_logic;
           rst_n_i       : std_logic; 
           
           irq_slave_o   : out t_wishbone_slave_out_array(g_queues-1 downto 0);
           irq_slave_i   : in  t_wishbone_slave_in_array(g_queues-1 downto 0);
           irq_o         : out std_logic_vector(g_queues-1 downto 0);   
           
           ctrl_slave_o  : out t_wishbone_slave_out;
           ctrl_slave_i  : in  t_wishbone_slave_in
  );
  end component;
  
  component wb_irq_lm32 is
  generic(g_msi_queues: natural := 3;
          g_profile: string);
  port(
  clk_sys_i : in  std_logic;
  rst_n_i : in  std_logic;

  dwb_o  : out t_wishbone_master_out;
  dwb_i  : in  t_wishbone_master_in;
  iwb_o  : out t_wishbone_master_out;
  iwb_i  : in  t_wishbone_master_in;

  irq_slave_o  : out t_wishbone_slave_out_array(g_msi_queues-1 downto 0);  -- wb msi interface
  irq_slave_i  : in  t_wishbone_slave_in_array(g_msi_queues-1 downto 0);
           
  ctrl_slave_o : out t_wishbone_slave_out;                             -- ctrl interface for LM32 irq processing
  ctrl_slave_i : in  t_wishbone_slave_in
  );
  end component;
  
end package;

package body wb_irq_pkg is



function f_bin_to_hot(x : natural; len : natural
  ) return std_logic_vector is

    variable ret : std_logic_vector(len-1 downto 0);

  begin

    ret := (others => '0');
    ret(x) := '1';
    return ret;
  end function;

function or_all(slv_in : std_logic_vector)
return std_logic is
variable I : natural;
variable ret : std_logic;
begin
  ret := '0';
  for I in 0 to slv_in'left loop
	ret := ret or slv_in(I);
  end loop; 	
  return ret;
end function or_all;  
  
end package body;
