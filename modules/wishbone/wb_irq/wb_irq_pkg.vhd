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
  
  constant c_irq_slave_ctrl_sdb : t_sdb_device := (
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
    name          => "IRQ_SLAVE_CTRL     ")));

  constant c_irq_master_ctrl_sdb : t_sdb_device := (
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
    device_id     => x"10040084",
    version       => x"00000001",
    date          => x"20130414",
    name          => "IRQ_MASTER_CTRL    ")));

  component wb_irq_master is
  generic(
    g_channels     : natural := 32;   -- number of interrupt lines
    g_round_rb     : boolean := true; -- scheduler       true: round robin,                         false: prioritised 
    g_det_edge     : boolean := true;  -- edge detection. true: trigger on rising edge of irq lines, false: trigger on high level
    g_has_dev_id   : boolean := false;  -- if set, dst adr bits 11..7 hold g_dev_id as device identifier
    g_dev_id       : std_logic_vector(4 downto 0) := (others => '0'); -- device identifier
    g_has_ch_id    : boolean := false;  -- if set, dst adr bits  6..2 hold g_ch_id  as device identifier         
    g_default_msg  : boolean := true   -- initialises msgs to a default value in order to detect uninitialised irq master
    ); 
  port(
    clk_i          : std_logic;   -- clock
    rst_n_i        : std_logic;   -- reset, active LO
    --msi if
    irq_master_o   : out t_wishbone_master_out;  -- Wishbone msi irq interface
    irq_master_i   : in  t_wishbone_master_in;
    -- ctrl interface  
    ctrl_slave_o : out t_wishbone_slave_out;         
    ctrl_slave_i : in  t_wishbone_slave_in;
    --irq lines
    irq_i          : std_logic_vector(g_channels-1 downto 0)  -- irq lines
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
 

  constant c_irq_timer_sdb : t_sdb_device := (
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
    device_id     => x"10040088",
    version       => x"00000001",
    date          => x"20120308",
    name          => "IRQ_TIMER          ")));
 
  component wb_irq_timer is
  generic ( g_timers  : natural := 4);
  port    (clk_sys_i    : in std_logic;           
           rst_sys_n_i  : in std_logic;             
         
           tm_tai8ns_i  : in std_logic_vector(63 downto 0);         

           ctrl_slave_o : out t_wishbone_slave_out;  -- ctrl interface for LM32 irq processing
           ctrl_slave_i : in  t_wishbone_slave_in;
           
           irq_master_o : out t_wishbone_master_out;                             -- wb msi interface 
           irq_master_i : in  t_wishbone_master_in
   );
   end component;
 
   component irqm_core is
   generic( g_channels  : natural := 32;  -- number of interrupt lines
         g_round_rb     : boolean := true;   -- scheduler       true: round robin,                         false: prioritised 
         g_det_edge     : boolean := true    -- edge detection. true: trigger on rising edge of irq lines, false: trigger on high level
   ); 
   port    (clk_i          : in std_logic;   -- clock
            rst_n_i        : in std_logic;   -- reset, active LO
            --msi if
            irq_master_o   : out t_wishbone_master_out;  -- Wishbone msi irq interface
            irq_master_i   : in  t_wishbone_master_in;
            --config        
            msi_dst_array  : in t_wishbone_address_array(g_channels-1 downto 0); -- MSI Destination address for each channel
            msi_msg_array  : in t_wishbone_data_array(g_channels-1 downto 0);    -- MSI Message for each channel
            --irq lines
            en_i           : in std_logic;                                 -- global interrupt enable          
            mask_i         : in std_logic_vector(g_channels-1 downto 0);   -- interrupt mask
            irq_i          : in std_logic_vector(g_channels-1 downto 0)    -- interrupt lines
   );
   end component; 

   component wb_irq_lm32 is
   generic( g_msi_queues    : natural := 3;
            g_profile       : string;
            g_reset_vector  : std_logic_vector(31 downto 0) := x"00000000"
   );
   port(
      clk_sys_i      : in  std_logic;
      rst_n_i        : in  std_logic;

      dwb_o          : out t_wishbone_master_out;
      dwb_i          : in  t_wishbone_master_in;
      iwb_o          : out t_wishbone_master_out;
      iwb_i          : in  t_wishbone_master_in;

      irq_slave_o    : out t_wishbone_slave_out_array(g_msi_queues-1 downto 0);  -- wb msi interface
      irq_slave_i    : in  t_wishbone_slave_in_array(g_msi_queues-1 downto 0);
               
      ctrl_slave_o   : out t_wishbone_slave_out;                             -- ctrl interface for LM32 irq processing
      ctrl_slave_i   : in  t_wishbone_slave_in
   );
   end component;
  
end package;

package body wb_irq_pkg is


function f_big_ripple(a, b : std_logic_vector; c : std_logic) return std_logic_vector is
    constant len : natural := a'length;
    variable aw, bw, rw : std_logic_vector(len+1 downto 0);
    variable x : std_logic_vector(len downto 0);
  begin
    aw := "0" & a & c;
    bw := "0" & b & c;
    rw := std_logic_vector(unsigned(aw) + unsigned(bw));
    x := rw(len+1 downto 1);
    return x;
  end f_big_ripple;

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
