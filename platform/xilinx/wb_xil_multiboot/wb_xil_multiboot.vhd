--==============================================================================
-- CERN (BE-CO-HT)
-- Xilinx MultiBoot core top-level file
--==============================================================================
--
-- author: Theodor Stana (t.stana@cern.ch)
--
-- date of creation: 2013-08-19
--
-- version: 1.0
--
-- description:
--
-- dependencies:
--
-- references:
--
--==============================================================================
-- GNU LESSER GENERAL PUBLIC LICENSE
--==============================================================================
-- This source file is free software; you can redistribute it and/or modify it
-- under the terms of the GNU Lesser General Public License as published by the
-- Free Software Foundation; either version 2.1 of the License, or (at your
-- option) any later version. This source is distributed in the hope that it
-- will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
-- of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU Lesser General Public License for more details. You should have
-- received a copy of the GNU Lesser General Public License along with this
-- source; if not, download it from http://www.gnu.org/licenses/lgpl-2.1.html
--==============================================================================
-- last changes:
--    2013-08-19   Theodor Stana     t.stana@cern.ch     File created
--==============================================================================
-- TODO: -
--==============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

use work.wishbone_pkg.all;

entity wb_xil_multiboot is
  port
  (
    -- Clock and reset input ports
    clk_i   : in  std_logic;
    rst_n_i : in  std_logic;

    -- Wishbone ports
    wbs_i   : in  t_wishbone_slave_in;
    wbs_o   : out t_wishbone_slave_out;

    -- SPI ports
    spi_cs_n_o : out std_logic;
    spi_sclk_o : out std_logic;
    spi_mosi_o : out std_logic;
    spi_miso_i : in  std_logic
  );
end entity wb_xil_multiboot;


architecture struct of wb_xil_multiboot is

  --============================================================================
  -- Component declarations
  --============================================================================
  -- Register component
  component multiboot_regs is
    port (
      rst_n_i                                  : in     std_logic;
      clk_sys_i                                : in     std_logic;
      wb_adr_i                                 : in     std_logic_vector(2 downto 0);
      wb_dat_i                                 : in     std_logic_vector(31 downto 0);
      wb_dat_o                                 : out    std_logic_vector(31 downto 0);
      wb_cyc_i                                 : in     std_logic;
      wb_sel_i                                 : in     std_logic_vector(3 downto 0);
      wb_stb_i                                 : in     std_logic;
      wb_we_i                                  : in     std_logic;
      wb_ack_o                                 : out    std_logic;
      wb_stall_o                               : out    std_logic;
  -- Port for std_logic_vector field: 'Configuration register address' in reg: 'CR'
      reg_cr_cfgregadr_o                       : out    std_logic_vector(5 downto 0);
  -- Port for MONOSTABLE field: 'Read FPGA configuration register' in reg: 'CR'
      reg_cr_rdcfgreg_o                        : out    std_logic;
  -- Ports for BIT field: 'Unlock bit for the IPROG command' in reg: 'CR'
      reg_cr_iprog_unlock_o                    : out    std_logic;
      reg_cr_iprog_unlock_i                    : in     std_logic;
      reg_cr_iprog_unlock_load_o               : out    std_logic;
  -- Ports for BIT field: 'Start IPROG sequence' in reg: 'CR'
      reg_cr_iprog_o                           : out    std_logic;
      reg_cr_iprog_i                           : in     std_logic;
      reg_cr_iprog_load_o                      : out    std_logic;
  -- Port for std_logic_vector field: 'Configuration register image' in reg: 'SR'
      reg_sr_cfgregimg_i                       : in     std_logic_vector(15 downto 0);
  -- Port for BIT field: 'Configuration register image valid' in reg: 'SR'
      reg_sr_imgvalid_i                        : in     std_logic;
  -- Ports for BIT field: 'MultiBoot FSM stalled at one point and was reset by FSM watchdog' in reg: 'SR'
      reg_sr_wdto_o                            : out    std_logic;
      reg_sr_wdto_i                            : in     std_logic;
      reg_sr_wdto_load_o                       : out    std_logic;
  -- Port for std_logic_vector field: 'Bits of GBBAR register' in reg: 'GBBAR'
      reg_gbbar_bits_o                         : out    std_logic_vector(31 downto 0);
  -- Port for std_logic_vector field: 'Bits of MBBAR register' in reg: 'MBBAR'
      reg_mbbar_bits_o                         : out    std_logic_vector(31 downto 0);
  -- Port for std_logic_vector field: 'Flash data field' in reg: 'FAR'
      reg_far_data_o                           : out    std_logic_vector(23 downto 0);
      reg_far_data_i                           : in     std_logic_vector(23 downto 0);
      reg_far_data_load_o                      : out    std_logic;
  -- Port for std_logic_vector field: 'Number of DATA fields to send and receive in one transfer:' in reg: 'FAR'
      reg_far_nbytes_o                         : out    std_logic_vector(1 downto 0);
  -- Port for MONOSTABLE field: 'Start transfer to and from flash' in reg: 'FAR'
      reg_far_xfer_o                           : out    std_logic;
  -- Port for BIT field: 'Chip select bit' in reg: 'FAR'
      reg_far_cs_o                             : out    std_logic;
  -- Port for BIT field: 'Flash access ready' in reg: 'FAR'
      reg_far_ready_i                          : in     std_logic
    );
  end component multiboot_regs;

  -- FSM component
  component multiboot_fsm is
    port
    (
      -- Clock and reset inputs
      clk_i                : in  std_logic;
      rst_n_i              : in  std_logic;

      -- Control register inputs
      reg_rdcfgreg_i       : in  std_logic;
      reg_cfgregadr_i      : in  std_logic_vector(5 downto 0);
      reg_iprog_i          : in  std_logic;

      -- Multiboot and golden bitstream start addresses
      reg_gbbar_i          : in  std_logic_vector(31 downto 0);
      reg_mbbar_i          : in  std_logic_vector(31 downto 0);

      -- Outputs to status register
      reg_wdto_p_o         : out std_logic;
      reg_cfgreg_img_o     : out std_logic_vector(15 downto 0);
      reg_cfgreg_valid_o   : out std_logic;

      -- Flash access register signals
      reg_far_data_i       : in  std_logic_vector(23 downto 0);
      reg_far_data_o       : out std_logic_vector(23 downto 0);
      reg_far_nbytes_i     : in  std_logic_vector(1 downto 0);
      reg_far_xfer_i       : in  std_logic;
      reg_far_cs_i         : in  std_logic;
      reg_far_ready_o      : out std_logic;

      -- SPI master signals
      spi_xfer_o           : out std_logic;
      spi_cs_o             : out std_logic;
      spi_data_i           : in  std_logic_vector(7 downto 0);
      spi_data_o           : out std_logic_vector(7 downto 0);
      spi_ready_i          : in  std_logic;

      -- Ports for the external ICAP component
      icap_dat_i           : in  std_logic_vector(15 downto 0);
      icap_dat_o           : out std_logic_vector(15 downto 0);
      icap_busy_i          : in  std_logic;
      icap_ce_n_o          : out std_logic;
      icap_wr_n_o          : out std_logic
    );
  end component multiboot_fsm;

  -- SPI master
  component spi_master is
    generic(
      -- clock division ratio (SCLK = clk_sys_i / (2 ** g_div_ratio_log2).
      g_div_ratio_log2 : integer := 2;
      -- number of data bits per transfer
      g_num_data_bits  : integer := 2);
    port (
      clk_sys_i : in std_logic;
      rst_n_i   : in std_logic;

      -- state of the Chip select line (1 = CS active). External control
      -- allows for multi-transfer commands (SPI master itself does not
      -- control the state of spi_cs_n_o)
      cs_i : in std_logic;

      -- 1: start next transfer (using CPOL, DATA and SEL from the inputs below)
      start_i    : in  std_logic;

      -- Clock polarity: 1: slave clocks in the data on rising SCLK edge, 0: ...
      -- on falling SCLK edge
      cpol_i     : in  std_logic;

      -- TX Data input
      data_i     : in  std_logic_vector(g_num_data_bits - 1 downto 0);

      -- 1: data_o contains the result of last read operation. Core is ready to initiate
      -- another transfer.
      ready_o    : out std_logic;

      -- data read from selected slave, valid when ready_o == 1.
      data_o     : out std_logic_vector(g_num_data_bits - 1 downto 0);

      -- these are obvious
      spi_cs_n_o : out std_logic;
      spi_sclk_o : out std_logic;
      spi_mosi_o : out std_logic;
      spi_miso_i : in  std_logic
    );
  end component spi_master;

  --============================================================================
  -- Signal declarations
  --============================================================================
  -- Control and status register signals
  signal rdcfgreg            : std_logic;
  signal cfgregadr           : std_logic_vector(5 downto 0);
  signal iprog_unlock        : std_logic;
  signal iprog_unlock_bit    : std_logic;
  signal iprog_unlock_bit_ld : std_logic;
  signal iprog               : std_logic;
  signal iprog_bit           : std_logic;
  signal iprog_bit_ld        : std_logic;
  signal cfgregimg           : std_logic_vector(15 downto 0);
  signal imgvalid            : std_logic;
  signal wdto                : std_logic;
  signal wdto_bit            : std_logic;
  signal wdto_bit_ld         : std_logic;
  signal gbbar, mbbar        : std_logic_vector(31 downto 0);

  -- FSM signals
  signal fsm_icap_din        : std_logic_vector(15 downto 0);
  signal fsm_icap_dout       : std_logic_vector(15 downto 0);
  signal fsm_wdto_p          : std_logic;

  -- Flash controller signals
  signal far_data_out        : std_logic_vector(23 downto 0);
  signal far_data_in         : std_logic_vector(23 downto 0);
  signal far_data_ld         : std_logic;
  signal far_nbytes          : std_logic_vector(1 downto 0);
  signal far_xfer            : std_logic;
  signal far_cs              : std_logic;
  signal far_ready           : std_logic;

  -- SPI master signals
  signal spi_data_in         : std_logic_vector(7 downto 0);
  signal spi_data_out        : std_logic_vector(7 downto 0);
  signal spi_xfer            : std_logic;
  signal spi_cs              : std_logic;
  signal spi_ready           : std_logic;

  -- ICAP signals
  signal icap_ce_n           : std_logic;
  signal icap_wr_n           : std_logic;
  signal icap_busy           : std_logic;
  signal icap_din            : std_logic_vector(15 downto 0);
  signal icap_dout           : std_logic_vector(15 downto 0);

--==============================================================================
--  architecture begin
--==============================================================================
begin

  --============================================================================
  -- Register component instantiation
  --============================================================================
  -- First, instantiate the register component
  cmp_regs : multiboot_regs
    port map
    (
      rst_n_i                    => rst_n_i,
      clk_sys_i                  => clk_i,

      wb_adr_i                   => wbs_i.adr(4 downto 2),
      wb_dat_i                   => wbs_i.dat,
      wb_dat_o                   => wbs_o.dat,
      wb_cyc_i                   => wbs_i.cyc,
      wb_sel_i                   => wbs_i.sel,
      wb_stb_i                   => wbs_i.stb,
      wb_we_i                    => wbs_i.we,
      wb_ack_o                   => wbs_o.ack,
      wb_stall_o                 => wbs_o.stall,

      reg_cr_rdcfgreg_o          => rdcfgreg,
      reg_cr_cfgregadr_o         => cfgregadr,
      reg_cr_iprog_unlock_o      => iprog_unlock_bit,
      reg_cr_iprog_unlock_i      => iprog_unlock,
      reg_cr_iprog_unlock_load_o => iprog_unlock_bit_ld,
      reg_cr_iprog_o             => iprog_bit,
      reg_cr_iprog_i             => iprog,
      reg_cr_iprog_load_o        => iprog_bit_ld,

      reg_sr_cfgregimg_i         => cfgregimg,
      reg_sr_imgvalid_i          => imgvalid,
      reg_sr_wdto_o              => wdto_bit,
      reg_sr_wdto_i              => wdto,
      reg_sr_wdto_load_o         => wdto_bit_ld,

      reg_gbbar_bits_o           => gbbar,
      reg_mbbar_bits_o           => mbbar,

      reg_far_data_o             => far_data_out,
      reg_far_data_i             => far_data_in,
      reg_far_data_load_o        => open,
      reg_far_nbytes_o           => far_nbytes,
      reg_far_xfer_o             => far_xfer,
      reg_far_cs_o               => far_cs,
      reg_far_ready_i            => far_ready
    );

  -- Implement the IPROG_UNLOCK bit register
  -- This bit is used to unlock the IPROG bit for writing
  p_iprog_unl : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if (rst_n_i = '0') then
        iprog_unlock <= '0';
      elsif (iprog_unlock_bit_ld = '1') then
        if (iprog_unlock_bit = '1') then
          iprog_unlock <= '1';
        else
          iprog_unlock <= '0';
        end if;
      end if;
    end if;
  end process p_iprog_unl;

  -- Implement the IPROG bit register
  -- The bit is set when the IPROG bit is set and the IPROG_UNLOCK bit has been
  -- set in a previous cycle
  p_iprog : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if (rst_n_i = '0') then
        iprog <= '0';
      elsif (iprog_bit_ld = '1') and (iprog_bit = '1')
            and (iprog_unlock = '1') then
        iprog <= '1';
      else
        iprog <= '0';
      end if;
    end if;
  end process p_iprog;

  -- Implement the register for the WDTO bit in the SR
  -- The bit is set by the pulse WDTO output from the FSM
  -- The bit is cleared by writing a '1' to it
  p_wdto_bit : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if (rst_n_i = '0') then
        wdto <= '0';
      elsif (fsm_wdto_p = '1') then
        wdto <= '1';
      elsif (wdto_bit_ld = '1') and (wdto_bit = '1') then
        wdto <= '0';
      end if;
    end if;
  end process p_wdto_bit;

  --============================================================================
  -- FSM component instantiation
  --============================================================================
  cmp_fsm : multiboot_fsm
    port map
    (
      clk_i                => clk_i,
      rst_n_i              => rst_n_i,

      reg_rdcfgreg_i       => rdcfgreg,
      reg_cfgregadr_i      => cfgregadr,
      reg_iprog_i          => iprog,

      reg_gbbar_i          => gbbar,
      reg_mbbar_i          => mbbar,

      reg_wdto_p_o         => fsm_wdto_p,
      reg_cfgreg_img_o     => cfgregimg,
      reg_cfgreg_valid_o   => imgvalid,

      reg_far_data_i       => far_data_out,
      reg_far_data_o       => far_data_in,
      reg_far_nbytes_i     => far_nbytes,
      reg_far_xfer_i       => far_xfer,
      reg_far_cs_i         => far_cs,
      reg_far_ready_o      => far_ready,

      spi_xfer_o           => spi_xfer,
      spi_cs_o             => spi_cs,
      spi_data_i           => spi_data_out,
      spi_data_o           => spi_data_in,
      spi_ready_i          => spi_ready,

      icap_dat_i           => fsm_icap_din,
      icap_dat_o           => fsm_icap_dout,
      icap_busy_i          => icap_busy,
      icap_ce_n_o          => icap_ce_n,
      icap_wr_n_o          => icap_wr_n
    );

  --============================================================================
  -- Flash controller instantiation
  --============================================================================
  cmp_spi_master : spi_master
    generic map
    (
      g_div_ratio_log2 => 0,
      g_num_data_bits  => 8
    )
    port map
    (
      clk_sys_i  => clk_i,
      rst_n_i    => rst_n_i,
      cs_i       => spi_cs,
      start_i    => spi_xfer,
      cpol_i     => '0',
      data_i     => spi_data_in,
      data_o     => spi_data_out,
      ready_o    => spi_ready,
      spi_cs_n_o => spi_cs_n_o,
      spi_sclk_o => spi_sclk_o,
      spi_mosi_o => spi_mosi_o,
      spi_miso_i => spi_miso_i
    );

  --============================================================================
  -- Xilinx ICAP logic
  --============================================================================
  -- First, bit-flip the data to/from the FSM
  icap_din( 0) <= fsm_icap_dout( 7);
  icap_din( 1) <= fsm_icap_dout( 6);
  icap_din( 2) <= fsm_icap_dout( 5);
  icap_din( 3) <= fsm_icap_dout( 4);
  icap_din( 4) <= fsm_icap_dout( 3);
  icap_din( 5) <= fsm_icap_dout( 2);
  icap_din( 6) <= fsm_icap_dout( 1);
  icap_din( 7) <= fsm_icap_dout( 0);
  icap_din( 8) <= fsm_icap_dout(15);
  icap_din( 9) <= fsm_icap_dout(14);
  icap_din(10) <= fsm_icap_dout(13);
  icap_din(11) <= fsm_icap_dout(12);
  icap_din(12) <= fsm_icap_dout(11);
  icap_din(13) <= fsm_icap_dout(10);
  icap_din(14) <= fsm_icap_dout( 9);
  icap_din(15) <= fsm_icap_dout( 8);

  fsm_icap_din( 0) <= icap_dout( 7);
  fsm_icap_din( 1) <= icap_dout( 6);
  fsm_icap_din( 2) <= icap_dout( 5);
  fsm_icap_din( 3) <= icap_dout( 4);
  fsm_icap_din( 4) <= icap_dout( 3);
  fsm_icap_din( 5) <= icap_dout( 2);
  fsm_icap_din( 6) <= icap_dout( 1);
  fsm_icap_din( 7) <= icap_dout( 0);
  fsm_icap_din( 8) <= icap_dout(15);
  fsm_icap_din( 9) <= icap_dout(14);
  fsm_icap_din(10) <= icap_dout(13);
  fsm_icap_din(11) <= icap_dout(12);
  fsm_icap_din(12) <= icap_dout(11);
  fsm_icap_din(13) <= icap_dout(10);
  fsm_icap_din(14) <= icap_dout( 9);
  fsm_icap_din(15) <= icap_dout( 8);

  -- and instantiate the ICAP component
  cmp_icap : ICAP_SPARTAN6
    port map
    (
      CLK   => clk_i,
      CE    => icap_ce_n,
      WRITE => icap_wr_n,
      I     => icap_din,
      O     => icap_dout,
      BUSY  => icap_busy
    );

end architecture struct;
--==============================================================================
--  architecture end
--==============================================================================
