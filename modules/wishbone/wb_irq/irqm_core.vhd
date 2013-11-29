library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.genram_pkg.all;
use work.wb_irq_pkg.all;

entity irqm_core is
generic( g_channels     : natural := 32;     -- number of interrupt lines
         g_round_rb     : boolean := true;   -- scheduler       true: round robin,                         false: prioritised 
         g_det_edge     : boolean := true    -- edge detection. true: trigger on rising edge of irq lines, false: trigger on high level
); 
port    (clk_i          : in  std_logic;   -- clock
         rst_n_i        : in  std_logic;   -- reset, active LO
         --msi if
         irq_master_o   : out t_wishbone_master_out;  -- Wishbone msi irq interface
         irq_master_i   : in  t_wishbone_master_in;
         --config        
         msi_dst_array  : in  t_wishbone_address_array(g_channels-1 downto 0); -- MSI Destination address for each channel
         msi_msg_array  : in  t_wishbone_data_array(g_channels-1 downto 0);    -- MSI Message for each channel
         --irq lines
         en_i           : in  std_logic;         
         mask_i         : in  std_logic_vector(g_channels-1 downto 0);   -- interrupt mask
         irq_i          : in  std_logic_vector(g_channels-1 downto 0)    -- interrupt lines
);
end entity;

architecture behavioral of irqm_core is

signal s_msg         : t_wishbone_data_array(g_channels-1 downto 0);    
signal s_dst         : t_wishbone_address_array(g_channels-1 downto 0);

signal s_irq_edge    : std_logic_vector(g_channels-1 downto 0);
signal r_irq         : std_logic_vector(g_channels-1 downto 0);
signal r_pending     : std_logic_vector(g_channels-1 downto 0);

signal s_wb_send     : std_logic;
signal r_wb_sending  : std_logic;
signal idx           : natural range 0 to g_channels-1;
signal idx_robin     : natural range 0 to g_channels-1;
signal idx_prio      : natural range 0 to g_channels-1;

signal s_en          : std_logic_vector(g_channels-1 downto 0); 
signal r_cyc         : std_logic;
signal r_stb         : std_logic;

begin

--shorter names
s_msg             <= msi_msg_array;
s_dst             <= msi_dst_array;

-- always full words, always write 
irq_master_o.cyc  <= r_cyc;
irq_master_o.stb  <= r_stb;
irq_master_o.sel  <= (others => '1');
irq_master_o.we   <= '1';

s_en <= (others => en_i);

-------------------------------------------------------------------------
-- registering and counters
-------------------------------------------------------------------------
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if(rst_n_i = '0') then
      else 
         r_irq <= irq_i and mask_i and s_en;
      end if;
    end if;
  end process; 


  G_Edge_1 : if(g_det_edge) generate
   begin    
      s_irq_edge <= (irq_i and mask_i) and not r_irq;    
   end generate;
   
   G_Edge_2 : if(not g_det_edge) generate
   begin 
      s_irq_edge <= r_irq;
   end generate;

 
     -- round robin
     idx_round_robin : process(clk_i)
     begin
       if rising_edge(clk_i) then
         if(rst_n_i = '0') then
            idx_robin       <= 0;
         else 

           if((not r_wb_sending and r_pending(idx_robin)) = '0') then 
              if(idx_robin = g_channels-1) then
                  idx_robin <= 0;   
              else
                  idx_robin <= idx_robin +1; 
              end if;         
           end if; 
          
         end if;
       end if;
     end process;
    
      -- priority
      with f_hot_to_bin(r_pending) select
      idx_prio          <= 0 when 0,
                      f_hot_to_bin(r_pending)-1 when others; 

   idx <= idx_robin when g_round_rb else idx_prio;

-------------------------------------------------------------------------

--******************************************************************************************   
-- WB IRQ Interface Arbitration
--------------------------------------------------------------------------------------------
   s_wb_send   <= r_pending(idx);
 
   -- keep track of what needs sending
   queue_mux : process(clk_i)
   variable v_set_pending, v_clr_pending : std_logic_vector(r_pending'length-1 downto 0);
   begin
      if rising_edge(clk_i) then
         if((rst_n_i) = '0') then            
            r_pending <= (others => '0');
         else
            v_clr_pending        := (others => '1');                
            v_clr_pending(idx)   := not r_wb_sending;
            v_set_pending        := s_irq_edge; 
            r_pending            <= (r_pending or v_set_pending) and v_clr_pending;
          end if;
      end if;
   end process queue_mux; 


-------------------------------------------------------------------------
-- WB master generating IRQ msgs
-------------------------------------------------------------------------
-- send pending MSI IRQs over WB
  wb_irq_master : process(clk_i)
  begin
   if rising_edge(clk_i) then
      if(rst_n_i = '0') then
         r_cyc <= '0';
         r_stb <= '0';
         r_wb_sending <= '0';
      else
         r_wb_sending <= '0';
        
         if r_cyc = '1' then
           if irq_master_i.stall = '0' then
             r_stb <= '0';
           end if;
           if (irq_master_i.ack or irq_master_i.err or irq_master_i.rty) = '1' then
             r_cyc <= '0';
           end if;
         else
           r_cyc <= s_wb_send;
           r_stb <= s_wb_send;
           r_wb_sending <= s_wb_send;
           irq_master_o.adr <= s_dst(idx); 
           irq_master_o.dat <= s_msg(idx);
         end if;
      end if;
    end if;
  end process;
          
                 

end architecture;
