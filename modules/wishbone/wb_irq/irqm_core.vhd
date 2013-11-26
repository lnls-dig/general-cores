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

type   t_state is (st_IDLE, st_SEND, st_WAITACK);
signal r_state       : t_state;

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

begin

--shorter names
s_msg             <= msi_msg_array;
s_dst             <= msi_dst_array;

-- always full words, always write 
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
      variable v_state        : t_state;
  begin
   if rising_edge(clk_i) then
      if(rst_n_i = '0') then
         irq_master_o.cyc  <= '0';
         irq_master_o.stb  <= '0';
         r_state           <= st_IDLE;
      else
         v_state       := r_state;
         r_wb_sending  <= '0';
         
         case r_state is
           when st_IDLE    => if(s_wb_send = '1') then
                                 v_state      := st_SEND;
                                                               
                                 irq_master_o.adr <= s_dst(idx); 
                                 irq_master_o.dat <= s_msg(idx);
                                 r_wb_sending     <= '1';
                              end if;
           
           when st_SEND    => if(irq_master_i.stall = '0') then
                               v_state := st_WAITACK;
                              end if;
                              
           when st_WAITACK => if(irq_master_i.ack = '1') then
                               v_state := st_IDLE;
                              end if; 
   
           when others     => v_state := st_IDLE;
         end case;
         
         -- flags on state transition
         if(v_state = st_SEND) then
           irq_master_o.cyc   <= '1';
           irq_master_o.stb   <= '1';
         else
           irq_master_o.cyc   <= '0';
           irq_master_o.stb   <= '0';
         end if;
         r_state <= v_state;
      end if;
    end if;
  end process;
          
                 

end architecture;
