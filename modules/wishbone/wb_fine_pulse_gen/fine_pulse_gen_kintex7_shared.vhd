library ieee;

use ieee.std_logic_1164.all;

library unisim;

use unisim.VCOMPONENTS.all;

entity fine_pulse_gen_kintex7_shared is
  generic (
    g_global_use_odelay : boolean;
    g_use_external_serdes_clock : boolean
    );
  port (
    -- PLL async reset
    pll_rst_i : in std_logic;

    idelayctrl_rst_i : in std_logic;
    idelayctrl_rdy_o : out std_logic;

    clk_ser_ext_i : in std_logic;
    
    -- 62.5 MHz reference
    clk_ref_i : in std_logic;

    -- serdes parallel clock
    clk_par_o : out std_logic;

    -- serdes serial clock
    clk_ser_o : out std_logic;

    clk_odelay_o : out std_logic;

    pll_locked_o : out std_logic
    );

end fine_pulse_gen_kintex7_shared;

architecture rtl of fine_pulse_gen_kintex7_shared is

  signal pll_locked                                                 : std_logic;
  signal clk_fb_pll, clk_fb_pll_bufg, clk_iodelay, clk_iodelay_bufg : std_logic;

begin

  pll_iodelay_map : PLLE2_ADV
    generic map(
      BANDWIDTH          => ("HIGH"),
      COMPENSATION       => ("ZHOLD"),
      STARTUP_WAIT       => ("FALSE"),
      DIVCLK_DIVIDE      => (1),
      CLKFBOUT_MULT      => (16),
      CLKFBOUT_PHASE     => (0.000),
      CLKOUT0_DIVIDE     => (5),        -- 200 MHz
      CLKOUT0_PHASE      => (0.000),
      CLKOUT0_DUTY_CYCLE => (0.500),
      CLKOUT1_DIVIDE     => (2),        -- 500 MHz
      CLKOUT1_PHASE      => (0.000),
      CLKOUT1_DUTY_CYCLE => (0.500),
      CLKIN1_PERIOD      => (16.000))
    port map(

      CLKFBOUT => clk_fb_pll,
      CLKOUT0  => clk_iodelay,
      CLKOUT1  => clk_ser_o,
      -- Input clock control
      CLKFBIN  => clk_fb_pll_bufg,
      CLKIN1   => clk_ref_i,
      CLKIN2   => '0',
      CLKINSEL => '1',
      DADDR    => (others => '0'),
      DCLK     => '0',
      DEN      => '0',
      DI       => (others => '0'),

      DWE    => '0',
      PWRDWN => '0',
      RST    => pll_rst_i,
      LOCKED => pll_locked_o

      );

  clk_par_o <= clk_ref_i;

  int_bufg : BUFG
    port map (
      O => clk_fb_pll_bufg,
      I => clk_fb_pll
      );

  gen_with_iodelay : if g_global_use_odelay generate

    int_bufg_clkiodelay : BUFG
      port map (
        O => clk_iodelay_bufg,
        I => clk_iodelay
        );

    IDELAYCTRL_inst : IDELAYCTRL
      port map (
        RDY    => idelayctrl_rdy_o,                 -- 1-bit output: Ready output
        REFCLK => clk_iodelay_bufg,     -- 1-bit input: Reference clock input
        RST    => idelayctrl_rst_i                   -- 1-bit input: Active high reset input
        );

    clk_odelay_o <= clk_iodelay_bufg;
    
  end generate gen_with_iodelay;

end rtl;
