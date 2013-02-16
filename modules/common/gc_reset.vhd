library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity gc_reset is
  generic(
    g_clocks    : natural := 1;
    g_logdelay  : natural := 10;
    g_syncdepth : natural := 3);
  port(
    free_clk_i : in  std_logic;
    locked_i   : in  std_logic := '1'; -- All the PLL locked signals ANDed together
    clks_i     : in  std_logic_vector(g_clocks-1 downto 0);
    rstn_o     : out std_logic_vector(g_clocks-1 downto 0));
end gc_reset;

architecture rtl of gc_reset is
  subtype t_shifter is std_logic_vector(g_syncdepth-1 downto 0);
  type t_shifters is array(natural range <>) of t_shifter;
  
  signal shifters : t_shifters(g_clocks-1 downto 0) := (others => (others => '0')); -- start reset
  signal locked_count : unsigned(g_logdelay-1 downto 0) := (others => '0');
  signal master_rstn : std_logic;
begin
  lock : process(free_clk_i, locked_i)
    constant locked_done : unsigned(g_logdelay-1 downto 0) := (others => '1');
  begin
    -- Asynchronous reset
    if locked_i = '0' then
      master_rstn <= '0';
      locked_count <= (others => '0');
    else
      if rising_edge(free_clk_i) then
        if locked_count = locked_done then
          master_rstn <= '1';
        else
          master_rstn <= '0';
          locked_count <= locked_count + 1;
        end if;
      end if;
    end if;
  end process;
  
  -- Generate the sync chains for each clock domain
  syncs : for i in g_clocks-1 downto 0 generate
    sync : process(clks_i(i))
    begin
      if rising_edge(clks_i(i)) then
        shifters(i) <= master_rstn & shifters(i)(g_syncdepth-1 downto 1);
      end if;
    end process;
  end generate;

  -- Output the synchronized reset
  rstn : for i in g_clocks-1 downto 0 generate
    rstn_o(i) <= shifters(i)(0);
  end generate;
  
end rtl;
