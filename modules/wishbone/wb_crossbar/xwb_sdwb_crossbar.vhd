library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wishbone_pkg.all;

entity xwb_sdwb_crossbar is
  generic(
    g_num_masters : natural := 1;
    g_num_slaves  : natural := 1;
    g_registered  : boolean := false;
    g_wraparound  : boolean := true;
    g_layout      : t_sdwb_device_array;
    g_sdwb_addr   : t_wishbone_address);
  port(
    clk_sys_i     : in  std_logic;
    rst_n_i       : in  std_logic;
    -- Master connections (INTERCON is a slave)
    slave_i       : in  t_wishbone_slave_in_array(g_num_masters-1 downto 0);
    slave_o       : out t_wishbone_slave_out_array(g_num_masters-1 downto 0);
    -- Slave connections (INTERCON is a master)
    master_i      : in  t_wishbone_master_in_array(g_num_slaves-1 downto 0);
    master_o      : out t_wishbone_master_out_array(g_num_slaves-1 downto 0));
end xwb_sdwb_crossbar;

architecture rtl of xwb_sdwb_crossbar is
  alias c_layout : t_sdwb_device_array(g_num_slaves-1 downto 0) is g_layout;

  -- Step 1. Place the SDWB ROM on the bus
  -- How much space does the ROM need?
  constant c_used_entries : natural := c_layout'length + 1;
  constant c_rom_entries  : natural := 2**f_ceil_log2(c_used_entries); -- next power of 2
  constant c_sdwb_bytes   : natural := c_sdwb_device_length / 8;
  constant c_rom_bytes    : natural := c_rom_entries * c_sdwb_bytes;
  
  -- Step 2. Find the size of the bus
  function f_bus_end return unsigned is
    variable result : unsigned(63 downto 0);
    constant zero : t_wishbone_address := (others => '0');
  begin
    -- The SDWB block must be aligned
    assert (g_sdwb_addr and std_logic_vector(to_unsigned(c_rom_bytes - 1, c_wishbone_address_width))) = zero
    report "SDWB address is not aligned. This is not supported by the crossbar."
    severity Failure;
      
    if not g_wraparound then
      result := (others => '0');
      for i in 0 to c_wishbone_address_width-1 loop
        result(i) := '1';
      end loop;
    else
      -- The ROM will be an addressed slave as well
      result := (others => '0');
      result(c_wishbone_address_width-1 downto 0) := unsigned(g_sdwb_addr);
      result := result + to_unsigned(c_rom_bytes, 64) - 1;
      
      for i in c_layout'range loop
        if c_layout(i).wbd_end > result then
          result := c_layout(i).wbd_end;
        end if;
      end loop;
      -- round result up to a power of two -1
      for i in 62 downto 0 loop
        result(i) := result(i) or result(i+1);
      end loop;
    end if;
    return result;
  end f_bus_end;
  
  constant c_bus_end  : unsigned(63 downto 0) := f_bus_end;
  
  -- Step 3. Map device address begin values
  function f_addresses return t_wishbone_address_array is
    variable result : t_wishbone_address_array(c_layout'range);
    variable extend : unsigned(63 downto 0) := (others => '0');
  begin
    for i in c_layout'range loop
      result(i) := std_logic_vector(c_layout(i).wbd_begin(c_wishbone_address_width-1 downto 0));
      
      -- Range must be valid
      assert c_layout(i).wbd_begin <= c_layout(i).wbd_end
      report "Wishbone slave device #" & Integer'image(i) & " (" & c_layout(i).description & ") wbd_begin address must precede wbd_end address."
      severity Failure;
      
      -- Address must fit
      extend(c_wishbone_address_width-1 downto 0) := unsigned(result(i));
      assert c_layout(i).wbd_begin = extend
      report "Wishbone slave device #" & Integer'image(i) & " (" & c_layout(i).description & ") wbd_begin does not fit in t_wishbone_address."
      severity Failure;
    end loop;
    return result;
  end f_addresses;
  
  -- Step 3. Map device address end values
  function f_masks return t_wishbone_address_array is
    variable result : t_wishbone_address_array(c_layout'range);
    variable size : unsigned(63 downto 0);
    constant zero : unsigned(63 downto 0) := (others => '0');
  begin
    for i in c_layout'range loop
      size := c_layout(i).wbd_end - c_layout(i).wbd_begin;
      
      -- size must be of the form 000000...00001111...1
      assert (size and (size + to_unsigned(1, 64))) = zero
      report "Wishbone slave device #" & Integer'image(i) & " (" & c_layout(i).description & ") has an address range size that is not a power of 2 minus one (" & Integer'image(to_integer(size)) & "). This is not supported by the crossbar."
      severity Warning;
      
      -- fix the size up to the form 000...0001111...11
      for j in c_wishbone_address_width-2 downto 0 loop
        size(j) := size(j) or size(j+1);
      end loop;
      
      -- the base address must be aligned to the size
      assert (c_layout(i).wbd_begin and size) = zero
      report "Wishbone slave device #" & Integer'image(i) & " (" & c_layout(i).description & ") wbd_begin address is not aligned. This is not supported by the crossbar."
      severity Failure;
      
      size := c_bus_end - size;
      result(i) := std_logic_vector(size(c_wishbone_address_width-1 downto 0));
    end loop;
    return result;
  end f_masks;
  
  constant c_rom_mask : unsigned(63 downto 0) := 
    c_bus_end - to_unsigned(c_rom_bytes-1, 64);
  constant c_sdwb_mask : t_wishbone_address := 
    std_logic_vector(c_rom_mask(c_wishbone_address_width-1 downto 0));
  constant c_address : t_wishbone_address_array(g_num_slaves downto 0) :=
  
    g_sdwb_addr & f_addresses;
  constant c_mask : t_wishbone_address_array(g_num_slaves downto 0) :=
    c_sdwb_mask & f_masks;
  
  signal master_i_1 :  t_wishbone_master_in_array(g_num_slaves downto 0);
  signal master_o_1 : t_wishbone_master_out_array(g_num_slaves downto 0);
begin
  master_i_1(g_num_slaves-1 downto 0) <=  master_i;
  master_o <= master_o_1(g_num_slaves-1 downto 0);
  
  rom : sdwb_rom
    generic map(
      g_layout  => c_layout,
      g_bus_end => c_bus_end)
    port map(
      clk_sys_i => clk_sys_i,
      slave_i   => master_o_1(g_num_slaves),
      slave_o   => master_i_1(g_num_slaves));
  
  crossbar : xwb_crossbar
    generic map(
      g_num_masters => g_num_masters,
      g_num_slaves  => g_num_slaves + 1,
      g_registered  => g_registered,
      g_address     => c_address,
      g_mask        => c_mask)
    port map(
      clk_sys_i     => clk_sys_i,
      rst_n_i       => rst_n_i,
      slave_i       => slave_i, 
      slave_o       => slave_o, 
      master_i      => master_i_1, 
      master_o      => master_o_1);
end rtl;
