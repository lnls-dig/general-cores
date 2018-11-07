library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity wb_skidpad is
generic(
   g_adrbits   : natural   := 32 --Number of bits in adr
    
);
Port(
   clk_i        : std_logic;      
   rst_n_i      : std_logic;             
  
   push_i       : in  std_logic;  
   pop_i        : in  std_logic;  
   full_o       : out std_logic;  
   empty_o      : out std_logic;  

   adr_i        : in  std_logic_vector(g_adrbits-1 downto 0);
   dat_i        : in  std_logic_vector(32-1 downto 0);
   sel_i        : in  std_logic_vector(4-1 downto 0);  
   we_i         : in  std_logic;

   adr_o        : out std_logic_vector(g_adrbits-1 downto 0);
   dat_o        : out std_logic_vector(32-1 downto 0);
   sel_o        : out std_logic_vector(4-1 downto 0);  
   we_o         : out std_logic
 
   
);
end wb_skidpad;

architecture rtl of wb_skidpad is

  signal s_full,  s_valid : std_logic;
  signal r_full0, r_full1 : std_logic := '0';
  signal r_buff0, r_buff1 : std_logic_vector(g_adrbits + 32 + 4 + 1 -1 downto 0);
  signal s_mux            : std_logic_vector(g_adrbits + 32 + 4 + 1 -1 downto 0);
   
begin

  s_valid <= r_full1 or  r_full0;
  s_full  <= r_full1 and r_full0;

  control : process(clk_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_full0 <= '0';
      r_full1 <= '0';
    elsif rising_edge(clk_i) then
      r_full0 <= push_i or s_full;
      r_full1 <= not pop_i and s_valid;
    end if;
  end process;
  
  bulk : process(clk_i) is
  begin
    if rising_edge(clk_i) then
      if s_full = '0' then
        r_buff0 <= adr_i & dat_i & sel_i & we_i;
      end if;
      if r_full1 = '0' then      
        r_buff1 <= r_buff0;
      end if;
    end if;
  end process;
  
  s_mux <= r_buff1 when r_full1='1' else r_buff0;
  adr_o <= s_mux(37+g_adrbits-1 downto 37);
  dat_o <= s_mux(36 downto 5);
  sel_o <= s_mux(4 downto 1);
  we_o  <= s_mux(0);
  
  full_o  <= s_full;
  empty_o <= not s_valid;
  
end rtl;
