library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gencores_pkg.all;

library unisim;
use unisim.VCOMPONENTS.all;

entity fine_pulse_gen_kintexultrascale is
  generic (
    g_sim_delay_tap_ps : integer := 30;
    g_idelayctrl_ref_clk_freq     : real    := 250.0;
    g_use_odelay       : boolean := false
    );
  port
    (
      clk_sys_i  : in std_logic; -- system clock
      clk_ref_i    : in std_logic; -- 62.5 MHz (WR)
      clk_par_i    : in std_logic; -- 125 MHz
      clk_serdes_i : in std_logic; -- 500 MHz (DDR)
      rst_serdes_i : in std_logic;

      rst_sys_n_i : in std_logic;
      cont_i      : in std_logic;

      pol_i    : in std_logic;
      coarse_i : in std_logic_vector(7 downto 0);
      trig_p_i : in std_logic;
      ready_o : out std_logic;


      pulse_o : out std_logic;

      dly_load_i : in std_logic;
      dly_fine_i : in std_logic_vector(8 downto 0);


      odelay_cal_latch_i : in std_logic;
      odelay_value_out_o : out std_logic_vector(8 downto 0);
      odelay_value_in_i  : in  std_logic_vector(8 downto 0);
      odelay_en_vtc_i    : in  std_logic;
      odelay_load_i      : in  std_logic;
      odelay_rst_i       : in  std_logic
      );


end fine_pulse_gen_kintexultrascale;

architecture rtl of fine_pulse_gen_kintexultrascale is


  
  constant c_DELAY_VALUE : integer := 1000;  -- in ps

  component OSERDESE3 is
    generic (
      DATA_WIDTH         : integer := 8;
      INIT               : bit     := '0';
      IS_CLKDIV_INVERTED : bit     := '0';
      IS_CLK_INVERTED    : bit     := '0';
      IS_RST_INVERTED    : bit     := '0';
      ODDR_MODE          : string  := "FALSE";
      OSERDES_D_BYPASS   : string  := "FALSE";
      OSERDES_T_BYPASS   : string  := "FALSE";
      SIM_DEVICE         : string  := "ULTRASCALE";
      SIM_VERSION        : real    := 2.0);
    port (
      OQ     : out std_ulogic;
      T_OUT  : out std_ulogic;
      CLK    : in  std_ulogic;
      CLKDIV : in  std_ulogic;
      D      : in  std_logic_vector(7 downto 0);
      RST    : in  std_ulogic;
      T      : in  std_ulogic);
  end component OSERDESE3;


  component ODELAYE3
    generic (
      CASCADE          : string  := "NONE";
      DELAY_FORMAT     : string  := "TIME";
      DELAY_TYPE       : string  := "FIXED";
      DELAY_VALUE      : integer := 0;
      IS_CLK_INVERTED  : bit     := '0';
      IS_RST_INVERTED  : bit     := '0';
      REFCLK_FREQUENCY : real    := 300.0;
      SIM_DEVICE       : string  := "ULTRASCALE";
      SIM_VERSION      : real    := 2.0;
      UPDATE_MODE      : string  := "ASYNC"
      );
    port (
      CASC_OUT    : out std_ulogic;
      CNTVALUEOUT : out std_logic_vector(8 downto 0);
      DATAOUT     : out std_ulogic;
      CASC_IN     : in  std_ulogic;
      CASC_RETURN : in  std_ulogic;
      CE          : in  std_ulogic;
      CLK         : in  std_ulogic;
      CNTVALUEIN  : in  std_logic_vector(8 downto 0);
      EN_VTC      : in  std_ulogic;
      INC         : in  std_ulogic;
      LOAD        : in  std_ulogic;
      ODATAIN     : in  std_ulogic;
      RST         : in  std_ulogic
      );
  end component;



  signal par_data     : std_logic_vector(15 downto 0);
  signal par_data_125 : std_logic_vector(7 downto 0);
  signal par_data_rev : std_logic_vector(15 downto 0);

  signal odelay_load                              : std_logic;
  signal rst                                      : std_logic;
  signal pulse_predelay : std_logic;

  signal trig_d : std_logic;

--   function f_gen_bitmask (coarse : std_logic_vector; pol : std_logic; cont : std_logic) return std_logic_vector is
--     variable rv : std_logic_vector(15 downto 0);
--   begin

-- end f_gen_bitmask;

  signal mask       : std_logic_vector(31 downto 0);
  signal flip       : std_logic;
  signal dly_load_d : std_logic;

  signal clk_ref_div2                                : std_logic := '0';
  signal clk_ref_div2_d0, clk_ref_div2_d1, gb_sync_p : std_logic;

  signal odelay_value_out, odelay_value_in, odelay_value_in_pulse : std_logic_vector(8 downto 0);
  signal odelay_load_clk_ref, odelay_load_pulse    : std_logic;
  signal odelay_load_clk_par : std_logic;

  attribute mark_debug : string;

  attribute mark_debug of odelay_en_vtc_i : signal is "true";
  attribute mark_debug of odelay_cal_latch_i : signal is "true";
  attribute mark_debug of odelay_value_out : signal is "true";
  

 
begin

  rst <= not rst_sys_n_i;



  process(clk_ref_i)
    variable rv : std_logic_vector(31 downto 0);
  begin
    if rising_edge(clk_ref_i) then


      ready_o <= '1';
      dly_load_d <= dly_load_i;

      if dly_load_i = '1' then

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

      odelay_load_pulse <= dly_load_i or dly_load_d;
      odelay_value_in_pulse <= dly_fine_i;

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


  p_div_clk : process(clk_ref_i, rst_serdes_i)
  begin
    if rst_serdes_i = '1' then
      clk_ref_div2 <= '0';
    elsif rising_edge(clk_ref_i) then
      clk_ref_div2 <= not clk_ref_div2;

     
      odelay_load_clk_ref <= odelay_load_pulse or odelay_load_i;

      if odelay_load_pulse = '1' then
        odelay_value_in <= odelay_value_in_pulse; -- pulse gen FSM takes priority
      elsif odelay_load_i = '1' then -- ODELAY calibration FSM is 2nd in priority
        odelay_value_in <= odelay_value_in_i;
      end if;

      
    end if;
  end process;

  U_Sync_ODELAY_LOAD: entity work.gc_pulse_synchronizer
    port map (
      clk_in_i  => clk_ref_i,
      clk_out_i => clk_par_i,
      rst_n_i   => rst_sys_n_i,
      d_ready_o => open,
      d_p_i     => odelay_load_clk_ref,
      q_p_o     => odelay_load_clk_par);

  p_gearbox : process(clk_par_i)
  begin
    if rising_edge(clk_par_i) then
      clk_ref_div2_d0 <= clk_ref_div2;
      clk_ref_div2_d1 <= clk_ref_div2_d0;
      gb_sync_p       <= clk_ref_div2_d0 xor clk_ref_div2_d1;

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
      OQ     => pulse_predelay,
      CLK    => clk_serdes_i,
      CLKDIV => clk_par_i,
      D(0)   => par_data_125(7),
      D(1)   => par_data_125(6),
      D(2)   => par_data_125(5),
      D(3)   => par_data_125(4),
      D(4)   => par_data_125(3),
      D(5)   => par_data_125(2),
      D(6)   => par_data_125(1),
      D(7)   => par_data_125(0),
      RST    => rst_serdes_i,
      T      => '0'
      );

  gen_with_odelay : if g_use_odelay generate

    b_odelay : block
       attribute IODELAY_GROUP: string;
       attribute IODELAY_GROUP of U_ODELAYE3_Fine_Pulse_Gen : label is "IODELAY_FPGen";
       signal odelay_rst_clk_par : std_logic;
       signal odelay_en_vtc_clk_par : std_logic;
       begin

    U_Sync_Reset : gc_sync_ffs
    port map (
      clk_i    => clk_par_i,
      rst_n_i  => '1',
      data_i   => odelay_rst_i,
      synced_o => odelay_rst_clk_par
      );
    
    U_Sync_VTC : gc_sync_ffs
    port map (
      clk_i    => clk_par_i,
      rst_n_i  => '1',
      data_i   => odelay_en_vtc_i,
      synced_o => odelay_en_vtc_clk_par
      );


         
    -- If a OSERDESE3 block (or its simplified version ODDRE) is instantiated,
    -- the ODELAYE3 CLK and OSERDESE3 CLK_DIV (or ODDRE C) port must share the same clock
    U_ODELAYE3_Fine_Pulse_Gen : ODELAYE3
      generic map (
        CASCADE          => "NONE",  -- Cascade setting (MASTER, NONE, SLAVE_END, SLAVE_MIDDLE)
        DELAY_FORMAT     => "TIME",     -- (COUNT, TIME)
        DELAY_TYPE       => "VAR_LOAD",  -- Set the type of tap delay line (FIXED, VARIABLE, VAR_LOAD)
        DELAY_VALUE      => c_DELAY_VALUE,  -- Output delay tap setting
        IS_CLK_INVERTED  => '0',        -- Optional inversion for CLK
        IS_RST_INVERTED  => '0',        -- Optional inversion for RST
        REFCLK_FREQUENCY => g_idelayctrl_ref_clk_freq,  -- IDELAYCTRL clock input frequency in MHz (200.0-2667.0).
        SIM_DEVICE       => "ULTRASCALE",  -- Set the device version (ULTRASCALE, ULTRASCALE_PLUS, ULTRASCALE_PLUS_ES1, ULTRASCALE_PLUS_ES2)
        UPDATE_MODE      => "ASYNC"  -- Determines when updates to the delay will take effect (ASYNC, MANUAL, SYNC)
        )
      port map (
        CASC_OUT    => open,  -- 1-bit output: Cascade delay output to IDELAY input cascade
        CNTVALUEOUT => odelay_value_out,  -- 9-bit output: Counter value output
        DATAOUT     => pulse_o,  -- 1-bit output: Delayed data from ODATAIN input port
        CASC_IN     => '0',  -- 1-bit input: Cascade delay input from slave IDELAY CASCADE_OUT
        CASC_RETURN => '0',  -- 1-bit input: Cascade delay returning from slave IDELAY DATAOUT
        CE          => '0',  -- 1-bit input: Active high enable increment/decrement input
        CLK         => clk_par_i,    -- 1-bit input: Clock input
        CNTVALUEIN  => odelay_value_in,  -- 9-bit input: Counter value input
        EN_VTC      => odelay_en_vtc_clk_par,  -- 1-bit input: Keep delay constant over VT
        INC         => '0',  -- 1-bit input: Increment/Decrement tap delay input
        LOAD        => odelay_load_clk_par,   -- 1-bit input: Load DELAY_VALUE input
        ODATAIN     => pulse_predelay,  -- 1-bit input: Data input
        RST         => odelay_rst_clk_par  -- 1-bit input: Asynchronous Reset to the DELAY_VALUE
        );

    end block;

    -- same delay applied to all pins
    p_latch_delay : process(clk_sys_i)
    begin
      if rising_edge(clk_sys_i) then
        if odelay_cal_latch_i = '1' then
          odelay_value_out_o <= odelay_value_out;
        end if;
      end if;
    end process;

    
  end generate gen_with_odelay;

  gen_without_odelay : if not g_use_odelay generate
    pulse_o <= pulse_predelay;
    
  end generate gen_without_odelay;
  


end rtl;




