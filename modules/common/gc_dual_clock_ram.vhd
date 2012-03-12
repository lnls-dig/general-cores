library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Read during write has an undefined result
entity gc_dual_clock_ram is
   generic(
      addr_width : natural := 4;
      data_width : natural := 32);
   port(
      -- write port
      w_clk  : in  std_logic;
      w_en   : in  std_logic;
      w_addr : in  std_logic_vector(addr_width-1 downto 0);
      w_data : in  std_logic_vector(data_width-1 downto 0);
      -- read port
      r_clk  : in  std_logic;
      r_en   : in  std_logic;
      r_addr : in  std_logic_vector(addr_width-1 downto 0);
      r_data : out std_logic_vector(data_width-1 downto 0));
end gc_dual_clock_ram;

architecture rtl of gc_dual_clock_ram is
   type ram_t is array(2**addr_width-1 downto 0) of std_logic_vector(data_width-1 downto 0);
   signal ram : ram_t := (others => (others => '0'));
   
   -- Tell synthesizer we do not care about read during write behaviour
   attribute ramstyle : string;
   attribute ramstyle of ram : signal is "no_rw_check";
begin
   write : process(w_clk)
   begin
      if rising_edge(w_clk) then
         if w_en = '1' then
            ram(to_integer(unsigned(w_addr))) <= w_data;
         end if;
      end if;
   end process;
   
   read : process(r_clk)
   begin
      if rising_edge(r_clk) then
         if r_en = '1' then
            r_data <= ram(to_integer(unsigned(r_addr)));
         end if;
      end if;
   end process;
end rtl;
