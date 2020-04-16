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
      clk_ref_i    : in std_logic;
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
  
  signal par_data : std_logic_vector(15 downto 0);
  signal par_data_125 : std_logic_vector(7 downto 0);
  signal par_data_rev : std_logic_vector(15 downto 0);

  signal dout_predelay, dout_prebuf, dout_nodelay : std_logic;
  signal odelay_load                              : std_logic;
  signal rst                                      : std_logic;
  signal odelay_ntaps                             : std_logic_vector(4 downto 0);



  signal trig_d : std_logic;

--   function f_gen_bitmask (coarse : std_logic_vector; pol : std_logic; cont : std_logic) return std_logic_vector is
--     variable rv : std_logic_vector(15 downto 0);
--   begin

-- end f_gen_bitmask;

  signal mask       : std_logic_vector(31 downto 0);
  signal flip       : std_logic;
  signal dly_load_d : std_logic;

  signal clk_ref_div2 : std_logic := '0';
  signal clk_ref_div2_d0, clk_ref_div2_d1, gb_sync_p : std_logic;
  
  
  
begin

  rst <= not rst_sys_n_i;



  process(clk_ref_i)
    variable rv : std_logic_vector(31 downto 0);
  begin
    if rising_edge(clk_ref_i) then

      dly_load_d <= dly_load_i;
      if dly_load_i = '1' then
        odelay_ntaps <= dly_fine_i;

        if cont_i = '1' then

          case coarse_i is
            when x"00" =>
              rv := "11111111000000001111111100000000";
            when x"01" =>
              rv := "01111111100000000111111110000000";
            when x"02" =>
              rv := "00111111110000000011111111000000";
            when x"03" =>
              rv := "00011111111000000001111111100000";
            when x"04" =>
              rv := "00001111111100000000111111110000";
            when x"05" =>
              rv := "00000111111110000000011111111000";
            when x"06" =>
              rv := "00000011111111000000001111111100";
            when x"07" =>
              rv := "00000001111111100000000111111110";
            when x"08" =>
              rv := "00000000111111110000000011111111";
            when x"09" =>
              rv := "00000000011111111000000001111111";
            when x"0a" =>
              rv := "00000000001111111100000000111111";
            when x"0b" =>
              rv := "00000000000111111110000000011111";
            when x"0c" =>
              rv := "00000000000011111111000000001111";
            when x"0d" =>
              rv := "00000000000001111111100000000111";
            when x"0e" =>
              rv := "00000000000000111111110000000011";
            when x"0f" =>
              rv := "00000000000000011111111000000001";
            when others =>
              rv := (others => '0');
          end case;


        else
          case coarse_i is
            when x"00" =>
              rv := "11111111000000000000000000000000";
            when x"01" =>
              rv := "01111111100000000000000000000000";
            when x"02" =>
              rv := "00111111110000000000000000000000";
            when x"03" =>
              rv := "00011111111000000000000000000000";
            when x"04" =>
              rv := "00001111111100000000000000000000";
            when x"05" =>
              rv := "00000111111110000000000000000000";
            when x"06" =>
              rv := "00000011111111000000000000000000";
            when x"07" =>
              rv := "00000001111111100000000000000000";
            when x"08" =>
              rv := "00000000111111110000000000000000";
            when x"09" =>
              rv := "00000000011111111000000000000000";
            when x"0a" =>
              rv := "00000000001111111100000000000000";
            when x"0b" =>
              rv := "00000000000111111110000000000000";
            when x"0c" =>
              rv := "00000000000011111111000000000000";
            when x"0d" =>
              rv := "00000000000001111111100000000000";
            when x"0e" =>
              rv := "00000000000000111111110000000000";
            when x"0f" =>
              rv := "00000000000000011111111000000000";
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
        par_data <= mask(31 downto 16);
        flip     <= '0';
      elsif trig_d = '1' then
        par_data <= mask(15 downto 0);
      else

        if cont_i = '1' then
          if flip = '1' then
            par_data <= mask(15 downto 0);
          else
            par_data <= mask(31 downto 16);
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


  p_div_clk : process(clk_ref_i, rst_serdes_i )
  begin
    if rst_serdes_i = '1' then
      clk_ref_div2 <= '0';
    elsif rising_edge(clk_ref_i) then
      clk_ref_div2 <= not clk_ref_div2;
    end if;
  end process;
  
  
  p_gearbox : process(clk_par_i)
  begin
    if rising_edge(clk_par_i) then
      clk_ref_div2_d0 <= clk_ref_div2;
      clk_ref_div2_d1 <= clk_ref_div2_d0;
      gb_sync_p <= clk_ref_div2_d0 xor clk_ref_div2_d1;

      if gb_sync_p = '1' then
        par_data_125 <= par_data(15 downto 8);
      else
        par_data_125 <= par_data(7 downto 0);
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
        D(0)      => par_data_125(7),
        D(1)      => par_data_125(6),
        D(2)      => par_data_125(5),
        D(3)      => par_data_125(4),
        D(4)      => par_data_125(3),
        D(5)      => par_data_125(2),
        D(6)      => par_data_125(1),
        D(7)      => par_data_125(0),
        RST    => rst_serdes_i,
        T => '0'
   );



end rtl;




