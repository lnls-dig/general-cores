library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pcie_32to64 is
  port(
    clk_i            : in  std_logic;
    rstn_i           : in  std_logic;
    -- The 32-bit source
    master32_stb_i   : in  std_logic;
    master32_dat_i   : in  std_logic_vector(31 downto 0);
    master32_stall_o : out std_logic;
    -- The 64-bit sink
    slave64_stb_o    : out std_logic;
    slave64_dat_o    : out std_logic_vector(63 downto 0);
    slave64_stall_i  : in  std_logic);
end pcie_32to64;

architecture rtl of pcie_32to64 is
  signal low     : std_logic_vector(31 downto 0);
  signal full    : std_logic;
  signal stall32 : std_logic;
  signal stb64   : std_logic;
begin
  master32_stall_o <= stall32;
  stall32 <= slave64_stall_i and full;
  
  slave64_stb_o <= stb64;
  slave64_dat_o <= master32_dat_i & low;
  stb64 <= master32_stb_i and full;
  
  main : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rstn_i = '0' then
        full <= '0';
      else
        if (master32_stb_i and not stall32) = '1' then
          low <= master32_dat_i;
          full <= '1';
        end if;
        
        if (stb64 and not slave64_stall_i) = '1' then
          full <= '0';
        end if;
      end if;
    end if;
  end process;
end rtl;
