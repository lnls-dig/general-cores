library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gencores_pkg.all;

library unisim;
use unisim.VCOMPONENTS.all;

entity fine_pulse_gen_kintex7 is
  generic (
    g_sim_delay_tap_ps : integer := 30;
    g_ref_clk_freq     : real    := 125.0;
    g_use_odelay       : boolean := false
    );
  port
    (
      clk_par_i    : in std_logic;
      clk_serdes_i : in std_logic;

      rst_serdes_i : in std_logic;
      rst_sys_n_i : in std_logic;
      cont_i      : in std_logic;

      pol_i    : in std_logic;
      coarse_i : in std_logic_vector(7 downto 0);
      trig_p_i : in std_logic;


      pulse_o   : out std_logic;

      dly_load_i : in std_logic;
      dly_fine_i : in std_logic_vector(4 downto 0)
      );


end fine_pulse_gen_kintex7;

architecture rtl of fine_pulse_gen_kintex7 is

  signal par_data : std_logic_vector(7 downto 0);

  signal dout_predelay, dout_prebuf, dout_nodelay : std_logic;
  signal odelay_load                              : std_logic;
  signal rst                                      : std_logic;
  signal odelay_ntaps                             : std_logic_vector(4 downto 0);


  signal trig_d : std_logic;

--   function f_gen_bitmask (coarse : std_logic_vector; pol : std_logic; cont : std_logic) return std_logic_vector is
--     variable rv : std_logic_vector(15 downto 0);
--   begin

-- end f_gen_bitmask;

  signal mask       : std_logic_vector(15 downto 0);
  signal flip       : std_logic;
  signal dly_load_d : std_logic;
begin

  rst <= not rst_sys_n_i;



  process(clk_par_i)
    variable rv : std_logic_vector(15 downto 0);
  begin
    if rising_edge(clk_par_i) then

      dly_load_d <= dly_load_i;
      if dly_load_i = '1' then
        odelay_ntaps <= dly_fine_i;

        if cont_i = '1' then

          case coarse_i is
            when x"00" =>
              rv := "1111000011110000";
            when x"01" =>
              rv := "0111100001111000";
            when x"02" =>
              rv := "0011110000111100";
            when x"03" =>
              rv := "0001111000011110";
            when x"04" =>
              rv := "0000111100001111";
            when x"05" =>
              rv := "1000011110000111";
            when x"06" =>
              rv := "1100001111000011";
            when x"07" =>
              rv := "1110000111100001";
            when others =>
              rv := (others => '0');
          end case;


        else
          case coarse_i is
            when x"00" =>
              rv := "1111000000000000";
            when x"01" =>
              rv := "0111100000000000";
            when x"02" =>
              rv := "0011110000000000";
            when x"03" =>
              rv := "0001111000000000";
            when x"04" =>
              rv := "0000111100000000";
            when x"05" =>
              rv := "0000011110000000";
            when x"06" =>
              rv := "0000001111000000";
            when x"07" =>
              rv := "0000000111100000";
            when others =>
              rv := (others => '0');
          end case;
        end if;

        if pol_i = '0' then
          mask <= rv;
        else
          mask <= not rv;
        end if;

      end if;

      odelay_load <= dly_load_i or dly_load_d;


      trig_d <= trig_p_i;

      if trig_p_i = '1' then
        par_data <= mask(15 downto 8);
        flip     <= '0';
      elsif trig_d = '1' then
        par_data <= mask(7 downto 0);
      else

        if cont_i = '1' then
          if flip = '1' then
            par_data <= mask(7 downto 0);
          else
            par_data <= mask(15 downto 8);
          end if;
        else
          if pol_i = '1' then
            par_data <= (others => '1');
          else
            par_data <= (others => '0');
          end if;
        end if;
      end if;
    end if;
  end process;


  U_Serdes : OSERDESE2
    generic map (

      DATA_RATE_OQ   => "SDR",
      DATA_RATE_TQ   => "SDR",
      DATA_WIDTH     => 8,
      TRISTATE_WIDTH => 1,
      SERDES_MODE    => "MASTER")
    port map (

      D1       => par_data(7),
      D2       => par_data(6),
      D3       => par_data(5),
      D4       => par_data(4),
      D5       => par_data(3),
      D6       => par_data(2),
      D7       => par_data(1),
      D8       => par_data(0),
      T1       => '0',
      T2       => '0',
      T3       => '0',
      T4       => '0',
      SHIFTIN1 => '0',
      SHIFTIN2 => '0',
      OCE      => '1',
      CLK      => clk_serdes_i,
      CLKDIV   => clk_par_i,
      OFB      => dout_predelay,
      OQ       => dout_nodelay,
      TBYTEIN  => '0',
      TCE      => '0',
      RST      => rst_serdes_i);

  gen_with_odelay : if g_use_odelay generate

    U_Delay : ODELAYE2
      generic map (
        CINVCTRL_SEL          => "FALSE",
        DELAY_SRC             => "ODATAIN",
        HIGH_PERFORMANCE_MODE => "TRUE",
        ODELAY_TYPE           => "VAR_LOAD",
        ODELAY_VALUE          => 0,
        REFCLK_FREQUENCY      => g_ref_clk_freq,
        PIPE_SEL              => "FALSE",
        SIGNAL_PATTERN        => "DATA"
        )
      port map (
        DATAOUT    => dout_prebuf,
        CLKIN      => '0',
        C          => clk_par_i,
        CE         => '0',
        INC        => '0',
        ODATAIN    => dout_predelay,
        LD         => odelay_load,
        REGRST     => rst_serdes_i,
        LDPIPEEN   => '0',
        CNTVALUEIN => odelay_ntaps,
        CINVCTRL   => '0'
        );

  end generate gen_with_odelay;

  gen_without_odelay : if not g_use_odelay generate
    dout_prebuf <= dout_nodelay;
  end generate gen_without_odelay;

  pulse_o <= dout_prebuf;
  
  -- gen_output_diff : if g_use_diff_output generate
  --   U_OBuf : OBUFDS
  --     generic map(
  --       IOSTANDARD => "LVDS_25",
  --       SLEW       => "FAST")
  --     port map(
  --       O  => pulse_p_o,
  --       OB => pulse_n_o,
  --       I  => dout_prebuf);

  -- end generate gen_output_diff;




end rtl;




