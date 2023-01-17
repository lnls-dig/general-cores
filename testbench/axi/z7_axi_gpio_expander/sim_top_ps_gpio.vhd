-------------------------------------------------------------------------------
-- SPDX-FileCopyrightText: 2023 CERN (home.cern)
--
-- SPDX-License-Identifier: CERN-OHL-W-2.0+
-------------------------------------------------------------------------------
-- Title      : AXI PS_GPIO Expander for Zynq-7 Testbench
-- Project    : General Cores
-------------------------------------------------------------------------------
-- File       : sim_top_ps_gpio.vhd
-- Author     : Grzegorz Daniluk <grzegorz.daniluk@cern.ch>
-- Company    : CERN
-- Platform   : FPGA-generics
-- Standard   : VHDL '93
-------------------------------------------------------------------------------
-- Description:
--
-- This is a very simple testbench for axi_gpio_expander for Zynq-7. It
-- instantiates AXI GPIO module that simulates simplified register map of Zynq-7
-- PS GPIO. Therefore no PS BFM is required and simulation can be performed
-- using xsim or GHDL.
--
-------------------------------------------------------------------------------

--=============================================================================
--                            Libraries & Packages                           --
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

--=============================================================================
--                    Entity declaration for sim_top_ps_gpio                 --
--=============================================================================

entity sim_top_ps_gpio is
end sim_top_ps_gpio;

--==============================================================================
--                           Architecture declaration                         --
--==============================================================================

architecture behav of sim_top_ps_gpio is

  -- Constants
  constant c_PERIOD : time := 10 ns;
  constant c_NUM    : integer := 54;

  -- Signals
  signal clk, rst_n : std_logic;
  signal ARVALID : std_logic;
  signal AWVALID : std_logic;
  signal BREADY  : std_logic;
  signal RREADY  : std_logic;
  signal WVALID  : std_logic;
  signal ARADDR  : std_logic_vector (31 downto 0);
  signal AWADDR  : std_logic_vector (31 downto 0);
  signal WDATA   : std_logic_vector (31 downto 0);
  signal WSTRB   : std_logic_vector (3 downto 0);
  signal ARREADY : std_logic;
  signal AWREADY : std_logic;
  signal BVALID  : std_logic;
  signal RVALID  : std_logic;
  signal WREADY  : std_logic;
  signal BRESP   : std_logic_vector (1 downto 0);
  signal RRESP   : std_logic_vector (1 downto 0);
  signal RDATA   : std_logic_vector (31 downto 0);

  signal error_b1   : std_logic;
  signal out_b0 : std_logic_vector(31 downto 0);
  signal out_b1 : std_logic_vector(31 downto 0);
  signal dir_b0 : std_logic_vector(31 downto 0);
  signal dir_b1 : std_logic_vector(31 downto 0);
  signal oen_b0 : std_logic_vector(31 downto 0);
  signal oen_b1 : std_logic_vector(31 downto 0);

  signal gpio_out : std_logic_vector(c_NUM-1 downto 0);
  signal gpio_oe  : std_logic_vector(c_NUM-1 downto 0);
  signal gpio_dir : std_logic_vector(c_NUM-1 downto 0);
  signal gpio_in  : std_logic_vector(c_NUM-1 downto 0);

begin

  CLK_GEN: process
  begin
    clk <= '0';
    wait for c_PERIOD/2;
    clk <= '1';
    wait for c_PERIOD/2;
  end process;

  rst_n <= '0', '1' after c_PERIOD*20;

  U_EXP: entity work.axi_gpio_expander
  generic map ( g_num => c_NUM)
  port map (
    clk_i   => clk,
    rst_n_i => rst_n,

    gpio_out => gpio_out,
    gpio_oe  => gpio_oe,
    gpio_dir => gpio_dir,
    gpio_in  => gpio_in,

    ARVALID =>  ARVALID,
    AWVALID =>  AWVALID,
    BREADY  =>  BREADY,
    RREADY  =>  RREADY,
    WVALID  =>  WVALID,
    ARADDR  =>  ARADDR,
    AWADDR  =>  AWADDR,
    WDATA   =>  WDATA,
    WSTRB   =>  WSTRB,
    ARREADY =>  ARREADY,
    AWREADY =>  AWREADY,
    BVALID  =>  BVALID,
    RLAST   => '0',
    RVALID  =>  RVALID,
    WREADY  =>  WREADY,
    BRESP   =>  BRESP,
    RRESP   =>  RRESP,
    RDATA   =>  RDATA);

  U_GPIO: entity work.axi_gpio
  port map (
    aclk      => clk,
    areset_n  => rst_n,
    arvalid   => ARVALID,
    awvalid   => AWVALID,
    bready    => BREADY,
    rready    => RREADY,
    wvalid    => WVALID,
    araddr    => ARADDR(15 downto 2),
    awaddr    => AWADDR(15 downto 2),
    wdata     => WDATA,
    wstrb     => WSTRB,
    arready   => ARREADY,
    awready   => AWREADY,
    bvalid    => BVALID,
    rvalid    => RVALID,
    wready    => WREADY,
    bresp     => BRESP,
    rresp     => RRESP,
    rdata     => RDATA,
    awprot    => (others=>'0'),
    arprot    => (others=>'0'),
    -- Bank0 out register
    out_b0_o  => out_b0,
    -- Bank1 out register
    out_b1_o  => out_b1,
    -- Bank0 in register
    in_b0_i   => out_b0,
    -- Bank1 in register
    in_b1_i   => out_b1,
    -- Bank0 dir register
    dir_b0_o  => dir_b0,
    -- Bank0 oen register
    oen_b0_o  => oen_b0,
    -- Bank1 dir register
    dir_b1_o  => dir_b1,
    -- Bank1 oen register
    oen_b1_o  => oen_b1);

  error_b1 <= or_reduce(out_b1(31 downto 22));

  STIM_DIR_GEN: process
  begin
    wait until rst_n = '1';
    gpio_dir <= "01" & x"abcdef3456789";
    wait for 1 us;
    while true loop
      gpio_dir <= gpio_dir(49 downto 0) & gpio_dir(53 downto 50);
      wait for 1 us;
    end loop;
    wait;
  end process;

  STIM_OE_GEN: process
  begin
    wait until rst_n = '1';
    gpio_oe <= "01" & x"abcdef3456789";
    wait for 600 ns;
    while true loop
      gpio_oe <= gpio_oe(49 downto 0) & gpio_dir(53 downto 50);
      wait for 1 us;
    end loop;
    wait;
  end process;

  STIM_GEN: process
  begin
    wait until rst_n = '1';
--    wait until rising_edge(clk);
    for i in 0 to c_NUM-1 loop
      gpio_out <= (others=>'0');
      gpio_out(i) <= '1';
      wait for 220 ns;
    end loop;
    wait;
  end process;

  --==============================================================================
  --                              Assertions                                    --
  --==============================================================================

  -- Check AXI-4 LITE signals
  p_axi_check : process(AWREADY,WREADY,BVALID,ARREADY,RVALID)
  begin
    if falling_edge(AWREADY) then
      assert (AWVALID = '0')
      report "Wrong AWVALID for AWREADY LOW" severity failure;
    end if;
    if falling_edge(WREADY) then
      assert (WVALID = '0')
      report "Wrong WVALID for WREADY LOW" severity failure;
    end if;
    if falling_edge(BVALID) then
      assert (BREADY = '0')
      report "Wrong BREADY for BVALID LOW" severity failure;
    end if;
    if falling_edge(ARREADY) then
      assert (ARVALID = '0')
      report "Wrong ARVALID for ARREADY LOW" severity failure;
    end if;
    if falling_edge(RVALID) then
      assert (RREADY = '0')
      report "Wrong RREADY for RVALID LOW" severity failure;
    end if;
  end process;


end behav;
