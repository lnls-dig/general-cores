library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wishbone_pkg.all;
use work.wb_irq_pkg.all;

entity wb_irq_lm32 is
generic(g_msi_queues    : natural := 3;
        g_profile       : string;
        g_reset_vector  : std_logic_vector(31 downto 0) := x"00000000"
);
port(
   clk_sys_i      : in  std_logic;
   rst_n_i        : in  std_logic;

   dwb_o          : out t_wishbone_master_out;
   dwb_i          : in  t_wishbone_master_in;
   iwb_o          : out t_wishbone_master_out;
   iwb_i          : in  t_wishbone_master_in;

   irq_slave_o    : out t_wishbone_slave_out_array(g_msi_queues-1 downto 0);  -- wb msi interface
   irq_slave_i    : in  t_wishbone_slave_in_array(g_msi_queues-1 downto 0);
            
   ctrl_slave_o   : out t_wishbone_slave_out;                             -- ctrl interface for LM32 irq processing
   ctrl_slave_i   : in  t_wishbone_slave_in
);
end wb_irq_lm32;

architecture rtl of wb_irq_lm32 is 

signal s_irq : std_logic_vector(31 downto 0);

begin

   s_irq(31 downto g_msi_queues) <= (others => '0');

   msi_irq: wb_irq_slave 
   GENERIC MAP(g_queues       => g_msi_queues,
               g_depth        => 8)
   PORT MAP (
      clk_i         => clk_sys_i,
      rst_n_i       => rst_n_i,  
           
      irq_slave_o   => irq_slave_o, 
      irq_slave_i   => irq_slave_i,
      irq_o         => s_irq(g_msi_queues-1 downto 0),
           
      ctrl_slave_o  => ctrl_slave_o,
      ctrl_slave_i  => ctrl_slave_i
   );

   LM32_CORE : xwb_lm32
   generic map(g_profile      => g_profile,
               g_reset_vector => g_reset_vector)
   port map(
      clk_sys_i   => clk_sys_i,
      rst_n_i     => rst_n_i,
      irq_i       => s_irq,

      dwb_o       => dwb_o,
      dwb_i       => dwb_i,
      iwb_o       => iwb_o,
      iwb_i       => iwb_i
   );
      
end rtl;         
