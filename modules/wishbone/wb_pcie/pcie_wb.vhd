library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pcie_wb_pkg.all;
use work.wishbone_pkg.all;

entity pcie_wb is
  generic(
    sdb_addr : t_wishbone_address);
  port(
    clk125_i      : in  std_logic; -- 125 MHz, free running
    cal_clk50_i   : in  std_logic; --  50 MHz, shared between all PHYs
    rstn_i        : in  std_logic;
    
    pcie_refclk_i : in  std_logic; -- 100 MHz, must not derive clk125_i or cal_clk50_i
    pcie_rstn_i   : in  std_logic;
    pcie_rx_i     : in  std_logic_vector(3 downto 0);
    pcie_tx_o     : out std_logic_vector(3 downto 0);
    
    wb_clk        : in  std_logic; -- Whatever clock you want these signals on:
    master_o      : out t_wishbone_master_out;
    master_i      : in  t_wishbone_master_in);
end pcie_wb;

architecture rtl of pcie_wb is
  signal internal_wb_clk : std_logic; -- Should be input in final version
  
  signal rstn, stall : std_logic;
  
  signal rx_wb_stb, rx_wb_stall : std_logic;
  signal rx_wb_dat : std_logic_vector(31 downto 0);
  signal rx_wb_bar : std_logic_vector(2 downto 0);
  
  signal tx_rdy, tx_alloc, tx_en, tx_eop, tx_pad : std_logic;
  signal tx_dat : std_logic_vector(31 downto 0);
  
  signal wb_stb, wb_ack, wb_stall : std_logic;
  signal wb_adr : std_logic_vector(63 downto 0);
  signal wb_bar : std_logic_vector(2 downto 0);
  signal wb_dat : std_logic_vector(31 downto 0);
  
  signal cfg_busdev : std_logic_vector(12 downto 0);
  
  signal slave_i : t_wishbone_slave_in;
  signal slave_o : t_wishbone_slave_out;
  
  -- timing registers
  signal r_sdb, r_high, r_ack : std_logic;
  
  -- control registers
  signal r_cyc   : std_logic;
  signal r_addr  : std_logic_vector(31 downto 16);
  signal r_error : std_logic_vector(63 downto  0);
begin

  pcie_phy : pcie_altera port map(
    clk125_i      => clk125_i,
    cal_clk50_i   => cal_clk50_i,
    rstn_i        => rstn_i,
    rstn_o        => rstn,
    pcie_refclk_i => pcie_refclk_i,
    pcie_rstn_i   => pcie_rstn_i,
    pcie_rx_i     => pcie_rx_i,
    pcie_tx_o     => pcie_tx_o,

    cfg_busdev_o  => cfg_busdev,

    wb_clk_o      => internal_wb_clk,
    
    rx_wb_stb_o   => rx_wb_stb,
    rx_wb_dat_o   => rx_wb_dat,
    rx_wb_bar_o   => rx_wb_bar,
    rx_wb_stall_i => rx_wb_stall,
    
    tx_rdy_o      => tx_rdy,
    tx_alloc_i    => tx_alloc,
    tx_en_i       => tx_en,
    tx_dat_i      => tx_dat,
    tx_eop_i      => tx_eop,
    tx_pad_i      => tx_pad);
  
  pcie_logic : pcie_tlp port map(
    clk_i         => internal_wb_clk,
    rstn_i        => rstn,
    
    rx_wb_stb_i   => rx_wb_stb,
    rx_wb_dat_i   => rx_wb_dat,
    rx_wb_bar_i   => rx_wb_bar,
    rx_wb_stall_o => rx_wb_stall,
    
    tx_rdy_i      => tx_rdy,
    tx_alloc_o    => tx_alloc,
    tx_en_o       => tx_en,
    tx_dat_o      => tx_dat,
    tx_eop_o      => tx_eop,
    tx_pad_o      => tx_pad,
    
    cfg_busdev_i  => cfg_busdev,
      
    wb_stb_o      => wb_stb,
    wb_adr_o      => wb_adr,
    wb_bar_o      => wb_bar,
    wb_we_o       => slave_i.we,
    wb_dat_o      => slave_i.dat,
    wb_sel_o      => slave_i.sel,
    wb_stall_i    => wb_stall,
    wb_ack_i      => wb_ack,
    wb_err_i      => slave_o.err,
    wb_rty_i      => slave_o.rty,
    wb_dat_i      => wb_dat);
  
  clock_crossing : xwb_clock_crossing port map(
    rst_n_i       => rstn,
    slave_clk_i   => internal_wb_clk,
    slave_i       => slave_i,
    slave_o       => slave_o,
    master_clk_i  => wb_clk, 
    master_i      => master_i,
    master_o      => master_o);
  
  slave_i.stb <= wb_stb        when wb_bar = "001" else '0';
  wb_stall    <= slave_o.stall when wb_bar = "001" else '0';
  wb_ack      <= slave_o.ack   when wb_bar = "001" else r_ack;
  wb_dat      <= slave_o.dat   when wb_bar = "001" else
                 r_error(63 downto 32) when r_sdb = '0' and r_high = '1' else
                 r_error(31 downto  0) when r_sdb = '0' and r_high = '0' else
                 sdb_addr              when r_sdb = '1' and r_high = '0' else
                 x"00000000";
  
  slave_i.cyc <= r_cyc;
  slave_i.adr(r_addr'range) <= r_addr;
  slave_i.adr(r_addr'right-1 downto 0)  <= wb_adr(r_addr'right-1 downto 0);
  
  control : process(internal_wb_clk)
  begin
    if rising_edge(internal_wb_clk) then
      -- Shift in the error register
      if slave_o.ack = '1' or slave_o.err = '1' or slave_o.rty = '1' then
        r_error <= r_error(r_error'length-2 downto 0) & (slave_o.err or slave_o.rty);
      end if;
      
      -- Is the control BAR targetted?
      if wb_bar = "000" then
        -- Feedback acks one cycle after strobe
        r_ack <= wb_stb;
        r_high <= not wb_adr(2);
        r_sdb <= wb_adr(4);
        
        -- Is this a write to the register space?
        if wb_stb = '1' and slave_i.we = '1' then
          -- Cycle line is high bit of register 0
          if wb_adr(6 downto 2) = "00000" and slave_i.sel(3) = '1' then
            r_cyc <= slave_i.dat(31);
          end if;
          -- Address 20 is low word of address window (register 2)
          if wb_adr(6 downto 2) = "00101" then
            if slave_i.sel(3) = '1' then
              r_addr(31 downto 24) <= slave_i.dat(31 downto 24);
            end if;
            if slave_i.sel(2) = '1' then
              r_addr(24 downto 16) <= slave_i.dat(24 downto 16);
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;
end rtl;
