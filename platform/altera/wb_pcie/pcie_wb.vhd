library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pcie_wb_pkg.all;
use work.wishbone_pkg.all;

entity pcie_wb is
  generic(
    g_family   : string  := "Arria II";
    g_fast_ack : boolean := true;
    sdb_addr   : t_wishbone_address);
  port(
    clk125_i      : in  std_logic; -- 125 MHz, free running
    cal_clk50_i   : in  std_logic; --  50 MHz, shared between all PHYs
    
    -- Physical PCIe pins
    pcie_refclk_i : in  std_logic; -- 100 MHz, must not derive clk125_i or cal_clk50_i
    pcie_rstn_i   : in  std_logic; -- Asynchronous "clear sticky" PCIe pin
    pcie_rx_i     : in  std_logic_vector(3 downto 0);
    pcie_tx_o     : out std_logic_vector(3 downto 0);
    
    -- Commands from PC to FPGA
    master_clk_i  : in  std_logic;
    master_rstn_i : in  std_logic;
    master_o      : out t_wishbone_master_out;
    master_i      : in  t_wishbone_master_in;
    
    -- Command to PC from FPGA
    slave_clk_i   : in  std_logic := '0';
    slave_rstn_i  : in  std_logic := '1';
    slave_i       : in  t_wishbone_slave_in := cc_dummy_slave_in;
    slave_o       : out t_wishbone_slave_out);
end pcie_wb;

architecture rtl of pcie_wb is
  signal internal_wb_clk, internal_wb_rstn, stall : std_logic; 
  signal internal_wb_rstn_sync : std_logic_vector(3 downto 0) := (others => '0');
  
  signal rx_wb64_stb, rx_wb64_stall : std_logic;
  signal rx_wb32_stb, rx_wb32_stall : std_logic;
  signal rx_wb64_dat : std_logic_vector(63 downto 0);
  signal rx_wb32_dat : std_logic_vector(31 downto 0);
  signal rx_bar : std_logic_vector(2 downto 0);
  
  signal tx_rdy, tx_eop : std_logic;
  signal tx64_alloc, tx_wb64_stb : std_logic;
  signal tx32_alloc, tx_wb32_stb : std_logic;
  signal tx_wb64_dat : std_logic_vector(63 downto 0);
  signal tx_wb32_dat : std_logic_vector(31 downto 0);
  
  signal tx_alloc_mask : std_logic := '1'; -- Only pass every even tx32_alloc to tx64_alloc.
  
  signal wb_stb, wb_ack, wb_stall : std_logic;
  signal wb_adr : std_logic_vector(63 downto 0);
  signal wb_bar : std_logic_vector(2 downto 0);
  signal wb_dat : std_logic_vector(31 downto 0);
  
  signal cfg_busdev : std_logic_vector(12 downto 0);
  
  -- Internal WB clock, PC->FPGA
  signal int_slave_i : t_wishbone_slave_in;
  signal int_slave_o : t_wishbone_slave_out;
  -- Internal WB clock: FPGA->PC
  signal int_master_o : t_wishbone_master_out;
  signal int_master_i : t_wishbone_master_in;
  signal ext_slave_o  : t_wishbone_slave_out;
  
  -- control registers
  signal r_cyc   : std_logic;
  signal r_int   : std_logic := '0'; -- interrupt mask, starts=0
  signal r_addr  : std_logic_vector(31 downto 16);
  signal r_error : std_logic_vector(63 downto  0);
  
  -- interrupt signals
  signal fifo_full, r_fifo_full, app_int_sts, app_msi_req : std_logic;
begin

  pcie_phy : pcie_altera 
    generic map(
      g_family => g_family)
    port map(
      clk125_i      => clk125_i,
      cal_clk50_i   => cal_clk50_i,
      async_rstn    => master_rstn_i and slave_rstn_i,
      
      pcie_refclk_i => pcie_refclk_i,
      pcie_rstn_i   => pcie_rstn_i,
      pcie_rx_i     => pcie_rx_i,
      pcie_tx_o     => pcie_tx_o,

      cfg_busdev_o  => cfg_busdev,
      app_msi_req   => app_msi_req,
      app_int_sts   => app_int_sts,

      wb_clk_o      => internal_wb_clk,
      wb_rstn_i     => internal_wb_rstn,
      
      rx_wb_stb_o   => rx_wb64_stb,
      rx_wb_dat_o   => rx_wb64_dat,
      rx_wb_stall_i => rx_wb64_stall,
      rx_bar_o      => rx_bar,
      
      tx_rdy_o      => tx_rdy,
      tx_alloc_i    => tx64_alloc,
      
      tx_wb_stb_i   => tx_wb64_stb,
      tx_wb_dat_i   => tx_wb64_dat,
      tx_eop_i      => tx_eop);
  
  pcie_rx : pcie_64to32 port map(
    clk_i            => internal_wb_clk,
    rstn_i           => internal_wb_rstn,
    master64_stb_i   => rx_wb64_stb,
    master64_dat_i   => rx_wb64_dat,
    master64_stall_o => rx_wb64_stall,
    slave32_stb_o    => rx_wb32_stb,
    slave32_dat_o    => rx_wb32_dat,
    slave32_stall_i  => rx_wb32_stall);
  
  pcie_tx : pcie_32to64 port map(
    clk_i            => internal_wb_clk,
    rstn_i           => internal_wb_rstn,
    master32_stb_i   => tx_wb32_stb,
    master32_dat_i   => tx_wb32_dat,
    master32_stall_o => open,
    slave64_stb_o    => tx_wb64_stb,
    slave64_dat_o    => tx_wb64_dat,
    slave64_stall_i  => '0');
  
  pcie_logic : pcie_tlp port map(
    clk_i         => internal_wb_clk,
    rstn_i        => internal_wb_rstn,
    
    rx_wb_stb_i   => rx_wb32_stb,
    rx_wb_dat_i   => rx_wb32_dat,
    rx_wb_stall_o => rx_wb32_stall,
    rx_bar_i      => rx_bar,
    
    tx_rdy_i      => tx_rdy,
    tx_alloc_o    => tx32_alloc,
    tx_wb_stb_o   => tx_wb32_stb,
    tx_wb_dat_o   => tx_wb32_dat,
    tx_eop_o      => tx_eop,
    
    cfg_busdev_i  => cfg_busdev,
      
    wb_stb_o      => wb_stb,
    wb_adr_o      => wb_adr,
    wb_bar_o      => wb_bar,
    wb_we_o       => int_slave_i.we,
    wb_dat_o      => int_slave_i.dat,
    wb_sel_o      => int_slave_i.sel,
    wb_stall_i    => wb_stall,
    wb_ack_i      => wb_ack,
    wb_err_i      => int_slave_o.err,
    wb_rty_i      => int_slave_o.rty,
    wb_dat_i      => wb_dat);
  
  internal_wb_rstn <= internal_wb_rstn_sync(0);
  tx64_alloc <= tx32_alloc and tx_alloc_mask;
  alloc : process(internal_wb_clk)
  begin
    if rising_edge(internal_wb_clk) then
      internal_wb_rstn_sync <= (master_rstn_i and slave_rstn_i) & internal_wb_rstn_sync(internal_wb_rstn_sync'length-1 downto 1);
      
      if internal_wb_rstn = '0' then
        tx_alloc_mask <= '1';
      else
        tx_alloc_mask <= tx_alloc_mask xor tx32_alloc;
      end if;
    end if;
  end process;
  
  PC_to_FPGA_clock_crossing : xwb_clock_crossing 
    generic map(g_size => 32) port map(
    slave_clk_i    => internal_wb_clk,
    slave_rst_n_i  => internal_wb_rstn,
    slave_i        => int_slave_i,
    slave_o        => int_slave_o,
    master_clk_i   => master_clk_i, 
    master_rst_n_i => master_rstn_i,
    master_i       => master_i,
    master_o       => master_o);
  
  int_slave_i.stb <= wb_stb        when wb_bar = "001" else '0';
  wb_stall    <= int_slave_o.stall when wb_bar = "001" else '0';
  
  int_slave_i.cyc <= r_cyc;
  int_slave_i.adr(r_addr'range) <= r_addr;
  int_slave_i.adr(r_addr'right-1 downto 0)  <= wb_adr(r_addr'right-1 downto 0);
  
  FPGA_to_PC_clock_crossing : xwb_clock_crossing
    generic map(g_size => 32) port map(
    slave_clk_i    => slave_clk_i,
    slave_rst_n_i  => slave_rstn_i,
    slave_i        => slave_i,
    slave_o        => ext_slave_o,
    master_clk_i   => internal_wb_clk, 
    master_rst_n_i => internal_wb_rstn,
    master_i       => int_master_i,
    master_o       => int_master_o);
  
  -- Do not wait for software acknowledgement
  fask_ack : if g_fast_ack generate
    slave_o.stall <= ext_slave_o.stall;
    slave_o.rty <= '0';
    slave_o.err <= '0';
    slave_o.dat <= (others => '0');
    
    fast_ack : process(slave_clk_i)
    begin
      if rising_edge(slave_clk_i) then
        slave_o.ack <= slave_i.cyc and slave_i.stb and not ext_slave_o.stall;
      end if;
    end process;
  end generate;
  
  -- Uses ack/err and dat from software
  slow_ack : if not g_fast_ack generate
    slave_o <= ext_slave_o;
  end generate;

  -- Notify the system when the FIFO is non-empty
  fifo_full <= int_master_o.cyc and int_master_o.stb;
  app_int_sts <= fifo_full and r_int; -- Classic interrupt until FIFO drained
  app_msi_req <= fifo_full and not r_fifo_full; -- Edge-triggered MSI
  
  int_master_i.rty <= '0';
  
  control : process(internal_wb_clk)
  begin
    if rising_edge(internal_wb_clk) then
      r_fifo_full <= fifo_full;
      
      -- Shift in the error register
      if int_slave_o.ack = '1' or int_slave_o.err = '1' or int_slave_o.rty = '1' then
        r_error <= r_error(r_error'length-2 downto 0) & (int_slave_o.err or int_slave_o.rty);
      end if;
      
      if wb_bar = "001" then
        wb_ack <= int_slave_o.ack;
        wb_dat <= int_slave_o.dat;
      else -- The control BAR is targetted
        -- Feedback acks one cycle after strobe
        wb_ack <= wb_stb;
        
        -- Always output read result (even w/o stb or we)
        case wb_adr(6 downto 2) is
          when "00000" => -- Control register high
            wb_dat(31) <= r_cyc;
            wb_dat(30) <= '0';
            wb_dat(29) <= r_int;
            wb_dat(28 downto 0) <= (others => '0');
          when "00010" => -- Error flag high
            wb_dat <= r_error(63 downto 32);
          when "00011" => -- Error flag low
            wb_dat <= r_error(31 downto 0);
          when "00101" => -- Window offset low
            wb_dat(r_addr'range) <= r_addr;
            wb_dat(r_addr'right-1 downto 0) <= (others => '0');
          when "00111" => -- SDWB address low
            wb_dat <= sdb_addr;
          when "10000" => -- Master FIFO status & flags
            wb_dat(31) <= fifo_full;
            wb_dat(30) <= int_master_o.we;
            wb_dat(29 downto 4) <= (others => '0');
            wb_dat(3 downto 0) <= int_master_o.sel;
          when "10011" => -- Master FIFO adr low
            wb_dat <= int_master_o.adr and c_pcie_msi.sdb_component.addr_last(31 downto 0);
          when "10101" => -- Master FIFO dat low
            wb_dat <= int_master_o.dat;
          when others =>
            wb_dat <= (others => '0');
        end case;
        
        -- Unless requested to by the PC, don't deque the FPGA->PC FIFO
        int_master_i.stall <= '1';
        int_master_i.ack <= '0';
        int_master_i.err <= '0';
        
        -- Is this a write to the register space?
        if wb_stb = '1' and int_slave_i.we = '1' then
          case wb_adr(6 downto 2) is
            when "00000" => -- Control register high
              if int_slave_i.sel(3) = '1' then
                if int_slave_i.dat(30) = '1' then
                  r_cyc <= int_slave_i.dat(31);
        	end if;
        	if int_slave_i.dat(28) = '1' then
        	  r_int <= int_slave_i.dat(29);
        	end if;
              end if;
            when "00101" => -- Window offset low
              if int_slave_i.sel(3) = '1' then
                r_addr(31 downto 24) <= int_slave_i.dat(31 downto 24);
              end if;
              if int_slave_i.sel(2) = '1' then
                r_addr(24 downto 16) <= int_slave_i.dat(24 downto 16);
              end if;
            when "10000" => -- Master FIFO status & flags
              if int_slave_i.sel(0) = '1' then
                case int_slave_i.dat(1 downto 0) is
                  when "00" => null;
                  when "01" => int_master_i.stall <= '0';
                  when "10" => int_master_i.ack <= '1';
                  when "11" => int_master_i.err <= '1';
                end case;
              end if;
            when "10101" => -- Master FIFO data low
              int_master_i.dat <= int_slave_i.dat;
            when others => null;
          end case;
        end if;
      end if;
    end if;
  end process;
  
end rtl;
