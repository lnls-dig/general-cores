library ieee;

use ieee.std_logic_1164.all;

library unisim;

use unisim.VCOMPONENTS.all;

entity fine_pulse_gen_kintexultrascale_shared is
  generic (
    g_global_use_odelay         : boolean;
    g_use_external_serdes_clock : boolean
    );
  port (
    -- PLL async reset
    pll_rst_i : in std_logic;

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

end fine_pulse_gen_kintexultrascale_shared;

architecture rtl of fine_pulse_gen_kintexultrascale_shared is

  component MMCME3_ADV
    generic (
      BANDWIDTH            : string  := "OPTIMIZED";
      CLKFBOUT_MULT_F      : real    := 5.000;
      CLKFBOUT_PHASE       : real    := 0.000;
      CLKFBOUT_USE_FINE_PS : string  := "FALSE";
      CLKIN1_PERIOD        : real    := 0.000;
      CLKIN2_PERIOD        : real    := 0.000;
      CLKOUT0_DIVIDE_F     : real    := 1.000;
      CLKOUT0_DUTY_CYCLE   : real    := 0.500;
      CLKOUT0_PHASE        : real    := 0.000;
      CLKOUT0_USE_FINE_PS  : string  := "FALSE";
      CLKOUT1_DIVIDE       : integer := 1;
      CLKOUT1_DUTY_CYCLE   : real    := 0.500;
      CLKOUT1_PHASE        : real    := 0.000;
      CLKOUT1_USE_FINE_PS  : string  := "FALSE";
      CLKOUT2_DIVIDE       : integer := 1;
      CLKOUT2_DUTY_CYCLE   : real    := 0.500;
      CLKOUT2_PHASE        : real    := 0.000;
      CLKOUT2_USE_FINE_PS  : string  := "FALSE";
      CLKOUT3_DIVIDE       : integer := 1;
      CLKOUT3_DUTY_CYCLE   : real    := 0.500;
      CLKOUT3_PHASE        : real    := 0.000;
      CLKOUT3_USE_FINE_PS  : string  := "FALSE";
      CLKOUT4_CASCADE      : string  := "FALSE";
      CLKOUT4_DIVIDE       : integer := 1;
      CLKOUT4_DUTY_CYCLE   : real    := 0.500;
      CLKOUT4_PHASE        : real    := 0.000;
      CLKOUT4_USE_FINE_PS  : string  := "FALSE";
      CLKOUT5_DIVIDE       : integer := 1;
      CLKOUT5_DUTY_CYCLE   : real    := 0.500;
      CLKOUT5_PHASE        : real    := 0.000;
      CLKOUT5_USE_FINE_PS  : string  := "FALSE";
      CLKOUT6_DIVIDE       : integer := 1;
      CLKOUT6_DUTY_CYCLE   : real    := 0.500;
      CLKOUT6_PHASE        : real    := 0.000;
      CLKOUT6_USE_FINE_PS  : string  := "FALSE";
      COMPENSATION         : string  := "AUTO";
      DIVCLK_DIVIDE        : integer := 1;
      IS_CLKFBIN_INVERTED  : bit     := '0';
      IS_CLKIN1_INVERTED   : bit     := '0';
      IS_CLKIN2_INVERTED   : bit     := '0';
      IS_CLKINSEL_INVERTED : bit     := '0';
      IS_PSEN_INVERTED     : bit     := '0';
      IS_PSINCDEC_INVERTED : bit     := '0';
      IS_PWRDWN_INVERTED   : bit     := '0';
      IS_RST_INVERTED      : bit     := '0';
      REF_JITTER1          : real    := 0.010;
      REF_JITTER2          : real    := 0.010;
      SS_EN                : string  := "FALSE";
      SS_MODE              : string  := "CENTER_HIGH";
      SS_MOD_PERIOD        : integer := 10000;
      STARTUP_WAIT         : string  := "FALSE"
      );
    port (
      CDDCDONE     : out std_ulogic;
      CLKFBOUT     : out std_ulogic;
      CLKFBOUTB    : out std_ulogic;
      CLKFBSTOPPED : out std_ulogic;
      CLKINSTOPPED : out std_ulogic;
      CLKOUT0      : out std_ulogic;
      CLKOUT0B     : out std_ulogic;
      CLKOUT1      : out std_ulogic;
      CLKOUT1B     : out std_ulogic;
      CLKOUT2      : out std_ulogic;
      CLKOUT2B     : out std_ulogic;
      CLKOUT3      : out std_ulogic;
      CLKOUT3B     : out std_ulogic;
      CLKOUT4      : out std_ulogic;
      CLKOUT5      : out std_ulogic;
      CLKOUT6      : out std_ulogic;
      DO           : out std_logic_vector(15 downto 0);
      DRDY         : out std_ulogic;
      LOCKED       : out std_ulogic;
      PSDONE       : out std_ulogic;
      CDDCREQ      : in  std_ulogic;
      CLKFBIN      : in  std_ulogic;
      CLKIN1       : in  std_ulogic;
      CLKIN2       : in  std_ulogic;
      CLKINSEL     : in  std_ulogic;
      DADDR        : in  std_logic_vector(6 downto 0);
      DCLK         : in  std_ulogic;
      DEN          : in  std_ulogic;
      DI           : in  std_logic_vector(15 downto 0);
      DWE          : in  std_ulogic;
      PSCLK        : in  std_ulogic;
      PSEN         : in  std_ulogic;
      PSINCDEC     : in  std_ulogic;
      PWRDWN       : in  std_ulogic;
      RST          : in  std_ulogic
      );
  end component;

  component BUFG is
    port (
      O : out std_ulogic;
      I : in  std_ulogic
      );
  end component BUFG;

  signal clk_ser_prebuf, mmcm_clk_fb_prebuf, mmcm_clk_fb : std_logic;
  signal clk_par_prebuf : std_logic;

begin

  gen_use_Ext_serdes_clock : if g_use_external_serdes_clock generate
    -- stub for the moment
    clk_ser_o    <= clk_ser_ext_i;
    clk_par_o    <= clk_ref_i;
    pll_locked_o <= '1';

  end generate gen_use_Ext_serdes_clock;

  gen_use_int_serdes_clock : if not g_use_external_serdes_clock generate

    U_MMCM : MMCME3_ADV
      generic map (
        BANDWIDTH       => "OPTIMIZED",  -- Jitter programming (HIGH, LOW, OPTIMIZED)
        COMPENSATION    => "AUTO",   -- AUTO, BUF_IN, EXTERNAL, INTERNAL, ZHOLD
        STARTUP_WAIT    => "FALSE",  -- Delays DONE until MMCM is locked (FALSE, TRUE)
        CLKOUT4_CASCADE => "FALSE",

        -- CLKIN_PERIOD: Input clock period in ns units, ps resolution (i.e. 33.333 is 30 MHz).
        CLKIN1_PERIOD => 16.0,

        CLKFBOUT_MULT_F => 16.0,  -- Multiply value for all CLKOUT (2.000-64.000)
        DIVCLK_DIVIDE   => 1,           -- Master division value (1-106)

        CLKFBOUT_PHASE       => 0.0,  -- Phase offset in degrees of CLKFB (-360.000-360.000)
        CLKFBOUT_USE_FINE_PS => "FALSE",

        CLKOUT0_DIVIDE_F    => 2.0,     -- clk_ser: 500 MHz
        CLKOUT0_DUTY_CYCLE  => 0.5,
        CLKOUT0_PHASE       => 0.0,
        CLKOUT1_DIVIDE    =>   8,     -- clk_par: 125 MHz
        CLKOUT1_DUTY_CYCLE  => 0.5,
        CLKOUT1_PHASE       => 0.0,
        CLKOUT0_USE_FINE_PS => "FALSE",
        CLKOUT1_USE_FINE_PS => "FALSE"
        )
      port map (
        -- Clock Inputs inputs: Clock inputs
        CLKIN1   => clk_ref_i,
        CLKIN2   => '0',
        -- Clock Outputs outputs: User configurable clock outputs
        CLKOUT0  => clk_ser_prebuf,
        CLKOUT1  => clk_par_prebuf,
        -- Feedback
        CLKFBOUT => mmcm_clk_fb_prebuf,
        CLKFBIN  => mmcm_clk_fb,
        -- Status Ports outputs: MMCM status ports
        LOCKED   => pll_locked_o,
        CDDCREQ  => '0',
        -- Control Ports inputs: MMCM control ports
        CLKINSEL => '1',
        PWRDWN   => '0',
        RST      => pll_rst_i,
        -- DRP Ports inputs: Dynamic reconfiguration ports
        DADDR    => (others => '0'),
        DCLK     => '0',
        DEN      => '0',
        DI       => (others => '0'),
        DWE      => '0',
        -- Dynamic Phase Shift Ports inputs: Ports used for dynamic phase shifting of the outputs
        PSCLK    => '0',
        PSEN     => '0',
        PSINCDEC => '0'
        );

    u_buf_mmcm_fb : BUFG
      port map (
        I => mmcm_clk_fb_prebuf,
        O => mmcm_clk_fb);

    u_buf_mmcm_ser : BUFG
      port map (
        I => clk_ser_prebuf,
        O => clk_ser_o);

    u_buf_mmcm_par : BUFG
      port map (
        I => clk_par_prebuf,
        O => clk_par_o);

  end generate gen_use_int_serdes_clock;



end rtl;
