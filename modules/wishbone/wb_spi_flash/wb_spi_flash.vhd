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
    g_port_width : natural := 1;   --  1 for EPCS,  4 for EPCQ
    g_addr_width : natural := 24); -- 24 for EPCS, 32 for EPCQ
  port(
    clk_i   : in  std_logic;
    rstn_i  : in  std_logic;
    slave_i : in  t_wishbone_slave_in;
    slave_o : out t_wishbone_slave_out;
    
    dclk_i  : in  std_logic; -- <=20 MHz for EPCS, <=100 MHz for EPCQ
    ncs_o   : out std_logic;
    asdi_o  : out std_logic_vector(g_port_width-1 downto 0);
    data_i  : in  std_logic_vector(g_port_width-1 downto 0);
    
    jreq_i  : in  std_logic; -- JTAG wants to use SPI?
    jrdy_o  : out std_logic);
end entity;

architecture rtl of wb_spi_flash is

  subtype t_word    is std_logic_vector(31 downto 0);
  subtype t_byte    is std_logic_vector( 7 downto 0);
  subtype t_address is unsigned(g_addr_width-1 downto 0);
  subtype t_count   is unsigned(f_ceil_log2(t_word'length)-1 downto 0);
  
  -- !!! these differ for EPCQ; modify when we have a chip to try
  constant c_read_status  : t_byte := "00000101"; -- datain
  constant c_write_enable : t_byte := "00000110"; -- 
  constant c_read_bytes   : t_byte := "00000011"; -- address, datain
  constant c_write_bytes  : t_byte := "00000010"; -- address, dataout
  constant c_erase_sector : t_byte := "11011000"; -- address
  
  constant c_low_time  : t_count := to_unsigned(2-1, t_count'length);

  constant c_whatever  : std_logic_vector(g_port_width-1 downto 0) := (others => '-');
  constant c_magic_reg : t_address := (others => '1');
  
  type t_state is (
    S_ERROR, S_WAIT, S_DISPATCH, S_JTAG,
    S_READ, S_READ_ADDR, S_READ_DATA, S_LOWER_CS_IDLE,
    S_ENABLE_WRITE, S_LOWER_CS_WRITE, S_WRITE, S_WRITE_ADDR, S_WRITE_DATA, 
    S_ENABLE_ERASE, S_LOWER_CS_ERASE, S_ERASE, S_ERASE_ADDR,
    S_LOWER_CS_WAIT, S_READ_STATUS, S_LOAD_STATUS, S_WAIT_READY);
  
  -- Format a command for output
  constant c_cmd_time : t_count := to_unsigned(t_byte'length-1, t_count'length);
  function f_stripe(cmd : t_byte) return t_word is
    variable result : t_word := (others => '-');
  begin
    for i in t_byte'range loop
      result(i*g_port_width + t_word'length-g_port_width*8) := cmd(i);
    end loop;
    return result;
  end f_stripe;
  
  -- Format data for output
  constant c_data_time : t_count := to_unsigned((t_wishbone_data'length/g_port_width)-1, t_count'length);
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
  constant c_addr_time : t_count := to_unsigned((t_address'length/g_port_width)-1, t_count'length);
  function f_address(address : t_address) return t_word is
    variable result : t_word := (others => '-');
  begin
    result(t_word'left downto t_word'length-t_address'length) := 
      std_logic_vector(address);
    return result;
  end f_address;
  
  -- Addresses wrap within a page
  constant c_page_size  : natural := 256;
  constant c_page_width : natural := f_ceil_log2(c_page_size);
  function f_increment(address : t_address) return t_address is
    variable result : t_address := address;
  begin
    result(c_page_width-1 downto 0) := result(c_page_width-1 downto 0) + 4;
    return result;
  end f_increment;
  
  signal r_state   : t_state         := S_LOWER_CS_WAIT;
  signal r_state_n : t_state         := S_LOWER_CS_WAIT;
  signal r_count   : t_count         := (others => '-');
  signal r_stall   : std_logic       := '0';
  signal r_stall_n : std_logic       := '0';
  signal r_ack     : std_logic       := '0';
  signal r_ack_n   : std_logic       := '0';
  signal r_dat     : t_wishbone_data := (others => '-');
  signal r_adr     : t_address       := (others => '-');
  signal r_ncs     : std_logic       := '1';
  signal r_shift_o : t_word          := (others => '-');
  signal r_shift_i : t_word          := (others => '-');
  
  -- Clock crossing signals
  signal master_i  : t_wishbone_master_in;
  signal master_o  : t_wishbone_master_out;
  signal dclk_rstn : std_logic;
  
begin

  crossing : xwb_clock_crossing
    port map(
      slave_clk_i    => clk_i,
      slave_rst_n_i  => rstn_i,
      slave_i        => slave_i,
      slave_o        => slave_o,
      master_clk_i   => dclk_i,
      master_rst_n_i => dclk_rstn,
      master_i       => master_i,
      master_o       => master_o);
  
  sync_reset : gc_sync_ffs
    generic map(
      g_sync_edge => "positive")
    port map(
      clk_i    => dclk_i,
      rst_n_i  => '1',
      data_i   => rstn_i,
      synced_o => dclk_rstn,
      npulse_o => open,
      ppulse_o => open);
  
  master_i.ack <= r_ack;
  master_i.rty <= '0';
  master_i.err <= '0';
  master_i.int <= '0';
  master_i.dat <= r_shift_i;
  master_i.stall <= r_stall;
  
  -- nCS and asdi should be latched on falling edge
  -- data_i should be latched on rising edge
  
  asdi_o <= r_shift_o(31 downto 32-g_port_width);
  ncs_o  <= r_ncs;
  
  output : process(dclk_i, dclk_rstn) is
  begin
    if dclk_rstn = '0' then
      r_shift_o <= (others => '-');
      r_ncs     <= '1';
    elsif falling_edge(dclk_i) then
      case r_state is
        when S_ERROR =>
          r_shift_o <= (others => '-');
          r_ncs     <= '1';
        
        when S_WAIT =>
          r_shift_o <= r_shift_o(31-g_port_width downto 0) & c_whatever;
          r_ncs     <= r_ncs;
        
        when S_DISPATCH =>
          r_shift_o <= (others => '-');
          r_ncs     <= '1';
        
        when S_JTAG =>
          r_shift_o <= (others => '-');
          r_ncs     <= '1';
        
        when S_READ =>
          r_shift_o <= f_stripe(c_read_bytes);
          r_ncs     <= '0';
          
        when S_READ_ADDR =>
          r_shift_o <= f_address(r_adr);
          r_ncs     <= '0';
        
        when S_READ_DATA =>
          r_shift_o  <= (others => '-');
          r_ncs     <= '0';
        
        when S_LOWER_CS_IDLE =>
          r_shift_o  <= (others => '-');
          r_ncs     <= '1'; 
        
        when S_ENABLE_WRITE =>
          r_shift_o <= f_stripe(c_write_enable);
          r_ncs     <= '0';
        
        when S_LOWER_CS_WRITE =>
          r_shift_o <= (others => '-');
          r_ncs     <= '1';
          
        when S_WRITE =>
          r_shift_o <= f_stripe(c_write_bytes);
          r_ncs     <= '0';

        when S_WRITE_ADDR =>
          r_shift_o <= f_address(r_adr);
        
        when S_WRITE_DATA =>
          r_shift_o <= r_dat;
          r_ncs     <= '0';
          
        when S_ENABLE_ERASE =>
          r_shift_o <= f_stripe(c_write_enable);
          r_ncs     <= '0';
        
        when S_LOWER_CS_ERASE =>
          r_shift_o <= (others => '-');
          r_ncs     <= '1';
          
        when S_ERASE =>
          r_shift_o <= f_stripe(c_erase_sector);
          r_ncs     <= '0';

        when S_ERASE_ADDR =>
          r_shift_o  <= f_address(r_adr);
        
        when S_LOWER_CS_WAIT =>
          r_shift_o <= (others => '-');
          r_ncs     <= '1'; 
        
        when S_READ_STATUS =>
          r_shift_o <= f_stripe(c_read_status);
          r_ncs     <= '0';
        
        when S_LOAD_STATUS =>
          r_shift_o <= (others => '-');
          r_ncs     <= '0';
        
        when S_WAIT_READY =>
          if r_shift_i(0) = '0' then -- not busy
            r_shift_o <= (others => '-');
            r_ncs     <= '1';
          else
            r_shift_o <= (others => '-');
            r_ncs     <= '0';
          end if;
          
      end case;
    end if;
  end process;
  
  input : process(dclk_i, dclk_rstn) is
  begin
    if dclk_rstn = '0' then
      r_state   <= S_LOWER_CS_WAIT;
      r_state_n <= S_LOWER_CS_WAIT;
      r_count   <= (others => '-');
      r_stall   <= '0';
      r_stall_n <= '0';
      r_ack     <= '0';
      r_ack_n   <= '0';
      r_dat     <= (others => '-');
      r_adr     <= (others => '-');
      r_shift_i <= (others => '-');
      jrdy_o    <= '0';
    elsif rising_edge(dclk_i) then
      
      r_shift_i <= r_shift_i(31-g_port_width downto 0) & data_i;
      
      -- Default transition rules
      r_state <= S_WAIT;
      r_stall <= '1';
      r_ack   <= '0';
      
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
            r_ack     <= r_ack_n;
            
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
            if unsigned(master_o.adr(t_address'range)) = c_magic_reg then
              if master_o.we = '0' then
                -- !!! read chip type
                r_state <= S_LOWER_CS_WAIT;
              else
                r_adr   <= unsigned(master_o.dat(t_address'range));
                r_state <= S_ENABLE_ERASE;
              end if;
            else
              if master_o.we = '0' then
                r_state <= S_READ;
              else
                r_state <= S_ENABLE_WRITE;
              end if;
            end if;
          elsif jreq_i = '1' then
            jrdy_o <= '1';
            r_state <= S_JTAG;
          end if;
        
        when S_JTAG =>
          r_count   <= (others => '-');
          r_state_n <= S_ERROR;
          
          if jreq_i = '1' then
            r_state <= S_JTAG;
          else
            r_state <= S_LOWER_CS_WAIT;
            jrdy_o <= '0';
          end if;
        
        when S_READ =>
          r_count   <= c_cmd_time;
          r_state_n <= S_READ_ADDR;
          
        when S_READ_ADDR =>
          r_count   <= c_addr_time;
          r_state_n <= S_READ_DATA;
          r_adr     <= f_increment(r_adr);
        
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
            r_stall    <= '0';
          else
            r_state_n  <= S_LOWER_CS_WAIT;
          end if;
          
        when S_ENABLE_ERASE =>
          r_count   <= c_cmd_time;
          r_state_n <= S_LOWER_CS_ERASE;
        
        when S_LOWER_CS_ERASE =>
          r_count   <= c_low_time;
          r_state_n <= S_ERASE;
          
        when S_ERASE =>
          r_count   <= c_cmd_time;
          r_state_n <= S_ERASE_ADDR;

        when S_ERASE_ADDR =>
          r_count    <= c_addr_time;
          r_state_n  <= S_LOWER_CS_WAIT;
        
        when S_LOWER_CS_WAIT =>
          r_count   <= c_low_time;
          r_state_n <= S_READ_STATUS;
        
        when S_READ_STATUS =>
          r_count   <= c_cmd_time;
          r_state_n <= S_LOAD_STATUS;
        
        when S_LOAD_STATUS =>
          r_count   <= c_cmd_time;
          r_state_n <= S_WAIT_READY;
        
        when S_WAIT_READY =>
          if r_shift_i(0) = '0' then -- not busy
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
