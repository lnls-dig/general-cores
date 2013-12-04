library ieee;
use ieee.std_logic_1164.all;

-- A wrapper for undocumented Altera SPI interface pins
entity altera_spi is
  generic(
    g_family     : string  := "none";
    g_port_width : natural := 1);
  port(
    dclk_i : in  std_logic;
    ncs_i  : in  std_logic;
    oe_i   : in  std_logic_vector(g_port_width-1 downto 0);
    asdo_i : in  std_logic_vector(g_port_width-1 downto 0);
    data_o : out std_logic_vector(g_port_width-1 downto 0));
end entity;

architecture rtl of altera_spi is

  -- Undocumented Altera ASMI interface components:
  
  component cyclone_asmiblock
    port(
      dclkin   : in  std_logic;
      scein    : in  std_logic;
      sdoin    : in  std_logic;
      data0out : out std_logic;
      oe       : in  std_logic);
  end component;

  component cycloneii_asmiblock 
    port(
      dclkin   : in  std_logic;
      scein    : in  std_logic;
      sdoin    : in  std_logic;
      data0out : out std_logic;
      oe       : in  std_logic);
  end component;

  component cyclonev_asmiblock 
    port(
      dclk     : in std_logic;
      sce      : in std_logic;
      oe       : in std_logic;
      data0out : in std_logic;
      data1out : in std_logic;
      data2out : in std_logic;
      data3out : in std_logic;
      data0oe  : in std_logic;
      data1oe  : in std_logic;
      data2oe  : in std_logic;
      data3oe  : in std_logic;
      data0in  : out std_logic;
      data1in  : out std_logic;
      data2in  : out std_logic;
      data3in  : out std_logic);
  end component;
  
  component stratixii_asmiblock 
    port(
      dclkin   : in  std_logic;
      scein    : in  std_logic;
      sdoin    : in  std_logic;
      data0out : out std_logic;
      oe       : in  std_logic);
  end component;
  
  component stratixiii_asmiblock 
    port(
      dclkin   : in  std_logic;
      scein    : in  std_logic;
      sdoin    : in  std_logic;
      data0out : out std_logic;
      oe       : in  std_logic);
  end component;
  
  component stratixiv_asmiblock 
    port(
      dclkin   : in  std_logic;
      scein    : in  std_logic;
      sdoin    : in  std_logic;
      data0out : out std_logic;
      oe       : in  std_logic);
  end component;
  
  component stratixv_asmiblock
    port(
      dclk     : in  std_logic;
      sce      : in  std_logic;
      oe       : in  std_logic;
      data0out : in  std_logic;
      data1out : in  std_logic;
      data2out : in  std_logic;
      data3out : in  std_logic;
      data0oe  : in  std_logic;
      data1oe  : in  std_logic;
      data2oe  : in  std_logic;
      data3oe  : in  std_logic;
      data0in  : out std_logic;
      data1in  : out std_logic;
      data2in  : out std_logic;
      data3in  : out std_logic);
  end component;
  
  component arriav_asmiblock 
    port(
      dclk     : in  std_logic;
      sce      : in  std_logic;
      oe       : in  std_logic;
      data0out : in  std_logic;
      data1out : in  std_logic;
      data2out : in  std_logic;
      data3out : in  std_logic;
      data0oe  : in  std_logic;
      data1oe  : in  std_logic;
      data2oe  : in  std_logic;
      data3oe  : in  std_logic;
      data0in  : out std_logic;
      data1in  : out std_logic;
      data2in  : out std_logic;
      data3in  : out std_logic);
  end component;
  
  type t_block is (T_CYCLONE, T_CYCLONEII, T_CYCLONEV,
                   T_STRATIXII, T_STRATIXIII, T_STRATIXIV, T_STRATIXV, 
                   T_ARRIAV, 
                   T_UNKNOWN);
  
  function f_block(family : string) return t_block is
    variable identifier : string(1 to 15) := (others => ' ');
  begin
    identifier(family'range) := family;
    case identifier is
      when "Cyclone        " => return T_CYCLONE;
      when "Cyclone II     " => return T_CYCLONEII;
      when "Cyclone III    " => return T_CYCLONEII;
      when "Cyclone III LS " => return T_CYCLONEII;
      when "Cyclone IV E   " => return T_CYCLONEII;
      when "Cyclone IV GX  " => return T_CYCLONEII;
      when "Cyclone V      " => return T_CYCLONEV;
      when "Stratix II     " => return T_STRATIXII;
      when "Stratix II GX  " => return T_STRATIXII;
      when "Arria GX       " => return T_STRATIXII;
      when "Stratix III    " => return T_STRATIXIII;
      when "Stratix IV     " => return T_STRATIXIV;
      when "Arria II GX    " => return T_STRATIXIV;
      when "Arria II GZ    " => return T_STRATIXIV;
      when "Stratix V      " => return T_STRATIXV;
      when "Arria V        " => return T_ARRIAV;
      when others            => return T_UNKNOWN;
    end case;
  end f_block;
  
  function f_support4(x : t_block) return boolean is
  begin
    case x is
      when T_ARRIAV   => return true;
      when T_CYCLONEV => return true;
      when T_STRATIXV => return true;
      when others     => return false;
    end case;
  end f_support4;
  
  constant c_block    : t_block := f_block(g_family);
  constant c_support4 : boolean := f_support4(c_block);
  
  signal oe   : std_logic_vector(3 downto 0);
  signal asdo : std_logic_vector(3 downto 0);
  signal data : std_logic_vector(3 downto 0);
  
  -- attribute altera_attribute : string;
  -- attribute altera_attribute of rtl: architecture is "SUPPRESS_DA_RULE_INTERNAL=C104";

begin

  assert (c_block /= T_UNKNOWN)
  report "g_family = " & g_family & " is unsupported"
  severity error;

  assert (g_port_width = 1 or g_port_width = 4)
  report "g_port_width must be 1 or 4, not " & integer'image(g_port_width)
  severity error;
  
  assert (g_port_width /= 4 or c_support4)
  report "g_family = " & g_family & " does not support g_port_width = 4"
  severity error;
  
  data_o <= data(data_o'range);
  
  width1 : if g_port_width = 1 generate
    oe   <= (0 => '1', 1 => '0', others => '1');
    asdo <= (0 => asdo_i(0), others => '1');
  end generate;
  
  width4 : if g_port_width = 4 generate
    oe   <= oe_i;
    asdo <= asdo_i;
  end generate;
  
  cyclone : if c_block = T_CYCLONE generate
    cyclone_inst : cyclone_asmiblock 
      port map(
        dclkin   => dclk_i,
        scein    => ncs_i,
        sdoin    => asdo(0),
        data0out => data(0),
        oe       => '0');
  end generate;
  
  cycloneii : if c_block = T_CYCLONEII generate
    cycloneii_inst: cycloneii_asmiblock
      port map(
        dclkin   => dclk_i,
        scein    => ncs_i,
        sdoin    => asdo(0),
        data0out => data(0),
        oe       => '0');
  end generate;

  stratixii : if c_block = T_STRATIXII generate
    stratixii_inst : stratixii_asmiblock 
      port map(
        dclkin   => dclk_i,
        scein    => ncs_i,
        sdoin    => asdo(0),
        data0out => data(0),
        oe       => '0');
  end generate;
  
  stratixiii : if c_block = T_STRATIXIII generate
    stratixiii_inst: stratixiii_asmiblock 
      port map(
	dclkin   => dclk_i,
	scein    => ncs_i,
	sdoin    => asdo(0),
	data0out => data(0),
	oe       => '0');
  end generate;
  
  stratixiv : if c_block = T_STRATIXIV generate
    asmi_inst: stratixiv_asmiblock
      port map(
	dclkin   => dclk_i,
	scein    => ncs_i,
	sdoin    => asdo(0),
	data0out => data(0),
	oe       => '0');
  end generate;
  
  stratixv : if c_block = T_STRATIXV generate
    stratixv_inst : stratixv_asmiblock
      port map(
        dclk     => dclk_i,
        sce      => ncs_i,
        oe       => '0',
        data0out => asdo(0),
        data1out => asdo(1),
        data2out => asdo(2),
        data3out => asdo(3),
        data0oe  => oe(0),
        data1oe  => oe(1),
        data2oe  => oe(2),
        data3oe  => oe(3),
        data0in  => data(0),
        data1in  => data(1),
        data2in  => data(2),
        data3in  => data(3));
  end generate;
  
  arriav : if c_block = T_ARRIAV generate
    arriav_inst : arriav_asmiblock
      port map(
        dclk     => dclk_i,
        sce      => ncs_i,
        oe       => '0',
        data0out => asdo(0),
        data1out => asdo(1),
        data2out => asdo(2),
        data3out => asdo(3),
        data0oe  => oe(0),
        data1oe  => oe(1),
        data2oe  => oe(2),
        data3oe  => oe(3),
        data0in  => data(0),
        data1in  => data(1),
        data2in  => data(2),
        data3in  => data(3));
  end generate;
  
  cyclonev : if c_block = T_CYCLONEV generate
    cyclonev_inst : cyclonev_asmiblock 
      port map(
        dclk     => dclk_i,
        sce      => ncs_i,
        oe       => '0',
        data0out => asdo(0),
        data1out => asdo(1),
        data2out => asdo(2),
        data3out => asdo(3),
        data0oe  => oe(0),
        data1oe  => oe(1),
        data2oe  => oe(2),
        data3oe  => oe(3),
        data0in  => data(0),
        data1in  => data(1),
        data2in  => data(2),
        data3in  => data(3));
  end generate;

end rtl;
