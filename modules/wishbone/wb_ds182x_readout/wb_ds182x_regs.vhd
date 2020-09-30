-- Do not edit.  Generated on Wed Sep 30 11:24:49 2020 by tgingold
-- With Cheby 1.4.dev0 and these options:
--  --gen-hdl wb_ds182x_regs.vhd -i wb_ds182x_regs.cheby


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wishbone_pkg.all;

entity wb_ds182x_regs is
  port (
    rst_n_i              : in    std_logic;
    clk_i                : in    std_logic;
    wb_i                 : in    t_wishbone_slave_in;
    wb_o                 : out   t_wishbone_slave_out;

    -- unique id
    id_i                 : in    std_logic_vector(63 downto 0);

    -- temperature
    -- temperature value
    temperature_data_i   : in    std_logic_vector(15 downto 0);
    -- temperature is not valid
    temperature_error_i  : in    std_logic;

    -- status
    -- Set when unique id was read
    status_id_read_i     : in    std_logic;
    -- Set when unique id was read, persist after reset
    status_id_ok_i       : in    std_logic;
    -- Set when the temperature register is correctly read
    status_temp_ok_i     : in    std_logic
  );
end wb_ds182x_regs;

architecture syn of wb_ds182x_regs is
  signal adr_int                        : std_logic_vector(3 downto 2);
  signal rd_req_int                     : std_logic;
  signal wr_req_int                     : std_logic;
  signal rd_ack_int                     : std_logic;
  signal wr_ack_int                     : std_logic;
  signal wb_en                          : std_logic;
  signal ack_int                        : std_logic;
  signal wb_rip                         : std_logic;
  signal wb_wip                         : std_logic;
  signal rd_ack_d0                      : std_logic;
  signal rd_dat_d0                      : std_logic_vector(31 downto 0);
  signal wr_req_d0                      : std_logic;
  signal wr_adr_d0                      : std_logic_vector(3 downto 2);
  signal wr_dat_d0                      : std_logic_vector(31 downto 0);
  signal wr_sel_d0                      : std_logic_vector(3 downto 0);
begin

  -- WB decode signals
  adr_int <= wb_i.adr(3 downto 2);
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

  -- Register id

  -- Register temperature

  -- Register status

  -- Process for write requests.
  process (wr_adr_d0, wr_req_d0) begin
    case wr_adr_d0(3 downto 3) is
    when "0" =>
      case wr_adr_d0(2 downto 2) is
      when "0" =>
        -- Reg id
        wr_ack_int <= wr_req_d0;
      when "1" =>
        -- Reg id
        wr_ack_int <= wr_req_d0;
      when others =>
        wr_ack_int <= wr_req_d0;
      end case;
    when "1" =>
      case wr_adr_d0(2 downto 2) is
      when "0" =>
        -- Reg temperature
        wr_ack_int <= wr_req_d0;
      when "1" =>
        -- Reg status
        wr_ack_int <= wr_req_d0;
      when others =>
        wr_ack_int <= wr_req_d0;
      end case;
    when others =>
      wr_ack_int <= wr_req_d0;
    end case;
  end process;

  -- Process for read requests.
  process (adr_int, rd_req_int, id_i, temperature_data_i, temperature_error_i, status_id_read_i, status_id_ok_i, status_temp_ok_i) begin
    -- By default ack read requests
    rd_dat_d0 <= (others => 'X');
    case adr_int(3 downto 3) is
    when "0" =>
      case adr_int(2 downto 2) is
      when "0" =>
        -- Reg id
        rd_ack_d0 <= rd_req_int;
        rd_dat_d0 <= id_i(63 downto 32);
      when "1" =>
        -- Reg id
        rd_ack_d0 <= rd_req_int;
        rd_dat_d0 <= id_i(31 downto 0);
      when others =>
        rd_ack_d0 <= rd_req_int;
      end case;
    when "1" =>
      case adr_int(2 downto 2) is
      when "0" =>
        -- Reg temperature
        rd_ack_d0 <= rd_req_int;
        rd_dat_d0(15 downto 0) <= temperature_data_i;
        rd_dat_d0(30 downto 16) <= (others => '0');
        rd_dat_d0(31) <= temperature_error_i;
      when "1" =>
        -- Reg status
        rd_ack_d0 <= rd_req_int;
        rd_dat_d0(0) <= status_id_read_i;
        rd_dat_d0(1) <= status_id_ok_i;
        rd_dat_d0(2) <= status_temp_ok_i;
        rd_dat_d0(31 downto 3) <= (others => '0');
      when others =>
        rd_ack_d0 <= rd_req_int;
      end case;
    when others =>
      rd_ack_d0 <= rd_req_int;
    end case;
  end process;
end syn;
