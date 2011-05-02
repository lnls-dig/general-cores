library ieee;
use ieee.std_logic_1164.all;

entity vic_prio_enc is

  port (
    in_i  : in  std_logic_vector(31 downto 0);
    out_o : out std_logic_vector(4 downto 0)
    );

end vic_prio_enc;

architecture syn of vic_prio_enc is

begin  -- syn

  prencode : process (in_i)
  begin  -- process prencode
    if in_i(0) = '1' then
      out_o <= "00000";
    elsif in_i(1) = '1' then
      out_o <= "00001";
    elsif in_i(2) = '1' then
      out_o <= "00010";
    elsif in_i(3) = '1' then
      out_o <= "00011";
    elsif in_i(4) = '1' then
      out_o <= "00100";
    elsif in_i(5) = '1' then
      out_o <= "00101";
    elsif in_i(6) = '1' then
      out_o <= "00110";
    elsif in_i(7) = '1' then
      out_o <= "00111";
    elsif in_i(8+0) = '1' then
      out_o <= "01000";
    elsif in_i(8+1) = '1' then
      out_o <= "01001";
    elsif in_i(8+2) = '1' then
      out_o <= "01010";
    elsif in_i(8+3) = '1' then
      out_o <= "01011";
    elsif in_i(8+4) = '1' then
      out_o <= "01100";
    elsif in_i(8+5) = '1' then
      out_o <= "01101";
    elsif in_i(8+6) = '1' then
      out_o <= "01110";
    elsif in_i(8+7) = '1' then
      out_o <= "01111";
    elsif in_i(16+0) = '1' then
      out_o <= "10000";
    elsif in_i(16+1) = '1' then
      out_o <= "10001";
    elsif in_i(16+2) = '1' then
      out_o <= "10010";
    elsif in_i(16+3) = '1' then
      out_o <= "10011";
    elsif in_i(16+4) = '1' then
      out_o <= "10100";
    elsif in_i(16+5) = '1' then
      out_o <= "10101";
    elsif in_i(16+6) = '1' then
      out_o <= "10110";
    elsif in_i(16+7) = '1' then
      out_o <= "10111";
    elsif in_i(24+0) = '1' then
      out_o <= "11000";
    elsif in_i(24+1) = '1' then
      out_o <= "11001";
    elsif in_i(24+2) = '1' then
      out_o <= "11010";
    elsif in_i(24+3) = '1' then
      out_o <= "11011";
    elsif in_i(24+4) = '1' then
      out_o <= "11100";
    elsif in_i(24+5) = '1' then
      out_o <= "11101";
    elsif in_i(24+6) = '1' then
      out_o <= "11110";
    elsif in_i(24+7) = '1' then
      out_o <= "11111";
    else
      out_o <= "XXXXX";
    end if;
  end process prencode;

end syn;
