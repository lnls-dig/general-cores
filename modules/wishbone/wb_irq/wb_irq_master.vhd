library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.genram_pkg.all;
use work.wb_irq_pkg.all;

entity wb_irq_master is
  port    (clk_i          : std_logic;
           rst_n_i        : std_logic; 
           
           master_o       : out t_wishbone_master_out;
           master_i       : in  t_wishbone_master_in;
           
           irq_i          : std_logic;
           adr_i          : t_wishbone_address;
           msg_i          : t_wishbone_data
  );
end entity;

architecture behavioral of wb_irq_master is

signal r_ffs_q    : std_logic;
signal r_ffs_r    : std_logic;
signal s_ffs_s    : std_logic;

type t_state is (s_IDLE, s_LOOKUP, s_SEND, s_DONE);
signal r_state    : t_state;
signal s_master_o   : t_wishbone_master_out;

begin


-------------------------------------------------------------------------
--input rs flipflops
-------------------------------------------------------------------------
process(clk_i)
  begin
    if rising_edge(clk_i) then
      if(rst_n_i = '0') then
         r_ffs_q <= '0';
      else 
        if(s_ffs_s = '0' and r_ffs_r = '1') then
          r_ffs_q  <= '0';
        elsif(s_ffs_s = '1' and r_ffs_r = '0') then
          r_ffs_q  <= '1';
        else
          r_ffs_q  <= r_ffs_q;
        end if;
      end if;
    end if;
  end process;

 

s_ffs_s <= irq_i;
s_master_o.sel <= (others => '1');
s_master_o.we <= '1';

master_o <= s_master_o;
-------------------------------------------------------------------------

-------------------------------------------------------------------------
-- WB master generating IRQ msgs
-------------------------------------------------------------------------
wb_irq_master : process(clk_i, rst_n_i)

      variable v_state        : t_state;
      variable v_irq          : natural;

  begin
    if(rst_n_i = '0') then

      s_master_o.cyc  <= '0';
      s_master_o.stb  <= '0';
      s_master_o.adr  <= (others => '0');
      s_master_o.dat  <= (others => '0');
      r_state         <= s_IDLE;

    elsif rising_edge(clk_i) then

      v_state       := r_state;
      
      case r_state is
        when s_IDLE   =>  if(r_ffs_q = '1') then
                            s_master_o.adr <= adr_i;
                            s_master_o.dat <= msg_i;
                            v_state      := s_SEND;
                          end if;
      
        when s_SEND   =>  if(master_i.stall = '0') then
                            v_state := s_DONE;
                          end if;
                          
        when s_DONE   =>  v_state := s_IDLE;
        when others   =>  v_state := s_IDLE;
      end case;
    
      -- flags on state transition
      if(v_state = s_DONE) then
        r_ffs_r <= '1';
      else
        r_ffs_r <= '0';
      end if;
      
      if(v_state = s_SEND) then
        s_master_o.cyc <= '1';
        s_master_o.stb <= '1';
      else
        s_master_o.cyc <= '0';
        s_master_o.stb <= '0';
      end if;
      
      r_state <= v_state;
    
    end if;
                  
  end process;
          
                 

end architecture;
