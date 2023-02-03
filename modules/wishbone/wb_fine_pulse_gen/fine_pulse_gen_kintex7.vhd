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
      rst_sys_n_i  : in std_logic;
      cont_i       : in std_logic;

      pol_i    : in std_logic;
      coarse_i : in std_logic_vector(3 downto 0);
      trig_p_i : in std_logic;
      length_i : in std_logic_vector(23 downto 0);

      pulse_o : out std_logic;
      ready_o : out std_logic;

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

  signal mask_start    : std_logic_vector(15 downto 0);
  signal mask_end      : std_logic_vector(15 downto 0);
  signal dly_load_d    : std_logic;
  signal length_d      : unsigned(23 downto 0);
  signal pulse_pending : std_logic;

  attribute mark_debug                 : string;
  attribute mark_debug of pol_i        : signal is "TRUE";
  attribute mark_debug of coarse_i     : signal is "TRUE";
  attribute mark_debug of trig_p_i     : signal is "TRUE";
  attribute mark_debug of dly_load_i   : signal is "TRUE";
  attribute mark_debug of dly_fine_i   : signal is "TRUE";
  attribute mark_debug of odelay_ntaps : signal is "TRUE";

  type t_state is (IDLE, CONT_H, CONT_L, START_PULSE_H, START_PULSE_L, MID_PULSE_H, MID_PULSE_L, END_PULSE_H, END_PULSE_L);

  signal state : t_state;

begin

  rst <= not rst_sys_n_i;



  process(clk_par_i, rst_sys_n_i)
    variable rv, rv2 : std_logic_vector(15 downto 0);
  begin
    if rst_sys_n_i = '0' then
      pulse_pending <= '0';
      dly_load_d <= '0';
      ready_o <= '0';
    elsif rising_edge(clk_par_i) then

      dly_load_d <= dly_load_i;

      if dly_load_i = '1' then
        odelay_ntaps <= dly_fine_i;
        length_d     <= unsigned(length_i);

        if cont_i = '1' then

          case coarse_i is
            when x"0" =>
              rv := "1111000011110000";
            when x"1" =>
              rv := "0111100001111000";
            when x"2" =>
              rv := "0011110000111100";
            when x"3" =>
              rv := "0001111000011110";
            when x"4" =>
              rv := "0000111100001111";
            when x"5" =>
              rv := "1000011110000111";
            when x"6" =>
              rv := "1100001111000011";
            when x"7" =>
              rv := "1110000111100001";
            when others =>
              rv := (others => '0');
          end case;

          if pol_i = '1' then
            mask_start <= not rv;
            mask_end   <= not rv;
          else
            mask_start <= rv;
            mask_end   <= rv;
          end if;



        else

          if unsigned(length_i) = 0 then

            case coarse_i is
              when x"0" =>
                rv := "1111000000000000";
              when x"1" =>
                rv := "0111100000000000";
              when x"2" =>
                rv := "0011110000000000";
              when x"3" =>
                rv := "0001111000000000";
              when x"4" =>
                rv := "0000111100000000";
              when x"5" =>
                rv := "0000011110000000";
              when x"6" =>
                rv := "0000001111000000";
              when x"7" =>
                rv := "0000000111100000";
              when others =>
                rv := (others => '0');
            end case;

            if pol_i = '1' then
              mask_start <= not rv;
              mask_end   <= not rv;
            else
              mask_start <= rv;
              mask_end   <= rv;
            end if;


          else
            case coarse_i is
              when x"0" =>
                rv := "1111111111111111";
              when x"1" =>
                rv := "0111111111111111";
              when x"2" =>
                rv := "0011111111111111";
              when x"3" =>
                rv := "0001111111111111";
              when x"4" =>
                rv := "0000111111111111";
              when x"5" =>
                rv := "0000011111111111";
              when x"6" =>
                rv := "0000001111111111";
              when x"7" =>
                rv := "0000000111111111";
              when x"8" =>
                rv := "0000000011111111";
              when x"9" =>
                rv := "0000000001111111";
              when x"a" =>
                rv := "0000000000111111";
              when x"b" =>
                rv := "0000000000011111";
              when x"c" =>
                rv := "0000000000001111";
              when x"d" =>
                rv := "0000000000000111";
              when x"e" =>
                rv := "0000000000000011";
              when x"f" =>
                rv := "0000000000000001";
              when others =>
                rv := (others => '0');
            end case;

            if pol_i = '1' then
              mask_start <= not rv;
              mask_end   <= rv;
            else
              mask_start <= rv;
              mask_end   <= not rv;
            end if;


          end if;
        end if;

      end if;

      odelay_load <= dly_load_i or dly_load_d;


      case state is
        when IDLE =>

          if pol_i = '1' then
            par_data <= (others => '1');
          else
            par_data <= (others => '0');
          end if;

          ready_o <= '1';

          if trig_p_i = '1' then
            if cont_i = '1' then
              state <= CONT_H;
              ready_o <= '0';
            elsif length_d = 0 then
              state <= END_PULSE_H;
              ready_o <= '0';
            else
              state <= START_PULSE_H;
              ready_o <= '0';
            end if;
          end if;

        when CONT_H =>
          if cont_i = '0' then
            state <= IDLE;
          else
            state <= CONT_L;
          end if;

          par_data <= mask_start(15 downto 8);
        when CONT_L =>
          par_data <= mask_start(7 downto 0);
          state    <= CONT_H;
        when START_PULSE_H =>
          par_data <= mask_start(15 downto 8);
          state    <= START_PULSE_L;

        when START_PULSE_L =>
          par_data <= mask_start(7 downto 0);
          if length_d = 0 then
            state <= IDLE;
          else
            state <= MID_PULSE_H;
          end if;

        when MID_PULSE_H =>
          state <= MID_PULSE_L;

          if pol_i = '1' then
            par_data <= (others => '0');
          else
            par_data <= (others => '1');
          end if;

        when MID_PULSE_L =>

          if length_d = 0 then
            state <= END_PULSE_H;
          else
            state <= MID_PULSE_L;
          end if;

          length_d <= length_d - 1;

          if pol_i = '1' then
            par_data <= (others => '0');
          else
            par_data <= (others => '1');
          end if;

        when END_PULSE_H =>
          par_data <= mask_end(15 downto 8);
          state    <= END_PULSE_L;

        when END_PULSE_L =>
          par_data <= mask_end(7 downto 0);
          state    <= IDLE;

      end case;

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




