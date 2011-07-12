library ieee;
use ieee.std_logic_1164.all;

use work.wishbone_pkg.all;

entity xwb_i2c_master is
  port (
    clk_sys_i : in std_logic;
    rst_n_i   : in std_logic;

    slave_i : in  t_wishbone_slave_in;
    slave_o : out t_wishbone_slave_out;
    desc_o  : out t_wishbone_device_descriptor;

    scl_pad_i    : in  std_logic;       -- i2c clock line input
    scl_pad_o    : out std_logic;       -- i2c clock line output
    scl_padoen_o : out std_logic;  -- i2c clock line output enable, active low
    sda_pad_i    : in  std_logic;       -- i2c data line input
    sda_pad_o    : out std_logic;       -- i2c data line output
    sda_padoen_o : out std_logic   -- i2c data line output enable, active low
    );
end xwb_i2c_master;

architecture rtl of xwb_i2c_master is

  component i2c_master_top
    generic (
      ARST_LVL : std_logic);
    port (
      wb_clk_i     : in  std_logic;
      wb_rst_i     : in  std_logic := '0';
      arst_i       : in  std_logic := not ARST_LVL;
      wb_adr_i     : in  std_logic_vector(2 downto 0);
      wb_dat_i     : in  std_logic_vector(7 downto 0);
      wb_dat_o     : out std_logic_vector(7 downto 0);
      wb_we_i      : in  std_logic;
      wb_stb_i     : in  std_logic;
      wb_cyc_i     : in  std_logic;
      wb_ack_o     : out std_logic;
      wb_inta_o    : out std_logic;
      scl_pad_i    : in  std_logic;
      scl_pad_o    : out std_logic;
      scl_padoen_o : out std_logic;
      sda_pad_i    : in  std_logic;
      sda_pad_o    : out std_logic;
      sda_padoen_o : out std_logic);
  end component;

  signal rst     : std_logic;
  signal dat_out : std_logic_vector(7 downto 0);
  
begin  -- rtl

  rst <= not rst_n_i;

  Wrapped_I2C : i2c_master_top
    generic map (
      ARST_LVL => '0')
    port map (
      wb_clk_i     => clk_sys_i,
      wb_rst_i     => rst,
      arst_i       => '1',
      wb_adr_i     => slave_i.adr(2 downto 0),
      wb_dat_i     => slave_i.dat(7 downto 0),
      wb_dat_o     => dat_out,
      wb_we_i      => slave_i.we,
      wb_stb_i     => slave_i.stb,
      wb_cyc_i     => slave_i.cyc,
      wb_ack_o     => slave_o.ack,
      wb_inta_o    => slave_o.int,
      scl_pad_i    => scl_pad_i,
      scl_pad_o    => scl_pad_o,
      scl_padoen_o => scl_padoen_o,
      sda_pad_i    => sda_pad_i,
      sda_pad_o    => sda_pad_o,
      sda_padoen_o => sda_padoen_o);

  slave_o.dat(7 downto 0)                <= dat_out;
  slave_o.dat(slave_o.dat'left downto 8) <= (others => '0');

end rtl;

