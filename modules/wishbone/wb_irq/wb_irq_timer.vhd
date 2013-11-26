------------------------------------------------------------------------------
-- Title      : WB Timer Interrupt
-- Project    : Wishbone
------------------------------------------------------------------------------
-- File       : wb_irq_timer.vhd
-- Author     : Mathias Kreider
-- Company    : GSI
-- Created    : 2013-08-10
-- Last update: 2013-08-10
-- Platform   : FPGA-generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Programmable Timer interrupt module (MSI) 
-------------------------------------------------------------------------------
-- Copyright (c) 2013 GSI
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2013-08-10  1.0      mkreider        Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.genram_pkg.all;
use work.wb_irq_pkg.all;
use work.gencores_pkg.all;


entity wb_irq_timer is
  generic ( g_timers  : natural := 4);    -- number of instantiated timers
  
  port    (clk_sys_i    : in std_logic;                     -- system clock         
           rst_sys_n_i  : in std_logic;                     -- system reset (act LO)           
         
           tm_tai8ns_i  : in std_logic_vector(63 downto 0); -- system time         

           ctrl_slave_o : out t_wishbone_slave_out;         -- timer ctrl interface
           ctrl_slave_i : in  t_wishbone_slave_in;
           
           irq_master_o : out t_wishbone_master_out;        -- msi irq src 
           irq_master_i : in  t_wishbone_master_in
  );
end entity;


architecture behavioral of wb_irq_timer is


function f_wb_wr(pval : std_logic_vector; ival : std_logic_vector; sel : std_logic_vector; mode : string := "owr") return std_logic_vector is
   variable n_sel     : std_logic_vector(pval'range);
	variable n_val     : std_logic_vector(pval'range);
   variable result 	 : std_logic_vector(pval'range);   
begin
  for i in pval'range loop 
   n_sel(i) := sel(i / 8);
	n_val(i) := ival(i);
  end loop;

  if(mode = "set") then  
   result := pval or (n_val and n_sel);
  elsif (mode = "clr") then
   result := pval and not (n_val and n_sel); 
  else
   result := (pval and not n_sel) or (n_val and n_sel);    
  end if;  
  
  return result;
end f_wb_wr;

function f_or_vec(a : std_logic_vector) return std_logic is
    variable result : std_logic := '0';
  begin
    for i in 0 to a'left loop 
     result := result or a(i); 
    end loop;
    return result;
  end f_or_vec;

function f_oob(a : std_logic_vector; limit : natural) return boolean is
begin
   if(to_integer(unsigned(a)) > limit-1) then
      return true;    
   else
      return false;   
    end if;

end f_oob;

--******************************************************************************************   
-- WB ctrl interface definitions and constants
--------------------------------------------------------------------------------------------
signal s_c_en, s_c_we, r_c_ack, r_c_err   : std_logic;
signal s_c_adr                            : natural range 255 downto 0;
signal s_c_dati, r_c_dato                 : t_wishbone_data;
signal s_c_sel                            : t_wishbone_byte_select;
signal r_rst_n                            : std_logic;

constant c_RST             : natural := 0;                     --0x00, wo, Reset Active Low
constant c_ARM_STAT        : natural := c_RST            +4;   --0x04, ro, Shows armed timers,  (1 armed, 0 disarmed), 1 bit per timer
constant c_ARM_SET         : natural := c_ARM_STAT       +4;   --0x08, wo, arm timers,          
constant c_ARM_CLR         : natural := c_ARM_SET        +4;   --0x0C, wo, disarm timers,         
constant c_SRC_STAT        : natural := c_ARM_CLR        +4;   --0x10, ro, shows timer sources, (1 diff time, 0 abs time), 1 bit per timer 
constant c_SRC_SET         : natural := c_SRC_STAT       +4;   --0x14, wo, select diff time as source
constant c_SRC_CLR         : natural := c_SRC_SET        +4;   --0x18, wo, select abs time as source    
constant c_D_MODE_STAT     : natural := c_SRC_CLR        +4;   --0x1C, ro, shows diff time modes, (1 periodic, 0 1time), 1 bit per timer 
constant c_D_MODE_SET      : natural := c_D_MODE_STAT    +4;   --0x20, wo, select periodic mode
constant c_D_MODE_CLR      : natural := c_D_MODE_SET     +4;   --0x24, wo, select 1time mode
constant c_CSC_STAT        : natural := c_D_MODE_CLR     +4;   --0x28, ro, shows cascaded start, (1 cascaded, 0 normal), 1 bit per timer 
constant c_CSC_SET         : natural := c_CSC_STAT       +4;   --0x2C, wo, set cascaded start
constant c_CSC_CLR         : natural := c_CSC_SET        +4;   --0x30, wo, select normal start    
constant c_DBG             : natural := c_CSC_CLR        +4;   --0x34, wo, reset counters, 1 bit per timer

constant c_BASE_TIMERS     : natural := 64;                    --0x40
constant c_TIMER_SEL       : natural := c_BASE_TIMERS    +0;   --0x40, rw, timer select. !!!CAUTION!!! content of all c_TM_... regs depends on this
constant c_TM_TIME_HI      : natural := c_TIMER_SEL      +4;   --0x44, rw, deadline HI word
constant c_TM_TIME_LO      : natural := c_TM_TIME_HI     +4;   --0x48, rw, deadline LO word
constant c_TM_MSG          : natural := c_TM_TIME_LO     +4;   --0x4C, rw, MSI msg to be sent on MSI when deadline7D5D7F53 is hit
constant c_TM_DST_ADR      : natural := c_TM_MSG         +4;   --0x50, rw, MSI adr to send the msg to when deadline is hit
constant c_CSC_SEL         : natural := c_TM_DST_ADR     +4;   --0x54, rw, select comparator output for cascaded start


subtype t_msk_cnt is unsigned(3 downto 0);
subtype t_time is std_logic_vector(63 downto 0);
type t_msk_cnt_array is array(natural range <>) of t_msk_cnt;
type t_time_array is array(natural range <>) of t_time;
type t_state is (st_IDLE, st_SEND);

signal r_tsl      : std_logic_vector(g_timers-1 downto 0);  --timer select
signal r_arm, r_arm_1, s_arm_edge : std_logic_vector(g_timers-1 downto 0);  --comps armed
signal r_src      : std_logic_vector(g_timers-1 downto 0);  --comps sources
signal r_mod      : std_logic_vector(g_timers-1 downto 0);  --counters mode
signal r_csc      : std_logic_vector(g_timers-1 downto 0);  --cascade starts
signal r_msg      : t_wishbone_data_array(g_timers-1 downto 0);   
signal r_dst      : t_wishbone_address_array(g_timers-1 downto 0);
signal r_csl      : t_wishbone_data_array(g_timers-1 downto 0);  --cascade selects
signal r_ddl_hi   : t_wishbone_data_array(g_timers-1 downto 0);   
signal r_ddl_lo   : t_wishbone_data_array(g_timers-1 downto 0);

signal s_comp_mask      : std_logic_vector(g_timers-1 downto 0);
signal r_msk_cnt        : t_msk_cnt_array(g_timers-1 downto 0);
signal r_time           : t_time;
signal s_deadline       : t_time_array(g_timers-1 downto 0);
signal s_deadline_abs   : t_time_array(g_timers-1 downto 0);
signal r_deadline_offs  : t_time_array(g_timers-1 downto 0);
signal s_x, s_y, s_sy   : t_time_array(g_timers-1 downto 0);
signal s_ovf1, s_ovf2   : std_logic_vector(g_timers-1 downto 0);

signal s_csc_arm, s_csc_arm_edge : std_logic_vector(g_timers-1 downto 0);  --cascade starts
--------------------------------------------------------------------------------------------

signal r_comp_1st, comp, s_comp_edge, r_comp : std_logic_vector(g_timers-1 downto 0);

      
begin

--******************************************************************************************   
-- WB ctrl interface implementation
--------------------------------------------------------------------------------------------
 
  s_c_en    <= ctrL_slave_i.cyc and ctrl_slave_i.stb;
  s_c_adr   <= to_integer(unsigned(ctrl_slave_i.adr(7 downto 2)) & "00");
  s_c_we    <= ctrl_slave_i.we; 
  s_c_dati  <= ctrl_slave_i.dat;
  s_c_sel   <= ctrl_slave_i.sel; 

  ctrl_slave_o.int    <= '0';
  ctrl_slave_o.rty    <= '0';
  ctrl_slave_o.stall  <= '0';    
  ctrl_slave_o.ack <= r_c_ack;
  ctrl_slave_o.err <= r_c_err;
  ctrl_slave_o.dat <= r_c_dato;

process(clk_sys_i)
  variable v_tm_sl : natural range g_timers-1 downto 0; 
  begin
      if rising_edge(clk_sys_i) then
         if(rst_sys_n_i = '0' or r_rst_n <= '0') then
            r_c_ack  <= '0';
            r_c_err  <= '0';
            r_rst_n  <= '1';
            r_tsl    <= (others => '0'); -- timer select
            r_arm    <= (others => '0'); -- armed timers
            r_src    <= (others => '0'); -- src selects
            r_mod    <= (others => '0'); -- counter modes
            r_csc    <= (others => '0'); -- counter cascade start  
         else
            -- Fire and Forget Registers        
         
            r_c_ack  <= '0';
            r_c_err  <= '0';
            r_c_dato <= (others => '0');
  
            if(s_c_en = '1') then
               v_tm_sl := to_integer(unsigned(r_tsl));
               r_c_ack  <= '1';
               if(s_c_we = '1') then              
                  case s_c_adr is
                     when c_RST           => r_rst_n           <= '0'; 
                     when c_ARM_SET       => r_arm             <= f_wb_wr(r_arm,             s_c_dati, s_c_sel, "set");  
                     when c_ARM_CLR       => r_arm             <= f_wb_wr(r_arm,             s_c_dati, s_c_sel, "clr");
                     when c_SRC_SET       => r_src             <= f_wb_wr(r_src,             s_c_dati, s_c_sel, "set");
                     when c_SRC_CLR       => r_src             <= f_wb_wr(r_src,             s_c_dati, s_c_sel, "clr"); 
                     when c_D_MODE_SET    => r_mod             <= f_wb_wr(r_mod,             s_c_dati, s_c_sel, "set"); 
                     when c_D_MODE_CLR    => r_mod             <= f_wb_wr(r_mod,             s_c_dati, s_c_sel, "clr");
                     when c_CSC_SET       => r_csc             <= f_wb_wr(r_csc,             s_c_dati, s_c_sel, "set");
                     when c_CSC_CLR       => r_csc             <= f_wb_wr(r_csc,             s_c_dati, s_c_sel, "clr"); 
                     when c_TIMER_SEL     => if(f_oob(s_c_dati, g_timers)) then  -- owr with limit check
                                                r_c_ack <= '0'; r_c_err <= '1';
                                             else
                                                r_tsl          <= f_wb_wr(r_tsl,             s_c_dati, s_c_sel, "owr"); 
                                             end if;
                     when c_TM_TIME_HI    => r_ddl_hi(v_tm_sl) <= f_wb_wr(r_ddl_hi(v_tm_sl), s_c_dati, s_c_sel, "owr");
                     when c_TM_TIME_LO    => r_ddl_lo(v_tm_sl) <= f_wb_wr(r_ddl_lo(v_tm_sl), s_c_dati, s_c_sel, "owr");   
                     when c_TM_MSG        => r_msg(v_tm_sl)    <= f_wb_wr(r_msg(v_tm_sl),    s_c_dati, s_c_sel, "owr");  
                     when c_TM_DST_ADR    => r_dst(v_tm_sl)    <= f_wb_wr(r_dst(v_tm_sl),    s_c_dati, s_c_sel, "owr");                     
                     when c_CSC_SEL       => if(f_oob(s_c_dati, g_timers)) then  -- owr with limit check
                                                r_c_ack <= '0'; r_c_err <= '1';
                                             else
                                                r_csl(v_tm_sl)          <= f_wb_wr(r_csl(v_tm_sl),             s_c_dati, s_c_sel, "owr"); 
                                             end if;
                     when others          => r_c_ack <= '0'; r_c_err <= '1';
                  end case;
               else
                  case s_c_adr is 
                     when c_ARM_STAT      => r_c_dato(r_arm'range)               <= r_arm;    
                     when c_SRC_STAT      => r_c_dato(r_src'range)               <= r_src;
                     when c_D_MODE_STAT   => r_c_dato(r_mod'range)               <= r_mod;
                     when c_CSC_STAT      => r_c_dato(r_csc'range)               <= r_csc;  
                     when c_TIMER_SEL     => r_c_dato(r_tsl'range)               <= r_tsl; 
                     when c_TM_TIME_HI    => r_c_dato(r_ddl_hi(v_tm_sl)'range)   <= r_ddl_hi(v_tm_sl); 
                     when c_TM_TIME_LO    => r_c_dato(r_ddl_lo(v_tm_sl)'range)   <= r_ddl_lo(v_tm_sl);    
                     when c_TM_MSG        => r_c_dato(r_msg(v_tm_sl)'range)      <= r_msg(v_tm_sl);    
                     when c_TM_DST_ADR    => r_c_dato(r_dst(v_tm_sl)'range)      <= r_dst(v_tm_sl);                      
                     when c_CSC_SEL       => r_c_dato(r_csl(v_tm_sl)'range)      <= r_csl(v_tm_sl);
							
                     when others          => r_c_ack <= '0'; r_c_err <= '1';
                  end case;
               end if; -- s_c_we
            end if; -- s_c_en
         end if; -- rst     
      end if; -- clk edge
   end process;

-- register system time to reduce fan out (1 cycle, must be taken into account for delay compensation in time clock crossing core!)
-- register comparator output
-- register start (arm)
   reggies : process(clk_sys_i)
   begin
      if rising_edge(clk_sys_i) then
         r_time <= tm_tai8ns_i;
         r_comp <= comp;
         r_arm_1 <= r_arm; 
      end if;
   end process reggies;

 -- rising edge detectors for comparators and arm regs
 s_comp_edge    <= (not r_comp and comp);
 s_arm_edge     <= (not r_arm_1 and r_arm); 

--******************************************************************************************   
-- counters, src muxes and comparators
--------------------------------------------------------------------------------------------
 
G1: for I in 0 to g_timers-1 generate
      
      
      s_csc_arm_edge(I) <= r_arm(I) and r_csc(I) and s_comp_edge(to_integer(unsigned(r_csl(I))));
      s_csc_arm(I) <= r_csc(I) and r_comp_1st(to_integer(unsigned(r_csl(I))));
      
      s_deadline_abs(I) <= (r_ddl_hi(I) & r_ddl_lo(I));
      
      
      s_comp_mask(I) <=  std_logic(r_msk_cnt(I)(r_msk_cnt(I)'left)) and r_arm(I) and (not r_csc(I) or s_csc_arm(I) or s_csc_arm_edge(I));  
      
      -- offset for deadline. set to current time if ...
      deadline_offs : process(clk_sys_i)     
      begin
         if rising_edge(clk_sys_i) then
                       
            if(rst_sys_n_i = '0') then
               r_msk_cnt(I) <= to_unsigned(5, r_msk_cnt(I)'length); 
               r_deadline_offs(I)  <=  (others => '0');
            else
               
              -- its in diff mode and ...
              -- start or periodic overflow or cascaded start occured
              if( (s_arm_edge(I) or (r_mod(I) and s_comp_edge(I) and std_logic(r_msk_cnt(I)(r_msk_cnt(I)'left))) or s_csc_arm_edge(I)) = '1' ) then 
                -- start countdown for comp mask
                r_msk_cnt(I) <= to_unsigned(5, r_msk_cnt(I)'length); 
                if( r_src(I) = '1') then
                  r_deadline_offs(I)  <=  r_time;
					      else
					        r_deadline_offs(I)  <=  (others => '0'); 
					      end if;
					   else
					   -- countdown until comp output mask is 1
					   r_msk_cnt(I) <= r_msk_cnt(I) - (to_unsigned(0, r_msk_cnt(I)'length-1) & not r_msk_cnt(I)(r_msk_cnt(I)'left)); 
					   end if;
           end if; 
         end if;
      end process deadline_offs;
  
 
   --create comparators
 
  -- carry-save
  s_x(I)   <= s_deadline_abs(I) xor r_deadline_offs(I) xor not r_time;
  s_y(I)   <= ((s_deadline_abs(I)   and r_deadline_offs(I))
            or (r_deadline_offs(I)  and not r_time)
            or (s_deadline_abs(I)   and not r_time));
  s_ovf1(I) <= s_y(I)(63);

  s_sy(I)(63 downto 1) <= s_y(I)(62 downto 0);
  s_sy(I)(0) <= '0';

  ea : gc_big_adder
  port map(
      clk_i   => clk_sys_i,
      stall_i => '0',
      a_i     => s_x(I),
      b_i     => s_sy(I),
      c_i     => '0',
      c1_o    => s_ovf2(I),
      x2_o    => open,
      c2_o    => open);
  
   end generate;
   
      comps : process(clk_sys_i)    
      begin
         if rising_edge(clk_sys_i) then
           if(rst_sys_n_i = '0') then
               r_comp_1st <=  (others => '0');
               comp <= (others => '0');
            else
              r_comp_1st <= (r_comp_1st or s_comp_edge) and not s_arm_edge;  
              comp       <= not (s_ovf1 or s_ovf2);
            end if;  
         end if;
      end process comps;
      
   irq :  irqm_core
   generic map(g_channels     => g_timers,
               g_round_rb     => true,
               g_det_edge     => false
   ) 
   port map(   clk_i          => clk_sys_i,
               rst_n_i        => rst_sys_n_i, 
            --msi if
               irq_master_o   => irq_master_o,
               irq_master_i   => irq_master_i,
            --config        
               msi_dst_array  => r_dst,
               msi_msg_array  => r_msg,
               en_i           => '1',  
               mask_i         => s_comp_mask,
            --irq lines
               irq_i          => s_comp_edge
   );


end architecture behavioral;

