-------------------------------------------------------------------------------
-- Title      : AXI PS_GPIO Expander for Zynq-7
-- Project    : General Cores
-------------------------------------------------------------------------------
-- File       : axi_gpio_expander.vhd
-- Author     : Grzegorz Daniluk <grzegorz.daniluk@cern.ch>
-- Company    : CERN
-- Platform   : FPGA-generics
-- Standard   : VHDL '93
-------------------------------------------------------------------------------
-- Description:
--
-- This module can be used with Zynq-7 platforms to access PS GPIOs (MIO) from
-- PL. It implements AXI-Lite Master interface that controlls (through internal
-- PS AXI interconnect) PS GPIO AXI slave to ensure transparent I/O access for PL.
-- The module should be connected to AXI Slave port of PS (S_AXI_GP*).
-- The module requires PS to be initialized, i.e. ps7_init() and
-- ps7_post_config() have to be executed either by the FSBL or custom
-- bare metal software.
--
-------------------------------------------------------------------------------
-- Copyright (c) 2019 CERN
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
use ieee.std_logic_misc.all;

use work.axi4_pkg.all;

entity axi_gpio_expander is
  generic (
    g_num : integer := 8);
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

  -------------------------------------------
  -- Zynq-7 PS GPIO parameters
  -------------------------------------------
  constant c_GPIOPS_BASE  : unsigned := x"e000a000";

  -- GPIO PS control registers
  type t_gpiops_adr is array (natural range <>) of std_logic_vector(31 downto 0);
  constant c_GPIOPS_R_OUT : t_gpiops_adr(0 to 1) := (x"e000a040", x"e000a044");
  constant c_GPIOPS_R_IN  : t_gpiops_adr(0 to 1) := (x"e000a060", x"e000a064");
  constant c_GPIOPS_R_DIR : t_gpiops_adr(0 to 1) := (x"e000a204", x"e000a244");
  constant c_GPIOPS_R_OEN : t_gpiops_adr(0 to 1) := (x"e000a208", x"e000a248");

  constant c_GPIOPS_BANK0 : integer := 32;
  constant c_GPIOPS_BANK1 : integer := 54;
  -------------------------------------------

  -------------------------------------------
  function pad_data (data : std_logic_vector; pad : std_logic)
    return std_logic_vector is
    variable tmp : std_logic_vector(31 downto 0);
  begin
    if data'length = 32 then
      return data;
    elsif data'length < 32 then
      tmp(31 downto data'length)  := (others=>pad);
      tmp(data'length-1 downto 0) := data;
    end if;
    return tmp;
  end function;
  -------------------------------------------
  function f_split_bank (gpio_dat : std_logic_vector; bank : integer)
    return std_logic_vector is
  begin
    if (bank = 0 and g_num < 32) then
      return pad_data(gpio_dat, '0');
    elsif (bank = 1 and g_num <= 32) then
      return x"00000000"; -- return empty word if there is no Bank1
    elsif (bank = 0 and g_num >= 32) then
      return gpio_dat(c_GPIOPS_BANK0-1 downto 0);
    elsif (bank = 1 and g_num > 32) then
      return pad_data(gpio_dat(g_num-1 downto c_GPIOPS_BANK0), '0');
    end if;
  end function;
  -------------------------------------------
  function f_update_prev (orig : std_logic_vector; new_val : std_logic_vector; bank : integer)
    return std_logic_vector is
    variable tmp : std_logic_vector(g_num-1 downto 0);
  begin
    tmp := orig;
    if (bank = 0 and g_num <= c_GPIOPS_BANK0) then
      -- there is no Bank1, everythin in _prev needs to be updated
      tmp := new_val(g_num-1 downto 0);
    elsif (bank = 0 and g_num > c_GPIOPS_BANK0) then
      tmp(c_GPIOPS_BANK0-1 downto 0) := new_val(c_GPIOPS_BANK0-1 downto 0);
    elsif (bank = 1 and g_num > c_GPIOPS_BANK0) then
      tmp(g_num-1 downto c_GPIOPS_BANK0) := new_val(g_num-1 downto c_GPIOPS_BANK0);
    end if;
    return tmp;
  end function;
  -------------------------------------------
  function f_update_gpio_in (orig : std_logic_vector; rd_data : std_logic_vector; bank : integer)
    return std_logic_vector is
    variable tmp : std_logic_vector(g_num-1 downto 0);
  begin
    tmp := orig;
    if (bank = 0 and g_num >= c_GPIOPS_BANK0) then
      tmp(c_GPIOPS_BANK0-1 downto 0) := rd_data;
    elsif (bank = 0 and g_num < c_GPIOPS_BANK0) then
      tmp := rd_data(g_num-1 downto 0);
    else
      tmp(g_num-1 downto c_GPIOPS_BANK0) := rd_data(g_num-c_GPIOPS_BANK0-1 downto 0);
    end if;
    return tmp;
  end function;
  -------------------------------------------

  type t_state is (IDLE, INIT_READ, READ, INIT_WRITE_DIR, WRITE_DIR,
    INIT_WRITE_TRI, WRITE_TRI, INIT_WRITE_OUT, WRITE_OUT, CHANGE_BANK);
  signal state : t_state;

  signal gpio_in_reg      : std_logic_vector(g_num-1 downto 0);
  signal gpio_oe_prev     : std_logic_vector(g_num-1 downto 0);
  signal gpio_dir_prev    : std_logic_vector(g_num-1 downto 0);
  signal gpio_out_prev    : std_logic_vector(g_num-1 downto 0);
  signal gpio_oe_changed  : std_logic_vector(1 downto 0);
  signal gpio_dir_changed : std_logic_vector(1 downto 0);
  signal gpio_out_changed : std_logic_vector(1 downto 0);
  signal refresh_all      : std_logic;
  signal current_bank     : integer range 0 to 1;

begin

  gpio_oe_changed (0) <= or_reduce(f_split_bank(gpio_oe,  0) xor f_split_bank(gpio_oe_prev,  0));
  gpio_dir_changed(0) <= or_reduce(f_split_bank(gpio_dir, 0) xor f_split_bank(gpio_dir_prev, 0));
  gpio_out_changed(0) <= or_reduce(f_split_bank(gpio_out, 0) xor f_split_bank(gpio_out_prev, 0));
  gpio_oe_changed (1) <= or_reduce(f_split_bank(gpio_oe,  1) xor f_split_bank(gpio_oe_prev,  1));
  gpio_dir_changed(1) <= or_reduce(f_split_bank(gpio_dir, 1) xor f_split_bank(gpio_dir_prev, 1));
  gpio_out_changed(1) <= or_reduce(f_split_bank(gpio_out, 1) xor f_split_bank(gpio_out_prev, 1));

  gpio_in <= gpio_in_reg;

  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
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
        gpio_in_reg   <= (others=>'0');
        gpio_oe_prev  <= (others=>'0');
        gpio_dir_prev <= (others=>'0');
        gpio_out_prev <= (others=>'0');
        refresh_all   <= '1';
        current_bank  <= 0;

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
            elsif (gpio_dir_changed(current_bank) = '1') then
              state <= INIT_WRITE_DIR;
            elsif (gpio_oe_changed(current_bank)  = '1') then
              state <= INIT_WRITE_TRI;
            elsif (gpio_out_changed(current_bank) = '1') then
              state <= INIT_WRITE_OUT;
            else
              state <= INIT_READ;
            end if;

          -------------------------------------------
          -- set the direction of I/Os
          -------------------------------------------
          when INIT_WRITE_DIR =>
            -- AXI: set address for write cycle
            AWVALID <= '1';
            AWADDR  <= c_GPIOPS_R_DIR(current_bank);
            -- AXI: set data for write cycle
            WVALID  <= '1';
            WDATA   <= f_split_bank(gpio_dir, current_bank);
            WSTRB   <= "1111";
            BREADY  <= '0';
            gpio_dir_prev <= f_update_prev(gpio_dir_prev, gpio_dir, current_bank);

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
              refresh_all <= '1';
              error_o <= '1';
              state   <= IDLE;
            end if;

          -------------------------------------------
          -- set Output Enable (Tristate Buffs) for I/Os
          -------------------------------------------
          when INIT_WRITE_TRI =>
            -- AXI: set address for write cycle
            AWVALID <= '1';
            AWADDR  <= c_GPIOPS_R_OEN(current_bank);
            -- AXI: set data for write cycle
            WVALID  <= '1';
            WDATA   <= f_split_bank(gpio_oe, current_bank);
            WSTRB   <= "1111";
            BREADY  <= '0';
            gpio_oe_prev <= f_update_prev(gpio_oe_prev, gpio_oe, current_bank);

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

            if (BVALID = '1' and BRESP = c_AXI4_RESP_OKAY and (refresh_all = '1' or gpio_out_changed(current_bank) = '1')) then
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
              refresh_all <= '1';
              error_o <= '1';
              state   <= IDLE;
            end if;

          -------------------------------------------
          -- set state of outputs
          -------------------------------------------
          when INIT_WRITE_OUT =>
            -- AXI: set address for write cycle
            AWVALID <= '1';
            AWADDR  <= c_GPIOPS_R_OUT(current_bank);
            -- AXI: set data for write cycle
            WVALID  <= '1';
            WDATA   <= f_split_bank(gpio_out, current_bank);
            WSTRB   <= "1111";
            BREADY  <= '0';
            gpio_out_prev <= f_update_prev(gpio_out_prev, gpio_out, current_bank);

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
              refresh_all <= '1';
              error_o <= '1';
              state   <= IDLE;
            end if;

          -------------------------------------------
          -- get state of inputs
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
            ARADDR  <= c_GPIOPS_R_IN(current_bank);
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
              gpio_in_reg <= f_update_gpio_in(gpio_in_reg, RDATA, current_bank);
              error_o <= '0';
              state   <= CHANGE_BANK;
            elsif (RVALID = '1') then
              RREADY <= '0';
              -- error on read
              error_o <= '1';
              state   <= IDLE;
            end if;

          -------------------------------------------
          -- change I/O bank if needed
          -------------------------------------------
          when CHANGE_BANK =>
            ARVALID <= '0';
            ARADDR  <= (others=>'X');
            RREADY  <= '0';
            AWVALID <= '0';
            AWADDR  <= (others=>'X');
            WVALID  <= '0';
            WDATA   <= (others=>'X');
            WSTRB   <= "0000";
            BREADY  <= '0';
            if (current_bank = 1) then
              refresh_all  <= '0';
              current_bank <= 0;
            elsif (g_num > c_GPIOPS_BANK0) then
              -- Don't touch refresh_all flag yet, if it's the first cycle, full
              -- config setting has to be done for both banks.
              current_bank <= 1;
            else -- current_bank = 0 and g_num =< c_GPIOPS_BANK0
              -- Only Bank0 is used, reset refresh_all flag, Bank0 registers are
              -- all set here.
              refresh_all <= '0';
            end if;
            state <= IDLE;

        end case;
      end if;
    end if;
  end process;

end behav;
