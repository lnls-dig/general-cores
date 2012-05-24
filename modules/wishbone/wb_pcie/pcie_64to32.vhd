library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pcie_64to32 is
  port(
    clk_i            : in  std_logic;
    rstn_i           : in  std_logic;
    -- The 64-bit source
    master64_stb_i   : in  std_logic;
    master64_dat_i   : in  std_logic_vector(63 downto 0);
    master64_stall_o : out std_logic;
    -- The 32-bit sink
    slave32_stb_o    : out std_logic;
    slave32_dat_o    : out std_logic_vector(31 downto 0);
    slave32_stall_i  : in  std_logic);
end pcie_64to32;

architecture rtl of pcie_64to32 is
  signal high    : std_logic_vector(31 downto 0);
  signal full    : std_logic;
  signal stall64 : std_logic;
  signal stb32   : std_logic;
begin
  master64_stall_o <= stall64;
  stall64 <= full or slave32_stall_i;
  
  slave32_stb_o <= stb32;
  slave32_dat_o <= high when full = '1' else master64_dat_i(31 downto 0);
  stb32 <= master64_stb_i or full;
  
  main : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rstn_i = '0' then
        full <= '0';
      else
        if (stb32 and not slave32_stall_i) = '1' then
          full <= '0';
        end if;
        
        if (master64_stb_i and not stall64) = '1' then
          high <= master64_dat_i(63 downto 32);
          full <= '1';
        end if;
      end if;
    end if;
  end process;
end rtl;
