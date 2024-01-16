--------------------------------------------------------------------------------
-- CERN BE-CEM-EDL
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   xwb_lm32_mcs
--
-- description: A minimal embedded microcontroller with some amount of RAM,
--              UART and a Wishbone bus for user peripherals. The code can
--              be preloaded or loaded on-the-fly through the Wishbone system bus.
--
--------------------------------------------------------------------------------
-- Copyright CERN 2020-2021
--------------------------------------------------------------------------------
-- Copyright and related rights are licensed under the Solderpad Hardware
-- License, Version 2.0 (the "License"); you may not use this file except
-- in compliance with the License. You may obtain a copy of the License at
-- http://solderpad.org/licenses/SHL-2.0.
-- Unless required by applicable law or agreed to in writing, software,
-- hardware and materials distributed under this License is distributed on an
-- "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
-- or implied. See the License for the specific language governing permissions
-- and limitations under the License.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.genram_pkg.all;
use work.wishbone_pkg.all;

entity xwb_lm32_mcs is
  generic(
    -- size of the code/data memory in bytes
    g_iram_size        : integer;
    -- timeout (in clock cycles) for the Wishbone master.
    -- exceeding the timeout (e.g. due to an incorrect address/
    -- unresponsive slave) causes a WB error after g_bus_timeout cycles.
    g_bus_timeout      : integer := 30;
    -- file (.bram format) with the firmware to pre-load during synthesis.
    g_preload_firmware : string  := "";
    -- Enable host interface (allows loading code from a system bus)
    g_with_host_if     : boolean := true;
    -- Enable Virtual UART (serial console accessible from the system bus)
    g_with_vuart       : boolean := true
    );

  port(
    clk_sys_i : in std_logic;
    rst_n_i   : in std_logic;
    irq_i     : in std_logic_vector(31 downto 0) := x"00000000";

    host_wb_i : in  t_wishbone_slave_in := cc_dummy_slave_in;
    host_wb_o : out t_wishbone_slave_out;

    dbg_txd_o : out std_logic;
    dbg_rxd_i : in  std_logic := '0';

    dwb_o : out t_wishbone_master_out;
    dwb_i : in  t_wishbone_master_in
    );
end xwb_lm32_mcs;

architecture wrapper of xwb_lm32_mcs is
signal CONTROL0 : std_logic_vector(35 downto 0);
  signal TRIG0    : std_logic_vector(31 downto 0);
  signal TRIG1    : std_logic_vector(31 downto 0);
  signal TRIG2    : std_logic_vector(31 downto 0);
  signal TRIG3    : std_logic_vector(31 downto 0);

  component chipscope_icon is
    port (
      CONTROL0 : inout std_logic_vector(35 downto 0));
  end component chipscope_icon;
  component chipscope_ila is
    port (
      CONTROL : inout std_logic_vector(35 downto 0);
      CLK     : in    std_logic;
      TRIG0   : in    std_logic_vector(31 downto 0);
      TRIG1   : in    std_logic_vector(31 downto 0);
      TRIG2   : in    std_logic_vector(31 downto 0);
      TRIG3   : in    std_logic_vector(31 downto 0));
  end component chipscope_ila;
  constant c_iram_addr_width : integer := f_log2_size(g_iram_size)-2;

  component lm32_cpu_wr_node is
    generic (
      eba_reset : std_logic_vector(31 downto 0) := x"00000000"
      );

    port (
      clk_i     : in std_logic;
      enable_i  : in std_logic                     := '1';
      rst_i     : in std_logic;
      interrupt : in std_logic_vector(31 downto 0) := x"00000000";

      -- dbg_csr_write_enable_i : in std_logic                     := '0';
      -- dbg_csr_write_data_i   : in std_logic_vector(31 downto 0) := x"00000000";
      -- dbg_csr_addr_i         : in std_logic_vector(4 downto 0)  := "00000";

      -- dbg_exception_o : out std_logic;
      -- dbg_reset_i     : in  std_logic := '0';
      -- dbg_break_i     : in  std_logic := '0';


      iram_i_adr_o : out std_logic_vector(31 downto 0);
      iram_i_dat_i : in  std_logic_vector(31 downto 0);
      iram_i_en_o  : out std_logic;
      iram_d_adr_o : out std_logic_vector(31 downto 0);
      iram_d_dat_o : out std_logic_vector(31 downto 0);
      iram_d_dat_i : in  std_logic_vector(31 downto 0);
      iram_d_sel_o : out std_logic_vector(3 downto 0);
      iram_d_we_o  : out std_logic;
      iram_d_en_o  : out std_logic;

      D_DAT_O : out std_logic_vector(31 downto 0);
      D_ADR_O : out std_logic_vector(31 downto 0);
      D_CTI_O : out std_logic_vector(2 downto 0);
      D_BTE_O : out std_logic_vector(1 downto 0);
      D_lock_o: out std_logic;
      D_CYC_O : out std_logic;
      D_SEL_O : out std_logic_vector(3 downto 0);
      D_STB_O : out std_logic;
      D_WE_O  : out std_logic;
      D_DAT_I : in  std_logic_vector(31 downto 0);
      D_ACK_I : in  std_logic;
      D_ERR_I : in  std_logic := '0';
      D_RTY_I : in  std_logic := '0'
      );

  end component;

  function f_x_to_zero (x : std_logic_vector) return std_logic_vector is
    variable tmp : std_logic_vector(x'length-1 downto 0);
  begin
    -- synthesis translate_off
    for i in 0 to x'length-1 loop
      if(x(i) = 'X' or x(i) = 'U') then
        tmp(i) := '0';
      else
        tmp(i) := x(i);
      end if;
    end loop;
    return tmp;
    -- synthesis translate_on
    return x;
  end function;

  constant c_cnx_slave_ports  : integer := 1;
  constant c_cnx_master_ports : integer := 2;

  constant c_master_host : integer := 0;

  constant c_slave_csr   : integer := 0;
  constant c_slave_vuart : integer := 1;

  signal cnx_slave_in   : t_wishbone_slave_in_array(c_cnx_slave_ports-1 downto 0);
  signal cnx_slave_out  : t_wishbone_slave_out_array(c_cnx_slave_ports-1 downto 0);
  signal cnx_master_in  : t_wishbone_master_in_array(c_cnx_master_ports-1 downto 0);
  signal cnx_master_out : t_wishbone_master_out_array(c_cnx_master_ports-1 downto 0);

  constant c_cfg_base_addr : t_wishbone_address_array(c_cnx_master_ports-1 downto 0) :=
    (c_slave_csr   => x"00000000",
     c_slave_vuart => x"00000040"
     );

  constant c_cfg_base_mask : t_wishbone_address_array(c_cnx_master_ports-1 downto 0) :=
    (c_slave_csr   => x"00000040",
     c_slave_vuart => x"00000040"
     );

  signal cpu_reset, cpu_enable, cpu_enable_init, cpu_reset_n : std_logic;

  signal d_adr : std_logic_vector(31 downto 0);

  signal core_sel_match : std_logic;

  signal iram_i_wr, iram_d_wr                : std_logic;
  signal iram_i_en, iram_i_en_cpu, iram_d_en : std_logic;

  signal iram_i_adr_cpu, iram_d_adr                             : std_logic_vector(31 downto 0);
  signal udata_addr, iram_i_adr, iram_i_adr_host                : std_logic_vector(f_log2_size(g_iram_size)-3 downto 0);
  signal iram_i_dat_q, iram_i_dat_d, iram_d_dat_d, iram_d_dat_q : std_logic_vector(31 downto 0);
  signal iram_d_sel                                             : std_logic_vector(3 downto 0);

  signal cpu_dwb_out, cpu_dwb_out_sys : t_wishbone_master_out;
  signal cpu_dwb_in, cpu_dwb_in_sys   : t_wishbone_master_in;

  signal dwb_out : t_wishbone_master_out;

  signal bus_timeout     : unsigned(7 downto 0);
  signal bus_timeout_hit : std_logic;

  signal host_slave_in  : t_wishbone_slave_in;
  signal host_slave_out : t_wishbone_slave_out;

  signal cpu_csr_udata_out, cpu_csr_uaddr_addr, cpu_csr_udata_in : std_logic_vector(31 downto 0);
  signal cpu_csr_udata_load                                      : std_logic;
  attribute keep : string;
  attribute keep of dwb_i   : signal is "true";
  attribute keep of cpu_dwb_in_sys   : signal is "true";
begin

  U_CPU : lm32_cpu_wr_node
    generic map (
      eba_reset => x"00000000")
    port map (
      clk_i     => clk_sys_i,
      rst_i     => cpu_reset,
      interrupt => irq_i,

-- instruction bus
      iram_i_adr_o => iram_i_adr_cpu,
      iram_i_dat_i => iram_i_dat_q,
      iram_i_en_o  => iram_i_en_cpu,
-- data bus (IRAM)
      iram_d_adr_o => iram_d_adr,
      iram_d_dat_o => iram_d_dat_d,
      iram_d_dat_i => iram_d_dat_q,
      iram_d_sel_o => iram_d_sel,
      iram_d_we_o  => iram_d_wr,
      iram_d_en_o  => iram_d_en,

      D_DAT_O => cpu_dwb_out.dat,
      D_ADR_O => cpu_dwb_out.adr,
      D_CYC_O => cpu_dwb_out.cyc,
      D_SEL_O => cpu_dwb_out.sel,
      D_STB_O => cpu_dwb_out.stb,
      D_WE_O  => cpu_dwb_out.we,
      D_DAT_I => cpu_dwb_in.dat,
      D_ACK_I => cpu_dwb_in.ack,
      D_ERR_I => cpu_dwb_in.err,
      D_RTY_I => cpu_dwb_in.rty);

  cpu_dwb_in.dat   <= f_x_to_zero(cpu_dwb_in_sys.dat);
  cpu_dwb_in.ack   <= cpu_dwb_in_sys.ack;
  cpu_dwb_in.stall <= cpu_dwb_in_sys.stall;
  cpu_dwb_in.rty   <= '0';
  cpu_dwb_in.err   <= bus_timeout_hit or cpu_dwb_in_sys.err;

  cpu_dwb_out_sys <= cpu_dwb_out;

  p_timeout_counter : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if cpu_reset = '1' or cpu_dwb_out.cyc = '0' or (cpu_dwb_in.ack = '1' and cpu_dwb_out.cyc = '1') then
        bus_timeout     <= (others => '0');
        bus_timeout_hit <= '0';
      elsif (bus_timeout /= g_bus_timeout) then
        bus_timeout     <= bus_timeout + 1;
        bus_timeout_hit <= '0';
      else
        bus_timeout_hit <= '1';
      end if;
    end if;
  end process;



  inst_iram : generic_dpram_split
    generic map (
      g_size                     => g_iram_size/4,
      g_addr_conflict_resolution => "dont_care",
      g_init_file                => g_preload_firmware,
      g_fail_if_file_not_found   => true )
    port map (
      rst_n_i => rst_n_i,
      clk_i   => clk_sys_i,
      bwea_i  => "1111",
      wea_i   => iram_i_wr,
      aa_i    => iram_i_adr,
      da_i    => iram_i_dat_d,
      qa_o    => iram_i_dat_q,
      bweb_i  => iram_d_sel,
      web_i   => iram_d_wr,
      ab_i    => iram_d_adr(f_log2_size(g_iram_size)-1 downto 2),
      db_i    => iram_d_dat_d,
      qb_o    => iram_d_dat_q);



  iram_i_dat_d <= cpu_csr_udata_out;
  iram_i_wr    <= cpu_csr_udata_load;
  iram_i_adr   <= cpu_csr_uaddr_addr(f_log2_size(g_iram_size)-3 downto 0) when cpu_enable = '0' else
                  iram_i_adr_cpu(f_log2_size(g_iram_size)-1 downto 2);

  iram_i_en <= '1' when cpu_enable = '0' else iram_i_en_cpu;

  cpu_csr_udata_in <= iram_i_dat_q;

  U_Classic2Pipe : wb_slave_adapter
    generic map (
      g_master_use_struct  => true,
      g_master_mode        => PIPELINED,
      g_master_granularity => BYTE,
      g_slave_use_struct   => true,
      g_slave_mode         => CLASSIC,
      g_slave_granularity  => BYTE)
    port map (
      clk_sys_i => clk_sys_i,
      rst_n_i   => rst_n_i,
      slave_i   => cpu_dwb_out_sys,
      slave_o   => cpu_dwb_in_sys,
      master_i  => dwb_i,
      master_o  => dwb_out);

  dwb_o <= dwb_out;

  cpu_reset   <= not rst_n_i or (not cpu_enable);
  cpu_reset_n <= not cpu_reset;

  cnx_slave_in(c_master_host) <= host_wb_i;
  host_wb_o                   <= cnx_slave_out(c_master_host);

  U_Intercon : xwb_crossbar
    generic map (
      g_num_masters => c_cnx_slave_ports,
      g_num_slaves  => c_cnx_master_ports,
      g_registered  => true,
      g_address     => c_cfg_base_addr,
      g_mask        => c_cfg_base_mask)
    port map (
      clk_sys_i => clk_sys_i,
      rst_n_i   => rst_n_i,
      slave_i   => cnx_slave_in,
      slave_o   => cnx_slave_out,
      master_i  => cnx_master_in,
      master_o  => cnx_master_out);

  U_UART : xwb_simple_uart
    generic map (
      g_with_virtual_uart   => true,
      g_with_physical_uart  => true,
      g_interface_mode      => PIPELINED,
      g_address_granularity => BYTE,
      g_vuart_fifo_size     => 1024)
    port map (
      clk_sys_i  => clk_sys_i,
      rst_n_i    => rst_n_i,
      slave_i    => cnx_master_out(c_slave_vuart),
      slave_o    => cnx_master_in(c_slave_vuart),
      uart_rxd_i => dbg_rxd_i,
      uart_txd_o => dbg_txd_o);


  iram_i_dat_d <= cpu_csr_udata_out;
  iram_i_wr    <= cpu_csr_udata_load;
  iram_i_adr   <= cpu_csr_uaddr_addr(f_log2_size(g_iram_size)-3 downto 0) when cpu_enable = '0' else
                  iram_i_adr_cpu(f_log2_size(g_iram_size)-1 downto 2);

  iram_i_en <= '1' when cpu_enable = '0' else iram_i_en_cpu;

  cpu_csr_udata_in <= iram_i_dat_q;

  host_slave_in              <= cnx_master_out(c_slave_csr);
  cnx_master_in(c_slave_csr) <= host_slave_out;

  p_local_regs : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        cpu_csr_udata_load   <= '0';
        cpu_enable           <= '0';
        cpu_csr_uaddr_addr   <= (others => '0');
        host_slave_out.ack   <= '0';
        host_slave_out.err   <= '0';
        host_slave_out.rty   <= '0';
        host_slave_out.stall <= '0';
        cpu_enable_init <= '0';
        
      else
        cpu_csr_udata_load <= '0';
        host_slave_out.ack <= '0';

        if g_preload_firmware /= "" and cpu_enable_init = '0' then
          cpu_enable <= '1';
          cpu_enable_init <= '1';
        end if;
        
        
        if host_slave_in.cyc = '1' and host_slave_in.stb = '1' then

          host_slave_out.ack <= '1';

          if host_slave_in.we = '1' then
            case host_slave_in.adr(3 downto 0) is
              when "0000" =>            -- csr
                cpu_enable <= host_slave_in.dat(0);

              when "0100" =>            -- data
                cpu_csr_udata_out  <= host_slave_in.dat;
                cpu_csr_udata_load <= '1';
                
              when "1000" =>            -- addr
                cpu_csr_uaddr_addr <= host_slave_in.dat;
              when others => null;
            end case;
          else
            case host_slave_in.adr(3 downto 0) is
              when "0000" =>
                host_slave_out.dat(0)           <= cpu_enable;
                host_slave_out.dat(31 downto 1) <= std_logic_vector(to_unsigned(g_iram_size, 31));
              when "0100" =>
                host_slave_out.dat <= cpu_csr_udata_in;
              when others => null;
            end case;
          end if;
        end if;
      end if;
    end if;
  end process;

   -- chipscope_icon_1 : chipscope_icon
   --   port map (
   --     CONTROL0 => CONTROL0);


   -- chipscope_ila_1 : chipscope_ila
   --   port map (
   --     CONTROL => CONTROL0,
   --     CLK     => clk_sys_i,
   --     TRIG0   => TRIG0,
   --     TRIG1   => TRIG1,
   --     TRIG2   => TRIG2,
   --     TRIG3   => TRIG3);

  trig0(31 downto 0) <= cnx_master_in(c_slave_vuart).dat;
  trig1(31 downto 0)  <= cnx_master_out(c_slave_vuart).dat;

  trig2(16)           <= cnx_master_out(c_slave_vuart).cyc;
  trig2(17)           <= cnx_master_out(c_slave_vuart).stb;
  trig2(18)           <= cnx_master_out(c_slave_vuart).we;
  trig2(19)           <= cnx_master_in(c_slave_vuart).stall;
  trig2(20)           <= cnx_master_in(c_slave_vuart).ack;
  trig3               <= cnx_master_out(c_slave_vuart).adr;
  
end wrapper;
