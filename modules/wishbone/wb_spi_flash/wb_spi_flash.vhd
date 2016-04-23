------------------------------------------------------------------------------
-- Title      : Wishbone memory-mapper SPI flash
-- Project    : General Cores
------------------------------------------------------------------------------
-- File       : wb_spi_flash.vhd
-- Author     : Wesley W. Terpstra
-- Company    : GSI
-- Created    : 2013-04-15
-- Last update: 2013-04-15
-- Platform   : FPGA-generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Maps an entire flash device to wishbone memory
-------------------------------------------------------------------------------
-- Copyright (c) 2013 GSI
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2013-04-15  1.0      terpstra        Created
-- 2013-08-28  2.0      terpstra        Quad-lane support
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.genram_pkg.all;
use work.gencores_pkg.all;

-- Memory mapped flash controller
entity wb_spi_flash is
  generic(
    g_port_width             : natural   := 1;  -- 1 for EPCS, 4 for EPCQ
    g_addr_width             : natural   := 24; -- size dependent (EPCQ256=25, EPCS128=24, ...)
    g_idle_time              : natural   := 3;
    g_dummy_time             : natural   := 8;
    -- leave these at defaults if you have:
    --   a) slow clock, b) valid constraints, or c) registered in/outputs
    g_input_latch_edge       : std_logic := '1'; -- rising
    g_output_latch_edge      : std_logic := '0'; -- falling
    g_input_to_output_cycles : natural   := 1);  -- between 1 and 8
  port(
    clk_i     : in  std_logic;
    rstn_i    : in  std_logic;
    slave_i   : in  t_wishbone_slave_in;
    slave_o   : out t_wishbone_slave_out;
    
    -- For properly constrained designs, set clk_out_i = clk_in_i.
    clk_out_i : in  std_logic;
    clk_in_i  : in  std_logic;
    ncs_o     : out std_logic;
    oe_o      : out std_logic_vector(g_port_width-1 downto 0);
    asdi_o    : out std_logic_vector(g_port_width-1 downto 0);
    data_i    : in  std_logic_vector(g_port_width-1 downto 0);
    
    external_request_i : in  std_logic; -- JTAG wants to use SPI?
    external_granted_o : out std_logic);
end entity;

architecture rtl of wb_spi_flash is

  subtype t_word      is std_logic_vector(31 downto 0);
  subtype t_byte      is std_logic_vector( 7 downto 0);
  subtype t_address   is unsigned(g_addr_width-1 downto 2);
  subtype t_status    is std_logic_vector(g_port_width-1 downto 0);
  subtype t_count     is unsigned(f_ceil_log2(t_word'length)-1 downto 0);
  subtype t_ack_delay is std_logic_vector(g_input_to_output_cycles-1 downto 0);
  
  constant c_read_status  : t_byte := "00000101"; -- datain
  constant c_write_enable : t_byte := "00000110"; -- 
  constant c_fast_read    : t_byte := "00001011"; -- address, dummy, datain
  constant c_fast_read2   : t_byte := "10111011"; -- address, dummy, datain
  constant c_fast_read4   : t_byte := "11101011"; -- address, dummy, datain
  constant c_write_bytes  : t_byte := "00000010"; -- address, dataout
  constant c_write_bytes2 : t_byte := "11010010"; -- address, dataout
  constant c_write_bytes4 : t_byte := "00010010"; -- address, dataout
  
  function f_addr_bits(x : natural) return natural is begin
    if x <= 24 then return 24; else return 32; end if;
  end f_addr_bits;
  constant c_addr_bits : natural := f_addr_bits(g_addr_width);
  
  constant c_low_time    : t_count := to_unsigned(g_idle_time-1,                           t_count'length);
  constant c_cmd_time    : t_count := to_unsigned(t_byte'length-1,                         t_count'length);
  constant c_status_time : t_count := to_unsigned(8*((g_input_to_output_cycles+14)/8)-1,   t_count'length);
  constant c_addr_time   : t_count := to_unsigned((c_addr_bits/g_port_width)-1,            t_count'length);
  constant c_data_time   : t_count := to_unsigned((t_wishbone_data'length/g_port_width)-1, t_count'length);

  constant c_whatever  : std_logic_vector(g_port_width-1 downto 0) := (others => '-');
  constant c_magic_reg : t_address := (others => '1');
  
  type t_state is (
    S_ERROR, S_WAIT, S_DISPATCH, S_JTAG, S_CUSTOM,
    S_READ, S_READ_ADDR, S_READ_DUMMY, S_READ_DATA, S_LOWER_CS_IDLE,
    S_ENABLE_WRITE, S_LOWER_CS_WRITE, S_WRITE, S_WRITE_ADDR, S_WRITE_DATA, 
    S_LOWER_CS_WAIT, S_READ_STATUS, S_LOAD_STATUS, S_WAIT_READY);
  
  -- Format a command for output
  function f_stripe(cmd : t_byte) return t_word is
    variable result : t_word := (others => '-');
  begin
    for i in t_byte'range loop
      result(i*g_port_width + t_word'length-g_port_width*8) := cmd(i);
      
      if g_port_width >= 4 then
        result(i*g_port_width + t_word'length-g_port_width*8 + 2) := '1';
        result(i*g_port_width + t_word'length-g_port_width*8 + 3) := '1';
      end if;
    end loop;
    return result;
  end f_stripe;
  
  -- Format data for output
  function f_data(data : t_wishbone_data; sel : t_wishbone_byte_select) return t_wishbone_data is
    variable result : t_wishbone_data := (others => '1');
  begin
    for i in t_wishbone_byte_select'range loop
      if sel(i) = '1' then -- leave unselected bytes high
        result(8*i+7 downto 8*i) := data(8*i+7 downto 8*i);
      end if;
    end loop;
    return result;
  end f_data;
  
  -- Format an address for output
  function f_address(address : t_address) return t_word is
    variable result : t_word := (others => '0');
  begin
    result((t_word'length-c_addr_bits)+t_address'left downto 
           (t_word'length-c_addr_bits)+t_address'right) := 
      std_logic_vector(address);
    return result;
  end f_address;
  
  -- Addresses wrap within a page
  constant c_page_size  : natural := 256;
  constant c_page_width : natural := f_ceil_log2(c_page_size);
  function f_increment(address : t_address) return t_address is
    variable result : t_address := address;
  begin
    result(c_page_width-1 downto 2) := result(c_page_width-1 downto 2) + 1;
    return result;
  end f_increment;
  
  constant c_full_oe : std_logic_vector(3 downto 0) := "1101";
  
  constant c_idle       : t_word   := f_stripe("--------");
  constant c_oe_default : t_status := c_full_oe(t_status'range);
  
  signal r_state   : t_state         := S_LOWER_CS_WAIT;
  signal r_state_n : t_state         := S_LOWER_CS_WAIT;
  signal r_count   : t_count         := (others => '-');
  signal r_stall   : std_logic       := '0';
  signal r_stall_n : std_logic       := '0';
  signal r_ack     : t_ack_delay     := (others => '0');
  signal r_ack_n   : std_logic       := '0';
  signal r_err     : std_logic       := '0';
  signal r_dat     : t_wishbone_data := (others => '-');
  signal r_adr     : t_address       := (others => '-');
  signal r_ncs     : std_logic       := '1';
  signal r_oe      : t_status        := (others => '0');
  signal r_shift_o : t_word          := (others => '-');
  signal r_shift_i : t_word          := (others => '-');
  signal r_data_i  : std_logic_vector(g_port_width-1 downto 0);
  signal r_data_neg: std_logic_vector(g_port_width-1 downto 0);
  
  -- Clock crossing signals
  signal master_i     : t_wishbone_master_in;
  signal master_o     : t_wishbone_master_out;
  signal clk_out_rstn : std_logic;
  signal s_wip        : std_logic; -- write in progress
  
  -- Custom command FIFO
  signal r_fifo_wen  : std_logic;
  signal r_fifo_wad  : std_logic_vector(9 downto 0);
  signal r_fifo_wdat : t_byte;
  signal r_fifo_rad  : std_logic_vector(9 downto 0);
  signal s_fifo_rdat : t_byte;
  
begin

  assert (g_port_width = 1 or g_port_width = 2 or g_port_width = 4)
  report "g_port_width must be 1, 2, or 4, not " & integer'image(g_port_width)
  severity error;
  
  assert (g_input_to_output_cycles >= 1 and g_input_to_output_cycles <= 8)
  report "g_input_to_output_cycles must be between 1 and 8, not " & integer'image(g_input_to_output_cycles)
  severity error;

  crossing : xwb_clock_crossing
    port map(
      slave_clk_i    => clk_i,
      slave_rst_n_i  => rstn_i,
      slave_i        => slave_i,
      slave_o        => slave_o,
      master_clk_i   => clk_out_i,
      master_rst_n_i => clk_out_rstn,
      master_i       => master_i,
      master_o       => master_o);
  
  sync_reset : gc_sync_ffs
    generic map(
      g_sync_edge => "positive")
    port map(
      clk_i    => clk_out_i,
      rst_n_i  => '1',
      data_i   => rstn_i,
      synced_o => clk_out_rstn,
      npulse_o => open,
      ppulse_o => open);
  
  fifo : generic_simple_dpram
    generic map(
      g_data_width       => 8,
      g_size             => 1024,
      g_with_byte_enable => false,
      g_dual_clock       => false)
    port map(
      clka_i => clk_out_i,
      bwea_i => (others => '1'),
      wea_i  => r_fifo_wen,
      aa_i   => r_fifo_wad,
      da_i   => r_fifo_wdat,
      clkb_i => clk_out_i,
      ab_i   => r_fifo_rad,
      qb_o   => s_fifo_rdat);
  
  master_i.ack <= r_ack(r_ack'left);
  master_i.err <= r_err;
  master_i.rty <= '0';
  master_i.int <= '0';
  master_i.dat <= r_shift_i;
  master_i.stall <= r_stall;
  
  -- input is prepared by SPI of falling edge => latch it on rising edge
  input : process(clk_in_i) is
  begin
    if clk_in_i'event and clk_in_i = g_input_latch_edge then
      r_data_i <= data_i;
    end if;
  end process;
  neg : process(clk_out_i) is
  begin
    if falling_edge(clk_out_i) then
      r_data_neg <= r_data_i;
    end if;
  end process;
      
  asdi_o <= r_shift_o(31 downto 32-g_port_width);
  ncs_o  <= r_ncs;
  oe_o   <= r_oe;
  
  -- output is latched by SPI on rising edge => prepare it on falling edge
  output : process(clk_out_i, clk_out_rstn) is
  begin
    if clk_out_rstn = '0' then
      r_shift_o <= (others => '-');
      r_ncs     <= '1';
      r_oe      <= (others => '0');
    elsif clk_out_i'event and clk_out_i = g_output_latch_edge then
      case r_state is
        when S_ERROR =>
          r_shift_o <= c_idle;
          r_ncs     <= '1';
          r_oe      <= c_oe_default;
        
        when S_WAIT =>
          r_shift_o <= r_shift_o(31-g_port_width downto 0) & c_whatever;
          r_ncs     <= r_ncs;
          r_oe      <= r_oe;
        
        when S_DISPATCH =>
          r_shift_o <= c_idle;
          r_ncs     <= '1';
          r_oe      <= c_oe_default;
        
        when S_JTAG =>
          r_shift_o <= (others => '-');
          r_ncs     <= '1';
          r_oe      <= (others => '0');
        
        when S_CUSTOM =>
          r_shift_o <= f_stripe(s_fifo_rdat);
          r_ncs     <= '0';
          r_oe      <= c_oe_default;
          
        when S_READ =>
          case g_port_width is
            when 1 => r_shift_o <= f_stripe(c_fast_read);
            when 2 => r_shift_o <= f_stripe(c_fast_read2);
            when 4 => r_shift_o <= f_stripe(c_fast_read4);
            when others => null;
          end case;
          r_ncs     <= '0';
          r_oe      <= c_oe_default;
          
        when S_READ_ADDR =>
          r_shift_o <= f_address(r_adr);
          r_ncs     <= '0';
          r_oe      <= (others => '1');
        
        when S_READ_DUMMY =>
          r_shift_o <= (others => '0');
          r_ncs     <= '0';
          r_oe      <= (others => '1');
        
        when S_READ_DATA =>
          r_shift_o <= (others => '-');
          r_ncs     <= '0';
          r_oe      <= (others => '0');
        
        when S_LOWER_CS_IDLE =>
          r_shift_o <= c_idle;
          r_ncs     <= '1'; 
          r_oe      <= (others => '0');
        
        when S_ENABLE_WRITE =>
          r_shift_o <= f_stripe(c_write_enable);
          r_ncs     <= '0';
          r_oe      <= c_oe_default;
        
        when S_LOWER_CS_WRITE =>
          r_shift_o <= c_idle;
          r_ncs     <= '1';
          r_oe      <= c_oe_default;
          
        when S_WRITE =>
          case g_port_width is
            when 1 => r_shift_o <= f_stripe(c_write_bytes);
            when 2 => r_shift_o <= f_stripe(c_write_bytes2);
            when 4 => r_shift_o <= f_stripe(c_write_bytes4);
            when others => null;
          end case;
          r_ncs     <= '0';
          r_oe      <= c_oe_default;

        when S_WRITE_ADDR =>
          r_shift_o <= f_address(r_adr);
          r_ncs     <= '0';
          r_oe      <= (others => '1');
        
        when S_WRITE_DATA =>
          r_shift_o <= r_dat;
          r_ncs     <= '0';
          r_oe      <= (others => '1');
        
        when S_LOWER_CS_WAIT =>
          r_shift_o <= c_idle;
          r_ncs     <= '1'; 
          r_oe      <= c_oe_default;
        
        when S_READ_STATUS =>
          r_shift_o <= f_stripe(c_read_status);
          r_ncs     <= '0';
          r_oe      <= c_oe_default;
        
        when S_LOAD_STATUS =>
          r_shift_o <= c_idle;
          r_ncs     <= '0';
          r_oe      <= c_oe_default;
        
        when S_WAIT_READY =>
          if s_wip = '0' then -- not busy
            r_shift_o <= c_idle;
            r_ncs     <= '1';
            r_oe      <= c_oe_default;
          else
            r_shift_o <= c_idle;
            r_ncs     <= '0';
            r_oe      <= c_oe_default;
          end if;
          
      end case;
    end if;
  end process;
  
  wip1 : if g_port_width = 1 generate
    s_wip <= r_shift_i((9-g_input_to_output_cycles) mod 8);
  end generate;
  wipx : if g_port_width /= 1 generate
    s_wip <= r_shift_i(((9-g_input_to_output_cycles) mod 8) * g_port_width + 1);
  end generate;
  
  main : process(clk_out_i, clk_out_rstn) is
  begin
    if clk_out_rstn = '0' then
      r_state   <= S_LOWER_CS_WAIT;
      r_state_n <= S_WAIT;
      r_count   <= (others => '-');
      r_stall   <= '0';
      r_stall_n <= '0';
      r_ack     <= (others => '0');
      r_ack_n   <= '0';
      r_err     <= '0';
      r_dat     <= (others => '-');
      r_adr     <= (others => '-');
      r_shift_i <= (others => '-');
      
      external_granted_o  <= '0';
      
      r_fifo_wen  <= '0';
      r_fifo_wad  <= (others => '1');
      r_fifo_wdat <= (others => '-');
      r_fifo_rad  <= (others => '0');
    elsif rising_edge(clk_out_i) then
      
      -- Default transition rules
      r_state  <= S_WAIT;
      r_stall  <= '1';
      r_ack(0) <= '0';
      r_err    <= '0';
      r_shift_i<= r_shift_i(31-g_port_width downto 0) & r_data_neg;
      r_fifo_wen <= '0';
      
      if g_input_to_output_cycles > 1 then
        r_ack(g_input_to_output_cycles-1 downto 1) <=
          r_ack(g_input_to_output_cycles-2 downto 0);
      end if;
      
      case r_state is
      
        when S_ERROR =>
          -- trap bad state machine behaviour
          r_count   <= (others => '-');
          r_state   <= S_ERROR;
          r_state_n <= S_ERROR;
        
        when S_WAIT =>
          r_count   <= r_count - 1;
          
          if r_count = 1 then -- is set to 0?
            r_state   <= r_state_n;
            r_stall   <= r_stall_n;
            r_ack(0)  <= r_ack_n;
            
            r_state_n <= S_ERROR;
            r_stall_n <= '1';
            r_ack_n   <= '0';
          end if;
        
        when S_DISPATCH =>
          r_count   <= (others => '-');
          r_state_n <= S_ERROR;
          
          r_dat     <= f_data(master_o.dat, master_o.sel);
          r_adr     <= unsigned(master_o.adr(t_address'range));
          r_stall   <= master_o.cyc and master_o.stb;
          
          r_state   <= S_DISPATCH;
          if master_o.cyc = '1' and master_o.stb = '1' then
            if master_o.we = '0' then
              r_state <= S_READ;
            else
              if unsigned(master_o.adr(t_address'range)) = c_magic_reg then
                if master_o.dat(31) = '0' then
                  r_fifo_wen  <= '1';
                  r_fifo_wad  <= std_logic_vector(unsigned(r_fifo_wad) + 1);
                  r_fifo_wdat <= master_o.dat(7 downto 0);
                  r_ack(0)<= '1';
                  r_stall <= '0';
                else
                  r_state_n <= S_CUSTOM;
                  r_state   <= S_WAIT;
                  r_count   <= to_unsigned(1, t_count'length);
                end if;
              else
                r_state <= S_ENABLE_WRITE;
              end if;
            end if;
          elsif external_request_i = '1' then
            external_granted_o <= '1';
            r_state <= S_JTAG;
          end if;
        
        when S_JTAG =>
          r_count   <= (others => '-');
          r_state_n <= S_ERROR;
          
          if external_request_i = '1' then
            r_state <= S_JTAG;
          else
            r_state <= S_LOWER_CS_WAIT;
            external_granted_o <= '0';
          end if;
        
        when S_CUSTOM =>
          r_count   <= c_cmd_time;
          if r_fifo_rad = r_fifo_wad then
            r_ack_n    <= '1';
            r_state_n  <= S_LOWER_CS_WAIT;
            r_fifo_rad <= (others => '0');
            r_fifo_wad <= (others => '1');
          else
            r_state_n  <= S_CUSTOM;
            r_fifo_rad <= std_logic_vector(unsigned(r_fifo_rad) + 1);
          end if;
        
        when S_READ =>
          r_count   <= c_cmd_time;
          r_state_n <= S_READ_ADDR;
          
        when S_READ_ADDR =>
          r_count   <= c_addr_time;
          r_state_n <= S_READ_DUMMY;
          r_adr     <= f_increment(r_adr);
        
        when S_READ_DUMMY =>
          r_count   <= to_unsigned(g_dummy_time-1, t_count'length);
          r_state_n <= S_READ_DATA;
        
        when S_READ_DATA =>
          r_count    <= c_data_time;
          r_ack_n    <= '1';
          r_adr      <= f_increment(r_adr);
          
          -- exploit the fact that clock_crossing doesn't change a stalled strobe
          if master_o.cyc = '1' and master_o.stb = '1' and master_o.we = '0' and
             master_o.adr(t_address'range) = std_logic_vector(r_adr) then
            r_state_n <= S_READ_DATA;
            r_stall   <= '0';
          else
            r_state_n <= S_LOWER_CS_IDLE;
          end if;
        
        when S_LOWER_CS_IDLE =>
          r_count   <= c_low_time;
          r_state_n <= S_DISPATCH;
          r_stall_n <= '0';
        
        when S_ENABLE_WRITE =>
          r_count   <= c_cmd_time;
          r_state_n <= S_LOWER_CS_WRITE;
        
        when S_LOWER_CS_WRITE =>
          r_count   <= c_low_time;
          r_state_n <= S_WRITE;
          
        when S_WRITE =>
          r_count   <= c_cmd_time;
          r_state_n <= S_WRITE_ADDR;

        when S_WRITE_ADDR =>
          r_count   <= c_addr_time;
          r_state_n <= S_WRITE_DATA;
          r_adr     <= f_increment(r_adr);
        
        when S_WRITE_DATA =>
          r_count    <= c_data_time;
          r_ack_n    <= '1';
          r_adr      <= f_increment(r_adr);
          
          -- exploit the fact that clock_crossing doesn't change a stalled strobe
          if master_o.cyc = '1' and master_o.stb = '1' and master_o.we = '1' and
             master_o.adr(t_address'range) = std_logic_vector(r_adr) then
            r_state_n  <= S_WRITE_DATA;
            r_dat      <= f_data(master_o.dat, master_o.sel);
            r_stall    <= '0';
          else
            r_state_n  <= S_LOWER_CS_WAIT;
          end if;
          
        when S_LOWER_CS_WAIT =>
          r_count   <= c_low_time;
          r_state_n <= S_READ_STATUS;
        
        when S_READ_STATUS =>
          r_count   <= c_cmd_time;
          r_state_n <= S_LOAD_STATUS;
        
        when S_LOAD_STATUS =>
          r_count   <= c_status_time;
          r_state_n <= S_WAIT_READY;
        
        when S_WAIT_READY =>
          -- Allow polling the magic register to detect busy
          if master_o.cyc = '1' and master_o.stb = '1' and master_o.we = '0' and
             unsigned(master_o.adr(t_address'range)) = c_magic_reg then
            r_dat      <= (others => '0');
            r_stall    <= '0';
            r_err      <= '1';
          end if;
          
          if s_wip = '0' then -- not busy
            r_count   <= c_low_time;
            r_state_n <= S_DISPATCH;
            r_stall_n <= '0';
          else
            r_count   <= c_cmd_time;
            r_state_n <= S_WAIT_READY;
          end if;
          
      end case;
      
    end if;
  end process;

end rtl;
