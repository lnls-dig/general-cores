library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wishbone_pkg.all;

entity sdwb_rom is
  generic(
    g_layout      : t_sdwb_device_array;
    g_bus_end     : unsigned(63 downto 0));
  port(
    clk_sys_i     : in  std_logic;
    slave_i       : in  t_wishbone_slave_in;
    slave_o       : out t_wishbone_slave_out);
end sdwb_rom;

architecture rtl of sdwb_rom is
  function f_ceil_log2(x : natural) return natural is
  begin
    if x <= 1
    then return 0;
    else return f_ceil_log2((x+1)/2) +1;
    end if;
  end f_ceil_log2;

  constant c_version : natural := 1;
  constant c_date    : natural := 16#20120305#;
  constant c_rom_description : string(1 to 16) := "WB4-Crossbar-GSI";

  -- The ROM must describe all slaves and the crossbar itself
  alias c_layout : t_sdwb_device_array(1 to g_layout'length) is g_layout;
  constant c_used_entries : natural := g_layout'length + 1;
  constant c_rom_entries  : natural := 2**f_ceil_log2(c_used_entries); -- next power of 2
  constant c_sdwb_words   : natural := c_sdwb_device_length / c_wishbone_data_width;
  constant c_rom_words    : natural := c_rom_entries * c_sdwb_words;
  constant c_rom_depth    : natural := f_ceil_log2(c_rom_words);
  constant c_rom_lowbits  : natural := f_ceil_log2(c_wishbone_data_width / 8);
  
  type t_rom is array(c_rom_words-1 downto 0) of t_wishbone_data;
  function f_build_rom
    return t_rom is
    variable res : t_rom := (others => (others => '0'));
    variable sdwb_device : std_logic_vector(0 to c_sdwb_device_length-1) := (others => '0');
  begin
    sdwb_device(  0 to 127) := not x"40f6e98c29eae24c7e6461ae8d2af247";           -- magic
    sdwb_device(128 to 191) := std_logic_vector(g_bus_end);                       -- bus_end
    sdwb_device(192 to 207) := std_logic_vector(to_unsigned(c_used_entries, 16)); -- sdwb_records
    sdwb_device(208 to 215) := x"01";                                             -- sdwb_ver_major
    sdwb_device(216 to 223) := x"00";                                             -- sdwb_ver_minor
    sdwb_device(224 to 255) := x"00000651";                                       -- bus_vendor (GSI)
    sdwb_device(256 to 287) := x"eef0b198";                                       -- bus_device
    sdwb_device(288 to 319) := std_logic_vector(to_unsigned(c_version, 32));      -- bus_version
    sdwb_device(320 to 351) := std_logic_vector(to_unsigned(c_date,    32));      -- bus_date
    sdwb_device(352 to 383) := x"00000000";                                       -- bus_flags
    for i in 1 to 16 loop
      sdwb_device(376+i*8 to 383+i*8) := 
        std_logic_vector(to_unsigned(character'pos(c_rom_description(i)), 8));
    end loop;
    
    for i in 0 to c_sdwb_words-1 loop
      res(i) := 
        sdwb_device(i*c_wishbone_data_width to (i+1)*c_wishbone_data_width-1);
    end loop;
    
    for slave in 1 to c_used_entries-1 loop
      sdwb_device(  0 to  63) := std_logic_vector(c_layout(slave).wbd_begin);
      sdwb_device( 64 to 127) := std_logic_vector(c_layout(slave).wbd_end);
      sdwb_device(128 to 191) := std_logic_vector(c_layout(slave).sdwb_child);
      sdwb_device(192 to 199) := c_layout(slave).wbd_flags;
      sdwb_device(200 to 207) := c_layout(slave).wbd_width;
      sdwb_device(208 to 215) := std_logic_vector(c_layout(slave).abi_ver_major);
      sdwb_device(216 to 223) := std_logic_vector(c_layout(slave).abi_ver_minor);
      sdwb_device(224 to 255) := c_layout(slave).abi_class;
      sdwb_device(256 to 287) := c_layout(slave).dev_vendor;
      sdwb_device(288 to 319) := c_layout(slave).dev_device;
      sdwb_device(320 to 351) := c_layout(slave).dev_version;
      sdwb_device(352 to 383) := c_layout(slave).dev_date;
      for i in 1 to 16 loop
        -- string to ascii
        sdwb_device(376+i*8 to 383+i*8) := 
          std_logic_vector(to_unsigned(character'pos(c_layout(slave).description(i)), 8));
      end loop;
      
      for i in 0 to c_sdwb_words-1 loop
        res(slave*c_sdwb_words + i) := 
          sdwb_device(i*c_wishbone_data_width to (i+1)*c_wishbone_data_width-1);
      end loop;
    end loop;
    return res;
  end f_build_rom;
   
  signal rom : t_rom := f_build_rom;
  signal adr_reg : unsigned(c_rom_depth-1 downto 0);

begin
  -- Simple ROM; ignore we/sel/dat
  slave_o.err   <= '0';
  slave_o.rty   <= '0';
  slave_o.stall <= '0';
  slave_o.int   <= '0'; -- Tom sucks! This should not be here.

  slave_o.dat <= rom(to_integer(adr_reg));
  
  slave_clk : process(clk_sys_i)
  begin
    if (rising_edge(clk_sys_i)) then
      adr_reg <= unsigned(slave_i.adr(c_rom_depth+c_rom_lowbits-1 downto c_rom_lowbits));
      slave_o.ack <= slave_i.cyc and slave_i.stb;
    end if;
  end process;
  
end rtl;
