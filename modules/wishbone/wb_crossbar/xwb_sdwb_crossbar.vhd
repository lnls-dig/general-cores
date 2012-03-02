library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wishbone_pkg.all;

entity xwb_sdwb_crossbar is
  generic(
    g_num_masters : natural := 1;
    g_num_slaves  : natural := 1;
    g_registered  : boolean := false;
    g_address     : t_wishbone_address_array;
    g_mask        : t_wishbone_address_array;
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
  function ceil_log2(x : natural) return natural is
  begin
    if x <= 1
    then return 0;
    else return ceil_log2((x+1)/2) +1;
    end if;
  end ceil_log2;
  
  -- Our next crossbar will have one extra slave
  -- The ROM must describe all slaves and the crossbar itself
  constant c_rom_entries  : natural := 2**ceil_log2(g_num_slaves + 2);
  constant c_sdwb_words   : natural := c_sdwb_device_length / c_wishbone_data_width;
  constant c_rom_words    : natural := c_rom_entries * c_sdwb_words;
  constant c_rom_depth    : natural := ceil_log2(c_rom_words);
  constant c_rom_lowbits  : natural := ceil_log2(c_wishbone_data_width / 8);
  constant c_rom_mask : t_wishbone_address := 
    not std_logic_vector(to_unsigned((c_rom_words*c_wishbone_data_width/8) - 1, 
                                     c_wishbone_address_width));
  
  constant c_address : t_wishbone_address_array(g_num_slaves downto 0) :=
     g_sdwb_addr & g_address(g_num_slaves-1 downto 0);
  constant c_mask : t_wishbone_address_array(g_num_slaves downto 0) :=
     c_rom_mask & g_mask(g_num_slaves-1 downto 0);
  
  type t_rom is array(c_rom_words-1 downto 0) of t_wishbone_data;
  function build_rom
    return t_rom is
    variable res : t_rom := (others => (others => '0'));
    variable sdwb_device : std_logic_vector(c_sdwb_device_length-1 downto 0) := (others => '0');
  begin
    for slave in 1 to g_num_slaves loop
      res(slave*c_sdwb_words+0) := c_address(slave-1);
      res(slave*c_sdwb_words+1) := c_mask(slave-1);
    end loop;
    return res;
  end build_rom;
   
  signal rom : t_rom := build_rom;
  signal rom_i : t_wishbone_slave_in;
  signal rom_o : t_wishbone_slave_out;
  signal rom_reg : unsigned(c_rom_depth-1 downto 0);

  signal master_i_1 :  t_wishbone_master_in_array(g_num_slaves downto 0);
  signal master_o_1 : t_wishbone_master_out_array(g_num_slaves downto 0);
begin
  master_i_1 <= rom_o & master_i;
  master_o <= master_o_1(g_num_slaves-1 downto 0);
  rom_i <= master_o_1(g_num_slaves);
  
  -- Simple ROM; ignore we/sel/dat
  rom_o.err <= '0';
  rom_o.rty <= '0';
  rom_o.stall <= '0';
  rom_o.int <= '0'; -- Tom sucks! This should not be here.
  rom_o.dat <= rom(to_integer(rom_reg));
  rom_clk : process(clk_sys_i)
  begin
    if (rising_edge(clk_sys_i)) then
      rom_reg <= unsigned(rom_i.adr(c_rom_depth+c_rom_lowbits-1 downto c_rom_lowbits));
      rom_o.ack <= rom_i.cyc and rom_i.stb;
    end if;
  end process;
  
  crossbar : xwb_crossbar
    generic map(
      g_num_masters => g_num_masters,
      g_num_slaves  => g_num_slaves + 1,
      g_registered  => g_registered)
    port map(
      clk_sys_i     => clk_sys_i,
      rst_n_i       => rst_n_i,
      slave_i       => slave_i, 
      slave_o       => slave_o, 
      master_i      => master_i_1, 
      master_o      => master_o_1, 
      cfg_address_i => c_address,
      cfg_mask_i    => c_mask);
end rtl;
