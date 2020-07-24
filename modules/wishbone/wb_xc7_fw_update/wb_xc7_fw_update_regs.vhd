-- Do not edit.  Generated on Tue May 19 11:16:59 2020 by tgingold
-- With Cheby 1.4.dev0 and these options:
--  -i wb_xc7_fw_update_regs.cheby --gen-hdl wb_xc7_fw_update_regs.vhd


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wishbone_pkg.all;

entity wb_xc7_fw_update_regs is
  port (
    rst_n_i              : in    std_logic;
    clk_i                : in    std_logic;
    wb_i                 : in    t_wishbone_slave_in;
    wb_o                 : out   t_wishbone_slave_out;

    -- Flash Access Register
    -- SPI Data
    far_data_i           : in    std_logic_vector(7 downto 0);
    far_data_o           : out   std_logic_vector(7 downto 0);
    -- SPI Start Transfer
    far_xfer_i           : in    std_logic;
    far_xfer_o           : out   std_logic;
    -- SPI Ready
    far_ready_i          : in    std_logic;
    far_ready_o          : out   std_logic;
    -- SPI Chip Select
    far_cs_i             : in    std_logic;
    far_cs_o             : out   std_logic;
    far_wr_o             : out   std_logic
  );
end wb_xc7_fw_update_regs;

architecture syn of wb_xc7_fw_update_regs is
  signal rd_req_int                     : std_logic;
  signal wr_req_int                     : std_logic;
  signal rd_ack_int                     : std_logic;
  signal wr_ack_int                     : std_logic;
  signal wb_en                          : std_logic;
  signal ack_int                        : std_logic;
  signal wb_rip                         : std_logic;
  signal wb_wip                         : std_logic;
  signal far_wreq                       : std_logic;
  signal rd_ack_d0                      : std_logic;
  signal rd_dat_d0                      : std_logic_vector(31 downto 0);
  signal wr_req_d0                      : std_logic;
  signal wr_dat_d0                      : std_logic_vector(31 downto 0);
  signal wr_sel_d0                      : std_logic_vector(3 downto 0);
begin

  -- WB decode signals
  wb_en <= wb_i.cyc and wb_i.stb;

  process (clk_i) begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        wb_rip <= '0';
      else
        wb_rip <= (wb_rip or (wb_en and not wb_i.we)) and not rd_ack_int;
      end if;
    end if;
  end process;
  rd_req_int <= (wb_en and not wb_i.we) and not wb_rip;

  process (clk_i) begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        wb_wip <= '0';
      else
        wb_wip <= (wb_wip or (wb_en and wb_i.we)) and not wr_ack_int;
      end if;
    end if;
  end process;
  wr_req_int <= (wb_en and wb_i.we) and not wb_wip;

  ack_int <= rd_ack_int or wr_ack_int;
  wb_o.ack <= ack_int;
  wb_o.stall <= not ack_int and wb_en;
  wb_o.rty <= '0';
  wb_o.err <= '0';

  -- pipelining for wr-in+rd-out
  process (clk_i) begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        rd_ack_int <= '0';
        wr_req_d0 <= '0';
      else
        rd_ack_int <= rd_ack_d0;
        wb_o.dat <= rd_dat_d0;
        wr_req_d0 <= wr_req_int;
        wr_dat_d0 <= wb_i.dat;
        wr_sel_d0 <= wb_i.sel;
      end if;
    end if;
  end process;

  -- Register far
  far_data_o <= wr_dat_d0(7 downto 0);
  far_xfer_o <= wr_dat_d0(8);
  far_ready_o <= wr_dat_d0(9);
  far_cs_o <= wr_dat_d0(10);
  far_wr_o <= far_wreq;

  -- Process for write requests.
  process (wr_req_d0) begin
    far_wreq <= '0';
    -- Reg far
    far_wreq <= wr_req_d0;
    wr_ack_int <= wr_req_d0;
  end process;

  -- Process for read requests.
  process (rd_req_int, far_data_i, far_xfer_i, far_ready_i, far_cs_i) begin
    -- By default ack read requests
    rd_dat_d0 <= (others => 'X');
    -- Reg far
    rd_ack_d0 <= rd_req_int;
    rd_dat_d0(7 downto 0) <= far_data_i;
    rd_dat_d0(8) <= far_xfer_i;
    rd_dat_d0(9) <= far_ready_i;
    rd_dat_d0(10) <= far_cs_i;
    rd_dat_d0(31 downto 11) <= (others => '0');
  end process;
end syn;
