library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.axi4_pkg.all;

entity axi_gpio_expander is
  generic (
    g_num : integer :=8);
  port (
    clk_i   : in  std_logic;
    rst_n_i : in  std_logic;
    error_o : out std_logic;

    gpio_out : in  std_logic_vector(g_num-1 downto 0);
    gpio_oe  : in  std_logic_vector(g_num-1 downto 0);
    gpio_dir : in  std_logic_vector(g_num-1 downto 0); -- '1' for output
    gpio_in  : out std_logic_vector(g_num-1 downto 0);

    ARVALID  : out std_logic;
    AWVALID  : out std_logic;
    BREADY   : out std_logic;
    RREADY   : out std_logic;
    WVALID   : out std_logic;
    ARADDR   : out std_logic_vector (31 downto 0);
    AWADDR   : out std_logic_vector (31 downto 0);
    WDATA    : out std_logic_vector (31 downto 0);
    WSTRB    : out std_logic_vector (3 downto 0);
    ARREADY  : in std_logic;
    AWREADY  : in std_logic;
    BVALID   : in std_logic;
    RLAST    : in std_logic;
    RVALID   : in std_logic;
    WREADY   : in std_logic;
    BRESP    : in std_logic_vector (1 downto 0);
    RRESP    : in std_logic_vector (1 downto 0);
    RDATA    : in std_logic_vector (31 downto 0));
end axi_gpio_expander;

architecture behav of axi_gpio_expander is

  constant c_GPIO_BASE  : unsigned := x"00000000";
  constant c_GPIO_R_TRI : unsigned := x"00000004";

  constant c_GPIOPS_BASE  : unsigned := x"e000a000";

  constant c_GPIOPS_R_OUT_B0 : std_logic_vector := x"e000a040";
  constant c_GPIOPS_R_IN_B0  : std_logic_vector := x"e000a060";
  constant c_GPIOPS_R_DIR_B0 : std_logic_vector := x"e000a204";
  constant c_GPIOPS_R_OEN_B0 : std_logic_vector := x"e000a208";

  constant c_GPIOPS_R_OUT_B1 : std_logic_vector := x"e000a044";
  constant c_GPIOPS_R_IN_B1  : std_logic_vector := x"e000a064";
  constant c_GPIOPS_R_DIR_B1 : std_logic_vector := x"e000a244";
  constant c_GPIOPS_R_OEN_B1 : std_logic_vector := x"e000a248";

  constant c_GPIOPS_BANK0 : integer := 32;
  constant c_GPIOPS_BANK1 : integer := 54;
  constant c_MIO7_ON  : unsigned := x"ff7f0080";
  constant c_MIO7_OFF : unsigned := x"ff7f0000";

  -------------------------------------------
  function pad_data (data : std_logic_vector; pad : std_logic) return std_logic_vector is
    variable tmp : std_logic_vector(31 downto 0);
  begin
    if g_num = 32 then
      return data;
    elsif g_num < 32 then
      tmp(31 downto g_num)  := (others=>pad);
      tmp(g_num-1 downto 0) := data;
    end if;
    return tmp;
  end function;
  -------------------------------------------
  function f_split_bank (gpio_dat : std_logic_vector; bank : integer) return std_logic_vector is
  begin
    if (bank = 0 and g_num < 32) then
      return pad_data(gpio_dat, '0');
    elsif (bank = 0) then
      return gpio_dat(c_GPIOPS_BANK0-1 downto 0);
    else -- bank1
      return pad_data(gpio_dat(c_GPIOPS_BANK1-1 downto c_GPIOPS_BANK0), '0');
    end if;
  end function;
  -------------------------------------------

  --type t_state is (IDLE, READ_IN, WRITE_DIR, WRITE_TRI, WRITE_OUT);
  type t_state is (IDLE, INIT_READ, READ, INIT_WRITE_DIR, WRITE_DIR, INIT_WRITE_TRI, WRITE_TRI, INIT_WRITE_OUT, WRITE_OUT);
  signal state : t_state;

  signal gpio_oe_n : std_logic_vector(g_num-1 downto 0);
  signal gpio_oe_prev  : std_logic_vector(g_num-1 downto 0);
  signal gpio_dir_prev : std_logic_vector(g_num-1 downto 0);
  signal gpio_out_prev : std_logic_vector(g_num-1 downto 0);
  signal gpio_oe_changed  : std_logic;
  signal gpio_dir_changed : std_logic;
  signal gpio_out_changed : std_logic;
  signal refresh_all : std_logic;

begin

  gpio_oe_n <= not gpio_oe;
  gpio_oe_changed  <= or_reduce(gpio_oe  xor gpio_oe_prev);
  gpio_dir_changed <= or_reduce(gpio_dir xor gpio_dir_prev);
  gpio_out_changed <= or_reduce(gpio_out xor gpio_out_prev);

  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        gpio_in <= (others=>'0');
        ARVALID <= '0';
        ARADDR  <= (others=>'X');
        RREADY  <= '0';
        AWVALID <= '0';
        AWADDR  <= (others=>'X');
        WVALID  <= '0';
        WDATA   <= (others=>'X');
        WSTRB   <= "0000";
        BREADY  <= '0';
        error_o <= '0';
        gpio_oe_prev  <= (others=>'0');
        gpio_dir_prev <= (others=>'0');
        gpio_out_prev <= (others=>'0');
        refresh_all <= '1';

        state <= IDLE;
      else
        case state is
          -------------------------------------------
          when IDLE =>
            ARVALID <= '0';
            ARADDR  <= (others=>'X');
            RREADY  <= '0';

            AWVALID <= '0';
            AWADDR  <= (others=>'X');
            WVALID  <= '0';
            WDATA   <= (others=>'X');
            WSTRB   <= "0000";
            BREADY  <= '0';

            -- decide where to go depending what has changed
            if (refresh_all = '1') then
              state <= INIT_WRITE_DIR;
            elsif (gpio_dir_changed = '1') then
              state <= INIT_WRITE_DIR;
            elsif (gpio_oe_changed = '1') then
              state <= INIT_WRITE_TRI;
            elsif (gpio_out_changed = '1') then
              state <= INIT_WRITE_OUT;
            else
              state <= INIT_READ;
            end if;

          -------------------------------------------
          when INIT_WRITE_DIR =>
            -- AXI: set address for write cycle
            AWVALID <= '1';
            AWADDR  <= c_GPIOPS_R_DIR_B0;
            -- AXI: set data for write cycle
            WVALID  <= '1';
            WDATA   <= f_split_bank(gpio_dir, 0);
            WSTRB   <= "1111";
            BREADY  <= '0';
            gpio_dir_prev <= gpio_dir;

            state <= WRITE_DIR;

          -------------------------------------------
          when WRITE_DIR =>
            BREADY <= '1';

            if (AWREADY = '1') then
              AWVALID <= '0';
            end if;
            if (WREADY = '1') then
              WVALID <= '0';
            end if;

            if (BVALID = '1' and BRESP = c_AXI4_RESP_OKAY) then
              -- write accepted, let's proceed
              BREADY <= '0';
              state <= INIT_WRITE_TRI;
            elsif (BVALID = '1') then
              -- error on write, let's retry
              BREADY <= '0';
              error_o <= '1';
              state   <= IDLE;
            end if;

          -------------------------------------------
          when INIT_WRITE_TRI =>
            -- AXI: set address for write cycle
            AWVALID <= '1';
            AWADDR  <= c_GPIOPS_R_OEN_B0;
            -- AXI: set data for write cycle
            WVALID  <= '1';
            WDATA   <= f_split_bank(gpio_oe, 0);
            WSTRB   <= "1111";
            BREADY  <= '0';
            gpio_oe_prev <= gpio_oe;

            state <= WRITE_TRI;

          -------------------------------------------
          when WRITE_TRI =>
            BREADY <= '1';

            if (AWREADY = '1') then
              AWVALID <= '0';
            end if;
            if (WREADY = '1') then
              WVALID <= '0';
            end if;

            if (BVALID = '1' and BRESP = c_AXI4_RESP_OKAY and (refresh_all = '1' or gpio_out_changed = '1')) then
              -- write accepted, let's proceed
              BREADY <= '0';
              state <= INIT_WRITE_OUT;
            elsif (BVALID = '1' and BRESP = c_AXI4_RESP_OKAY) then 
              -- nothing to update in GPIO_OUT, skip to GPIO reading
              BREADY <= '0';
              state <= INIT_READ;
            elsif (BVALID = '1') then
              -- error on write, let's retry
              BREADY <= '0';
              error_o <= '1';
              state   <= IDLE;
            end if;

          -------------------------------------------
          when INIT_WRITE_OUT =>
            -- AXI: set address for write cycle
            AWVALID <= '1';
            AWADDR  <= c_GPIOPS_R_OUT_B0;
            -- AXI: set data for write cycle
            WVALID  <= '1';
            WDATA   <= f_split_bank(gpio_out, 0);
            WSTRB   <= "1111";
            BREADY  <= '0';
            gpio_out_prev <= gpio_out;

            state <= WRITE_OUT;

          -------------------------------------------
          when WRITE_OUT =>
            BREADY <= '1';

            if (AWREADY = '1') then
              AWVALID <= '0';
            end if;
            if (WREADY = '1') then
              WVALID <= '0';
            end if;

            if (BVALID = '1' and BRESP = c_AXI4_RESP_OKAY) then
              -- write accepted, let's proceed
              BREADY <= '0';
              state <= INIT_READ;
            elsif (BVALID = '1') then
              -- error on write, let's retry
              BREADY <= '0';
              error_o <= '1';
              state   <= IDLE;
            end if;

          -------------------------------------------
          when INIT_READ =>
            AWVALID <= '0';
            AWADDR  <= (others=>'X');
            WVALID  <= '0';
            WDATA   <= (others=>'X');
            WSTRB   <= "0000";
            BREADY  <= '0';

            -- AXI: set address for read cycle
            ARVALID <= '1';
            ARADDR  <= c_GPIOPS_R_IN_B0;
            -- AXI: ready to accept data from slave
            RREADY  <= '1';

            state <= READ;

          -------------------------------------------
          when READ =>
            RREADY  <= '1';

            if (ARREADY = '1') then
              -- AXI: address received by slave
              ARVALID <= '0';
            end if;
            if (RVALID = '1' and RRESP = c_AXI4_RESP_OKAY) then
              RREADY <= '0';
              -- received valid data, pass it to I/Os
              gpio_in <= RDATA(g_num-1 downto 0);
              error_o <= '0';
              refresh_all <= '0';
              state   <= IDLE;
            elsif (RVALID = '1') then
              RREADY <= '0';
              -- error on read
              error_o <= '1';
              state   <= IDLE;
            end if;

        end case;
      end if;
    end if;
  end process;

end behav;
