

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gencores_pkg.all;

entity gc_soft_ramp_switch is
  generic (
    g_DATA_BITS    : positive             := 16;
    g_NUM_CHANNELS : integer range 1 to 2 := 2
    );

  port (
    clk_i : in std_logic;
    rst_i : in std_logic;

    rate_i : in std_logic_vector(15 downto 0);

    on_i : in std_logic;
    kill_i : in std_logic;

    is_on_o  : out std_logic;
    is_off_o : out std_logic;
    busy_o   : out std_logic;

    x_valid_i : in std_logic;
    x0_i      : in std_logic_vector(g_DATA_BITS-1 downto 0);
    x1_i      : in std_logic_vector(g_DATA_BITS-1 downto 0) := (others => '0');
    x2_i      : in std_logic_vector(g_DATA_BITS-1 downto 0) := (others => '0');
    x3_i      : in std_logic_vector(g_DATA_BITS-1 downto 0) := (others => '0');

    y_valid_o : out std_logic;
    y0_o      : out std_logic_vector(g_DATA_BITS-1 downto 0);
    y1_o      : out std_logic_vector(g_DATA_BITS-1 downto 0);
    y2_o      : out std_logic_vector(g_DATA_BITS-1 downto 0);
    y3_o      : out std_logic_vector(g_DATA_BITS-1 downto 0)
    );
end gc_soft_ramp_switch;

architecture rtl of gc_soft_ramp_switch is

  type t_SIG_ARRAY is array(0 to 3) of signed(g_DATA_BITS-1 downto 0);

  constant c_MUL_BITS        : integer := g_DATA_BITS + 18;
  constant c_RAMP_INTEG_BITS : integer := 24;

  type t_STATE is (SW_OFF, SW_RAMP_UP, SW_ON, SW_RAMP_DOWN);

  signal ramp_integ : unsigned(c_RAMP_INTEG_BITS-1 downto 0);
  signal state      : t_STATE;

  signal mulf   : unsigned(17 downto 0);
  signal xi, yo : t_SIG_ARRAY;

  function f_mul_sar(x : signed; y : unsigned; outbits : integer) return signed is
    variable tmp : signed(x'length + y'length downto 0);
  begin
    tmp := x * signed('0'&y);

    return tmp(tmp'length-3 downto tmp'length - outbits-2);
  end f_mul_sar;


begin

  p_switch : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' or kill_i = '1' then
        state      <= SW_OFF;
        ramp_integ <= (others => '0');
        is_off_o   <= '1';
        is_on_o    <= '0';
        busy_o     <= '0';
      else
        case state is
          when SW_OFF =>
            is_off_o <= '1';
            busy_o   <= '0';
            if on_i = '1' then
              ramp_integ <= (others => '0');
              state      <= SW_RAMP_UP;
            end if;

          when SW_RAMP_UP =>
            busy_o   <= '1';
            is_off_o <= '0';
            if ramp_integ(ramp_integ'length-1) = '1' then
              state <= SW_ON;
            end if;
            ramp_integ <= ramp_integ + unsigned(rate_i);

          when SW_ON =>
            ramp_integ <= to_unsigned(2**(c_RAMP_INTEG_BITS-1), c_RAMP_INTEG_BITS);
            busy_o     <= '0';
            is_on_o    <= '1';

            if on_i = '0' then
              state <= SW_RAMP_DOWN;
            end if;

          when SW_RAMP_DOWN =>
            is_on_o <= '0';
            busy_o  <= '1';
            if(ramp_integ < unsigned(rate_i)) then
              ramp_integ <= (others => '0');
              state      <= SW_OFF;
            else
              ramp_integ <= ramp_integ - unsigned(rate_i);
            end if;
        end case;
      end if;
    end if;
  end process;


  xi(0) <= signed(x0_i);
  xi(1) <= signed(x1_i);
  xi(2) <= signed(x2_i);
  xi(3) <= signed(x3_i);

  y0_o <= std_logic_vector(yo(0));
  y1_o <= std_logic_vector(yo(1));
  y2_o <= std_logic_vector(yo(2));
  y3_o <= std_logic_vector(yo(3));


  p_mulf : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' then
        y_valid_o <= '0';
        mulf      <= (others => '0');
      else
        mulf <= ramp_integ(ramp_integ'length-1 downto ramp_integ'length - 18);

        y_valid_o <= x_valid_i;

        for i in 0 to g_NUM_CHANNELS loop
          if kill_i = '0' then
            yo(i) <= f_mul_sar(xi(i), mulf, g_DATA_BITS);
          else
            yo(i) <= (others => '0');
          end if;
        end loop;
      end if;
    end if;
  end process;
end rtl;

