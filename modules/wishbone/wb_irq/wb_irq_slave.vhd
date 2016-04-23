------------------------------------------------------------------------------
-- Title      : WB MSI Core
-- Project    : Wishbone
------------------------------------------------------------------------------
-- File       : wb_irq_slave.vhd
-- Author     : Mathias Kreider
-- Company    : GSI
-- Created    : 2013-08-10
-- Last update: 2013-08-10
-- Platform   : FPGA-generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Provide prioritized Message Signaled Interrupt queues  for an LM32
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


entity wb_irq_slave is
  generic ( g_queues  : natural := 4;  -- number of int lines & queues
            g_depth   : natural := 8;  -- queues depth
            g_datbits : natural := 32; -- data bits from irq wb to store
            g_adrbits : natural := 32; -- addr bits from irq wb to store 
            g_selbits : natural := 4   -- sel  bits from irq wb to store
  );
  port    (clk_i        : std_logic;
           rst_n_i      : std_logic; 
           
           irq_slave_o  : out t_wishbone_slave_out_array(g_queues-1 downto 0);  -- wb msi interface
           irq_slave_i  : in  t_wishbone_slave_in_array(g_queues-1 downto 0);
           irq_o        : out std_logic_vector(g_queues-1 downto 0);            -- pending irq flags of queues 
           
           ctrl_slave_o : out t_wishbone_slave_out;                             -- ctrl interface for LM32 irq processing
           ctrl_slave_i : in  t_wishbone_slave_in
  );
end entity;

architecture behavioral of wb_irq_slave is
-------------------------------------------------------------------------
--memory map for ctrl wb
-------------------------------------------------------------------------
constant c_RST        : natural := 0;             --wo
constant c_STATUS     : natural := c_RST+4;       --ro, 1 bit per queue  
constant c_POP        : natural := c_STATUS+4;    --wo, 1 bit per queue pop
constant c_CLEAR      : natural := c_POP+4;       --wo, 1 bit per queue clear
constant c_ENA_GET    : natural := c_CLEAR+4;     --ro, queue enable status (1 bit per queue) default to enabled
constant c_ENA_SET    : natural := c_ENA_GET+4;   --wo, queue enable set
constant c_ENA_CLR    : natural := c_ENA_SET+4;   --wo, queue enable clear

--pages for queues
--queue I is found at: c_QUEUES + I * c_N_QUEUE
constant c_QUEUES     : natural := 32;
constant c_N_QUEUE    : natural := 16; 
constant c_OFFS_DATA  : natural := 0;             --ro wb data, msi message
constant c_OFFS_ADDR  : natural := c_OFFS_DATA+4; --ro wb addr, msi adr low bits ID caller device
constant c_OFFS_SEL   : natural := c_OFFS_ADDR+4; --ro wb sel,  
-------------------------------------------------------------------------
function f_wb_wr(pval : std_logic_vector; ival : std_logic_vector; sel : std_logic_vector; mode : string := "owr") return std_logic_vector is
   variable n_sel     : std_logic_vector(pval'range);
   variable n_val     : std_logic_vector(pval'range);
   variable result     : std_logic_vector(pval'range);   
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


--ctrl wb signals
signal r_rst_n : std_logic;
signal s_rst_n : std_logic_vector(g_queues-1 downto 0);
signal r_status,
       r_pop,
       r_clr,
       r_ena : std_logic_vector(g_queues-1 downto 0);
signal queue_offs : natural;
signal word_offs  : natural;
signal adr        : unsigned(7 downto 0);

--queue signals
type t_queue_dat is array(natural range <>) of std_logic_vector(g_datbits+g_adrbits+g_selbits-1 downto 0);
signal irq_push, irq_pop, irq_full, irq_empty : std_logic_vector(g_queues-1 downto 0);
signal irq_d, irq_q : t_queue_dat(g_queues-1 downto 0);
signal ctrl_en : std_logic;

begin  


  -------------------------------------------------------------------------
  --irq wb and queues
  -------------------------------------------------------------------------
  irq_o <= r_status(g_queues-1 downto 0); -- LM32 IRQs are active low!
  s_rst_n <= (s_rst_n'range => rst_n_i) and (s_rst_n'range => r_rst_n) and not r_clr;
  
  G1: for I in 0 to g_queues-1 generate
    
    irq_d(I)              <= irq_slave_i(I).sel & irq_slave_i(I).adr & irq_slave_i(I).dat;
    irq_push(I)           <= irq_slave_i(I).cyc and irq_slave_i(I).stb and irq_slave_i(I).we and not irq_full(I) and r_ena(I); 
    irq_slave_o(I).stall  <= irq_full(I);
    irq_pop(I)            <= r_pop(I) and r_status(I);
    r_status(I)           <= not irq_empty(I);
    
    irq_slave_o(I).int    <= '0'; --will be obsolete soon
    irq_slave_o(I).rty    <= '0';
    irq_slave_o(I).err    <= '0';  
    irq_slave_o(I).dat    <= (others => '0');

    p_ack : process(clk_i) -- ack all 
    begin
      if rising_edge(clk_i) then
        irq_slave_o(I).ack <= irq_push(I);
      end if;
    end process;

   irqfifo : generic_sync_fifo
      generic map (
        g_data_width    => g_datbits + g_adrbits + g_selbits, 
        g_size          => g_depth,
        g_show_ahead    => true,
         g_with_empty   => true,
        g_with_full     => true)
      port map (
         rst_n_i        => s_rst_n(I),         
         clk_i          => clk_i,
         d_i            => irq_d(I),
         we_i           => irq_push(I),
         q_o            => irq_q(I),
         rd_i           => irq_pop(I),
         empty_o        => irq_empty(I),
         full_o         => irq_full(I),
         almost_empty_o => open,
         almost_full_o  => open,
         count_o        => open);

  end generate;
  -------------------------------------------------------------------------


  -------------------------------------------------------------------------
  -- ctrl wb and output
  -------------------------------------------------------------------------
  ctrl_en     <= ctrL_slave_i.cyc and ctrl_slave_i.stb;
  adr         <= unsigned(ctrl_slave_i.adr(7 downto 2)) & "00";
  queue_offs  <= to_integer(adr(adr'left downto 4)-1);
  word_offs   <= to_integer(adr(3 downto 0));

  ctrl_slave_o.int    <= '0';
  ctrl_slave_o.rty    <= '0';
  ctrl_slave_o.stall  <= '0';    

  process(clk_i)
  
    variable v_dat  : std_logic_vector(g_datbits-1 downto 0);
    variable v_adr  : std_logic_vector(g_adrbits-1 downto 0);  
    variable v_sel  : std_logic_vector(g_selbits-1 downto 0); 
  
  begin
      if rising_edge(clk_i) then
        if(rst_n_i = '0' or r_rst_n = '0') then
          r_rst_n <= '1';
          r_clr <= (others => '0');
          r_pop <= (others => '0');
          r_ena <= (others => '1');
        else
         
          ctrl_slave_o.ack <= '0';
          ctrl_slave_o.err <= '0';
          r_pop <= (others => '0');
          r_clr <= (others => '0'); 
          ctrl_slave_o.dat <= (others => '0');
            
          if(ctrl_en = '1') then
            ctrl_slave_o.ack <= '1'; -- ack is default, we'll change it if an error occurs
            if(to_integer(adr) < c_QUEUES) then
               -- control registers
               if(ctrl_slave_i.we = '1') then              
                  case to_integer(adr) is
                     when c_RST     => r_rst_n           <= '0'; 
                     when c_POP     => r_pop             <= f_wb_wr(r_pop, ctrl_slave_i.dat, ctrl_slave_i.sel, "set");  
                     when c_CLEAR   => r_clr             <= f_wb_wr(r_clr, ctrl_slave_i.dat, ctrl_slave_i.sel, "set");                    
                     when c_ENA_SET => r_ena             <= f_wb_wr(r_ena, ctrl_slave_i.dat, ctrl_slave_i.sel, "set");
                     when c_ENA_CLR => r_ena             <= f_wb_wr(r_ena, ctrl_slave_i.dat, ctrl_slave_i.sel, "clr");
                     when others => ctrl_slave_o.ack  <= '0'; ctrl_slave_o.err <= '1';
                  end case;
               else
                  case to_integer(adr) is
                     when c_STATUS   => ctrl_slave_o.dat(r_status'range)   <= r_status;
                     when c_ENA_GET  => ctrl_slave_o.dat(r_ena'range)      <= r_ena;
                     when others     => ctrl_slave_o.ack <= '0'; ctrl_slave_o.err <= '1';
                  end case;
               end if;       
            else -- queues, one mem page per queue
              if(adr < c_QUEUES + c_N_QUEUE * g_queues and ctrl_slave_i.we = '0') then
                v_dat := irq_q(queue_offs)(g_datbits-1 downto 0); 
                v_adr := irq_q(queue_offs)(g_adrbits+g_datbits-1 downto g_datbits);
                v_sel := irq_q(queue_offs)(g_selbits + g_adrbits + g_datbits-1 downto g_adrbits+g_datbits);
                
                case word_offs is
                  when c_OFFS_DATA =>  ctrl_slave_o.dat <= std_logic_vector(to_unsigned(0, 32-g_datbits)) & v_dat; 
                  when c_OFFS_ADDR =>  ctrl_slave_o.dat <= std_logic_vector(to_unsigned(0, 32-g_adrbits)) & v_adr;
                  when c_OFFS_SEL  =>  ctrl_slave_o.dat <= std_logic_vector(to_unsigned(0, 32-g_selbits)) & v_sel;
                  when others =>  ctrl_slave_o.ack <= '0'; ctrl_slave_o.err <= '1';
                end case;
              else
                ctrl_slave_o.ack <= '0'; ctrl_slave_o.err <= '1';            
              end if;
            end if;
          
          end if;
        end if; -- rst       
      end if; -- clk edge
  end process;
  -------------------------------------------------------------------------
end architecture;
