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

  signal s_push0, s_push1, s_pop  : std_logic := '0';
  signal r_cnt                    : unsigned(1 downto 0) := "11";
  signal s_inc, s_dec             : unsigned(1 downto 0) := "00";
  signal s_full, s_empty          : std_logic := '0';
  signal s_stall                  : std_logic := '0';
  signal r_buff0, r_buff1, s_buff : std_logic_vector(g_adrbits + 32 + 4 + 1 -1 downto 0) := (others => '0');  
   
begin

  s_inc <= "0" & s_push0;
  s_dec <= (others => (s_pop and not s_empty));   

  s_push0 <= push_i;
  s_push1 <= s_push0 and not pop_i;
  s_pop   <= pop_i; 

  s_full <= '1' when r_cnt = "01" 
        else '0';
  s_empty <= '1' when r_cnt = "11"
       else '0';

  mux: with (s_full) select
  s_buff <= r_buff1 when '1',
            r_buff0 when others;

  adr_o <= s_buff(37+g_adrbits-1 downto 37);    
  dat_o <= s_buff(36 downto 5);
  sel_o <= s_buff(4 downto 1);
  we_o  <= s_buff(0);  

  full_o <= s_full;
  empty_o <= s_empty; 

  slave : process(clk_i)
  begin
    if rising_edge(clk_i) then
       if(rst_n_i = '0') then
          r_buff0    <= (others => '0');
          r_buff1    <= (others => '0');
          r_cnt      <= (others => '1');
       else
          
          if (s_push0 = '1') then
            r_buff0 <= adr_i & dat_i & sel_i & we_i;
          end if;

          if (s_push1 = '1') then
            r_buff1  <= r_buff0;
          end if;
          
          r_cnt <= r_cnt + s_inc + s_dec;
                          
       end if; -- rst
    end if; -- clk edge
  end process;

end rtl;
