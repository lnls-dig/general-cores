------------------------------------------------------------------------------
-- Title      : Raw WB Interrupt master
-- Project    : Wishbone
------------------------------------------------------------------------------
-- File       : wb_irq_timer.vhd
-- Author     : Mathias Kreider
-- Company    : GSI
-- Created    : 2013-08-10
-- Last update: 2014-06-05
-- Platform   : FPGA-generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: WB MSI interrupt generator
-------------------------------------------------------------------------------
-- Copyright (c) 2014 GSI
-------------------------------------------------------------------------------
--
-- Revisions  :
-- Date        Version  Author          Description
-- 2013-08-10  1.0      mkreider        Created
-- 2014-06-05  1.01     mkreider        fixed bug in sending fsm
-- 2014-06-05  1.1      mkreider        bullet proofed irq inputs with sync chains
-------------------------------------------------------------------------------

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
         g_det_edge     : boolean   -- edge detection. true: trigger on rising edge of irq lines, false: trigger on high level
); 
port    (clk_i          : in  std_logic;   -- clock
         rst_n_i        : in  std_logic;   -- reset, active LO
         --msi if
         irq_master_o   : out t_wishbone_master_out;  -- Wishbone msi irq interface
         irq_master_i   : in  t_wishbone_master_in;
         --config 
         -- we assume these as stable, they won't be synced!			
         msi_dst_array  : in  t_wishbone_address_array(g_channels-1 downto 0); -- MSI Destination address for each channel
         msi_msg_array  : in  t_wishbone_data_array(g_channels-1 downto 0);    -- MSI Message for each channel
         --irq lines
			-- all inputs are synced in
         en_i           : in  std_logic;         
         mask_i         : in  std_logic_vector(g_channels-1 downto 0);   -- interrupt mask
         irq_i          : in  std_logic_vector(g_channels-1 downto 0)    -- interrupt lines
);
end entity;

architecture behavioral of irqm_core is

subtype cnt is unsigned(8 downto 0);
type cnt_array is array(natural range <>) of cnt;

signal r_cnt_array : cnt_array(g_channels-1 downto 0);

signal s_msg         : t_wishbone_data_array(g_channels-1 downto 0);    
signal s_dst         : t_wishbone_address_array(g_channels-1 downto 0);

signal s_irq_edge    : std_logic_vector(g_channels-1 downto 0);
signal r_irq0,
       r_irq1, 
       r_irqm0,          
       r_irqm1,
       r_msk0,
		   r_msk1        : std_logic_vector(g_channels-1 downto 0);
signal r_en0,
       r_en1         : std_logic;

signal r_pending, r_wait     : std_logic_vector(g_channels-1 downto 0);

signal s_wb_send     : std_logic;

signal idx           : natural range 0 to g_channels-1;
signal idx_robin     : natural range 0 to g_channels-1;
signal idx_prio      : natural range 0 to g_channels-1;

signal r_cyc0, r_cyc1, s_cyc_f_edge : std_logic;
signal r_stb         : std_logic;

begin

--shorter names
s_msg             <= msi_msg_array; 
s_dst             <= msi_dst_array;

-- always full words, always write 
irq_master_o.cyc  <= r_cyc0;
irq_master_o.stb  <= r_stb;
irq_master_o.sel  <= (others => '1');
irq_master_o.we   <= '1';


   

-------------------------------------------------------------------------
-- registering and counters
-------------------------------------------------------------------------
  registerIn : process(clk_i, rst_n_i)
  variable v_en1 : std_logic_vector(g_channels-1 downto 0);
  begin
  
    if(rst_n_i = '0') then
			r_en0  <= '0';
			r_irq0 <= (others => '0');
			r_msk0 <= (others => '0');
    
    elsif rising_edge(clk_i) then
         r_irq0 <= irq_i;           -- reg all interrupt inputs 
			r_msk0 <= mask_i;          -- reg all mask inputs 
			r_en0  <= en_i;   			-- reg enable input
	 end if;
	 
	 if rising_edge(clk_i) then
			r_en1  <= r_en0;
			r_irq1 <= r_irq0;
			r_msk1 <= r_msk0;
			
			v_en1 := (others => r_en1);
			r_irqm0 <= r_irq1 and r_msk1 and v_en1; -- masked irq vector and reg
			r_irqm1 <= r_irqm0;                       -- reg one more time
	 end if;
  end process; 

  G_Edge_1 : if(g_det_edge) generate
   begin    
      s_irq_edge <= r_irqm0 and not r_irqm1;    
   end generate;
   
   G_Edge_2 : if(not g_det_edge) generate
   begin 
      s_irq_edge <= r_irqm0;
   end generate;
  
   s_cyc_f_edge <= not r_cyc0 and r_cyc1;
   
     -- round robin
     idx_round_robin : process(clk_i)
     begin
       if rising_edge(clk_i) then
         if(rst_n_i = '0') then
            idx_robin       <= 0;
         else 
           if(r_cyc0 = '0') then 
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
 
   
 
   GEN_REG: 
   for i in 0 to g_channels-1 generate
      r_pending(i) <= not r_cnt_array(i)(r_cnt_array(i)'high);

      -- keep track of what needs sending
      queue_mux : process(clk_i)
      variable v_inc, v_dec : unsigned(cnt'range);
      begin
         if rising_edge(clk_i) then
            if((rst_n_i) = '0') then            
               r_cnt_array(i) <= (others => '1');
               r_wait(i) <= '0';
            else
              -- add to each channel count with rising edge
              
               v_inc := (others => '0');
               v_inc(0) := s_irq_edge(i);
               
               -- subtract from sending channel count when cycle is finished
               v_dec := (others => '0');
               -- when my cnt is pending and it's my turn ...
               if(r_pending(i) = '1' and i = idx) then
                  r_wait(i) <= '1';
               end if;
               if( r_wait(i) = '1' and s_cyc_f_edge = '1') then  
                  v_dec := (others => s_cyc_f_edge);
                  r_wait(i) <= '0';
               end if;      
               r_cnt_array(i) <= r_cnt_array(i) + v_inc + v_dec;
                  
             end if;
         end if;
      end process queue_mux; 
   end generate GEN_REG; 

-------------------------------------------------------------------------
-- WB master generating IRQ msgs
-------------------------------------------------------------------------
-- send pending MSI IRQs over WB
  wb_irq_master : process(clk_i)
  begin
   if rising_edge(clk_i) then
      if(rst_n_i = '0') then
         r_cyc0 <= '0';
         r_cyc1 <= '0';
         r_stb <= '0';
      else
         r_cyc1 <= r_cyc0;
         if r_cyc0 = '1' then
           if irq_master_i.stall = '0' then
             r_stb <= '0';
           end if;
           if (irq_master_i.ack or irq_master_i.err) = '1' then
             r_cyc0 <= '0';
           end if;
         else
           r_cyc0 <= s_wb_send;
           r_stb <= s_wb_send;
           irq_master_o.adr <= s_dst(idx); 
           irq_master_o.dat <= s_msg(idx);
         end if;
      end if;
    end if;
  end process;
          
                 

end architecture;
