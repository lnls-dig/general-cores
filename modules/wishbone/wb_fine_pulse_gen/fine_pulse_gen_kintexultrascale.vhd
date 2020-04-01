library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gencores_pkg.all;

library unisim;
use unisim.VCOMPONENTS.all;

entity fine_pulse_gen_kintexultrascale is
  generic (
    g_sim_delay_tap_ps : integer := 30;
    g_ref_clk_freq     : real    := 125.0;
    g_use_odelay       : boolean := false
    );
  port
    (
      clk_par_i    : in std_logic;
      clk_serdes_i : in std_logic;

      rst_sys_n_i : in std_logic;
      cont_i      : in std_logic;

      pol_i    : in std_logic;
      coarse_i : in std_logic_vector(7 downto 0);
      trig_p_i : in std_logic;


      pulse_o   : out std_logic;

      dly_load_i : in std_logic;
      dly_fine_i : in std_logic_vector(4 downto 0)
      );


end fine_pulse_gen_kintexultrascale;

architecture rtl of fine_pulse_gen_kintexultrascale is

  component OSERDESE3 is
    generic (
         DATA_WIDTH : integer := 8;
    INIT : bit := '0';
    IS_CLKDIV_INVERTED : bit := '0';
    IS_CLK_INVERTED : bit := '0';
    IS_RST_INVERTED : bit := '0';
    ODDR_MODE : string := "FALSE";
    OSERDES_D_BYPASS : string := "FALSE";
    OSERDES_T_BYPASS : string := "FALSE";
    SIM_DEVICE : string := "ULTRASCALE";
    SIM_VERSION : real := 2.0);
    port (
      OQ     : out std_ulogic;
      T_OUT  : out std_ulogic;
      CLK    : in  std_ulogic;
      CLKDIV : in  std_ulogic;
      D      : in  std_logic_vector(7 downto 0);
      RST    : in  std_ulogic;
      T      : in  std_ulogic);
  end component OSERDESE3;
  
  signal par_data : std_logic_vector(7 downto 0);
  
  signal par_data_rev : std_logic_vector(7 downto 0);

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


    U_Serdes : OSERDESE3
      generic map (
        DATA_WIDTH         => 8,
        INIT               => '0',
        IS_CLKDIV_INVERTED => '0',
        IS_CLK_INVERTED    => '0',
        IS_RST_INVERTED    => '0',
        ODDR_MODE          => "FALSE",
        OSERDES_D_BYPASS   => "FALSE",
        OSERDES_T_BYPASS   => "FALSE",
        SIM_DEVICE         => "ULTRASCALE")
      port map (
        OQ     => pulse_o,
        CLK    => clk_serdes_i,
        CLKDIV => clk_par_i,
        D(0)      => par_data(7),
        D(1)      => par_data(6),
        D(2)      => par_data(5),
        D(3)      => par_data(4),
        D(4)      => par_data(3),
        D(5)      => par_data(2),
        D(6)      => par_data(1),
        D(7)      => par_data(0),
        RST    => RST,
        T => '0'
   );



end rtl;




