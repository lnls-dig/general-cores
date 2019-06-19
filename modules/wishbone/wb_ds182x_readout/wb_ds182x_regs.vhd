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
    temperature_data_i   : in    std_logic_vector(15 downto 0);

    -- Set when unique id was read
    status_id_read_i     : in    std_logic;

    -- Set when unique id was read, persist after reset
    status_id_ok_i       : in    std_logic
  );
end wb_ds182x_regs;

architecture syn of wb_ds182x_regs is
  signal rd_int                         : std_logic;
  signal wr_int                         : std_logic;
  signal rd_ack_int                     : std_logic;
  signal wr_ack_int                     : std_logic;
  signal wb_en                          : std_logic;
  signal ack_int                        : std_logic;
  signal wb_rip                         : std_logic;
  signal wb_wip                         : std_logic;
  signal reg_rdat_int                   : std_logic_vector(31 downto 0);
  signal rd_ack1_int                    : std_logic;
begin

  -- WB decode signals
  wb_en <= wb_i.cyc and wb_i.stb;

  process (clk_i, rst_n_i) begin
    if rst_n_i = '0' then 
      wb_rip <= '0';
    elsif rising_edge(clk_i) then
      wb_rip <= (wb_rip or (wb_en and not wb_i.we)) and not rd_ack_int;
    end if;
  end process;
  rd_int <= (wb_en and not wb_i.we) and not wb_rip;

  process (clk_i, rst_n_i) begin
    if rst_n_i = '0' then 
      wb_wip <= '0';
    elsif rising_edge(clk_i) then
      wb_wip <= (wb_wip or (wb_en and wb_i.we)) and not wr_ack_int;
    end if;
  end process;
  wr_int <= (wb_en and wb_i.we) and not wb_wip;

  ack_int <= rd_ack_int or wr_ack_int;
  wb_o.ack <= ack_int;
  wb_o.stall <= not ack_int and wb_en;
  wb_o.rty <= '0';
  wb_o.err <= '0';

  -- Assign outputs

  -- Process for write requests.
  process (clk_i, rst_n_i) begin
    if rst_n_i = '0' then 
      wr_ack_int <= '0';
    elsif rising_edge(clk_i) then
      wr_ack_int <= '0';
      case wb_i.adr(3 downto 3) is
      when "0" => 
        case wb_i.adr(2 downto 2) is
        when "0" => 
          -- Register id
        when "1" => 
          -- Register id
        when others =>
          wr_ack_int <= wr_int;
        end case;
      when "1" => 
        case wb_i.adr(2 downto 2) is
        when "0" => 
          -- Register temperature
        when "1" => 
          -- Register status
        when others =>
          wr_ack_int <= wr_int;
        end case;
      when others =>
        wr_ack_int <= wr_int;
      end case;
    end if;
  end process;

  -- Process for registers read.
  process (clk_i, rst_n_i) begin
    if rst_n_i = '0' then 
      rd_ack1_int <= '0';
      reg_rdat_int <= (others => 'X');
    elsif rising_edge(clk_i) then
      reg_rdat_int <= (others => '0');
      case wb_i.adr(3 downto 3) is
      when "0" => 
        case wb_i.adr(2 downto 2) is
        when "0" => 
          -- id
          reg_rdat_int <= id_i(63 downto 32);
          rd_ack1_int <= rd_int;
        when "1" => 
          -- id
          reg_rdat_int <= id_i(31 downto 0);
          rd_ack1_int <= rd_int;
        when others =>
          rd_ack1_int <= rd_int;
        end case;
      when "1" => 
        case wb_i.adr(2 downto 2) is
        when "0" => 
          -- temperature
          reg_rdat_int(15 downto 0) <= temperature_data_i;
          rd_ack1_int <= rd_int;
        when "1" => 
          -- status
          reg_rdat_int(0) <= status_id_read_i;
          reg_rdat_int(1) <= status_id_ok_i;
          rd_ack1_int <= rd_int;
        when others =>
          rd_ack1_int <= rd_int;
        end case;
      when others =>
        rd_ack1_int <= rd_int;
      end case;
    end if;
  end process;

  -- Process for read requests.
  process (wb_i.adr, reg_rdat_int, rd_ack1_int, rd_int) begin
    -- By default ack read requests
    wb_o.dat <= (others => '0');
    case wb_i.adr(3 downto 3) is
    when "0" => 
      case wb_i.adr(2 downto 2) is
      when "0" => 
        -- id
        wb_o.dat <= reg_rdat_int;
        rd_ack_int <= rd_ack1_int;
      when "1" => 
        -- id
        wb_o.dat <= reg_rdat_int;
        rd_ack_int <= rd_ack1_int;
      when others =>
        rd_ack_int <= rd_int;
      end case;
    when "1" => 
      case wb_i.adr(2 downto 2) is
      when "0" => 
        -- temperature
        wb_o.dat <= reg_rdat_int;
        rd_ack_int <= rd_ack1_int;
      when "1" => 
        -- status
        wb_o.dat <= reg_rdat_int;
        rd_ack_int <= rd_ack1_int;
      when others =>
        rd_ack_int <= rd_int;
      end case;
    when others =>
      rd_ack_int <= rd_int;
    end case;
  end process;
end syn;
