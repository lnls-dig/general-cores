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
      w_clk_i  : in  std_logic;
      w_en_i   : in  std_logic;
      w_addr_i : in  std_logic_vector(addr_width-1 downto 0);
      w_data_i : in  std_logic_vector(data_width-1 downto 0);
      -- read port
      r_clk_i  : in  std_logic;
      r_en_i   : in  std_logic;
      r_addr_i : in  std_logic_vector(addr_width-1 downto 0);
      r_data_o : out std_logic_vector(data_width-1 downto 0));
end gc_dual_clock_ram;

architecture rtl of gc_dual_clock_ram is
   type ram_t is array(2**addr_width-1 downto 0) of std_logic_vector(data_width-1 downto 0);
   signal ram : ram_t := (others => (others => '0'));
   
   -- Tell synthesizer we do not care about read during write behaviour
   attribute ramstyle : string;
   attribute ramstyle of ram : signal is "no_rw_check";
begin
   write : process(w_clk_i)
   begin
      if rising_edge(w_clk_i) then
         if w_en_i = '1' then
            ram(to_integer(unsigned(w_addr_i))) <= w_data_i;
         end if;
      end if;
   end process;
   
   read : process(r_clk_i)
   begin
      if rising_edge(r_clk_i) then
         if r_en_i = '1' then
            r_data_o <= ram(to_integer(unsigned(r_addr_i)));
         end if;
      end if;
   end process;
end rtl;
