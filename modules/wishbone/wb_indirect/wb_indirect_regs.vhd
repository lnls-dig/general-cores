-- Do not edit.  Generated on Mon Apr 20 10:08:30 2020 by gingold
-- With Cheby 1.4.dev0 and these options:
--  -i wb_indirect_regs.cheby --gen-hdl=wb_indirect_regs.vhd


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wishbone_pkg.all;

entity wb_indirect_regs is
  port (
    rst_n_i              : in    std_logic;
    clk_i                : in    std_logic;
    wb_i                 : in    t_wishbone_slave_in;
    wb_o                 : out   t_wishbone_slave_out;

    -- address to use on the wishbone bus
    addr_i               : in    std_logic_vector(31 downto 0);
    addr_o               : out   std_logic_vector(31 downto 0);
    addr_wr_o            : out   std_logic;

    -- data word to be read or written
    data_i               : in    std_logic_vector(31 downto 0);
    data_o               : out   std_logic_vector(31 downto 0);
    data_wr_o            : out   std_logic;
    data_rd_o            : out   std_logic;
    data_wack_i          : in    std_logic;
    data_rack_i          : in    std_logic
  );
end wb_indirect_regs;

architecture syn of wb_indirect_regs is
  signal adr_int                        : std_logic_vector(2 downto 2);
  signal rd_req_int                     : std_logic;
  signal wr_req_int                     : std_logic;
  signal rd_ack_int                     : std_logic;
  signal wr_ack_int                     : std_logic;
  signal wb_en                          : std_logic;
  signal ack_int                        : std_logic;
  signal wb_rip                         : std_logic;
  signal wb_wip                         : std_logic;
  signal addr_wreq                      : std_logic;
  signal data_wreq                      : std_logic;
  signal rd_ack_d0                      : std_logic;
  signal rd_dat_d0                      : std_logic_vector(31 downto 0);
  signal wr_req_d0                      : std_logic;
  signal wr_adr_d0                      : std_logic_vector(2 downto 2);
  signal wr_dat_d0                      : std_logic_vector(31 downto 0);
  signal wr_sel_d0                      : std_logic_vector(3 downto 0);
begin

  -- WB decode signals
  adr_int <= wb_i.adr(2 downto 2);
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
        wr_adr_d0 <= adr_int;
        wr_dat_d0 <= wb_i.dat;
        wr_sel_d0 <= wb_i.sel;
      end if;
    end if;
  end process;

  -- Register addr
  addr_o <= wr_dat_d0;
  addr_wr_o <= addr_wreq;

  -- Register data
  data_o <= wr_dat_d0;
  data_wr_o <= data_wreq;

  -- Process for write requests.
  process (wr_adr_d0, wr_req_d0, data_wack_i) begin
    addr_wreq <= '0';
    data_wreq <= '0';
    case wr_adr_d0(2 downto 2) is
    when "0" => 
      -- Reg addr
      addr_wreq <= wr_req_d0;
      wr_ack_int <= wr_req_d0;
    when "1" => 
      -- Reg data
      data_wreq <= wr_req_d0;
      wr_ack_int <= data_wack_i;
    when others =>
      wr_ack_int <= wr_req_d0;
    end case;
  end process;

  -- Process for read requests.
  process (adr_int, rd_req_int, addr_i, data_rack_i, data_i) begin
    -- By default ack read requests
    rd_dat_d0 <= (others => 'X');
    data_rd_o <= '0';
    case adr_int(2 downto 2) is
    when "0" => 
      -- Reg addr
      rd_ack_d0 <= rd_req_int;
      rd_dat_d0 <= addr_i;
    when "1" => 
      -- Reg data
      data_rd_o <= rd_req_int;
      rd_ack_d0 <= data_rack_i;
      rd_dat_d0 <= data_i;
    when others =>
      rd_ack_d0 <= rd_req_int;
    end case;
  end process;
end syn;
