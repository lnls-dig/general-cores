library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity pow_reset is
	port (
		clk:	in std_logic;		-- 125Mhz
		nreset:	buffer std_logic
		);
end entity;

architecture pow_reset_arch of pow_reset is

signal powerOn:	unsigned(6 downto 0) := "0000000";		-- 7Bit for 1ms nrst

begin

nres: process(Clk)
begin
if Clk'event and Clk = '1' then
	if nreset = '0' then
		powerOn <= powerOn + 1;
	end if;
	nReset <= std_logic(powerOn(powerON'high));
	end if;
end process;

end architecture;