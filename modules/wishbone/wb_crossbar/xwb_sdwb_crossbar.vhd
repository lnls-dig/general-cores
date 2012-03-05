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
  -- Step 1. Find the size of the bus address lines
  type bus_size is record
    bus_end  : unsigned(63 downto 0);
    bus_bits : natural;
  end record bus_size;
  
  function f_bus_size return bus_size is
    variable result : bus_size;
  begin
    if not g_wraparound then
      result.bus_bits := c_wishbone_address_width;
      result.bus_end := (others => '0');
      for i in 0 to c_wishbone_address_width-1 loop
        result.bus_end(i) := '1';
      end loop;
    else
      result.bus_end := (others => '0');
      for i in g_layout'range loop
        if g_layout(i).wbd_end > result.bus_end then
          result.bus_end := g_layout(i).wbd_end;
        end if;
      end loop;
      -- round result up to a power of two -1
      result.bus_bits := 0;
      for i in 0 to 63 loop
        if result.bus_end(i) = '1' then
          result.bus_bits := i + 1;
        end if;
      end loop;
      for i in 62 downto 0 loop
        result.bus_end(i) := result.bus_end(i) or result.bus_end(i+1);
      end loop;
    end if;
    return result;
  end f_bus_size;
  
  constant c_bus_size : bus_size := f_bus_size;
  constant c_bus_bits : natural  := c_bus_size.bus_bits;
  constant c_bus_end  : unsigned(63 downto 0) := c_bus_size.bus_end;
  
  function f_addresses return t_wishbone_address_array is
    variable result : t_wishbone_address_array(g_layout'range);
    variable extend : unsigned(63 downto 0) := (others => '0');
  begin
    for i in g_layout'range loop
      result(i) := std_logic_vector(g_layout(i).wbd_begin(c_wishbone_address_width-1 downto 0));
      
      -- Range must be valid
      assert g_layout(i).wbd_begin <= g_layout(i).wbd_end
      report "Wishbone slave device #" & Integer'image(i) & " (" & g_layout(i).description & ") wbd_begin address must precede wbd_end address."
      severity Failure;
      
      -- Address must fit
      extend(c_wishbone_address_width-1 downto 0) := unsigned(result(i));
      assert g_layout(i).wbd_begin = extend
      report "Wishbone slave device #" & Integer'image(i) & " (" & g_layout(i).description & ") wbd_begin does not fit in t_wishbone_address."
      severity Failure;
    end loop;
    return result;
  end f_addresses;
  
  function f_masks return t_wishbone_address_array is
    variable result : t_wishbone_address_array(g_layout'range);
    variable size : unsigned(63 downto 0);
    variable zero : unsigned(63 downto 0) := (others => '0');
  begin
    for i in g_layout'range loop
      size := g_layout(i).wbd_end - g_layout(i).wbd_begin;
      
      -- size must be of the form 000000...00001111...1
      assert (size and (size + to_unsigned(1, 64))) = zero
      report "Wishbone slave device #" & Integer'image(i) & " (" & g_layout(i).description & ") has an address range size that is not a power of 2 minus one (" & Integer'image(to_integer(size)) & "). This is not supported by this crossbar."
      severity Failure;
      
      -- the base address must be aligned to the size
      assert (g_layout(i).wbd_begin and size) = zero
      report "Wishbone slave device #" & Integer'image(i) & " (" & g_layout(i).description & ") wbd_begin address is not aligned. This is not supported by this crossbar."
      severity Failure;
      
      size := c_bus_bits - size;
      result(i) := std_logic_vector(size(c_wishbone_address_width-1 downto 0));
    end loop;
    return result;
  end f_masks;
  
  function f_ceil_log2(x : natural) return natural is
  begin
    if x <= 1
    then return 0;
    else return f_ceil_log2((x+1)/2) +1;
    end if;
  end f_ceil_log2;
  
  -- How much space does the ROM need?
  constant c_used_entries : natural := g_layout'length + 1;
  constant c_rom_entries  : natural := 2**f_ceil_log2(c_used_entries); -- next power of 2
  constant c_sdwb_bytes   : natural := c_sdwb_device_length / 8;
  constant c_rom_bytes    : natural := c_rom_entries * c_sdwb_bytes;
  constant c_rom_mask     : unsigned(63 downto 0) := c_bus_bits - to_unsigned(c_rom_bytes-1, 64);
  constant c_sdwb_mask    : t_wishbone_address := std_logic_vector(c_rom_mask(c_wishbone_address_width-1 downto 0));
  
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
      g_layout  => g_layout,
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
