------------------------------------------
------------------------------------------
-- Date        : Fri May 08 16:16:48 2015
--
-- Author      : Gregoire Hagmann
--
-- Company     : CERN BE-RF
--
-- Description : Complex IQ modulator Fs/4
--
--  I_i, Q_i : IQ data in baseband
--  Q_o, Q_o : modulated IQ data
--
--  Sync : Synchronization pulse for
--         modulator reset (Cnt=0).
--         1 clk period width
--
--  ModEna: Activation of the modulator
--         '1' : Modulator on
--         '0' : Modulator off
--               (I_o=I_i)
--               (Q_o=Q_i)
--
--  Rst : output reset ('0' output)
--
--  Latency is 2 clk period
--
--  cnt= 0 /  1 /  2 /  3
--  I' = I / -Q / -I /  Q
--  Q' = Q /  I / -Q / -I
------------------------------------------
------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

entity gc_iq_modulator is
  generic (
    -- number of data bits
    g_N : positive := 16
    );
  port (
    clk_i  : in std_logic;
    en_i   : in std_logic;
    sync_p1_i : in std_logic;
    rst_i  : in std_logic;

    i_i : in std_logic_vector(g_N-1 downto 0);
    q_i : in std_logic_vector(g_N-1 downto 0);

    i_o : out std_logic_vector(g_N-1 downto 0);
    q_o : out std_logic_vector(g_N-1 downto 0)
    );
end gc_iq_modulator;


architecture rtl of gc_iq_modulator is

  type t_IQ_STATE is (S_0, S_PI2, S_PI, S_3PI2);

  signal state : t_IQ_STATE;
  signal sync  : std_logic;

  signal iin, qin   : signed(i_i'range);
  signal iout, qout : signed(i_o'range);
begin

  --Input signal Synchronization
  p_latch_input : process(clk_i)
  begin
    if rising_edge(clk_i) then
      iin  <= signed(i_i);
      qin  <= signed(q_i);
      sync <= sync_p1_i;
    end if;
  end process;


  p_modulator : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' then
        state <= S_0;
        iout  <= (others => '0');
        qout  <= (others => '0');
      elsif en_i = '0' then
        state <= S_0;
        iout  <= iin;
        qout  <= qin;
      elsif sync = '1' or state = S_3PI2 then
        state <= S_0;
        iout  <= iin;
        qout  <= qin;
      elsif state = S_0 then
        state <= S_PI2;
        iout  <= -qin;
        qout  <= iin;
      elsif state = S_PI2 then
        state <= S_PI;
        iout  <= -iin;
        qout  <= -qin;
      elsif state = S_PI then
        state <= S_3PI2;
        iout  <= qin;
        qout  <= -iin;
      end if;
    end if;
  end process;

  --output IQ data in std_logic format
  i_o <= std_logic_vector(iout);
  q_o <= std_logic_vector(qout);

end rtl;
