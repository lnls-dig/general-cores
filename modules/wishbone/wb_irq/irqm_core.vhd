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
         g_det_edge     : boolean := true;   -- edge detection. true: trigger on rising edge of irq lines, false: trigger on high level
         g_has_dev_id   : boolean := false;  -- if set, dst adr bits 15..8 hold g_dev_id as device identifier
         g_dev_id       : std_logic_vector(4 downto 0) := (others => '0'); -- device identifier
         g_default_msg  : boolean := true   -- initialises msgs to a default value in order to detect uninitialised irq master
); 
port    (clk_i          : std_logic;   -- clock
         rst_n_i        : std_logic;   -- reset, active LO
         --msi if
         irq_master_o   : out t_wishbone_master_out;  -- Wishbone msi irq interface
         irq_master_i   : in  t_wishbone_master_in;
         --config        
         msi_dst_array  : in t_wishbone_address_array(g_channels-1 downto 0); -- MSI Destination address for each channel
         msi_msg_array  : in t_wishbone_data_array(g_channels-1 downto 0);    -- MSI Message for each channel
         --irq lines         
         mask_i         : std_logic_vector(g_channels-1 downto 0);   -- interrupt mask
         irq_i          : std_logic_vector(g_channels-1 downto 0)    -- interrupt lines
);
end entity;

architecture behavioral of irqm_core is

type   t_state is (st_IDLE, st_SEND);
signal r_state       : t_state;

signal s_msg         : t_wishbone_data_array(g_channels-1 downto 0);    
signal s_dst         : t_wishbone_address_array(g_channels-1 downto 0);

signal s_irq_edge    : std_logic_vector(g_channels-1 downto 0);
signal r_irq         : std_logic_vector(g_channels-1 downto 0);
signal r_pending     : std_logic_vector(g_channels-1 downto 0);

signal s_wb_send     : std_logic;
signal r_wb_sending  : std_logic;
signal idx           : natural range 0 to g_channels-1;

begin

--shorter names
s_msg             <= msi_msg_array;
s_dst             <= msi_dst_array;

-- always full words, always write 
irq_master_o.sel  <= (others => '1');
irq_master_o.we   <= '1';

-------------------------------------------------------------------------
-- registering and counters
-------------------------------------------------------------------------
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if(rst_n_i = '0') then
      else 
         r_irq <= irq_i and mask_i;
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

 G_RR_1 : if(g_round_rb) generate
 
 begin 
     -- round robin
     process(clk_i)
     begin
       if rising_edge(clk_i) then
         if(rst_n_i = '0') then
            idx       <= 0;
         else 

           if((not r_wb_sending and r_pending(idx)) = '0') then 
              if(idx = g_channels-1) then
                  idx <= 0;   
              else
                  idx <= idx +1; 
              end if;         
           end if; 
          
         end if;
       end if;
     end process;
   end generate;
    
   G_RR_2 : if(not g_round_rb) generate
   
   begin    
      -- priority
      with f_hot_to_bin(r_pending) select
      idx          <= 0 when 0,
                      f_hot_to_bin(r_pending)-1 when others; 

   end generate;

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
      variable v_dst          : std_logic_vector(31 downto 0);
  begin
    

   if rising_edge(clk_i) then
		if(rst_n_i = '0') then
			irq_master_o.cyc  <= '0';
			irq_master_o.stb  <= '0';
			r_state           <= st_IDLE;
         v_dst             := (others => '0');
      else
			v_state       := r_state;
			r_wb_sending  <= '0';
         
         case r_state is
			  when st_IDLE    => if(s_wb_send = '1') then
                                 v_state      := st_SEND;
                                                               
                                 v_dst(6 downto 2) := std_logic_vector(to_unsigned(idx, 5));
                                 if(g_has_dev_id) then
                                    v_dst(15 downto 8)   := g_dev_id;
                                    v_dst(31 downto 16)  := s_dst(idx)(31 downto 16);    
                                 else
                                    v_dst(31 downto 7)   := s_dst(idx)(31 downto 7);
                                 end if;
                
                                 irq_master_o.adr <= v_dst; 
                                 irq_master_o.dat <= s_msg(idx);
                                 r_wb_sending     <= '1';
										end if;
			  when st_SEND    => if(irq_master_i.stall = '0') then
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
