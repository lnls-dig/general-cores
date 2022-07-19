library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gencores_pkg.all;
use work.wishbone_pkg.all;

use work.fpg_wbgen2_pkg.all;

--library unisim;
--use unisim.VCOMPONENTS.all;

entity xwb_fine_pulse_gen is
  generic (
    g_num_channels: integer := 6;
    g_use_external_serdes_clock : boolean := false;
    g_target_platform : string := "Kintex7";
    g_use_odelay : bit_vector(5 downto 0) := "110000"
    );
  port (
    clk_sys_i   : in std_logic;
    clk_ref_i   : in std_logic;         -- 62.5 MHz WR reference
    rst_sys_n_i : in std_logic;

    clk_ser_ext_i : in std_logic := '0';       -- external SERDES clock, used when
                                        -- g_use_external_serdes_clock == true

    ext_trigger_p_i : in std_logic := '0'; -- External trigger (i.e. RF receiver)

    pps_p_i : in std_logic;             -- WR PPS

    pulse_o : out std_logic_vector(g_num_channels-1 downto 0);

    clk_par_o : out std_logic;

    slave_i : in  t_wishbone_slave_in;
    slave_o : out t_wishbone_slave_out
    );

end xwb_fine_pulse_gen;

architecture rtl of xwb_fine_pulse_gen is

  impure function f_global_use_odelay return boolean is
  begin
    if g_use_odelay /= "000000" then
      return true;
    else
      return false;
    end if;
  end function;



  component fine_pulse_gen_kintex7_shared is
    generic (
      g_global_use_odelay : boolean;
      g_use_external_serdes_clock : boolean);
    port (
      pll_rst_i    : in  std_logic;
      clk_ser_ext_i : in std_logic;
      clk_ref_i    : in  std_logic;
      clk_par_o    : out std_logic;
      clk_ser_o    : out std_logic;
      clk_odelay_o : out std_logic;
      pll_locked_o : out std_logic);
  end component fine_pulse_gen_kintex7_shared;

  component fine_pulse_gen_kintexultrascale_shared is
    generic (
      g_global_use_odelay : boolean;
      g_use_external_serdes_clock : boolean
      );
    port (
      pll_rst_i    : in  std_logic;
      clk_ser_ext_i : in std_logic;
      clk_ref_i    : in  std_logic;
      clk_par_o    : out std_logic;
      clk_ser_o    : out std_logic;
      clk_odelay_o : out std_logic;
      pll_locked_o : out std_logic);
  end component fine_pulse_gen_kintexultrascale_shared;

  type t_channel_state is (IDLE, WAIT_PPS, WAIT_PPS_FORCED, WAIT_TRIGGER);

  type t_channel is record
    arm : std_logic;
    state      : t_channel_state;
    trig_p     : std_logic;
    trig_in : std_logic;
    trig_in_d : std_logic;
    trig_sel : std_logic;
    ready : std_logic;
    pol        : std_logic;
    cnt : unsigned(3 downto 0);
    pps_offs : unsigned(3 downto 0);
    mask       : std_logic_vector(7 downto 0);
    delay_load : std_logic;
    delay_fine : std_logic_vector(8 downto 0);
    cont : std_logic;
    force_tr : std_logic;


    odelay_load      :  std_logic;
    odelay_value_out : std_logic_vector(8 downto 0);

  end record;

  type t_channel_array is array(integer range <>) of t_channel;

  constant c_MAX_NUM_CHANNELS : integer := 6;

  signal ch : t_channel_array(0 to c_MAX_NUM_CHANNELS-1);

  signal clk_par : std_logic;
  signal clk_ser : std_logic;
  signal clk_odelay : std_logic;

  signal regs_out : t_fpg_out_registers;
  signal regs_in  : t_fpg_in_registers;

  signal rst_n_wr : std_logic;
  signal pps_p_d : std_logic;

  function f_to_bool(x : bit) return boolean is
  begin
    if x= '1' then
      return true;
    else
      return false;
    end if;
  end f_to_bool;

  constant c_pps_divider : integer := 6250;
  signal pps_ext   : std_logic;
  signal pps_cnt : unsigned(15 downto 0);

  signal pll_locked : std_logic;

  signal rst_serdes_in, rst_serdes : std_logic;
  signal odelay_calib_rdy : std_logic;

  signal pps_p1 : std_logic;

begin


  p_extend_pps : process(clk_ref_i)
  begin
    if rising_edge(clk_ref_i) then
      if rst_n_wr = '0' then
        pps_ext <= '0';
        pps_cnt <= (others => '0');
        pps_p1 <= '0';
      else

        pps_p_d <= pps_p_i;
        pps_p1 <= not pps_p_d and pps_p_i;

        if pps_p_i = '1' and pps_p_d = '0' then
          pps_cnt <= to_unsigned(1, pps_cnt'length);
          pps_ext <= '0';
        elsif pps_cnt = c_pps_divider-1 then
          pps_cnt <= (others => '0');
          pps_ext <= '1';
        else
          pps_cnt <= pps_cnt+ 1;
          pps_ext <= '0';
        end if;
      end if;
    end if;
  end process;

  U_Regs : entity work.fine_pulse_gen_wb
    port map (
      rst_n_i   => rst_sys_n_i,
      clk_sys_i => clk_sys_i,
      slave_i   => slave_i,
      slave_o   => slave_o,
      regs_i    => regs_in,
      regs_o    => regs_out);

  U_Sync_Reset : gc_sync_ffs
    port map (
      clk_i    => clk_ref_i,
      rst_n_i  => '1',
      data_i   => rst_sys_n_i,
      synced_o => rst_n_wr
      );


  U_Sync1: entity work.gc_pulse_synchronizer
    port map (
      clk_in_i  => clk_sys_i,
      clk_out_i => clk_ref_i,
      rst_n_i   => rst_sys_n_i,
      d_p_i     => regs_out.csr_trig0_o,
      q_p_o     => ch(0).arm);
  U_Sync2: entity work.gc_pulse_synchronizer
    port map (
      clk_in_i  => clk_sys_i,
      clk_out_i => clk_ref_i,
      rst_n_i   => rst_sys_n_i,
      d_p_i     => regs_out.csr_trig1_o,
      q_p_o     => ch(1).arm);
  U_Sync3: entity work.gc_pulse_synchronizer
    port map (
      clk_in_i  => clk_sys_i,
      clk_out_i => clk_ref_i,
      rst_n_i   => rst_sys_n_i,
      d_p_i     => regs_out.csr_trig2_o,
      q_p_o     => ch(2).arm);
  U_Sync4: entity work.gc_pulse_synchronizer
    port map (
      clk_in_i  => clk_sys_i,
      clk_out_i => clk_ref_i,
      rst_n_i   => rst_sys_n_i,
      d_p_i     => regs_out.csr_trig3_o,
      q_p_o     => ch(3).arm);
  U_Sync5: entity work.gc_pulse_synchronizer
    port map (
      clk_in_i  => clk_sys_i,
      clk_out_i => clk_ref_i,
      rst_n_i   => rst_sys_n_i,
      d_p_i     => regs_out.csr_trig4_o,
      q_p_o     => ch(4).arm);
  U_Sync6: entity work.gc_pulse_synchronizer
    port map (
      clk_in_i  => clk_sys_i,
      clk_out_i => clk_ref_i,
      rst_n_i   => rst_sys_n_i,
      d_p_i     => regs_out.csr_trig5_o,
      q_p_o     => ch(5).arm);

  U_Sync71: entity work.gc_pulse_synchronizer
    port map (
      clk_in_i  => clk_sys_i,
      clk_out_i => clk_ref_i,
      rst_n_i   => rst_sys_n_i,
      d_p_i     => regs_out.csr_force0_o,
      q_p_o     => ch(0).force_tr);
  U_Sync72: entity work.gc_pulse_synchronizer
    port map (
      clk_in_i  => clk_sys_i,
      clk_out_i => clk_ref_i,
      rst_n_i   => rst_sys_n_i,
      d_p_i     => regs_out.csr_force1_o,
      q_p_o     => ch(1).force_tr);
  U_Sync73: entity work.gc_pulse_synchronizer
    port map (
      clk_in_i  => clk_sys_i,
      clk_out_i => clk_ref_i,
      rst_n_i   => rst_sys_n_i,
      d_p_i     => regs_out.csr_force2_o,
      q_p_o     => ch(2).force_tr);
  U_Sync74: entity work.gc_pulse_synchronizer
    port map (
      clk_in_i  => clk_sys_i,
      clk_out_i => clk_ref_i,
      rst_n_i   => rst_sys_n_i,
      d_p_i     => regs_out.csr_force3_o,
      q_p_o     => ch(3).force_tr);
  U_Sync75: entity work.gc_pulse_synchronizer
    port map (
      clk_in_i  => clk_sys_i,
      clk_out_i => clk_ref_i,
      rst_n_i   => rst_sys_n_i,
      d_p_i     => regs_out.csr_force4_o,
      q_p_o     => ch(4).force_tr);
  U_Sync76: entity work.gc_pulse_synchronizer
    port map (
      clk_in_i  => clk_sys_i,
      clk_out_i => clk_ref_i,
      rst_n_i   => rst_sys_n_i,
      d_p_i     => regs_out.csr_force5_o,
      q_p_o     => ch(5).force_tr);



  gen_ready_flags : for i in 0 to g_num_channels-1 generate
  U_Sync : gc_sync_ffs
    port map (
      clk_i    => clk_sys_i,
      rst_n_i  => rst_sys_n_i,
      data_i   => ch(i).ready,
      synced_o => regs_in.csr_ready_i(i)
      );
  end generate gen_ready_flags;

  rst_serdes_in <= regs_out.odelay_calib_rst_oserdes_o or regs_out.csr_serdes_rst_o;

  U_Sync_Serdes_Reset : gc_sync_ffs
    port map (
      clk_i    => clk_ref_i,
      rst_n_i  => '1',
      data_i   => rst_serdes_in,
      synced_o => rst_serdes
      );


  ch(0).pol <= regs_out.ocr0_pol_o;
  ch(1).pol <= regs_out.ocr1_pol_o;
  ch(2).pol <= regs_out.ocr2_pol_o;
  ch(3).pol <= regs_out.ocr3_pol_o;
  ch(4).pol <= regs_out.ocr4_pol_o;
  ch(5).pol <= regs_out.ocr5_pol_o;

  ch(0).delay_fine <= regs_out.ocr0_fine_o;
  ch(1).delay_fine <= regs_out.ocr1_fine_o;
  ch(2).delay_fine <= regs_out.ocr2_fine_o;
  ch(3).delay_fine <= regs_out.ocr3_fine_o;
  ch(4).delay_fine <= regs_out.ocr4_fine_o;
  ch(5).delay_fine <= regs_out.ocr5_fine_o;

  ch(0).mask <= regs_out.ocr0_mask_o;
  ch(1).mask <= regs_out.ocr1_mask_o;
  ch(2).mask <= regs_out.ocr2_mask_o;
  ch(3).mask <= regs_out.ocr3_mask_o;
  ch(4).mask <= regs_out.ocr4_mask_o;
  ch(5).mask <= regs_out.ocr5_mask_o;

  ch(0).cont <= regs_out.ocr0_cont_o;
  ch(1).cont <= regs_out.ocr1_cont_o;
  ch(2).cont <= regs_out.ocr2_cont_o;
  ch(3).cont <= regs_out.ocr3_cont_o;
  ch(4).cont <= regs_out.ocr4_cont_o;
  ch(5).cont <= regs_out.ocr5_cont_o;

  ch(0).trig_sel <= regs_out.ocr0_trig_sel_o;
  ch(1).trig_sel <= regs_out.ocr1_trig_sel_o;
  ch(2).trig_sel <= regs_out.ocr2_trig_sel_o;
  ch(3).trig_sel <= regs_out.ocr3_trig_sel_o;
  ch(4).trig_sel <= regs_out.ocr4_trig_sel_o;
  ch(5).trig_sel <= regs_out.ocr5_trig_sel_o;

  ch(0).pps_offs <= unsigned(regs_out.ocr0_pps_offs_o);
  ch(1).pps_offs <= unsigned(regs_out.ocr1_pps_offs_o);
  ch(2).pps_offs <= unsigned(regs_out.ocr2_pps_offs_o);
  ch(3).pps_offs <= unsigned(regs_out.ocr3_pps_offs_o);
  ch(4).pps_offs <= unsigned(regs_out.ocr4_pps_offs_o);
  ch(5).pps_offs <= unsigned(regs_out.ocr5_pps_offs_o);

  gen_channels : for i in 0 to g_NUM_CHANNELS-1 generate





    p_fsm : process(clk_ref_i)
    begin
      if rising_edge(clk_ref_i) then
        if rst_n_wr = '0' then
          ch(i).state <= IDLE;
          ch(i).trig_p <= '0';
          ch(i).delay_load <= '0';
        else

          if ch(i).trig_sel = '1' then
            ch(i).trig_in <= ext_trigger_p_i;
          else
            ch(i).trig_in <= pps_p1;
          end if;

          ch(i).trig_in_d <= ch(i).trig_in;


          case ch(i).state is
            when IDLE =>
              ch(i).trig_p <= '0';


              if ch(i).force_tr = '1' then
                ch(i).ready <= '0';
                ch(i).cnt <= (others => '0');
                ch(i).state <= WAIT_PPS_FORCED;
                ch(i).delay_load <= '1';
              elsif ch(i).arm = '1' then
                ch(i).ready <= '0';
                ch(i).cnt <= (others => '0');
                ch(i).state <= WAIT_PPS;
                ch(i).delay_load <= '1';
              else
                ch(i).delay_load <= '0';

                ch(i).ready <= '1';

              end if;

            when WAIT_PPS_FORCED =>
              ch(i).trig_p <= '0';
              ch(i).delay_load <= '0';
              if pps_ext = '1' then
                ch(i).state <= WAIT_TRIGGER;
              end if;


            when WAIT_PPS =>
              ch(i).trig_p <= '0';
              ch(i).delay_load <= '0';
              if ch(i).trig_in = '1' and ch(i).trig_in_d = '0' then
                ch(i).state <= WAIT_TRIGGER;
              end if;

            when WAIT_TRIGGER =>
              if ch(i).cnt = ch(i).pps_offs then
                ch(i).trig_p <= '1';
                ch(i).state <= IDLE;
              else
                ch(i).trig_p <= '0';
              end if;

              ch(i).cnt <= ch(i).cnt + 1;
          end case;
        end if;
      end if;
    end process;



  gen_is_kintex7_pg: if g_target_platform = "Kintex7" generate

    U_Pulse_Gen : entity work.fine_pulse_gen_kintex7
      generic map (
        g_sim_delay_tap_ps => 50,
        g_ref_clk_freq     => 200.0,
        g_use_odelay => f_to_bool(g_use_odelay(i)) )
      port map (
        clk_par_i    => clk_par,
        clk_serdes_i => clk_ser,
        rst_serdes_i => rst_serdes,
        rst_sys_n_i  => rst_sys_n_i,
        trig_p_i     => ch(I).trig_p,
        cont_i =>  ch(i).cont,
        coarse_i       => ch(I).mask,
        pol_i        => ch(I).pol,
        pulse_o      => pulse_o(i),
        dly_load_i => ch(i).delay_load,
        dly_fine_i   => ch(i).delay_fine(4 downto 0));

  end generate gen_is_kintex7_pg;

  gen_is_kintex_us_pg: if g_target_platform = "KintexUltrascale" generate

    U_Pulse_Gen : entity work.fine_pulse_gen_kintexultrascale
      generic map (
        g_sim_delay_tap_ps => 50,
        g_idelayctrl_ref_clk_freq     => 250.0,
        g_use_odelay => f_to_bool(g_use_odelay(i)) )
      port map (
        clk_sys_i => clk_sys_i,
        clk_par_i    => clk_par,
        clk_ref_i => clk_ref_i,
        clk_serdes_i => clk_ser,
        rst_serdes_i => rst_serdes,
        rst_sys_n_i  => rst_sys_n_i,
        trig_p_i     => ch(I).trig_p,
        cont_i => ch(i).cont,
        coarse_i       => ch(I).mask,
        pol_i        => ch(I).pol,
        pulse_o      => pulse_o(i),
        dly_load_i => ch(i).delay_load,
        dly_fine_i   => ch(i).delay_fine,

        odelay_load_i => ch(i).odelay_load,
        odelay_en_vtc_i => regs_out.odelay_calib_en_vtc_o,
        odelay_rst_i => regs_out.odelay_calib_rst_odelay_o,
        odelay_value_in_i => regs_out.odelay_calib_value_o,
        odelay_value_out_o => ch(i).odelay_value_out,
        odelay_cal_latch_i => regs_out.odelay_calib_cal_latch_o

        );

  end generate gen_is_kintex_us_pg;

  end generate;


  regs_in.odelay_calib_taps_i <= ch(0).odelay_value_out;


  gen_is_kintex7: if g_target_platform = "Kintex7" generate

    U_K7_Shared: fine_pulse_gen_kintex7_shared
      generic map (
        g_global_use_odelay => f_global_use_odelay,
        g_use_external_serdes_clock => g_use_external_serdes_clock)
      port map (
        pll_rst_i    => regs_out.csr_pll_rst_o,
        clk_ref_i    => clk_ref_i,
        clk_par_o    => clk_par,
        clk_ser_o    => clk_ser,
        clk_ser_ext_i => clk_ser_ext_i,
--        clk_odelay_o => clk_odelay,
        pll_locked_o => pll_locked);

  end generate gen_is_kintex7;

  gen_is_kintex_ultrascale: if g_target_platform = "KintexUltrascale" generate

    U_K7U_Shared: entity work.fine_pulse_gen_kintexultrascale_shared
      generic map (
        g_global_use_odelay => f_global_use_odelay,
        g_use_external_serdes_clock => g_use_external_serdes_clock
        )
      port map (
        pll_rst_i    => regs_out.csr_pll_rst_o,
        clk_ref_i    => clk_ref_i,
        clk_par_o    => clk_par,
        clk_ser_o    => clk_ser,
        clk_ser_ext_i => clk_ser_ext_i,
--        clk_odelay_o => clk_odelay,
        pll_locked_o => pll_locked,

        odelayctrl_rdy_o => odelay_calib_rdy,
        odelayctrl_rst_i => regs_out.odelay_calib_rst_idelayctrl_o
        );

    U_Sync_Reset : gc_sync_ffs
    port map (
      clk_i    => clk_sys_i,
      rst_n_i  => rst_sys_n_i,
      data_i   => odelay_calib_rdy,
      synced_o => regs_in.odelay_calib_rdy_i
      );

  end generate gen_is_kintex_ultrascale;

  clk_par_o <= clk_par;
  regs_in.csr_pll_locked_i <= pll_locked;

end rtl;
