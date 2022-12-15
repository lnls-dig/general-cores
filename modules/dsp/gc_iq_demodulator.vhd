------------------------------------------
------------------------------------------
-- Date        : Sat Jul 11 15:15:22 2015
--
-- Author      : Daniel Valuch
--
-- Company     : CERN BE/RF/FB
--
-- Description : 
--
------------------------------------------
------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

entity gc_iq_demodulator is
  generic (
    -- number of data bits
    g_N : positive := 16
    );
  port (
    clk_i        : in std_logic;
    en_i         : in std_logic;
    sync_i       : in std_logic;
    rst_i        : in std_logic;
    adc_data_i   : in std_logic_vector(g_N-1 downto 0);
    dec_factor_i : in std_logic_vector(3 downto 0);

    i_o     : out std_logic_vector(23 downto 0);
    q_o     : out std_logic_vector(23 downto 0);
    valid_o : out std_logic
    );
end gc_iq_demodulator;


architecture rtl of gc_iq_demodulator is

  type t_IQ_STATE is (S_0, S_PI2, S_PI, S_3PI2);


  signal decim_cnt      : unsigned(15 downto 0);
  signal decim_cnt_init : unsigned(15 downto 0);
  signal iacc, qacc     : signed(28 downto 0);
  signal state          : t_IQ_STATE;

begin

  decim_cnt_init <= to_unsigned(2**to_integer(unsigned(dec_factor_i))-1, decim_cnt'length);

  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' or sync_i = '1' then
        state     <= S_0;
        iacc      <= (others => '0');
        qacc      <= (others => '0');
        i_o       <= (others => '0');
        q_o       <= (others => '0');
        valid_o   <= '0';
        decim_cnt <= decim_cnt_init;
      elsif en_i = '1' then

        case state is
          when S_0 =>
            state <= S_PI2;

            if decim_cnt = 0 then
              valid_o   <= '1';
              iacc      <= signed(adc_data_i);
              qacc      <= (others => '0');
              decim_cnt <= decim_cnt_init;

--                  I_out <= Std_logic_vector(Resize(shift_right(Iacc, To_Integer(Unsigned(Dec_factor))+1), 16)); -- Iacc + Signed(ADC_data) 
--                  Q_out <= Std_logic_vector(Resize(shift_right(Qacc, To_Integer(Unsigned(Dec_factor))+1), 16));   

              case dec_factor_i is
                when X"0" =>
                  I_o <= std_logic_vector(iacc(16 downto 0)&"0000000");
                  Q_o <= std_logic_vector(qacc(16 downto 0)&"0000000");
                when X"1" =>
                  I_o <= std_logic_vector(iacc(17 downto 0)&"000000");
                  Q_o <= std_logic_vector(qacc(17 downto 0)&"000000");
                when X"2" =>
                  I_o <= std_logic_vector(iacc(18 downto 0)&"00000");
                  Q_o <= std_logic_vector(Qacc(18 downto 0)&"00000");
                when X"3" =>
                  I_o <= std_logic_vector(Iacc(19 downto 0)&"0000");
                  Q_o <= std_logic_vector(Qacc(19 downto 0)&"0000");
                when X"4" =>
                  I_o <= std_logic_vector(Iacc(20 downto 0)&"000");
                  Q_o <= std_logic_vector(Qacc(20 downto 0)&"000");
                when X"5" =>
                  I_o <= std_logic_vector(Iacc(21 downto 0)&"00");
                  Q_o <= std_logic_vector(Qacc(21 downto 0)&"00");
                when X"6" =>
                  I_o <= std_logic_vector(Iacc(22 downto 0)&"0");
                  Q_o <= std_logic_vector(Qacc(22 downto 0)&"0");
                when X"7" =>
                  I_o <= std_logic_vector(Iacc(23 downto 0));
                  Q_o <= std_logic_vector(Qacc(23 downto 0));
                when X"8" =>
                  I_o <= std_logic_vector(Iacc(24 downto 1));
                  Q_o <= std_logic_vector(Qacc(24 downto 1));
                when X"9" =>
                  I_o <= std_logic_vector(Iacc(25 downto 2));
                  Q_o <= std_logic_vector(Qacc(25 downto 2));
                when X"A" =>
                  I_o <= std_logic_vector(Iacc(26 downto 3));
                  Q_o <= std_logic_vector(Qacc(26 downto 3));
                when X"B" =>
                  I_o <= std_logic_vector(Iacc(27 downto 4));
                  Q_o <= std_logic_vector(Qacc(27 downto 4));
                when X"C" =>
                  I_o <= std_logic_vector(Iacc(28 downto 5));
                  Q_o <= std_logic_vector(Qacc(28 downto 5));
                when others =>
                  I_o <= X"000000";
                  Q_o <= X"000000";
              end case;
            else
              decim_cnt <= decim_cnt - 1;
              iacc      <= iacc + signed(adc_data_i);
            end if;

          when S_PI2 =>
            state   <= S_PI;
            valid_o <= '0';
            qacc    <= qacc + signed(adc_data_i);
          when S_PI =>
            state <= S_3PI2;
            iacc  <= iacc - signed(adc_data_i);
          when S_3PI2 =>
            state <= S_0;
            qacc  <= qacc - signed(adc_data_i);
        end case;
      end if;
    end if;
  end process;

end rtl;
