library ieee;
use ieee.std_logic_1164.all;

entity wb_virtual_uart is
  port(
    rst_n_i     : in  std_logic;
    clk_sys_i    : in  std_logic;
    wb_addr_i   : in  std_logic_vector(2 downto 0);
    wb_data_i   : in  std_logic_vector(31 downto 0);
    wb_data_o   : out std_logic_vector(31 downto 0);
    wb_cyc_i    : in  std_logic;
    wb_sel_i    : in  std_logic_vector(3 downto 0);
    wb_stb_i    : in  std_logic;
    wb_we_i     : in  std_logic;
    wb_ack_o    : out std_logic
  );
end wb_virtual_uart;

architecture struct of wb_virtual_uart is

  component wb_virtual_uart_slave
    port (
      rst_n_i                 : in  std_logic;
      wb_clk_i                : in  std_logic;
      wb_addr_i               : in  std_logic_vector(2 downto 0);
      wb_data_i               : in  std_logic_vector(31 downto 0);
      wb_data_o               : out std_logic_vector(31 downto 0);
      wb_cyc_i                : in  std_logic;
      wb_sel_i                : in  std_logic_vector(3 downto 0);
      wb_stb_i                : in  std_logic;
      wb_we_i                 : in  std_logic;
      wb_ack_o                : out std_logic;
      uart_sr_tx_busy_i       : in  std_logic;
      uart_sr_rx_rdy_i        : in  std_logic;
      uart_bcr_o              : out std_logic_vector(31 downto 0);
      uart_tdr_tx_data_o      : out std_logic_vector(7 downto 0);
      uart_tdr_tx_data_i      : in  std_logic_vector(7 downto 0);
      uart_tdr_tx_data_load_o : out std_logic;
      uart_rdr_rx_data_i      : in  std_logic_vector(7 downto 0);
      rdr_rack_o              : out std_logic;
      uart_debug_wr_req_i     : in  std_logic;
      uart_debug_wr_full_o    : out std_logic;
      uart_debug_wr_empty_o   : out std_logic;
      uart_debug_wr_usedw_o   : out std_logic_vector(7 downto 0);
      uart_debug_tx_i         : in  std_logic_vector(7 downto 0);
      uart_debug_dupa_i       : in  std_logic_vector(31 downto 0));
  end component;
  
 
  signal tx_data      : std_logic_vector(7 downto 0);
  signal tx_data_load : std_logic;
  signal tdr_load : std_logic;
  signal fifo_full : std_logic;

begin

  tx_data_load <= (not fifo_full) and tdr_load;
  
  WB_SLAVE: wb_virtual_uart_slave
    port map(
      rst_n_i           => rst_n_i,
      wb_clk_i          => clk_sys_i,
      wb_addr_i         => wb_addr_i,
      wb_data_i         => wb_data_i,
      wb_data_o         => wb_data_o,
      wb_cyc_i          => wb_cyc_i,
      wb_sel_i          => wb_sel_i,
      wb_stb_i          => wb_stb_i,
      wb_we_i           => wb_we_i,
      wb_ack_o          => wb_ack_o,
      uart_sr_tx_busy_i => '0',
      uart_sr_rx_rdy_i  => '0',
      uart_bcr_o        => open,
      uart_tdr_tx_data_o  => tx_data,
      uart_tdr_tx_data_i  => x"00",
      uart_tdr_tx_data_load_o => tdr_load,
      uart_rdr_rx_data_i      => x"00",
      rdr_rack_o              => open,
  -- FIFO write request
      uart_debug_wr_req_i     => tx_data_load,
  -- FIFO full flag
      uart_debug_wr_full_o    => fifo_full,
  -- FIFO empty flag
      uart_debug_wr_empty_o   => open,
  -- FIFO number of used words
      uart_debug_wr_usedw_o   => open,
      uart_debug_tx_i         => tx_data,
      uart_debug_dupa_i => x"00000000"
    );


end struct;
