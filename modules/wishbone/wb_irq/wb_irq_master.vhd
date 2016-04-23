------------------------------------------------------------------------------
-- Title      : WB Interrupt master with WB ctrl if
-- Project    : Wishbone
------------------------------------------------------------------------------
-- File       : wb_irq_master.vhd
-- Author     : Mathias Kreider
-- Company    : GSI
-- Created    : 2013-08-10
-- Last update: 2014-06-05
-- Platform   : FPGA-generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: WB MSI interrupt generator with WB configuration/control interface 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 GSI
-------------------------------------------------------------------------------
--
--
--
--    31            16         6     0
--    Dst.............SrcID....ChID...   
--    *************************
--
-- Revisions  :
-- Date        Version  Author          Description
-- 2013-08-10  1.0      mkreider        Created
-- 2014-06-05  1.01     mkreider        fixed some wrong/out of date comments
-- 2014-06-05  1.02     mkreider        removed redundant declaration of f_wb_wr
-------------------------------------------------------------------------------
      

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.genram_pkg.all;
use work.wb_irq_pkg.all;

entity wb_irq_master is
generic( g_channels     : natural := 32;   -- number of interrupt lines
         g_round_rb     : boolean := true; -- scheduler       true: round robin,                         false: prioritised 
         g_det_edge     : boolean := true;  -- edge detection. true: trigger on rising edge of irq lines, false: trigger on high level
         g_has_dev_id   : boolean := false;  -- if set, dst adr bits 11..7 hold g_dev_id as device identifier
         g_dev_id       : std_logic_vector(4 downto 0) := (others => '0'); -- device identifier
         g_has_ch_id    : boolean := false;  -- if set, dst adr bits  6..2 hold g_ch_id  as device identifier         
         g_default_msg  : boolean := true   -- initialises msgs to a default value in order to detect uninitialised irq master
); 
port    (clk_i          : std_logic;   -- clock
         rst_n_i        : std_logic;   -- reset, active LO
         --msi if
         irq_master_o   : out t_wishbone_master_out;  -- Wishbone msi irq interface
         irq_master_i   : in  t_wishbone_master_in;
         -- ctrl interface  
         ctrl_slave_o : out t_wishbone_slave_out;         
         ctrl_slave_i : in  t_wishbone_slave_in;
         --irq lines
         irq_i          : std_logic_vector(g_channels-1 downto 0)  -- irq lines
  );
end entity;

architecture behavioral of wb_irq_master is

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
constant c_MSK_GET         : natural := c_RST            +4;   --0x04, ro, get irq mask. to only use irq mask vector (mask_i), set all bits to HI
constant c_MSK_SET         : natural := c_MSK_GET        +4;   --0x08, wo, set irq mask bits. 
constant c_MSK_CLR         : natural := c_MSK_SET        +4;   --0x0C, wo, clr irq mask bits,         
constant c_SW_IRQ          : natural := c_MSK_CLR        +4;   --0x10, wo, software irq
constant c_CHANNEL_INFO    : natural := c_SW_IRQ         +4;   --0x14  ro  number of channels in this device

constant c_CHANNEL_SEL     : natural :=              16#20#;   --0x20, rw, channel select. !!!CAUTION!!! content of all c_CH_... regs depends on this
constant c_CH_MSG          : natural := c_CHANNEL_SEL    +4;   --0x24, rw, MSI msg to be sent on MSI when deadline is hit
constant c_CH_DST          : natural := c_CH_MSG         +4;   --0x28, rw, MSI adr to send the msg to when deadline is hit

signal r_csl               : t_wishbone_data;                                 -- channel select
signal r_msk, s_msk        : std_logic_vector(g_channels-1 downto 0);         -- mask
signal r_msg               : t_wishbone_data_array(g_channels-1 downto 0);    -- messages  
signal r_dst               : t_wishbone_address_array(g_channels-1 downto 0); -- destinations
signal s_irq, r_swirq      : std_logic_vector(g_channels-1 downto 0);         -- 

--v_dst(6 downto 2) := std_logic_vector(to_unsigned(idx, 5));
--if(g_has_dev_id) then
--   v_dst(12 downto 8)   := g_dev_id;
--   v_dst(31 downto 16)  := s_dst(idx)(31 downto 16);    
--else
--   v_dst(31 downto 7)   := s_dst(idx)(31 downto 7);
--end if;

begin

--combine mask register and mask lines
s_msk <= r_msk;
s_irq <= irq_i or r_swirq; 

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

   process(clk_i)
  variable v_ch_sl : natural range g_channels-1 downto 0; 
  begin
      if rising_edge(clk_i) then
         if(rst_n_i = '0' or r_rst_n = '0') then
            r_c_ack  <= '0';
            r_c_err  <= '0';
            r_rst_n  <= '1';
            r_csl    <= (others => '0'); -- channel select
            r_msk    <= (others => '0'); -- irq mask
            r_swirq  <= (others => '0'); -- software irq

            --init code for messages
            if(g_default_msg) then         
               for i in irq_i'range loop 
                  r_dst(i) <= x"CAFEBABE";
               end loop;
            end if;
         else
            -- Fire and Forget Registers        
         
            r_c_ack  <= '0';
            r_c_err  <= '0';
            r_c_dato <= (others => '0');
  
            if(s_c_en = '1') then
               v_ch_sl := to_integer(unsigned(r_csl));
               r_c_ack  <= '1';
               if(s_c_we = '1') then              
                  case s_c_adr is
                     when c_RST           => r_rst_n           <= '0'; 
                     when c_MSK_SET       => r_msk             <= f_wb_wr(r_msk,             s_c_dati, s_c_sel, "set");  
                     when c_MSK_CLR       => r_msk             <= f_wb_wr(r_msk,             s_c_dati, s_c_sel, "clr");
                     when c_SW_IRQ        => r_swirq           <= f_wb_wr(r_swirq,           s_c_dati, s_c_sel, "owr");
                     when c_CHANNEL_SEL   => if(f_oob(s_c_dati, g_channels)) then  -- owr with limit check
                                                r_c_ack <= '0'; r_c_err <= '1';
                                             else
                                                r_csl          <= f_wb_wr(r_csl,             s_c_dati, s_c_sel, "owr"); 
                                             end if;
                     when c_CH_MSG        => r_msg(v_ch_sl)    <= f_wb_wr(r_msg(v_ch_sl),    s_c_dati, s_c_sel, "owr");  
                     when c_CH_DST        => r_dst(v_ch_sl)    <= f_wb_wr(r_dst(v_ch_sl),    s_c_dati, s_c_sel, "owr");                     
                     when others          => r_c_ack <= '0'; r_c_err <= '1';
                  end case;
               else
                  case s_c_adr is 
                     when c_MSK_GET       => r_c_dato(r_msk'range)               <= r_msk;    
                     when c_CHANNEL_INFO  => r_c_dato                            <= std_logic_vector(to_unsigned(g_channels,32));
                     when c_CHANNEL_SEL   => r_c_dato(r_csl'range)               <= r_csl; 
                     when c_CH_MSG        => r_c_dato(r_msg(v_ch_sl)'range)      <= r_msg(v_ch_sl);    
                     when c_CH_DST        => r_c_dato(r_dst(v_ch_sl)'range)      <= r_dst(v_ch_sl);                      
                     when others          => r_c_ack <= '0'; r_c_err <= '1';
                  end case;
               end if; -- s_c_we
            end if; -- s_c_en
         end if; -- rst     
      end if; -- clk edge
   end process;

   msi :  irqm_core
   generic map(g_channels     => g_channels,
               g_round_rb     => g_round_rb,
               g_det_edge     => g_det_edge
   ) 
   port map(   clk_i          => clk_i,
               rst_n_i        => rst_n_i, 
            --msi if
               irq_master_o   => irq_master_o,
               irq_master_i   => irq_master_i,
            --config        
               msi_dst_array  => r_dst,
               msi_msg_array  => r_msg,  
            --irq lines
               en_i           => '1',               
               mask_i         => s_msk,
               irq_i          => s_irq
   );
          
                 

end architecture;
