library ieee;
use ieee.std_logic_1164.all;

use work.wishbone_pkg.all;
use work.wbconmax_pkg.all;

entity xwb_conmax is
  
  generic (
    g_rf_addr      : integer          := 15;
    g_num_slaves   : integer;
    g_num_masters  : integer;
    g_adr_width    : integer;
    g_sel_width    : integer;
    g_dat_width    : integer;
    g_priority_sel : t_conmax_pri_sel := c_conmax_default_pri_sel);

  port(
    clk_sys_i : in std_logic;
    rst_n_i   : in std_logic;

    slave_i : in  t_wishbone_slave_in_array(0 to g_num_slaves-1);
    slave_o : out t_wishbone_slave_out_array(0 to g_num_slaves-1);

    master_i : in  t_wishbone_master_in_array(0 to g_num_masters-1);
    master_o : out t_wishbone_master_out_array(0 to g_num_masters-1)
    );
end xwb_conmax;

architecture rtl of xwb_conmax is

  component wb_conmax_master_if
    generic (
      g_adr_width : integer;
      g_sel_width : integer;
      g_dat_width : integer);
    port (
      clk_i       : in  std_logic;
      rst_i       : in  std_logic;
      wb_master_i : in  t_wishbone_slave_in;
      wb_master_o : out t_wishbone_slave_out;
      wb_slaves_i : in  t_wishbone_master_in_array(0 to 15);
      wb_slaves_o : out t_wishbone_master_out_array(0 to 15));
  end component;

  component wb_conmax_slave_if
    generic (
      g_pri_sel : integer);
    port (
      clk_i        : in  std_logic;
      rst_i        : in  std_logic;
      conf_i       : in  std_logic_vector(15 downto 0);
      wb_slave_i   : in  t_wishbone_master_in;
      wb_slave_o   : out t_wishbone_master_out;
      wb_masters_i : in  t_wishbone_slave_in_array(0 to 7);
      wb_masters_o : out t_wishbone_slave_out_array(0 to 7));
  end component;


  component wb_conmax_rf
    generic (
      g_rf_addr   : integer range 0 to 15;
      g_adr_width : integer;
      g_sel_width : integer;
      g_dat_width : integer);
    port (
      clk_i    : in  std_logic;
      rst_i    : in  std_logic;
      int_wb_i : in  t_wishbone_slave_in;
      int_wb_o : out t_wishbone_slave_out;
      ext_wb_i : in  t_wishbone_master_in;
      ext_wb_o : out t_wishbone_master_out;
      conf_o   : out t_conmax_rf_conf);
  end component;

  signal intwb_s15_i : t_wishbone_master_in;
  signal intwb_s15_o : t_wishbone_master_out;

  type t_conmax_slave_mux_in_array is array(integer range <>) of t_wishbone_master_in_array(0 to 15);

  type t_conmax_slave_mux_out_array is array(integer range <>) of t_wishbone_master_out_array(0 to 15);

  --M0Sx
  signal m_slaves_in  : t_conmax_slave_mux_in_array(0 to 7);
  signal m_slaves_out : t_conmax_slave_mux_out_array(0 to 7);


  signal s_conf : t_conmax_rf_conf;

  signal s15_wb_masters_i : t_wishbone_slave_in_array(0 to 7);
  signal s15_wb_masters_o : t_wishbone_slave_out_array(0 to 7);

  signal rst : std_logic;

  signal slave_i_int  : t_wishbone_slave_in_array(0 to 7);
  signal slave_o_int  : t_wishbone_slave_out_array(0 to 7);
  signal master_i_int : t_wishbone_master_in_array(0 to 15);
  signal master_o_int : t_wishbone_master_out_array(0 to 15);
  
begin  -- rtl

  rst <= not rst_n_i;


  gen_real_masters : for i in 0 to g_num_slaves-1 generate
    slave_i_int(i) <= slave_i(i);
    slave_o(i)     <= slave_o_int(i);
  end generate gen_real_masters;

  gen_dummy_masters : for i in g_num_slaves to 7 generate
    slave_i_int(i).cyc <= '0';
    slave_i_int(i).stb <= '0';
    slave_i_int(i).we  <= '0';
    slave_i_int(i).adr <= (others => '0');
    slave_i_int(i).dat <= (others => '0');
  end generate gen_dummy_masters;

  gen_master_ifs : for i in 0 to 7 generate
    U_Master_IF : wb_conmax_master_if
      generic map (
        g_adr_width => g_adr_width,
        g_sel_width => g_sel_width,
        g_dat_width => g_dat_width)
      port map(
        clk_i => clk_sys_i,
        rst_i => rst,

        --Master interface
        wb_master_i => slave_i_int(i),
        wb_master_o => slave_o_int(i),
        --Slaves(0 to 15) interface
        wb_slaves_i => m_slaves_in(i),
        wb_slaves_o => m_slaves_out(i)
        );
  end generate gen_master_ifs;

  gen_slave_ifs : for i in 0 to 14 generate
    U_Slave_IF : wb_conmax_slave_if
      generic map(
        g_pri_sel => g_priority_sel(i)
        )
      port map(
        clk_i  => clk_sys_i,
        rst_i  => rst,
        conf_i => s_conf(i),

        --Slave interface
        wb_slave_i => master_i_int(I),
        wb_slave_o => master_o_int(I),

        --Interfaces to masters
        wb_masters_i(0) => m_slaves_out(0)(I),
        wb_masters_i(1) => m_slaves_out(1)(I),
        wb_masters_i(2) => m_slaves_out(2)(I),
        wb_masters_i(3) => m_slaves_out(3)(I),
        wb_masters_i(4) => m_slaves_out(4)(I),
        wb_masters_i(5) => m_slaves_out(5)(I),
        wb_masters_i(6) => m_slaves_out(6)(I),
        wb_masters_i(7) => m_slaves_out(7)(I),

        wb_masters_o(0) => m_slaves_in(0)(i),
        wb_masters_o(1) => m_slaves_in(1)(I),
        wb_masters_o(2) => m_slaves_in(2)(I),
        wb_masters_o(3) => m_slaves_in(3)(I),
        wb_masters_o(4) => m_slaves_in(4)(I),
        wb_masters_o(5) => m_slaves_in(5)(I),
        wb_masters_o(6) => m_slaves_in(6)(I),
        wb_masters_o(7) => m_slaves_in(7)(I)
        );

  end generate gen_slave_ifs;

  s15_wb_masters_i(0) <= m_slaves_out(0)(15);
  s15_wb_masters_i(1) <= m_slaves_out(1)(15);
  s15_wb_masters_i(2) <= m_slaves_out(2)(15);
  s15_wb_masters_i(3) <= m_slaves_out(3)(15);
  s15_wb_masters_i(4) <= m_slaves_out(4)(15);
  s15_wb_masters_i(5) <= m_slaves_out(5)(15);
  s15_wb_masters_i(6) <= m_slaves_out(6)(15);
  s15_wb_masters_i(7) <= m_slaves_out(7)(15);

  m_slaves_in(0)(15) <= s15_wb_masters_o(0);
  m_slaves_in(1)(15) <= s15_wb_masters_o(1);
  m_slaves_in(2)(15) <= s15_wb_masters_o(2);
  m_slaves_in(3)(15) <= s15_wb_masters_o(3);
  m_slaves_in(4)(15) <= s15_wb_masters_o(4);
  m_slaves_in(5)(15) <= s15_wb_masters_o(5);
  m_slaves_in(6)(15) <= s15_wb_masters_o(6);
  m_slaves_in(7)(15) <= s15_wb_masters_o(7);

  U_Slave15 : wb_conmax_slave_if
    generic map(
      g_pri_sel => g_priority_sel(15)
      )
    port map(
      clk_i  => clk_sys_i,
      rst_i  => rst,
      conf_i => s_conf(15),

      --Slave interface
      wb_slave_i => intwb_s15_i,
      wb_slave_o => intwb_s15_o,

      --Interfaces to masters
      wb_masters_i => s15_wb_masters_i,
      wb_masters_o => s15_wb_masters_o
      );

  U_Reg_File : wb_conmax_rf
    generic map(
      g_rf_addr   => g_rf_addr,
      g_adr_width => g_adr_width,
      g_sel_width => g_sel_width,
      g_dat_width => g_dat_width
      )
    port map(
      clk_i => clk_sys_i,
      rst_i => rst,

      int_wb_i => intwb_s15_o,
      int_wb_o => intwb_s15_i,
      ext_wb_i => master_i_int(15),
      ext_wb_o => master_o_int(15),

      conf_o => s_conf
      );


  gen_slaves_ports : for i in 0 to g_num_masters-1 generate
    master_o(i) <= master_o_int(i);
    master_i_int(i) <= master_i(i);
  end generate gen_slaves_ports;

  gen_unused_slave_ports : for i in g_num_masters to 15 generate
    master_i_int(i).ack <= '0';
    master_i_int(i).err <= '0';
    master_i_int(i).rty <= '0';
  end generate gen_unused_slave_ports;

  
end rtl;

