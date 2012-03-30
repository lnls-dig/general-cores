-- Register map:
-- 0x00 = read issue address
-- 0x04 = write issue address
-- 0x08 = read stride
-- 0x0C = write stride
-- 0x10 = transfer count
--
-- Behaviour:
--   While (transfer count > 0) {
--     mem[write_issue_address] = mem[read_issue_address]
--     read_issue_address += read_stride
--     write_issue_address += write_stride
--   }
--   interrupt = (transfer_count == 0) && (transfer_count_was == 1)
--
-- Usage:
--   1. Fill in the issue and stride registers
--   2. Write non-zero to the counter to initiate transfer
--
-- Status information:
--   All registers can be inspected during the transfer
--   Interrupt line is raised upon completion

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wishbone_pkg.all;

-- Assumption: wishbone_data_width >= wishbone_address_Width
entity xwb_dma is
  generic(
    -- Value 0 cannot stream
    -- Value 1 only slaves with async ACK can stream
    -- Value 2 only slaves with combined latency = 2 can stream
    -- Value 3 only slaves with combined latency = 6 can stream
    -- Value 4 only slaves with combined latency = 14 can stream
    -- ....
    logRingLen : integer := 4
  );
  port(
    -- Common wishbone signals
    clk_i       : in  std_logic;
    rst_n_i     : in  std_logic;
    -- Slave control port
    slave_i     : in  t_wishbone_slave_in;
    slave_o     : out t_wishbone_slave_out;
    -- Master reader port
    r_master_i  : in  t_wishbone_master_in;
    r_master_o  : out t_wishbone_master_out;
    -- Master writer port
    w_master_i  : in  t_wishbone_master_in;
    w_master_o  : out t_wishbone_master_out;
    -- Pulsed high completion signal
    interrupt_o : out std_logic
  );
end xwb_dma;

architecture rtl of xwb_dma is
  constant ringLen : integer := 2**logRingLen;
  type ring_t is array (ringLen-1 downto 0) of t_wishbone_data;
  
  -- Ring buffer for shipping data from read master to write master
  signal ring : ring_t;
  
  -- State registers (pointer into the ring)
  -- Invariant: read_issue_offset >= read_result_offset >= write_issue_offset >= write_result_offset
  --            read_issue_offset - write_result_offset  <= ringLen (*NOT* strict '<')
  signal read_issue_offset   : unsigned(logRingLen downto 0);
  signal read_result_offset  : unsigned(logRingLen downto 0);
  signal write_issue_offset  : unsigned(logRingLen downto 0);
  signal write_result_offset : unsigned(logRingLen downto 0);
  
  -- DMA control registers
  signal read_issue_address  : t_wishbone_address;
  signal write_issue_address : t_wishbone_address;
  signal read_stride         : t_wishbone_address;
  signal write_stride        : t_wishbone_address;
  signal transfer_count      : t_wishbone_address;
  -- result status: fail/ok ?
  
  -- Registered wishbone control signals
  signal r_master_o_CYC : std_logic;
  signal w_master_o_CYC : std_logic;
  signal r_master_o_STB : std_logic;
  signal w_master_o_STB : std_logic;
  signal slave_o_ACK    : std_logic;
  signal slave_o_DAT    : t_wishbone_data;
  
  function active_high(x : boolean)
    return std_logic is
  begin
    if (x) then
      return '1';
    else
      return '0';
    end if;
  end active_high;
  
  function index(x : unsigned(logRingLen downto 0))
    return integer is
  begin
    if logRingLen > 0 then
      return to_integer(x(logRingLen-1 downto 0));
    else
      return 0;
    end if;
  end index;
  
  procedure update(signal o : out t_wishbone_address) is
  begin
    for i in (c_wishbone_data_width/8)-1 downto 0 loop
      if slave_i.SEL(i) = '1' then
        o(i*8+7 downto i*8) <= slave_i.DAT(i*8+7 downto i*8);
      end if;
    end loop;
  end update;
  
begin
  -- Hard-wired slave pins
  slave_o.ACK   <= slave_o_ACK;
  slave_o.ERR   <= '0';
  slave_o.RTY   <= '0';
  slave_o.STALL <= '0';
  slave_o.DAT   <= slave_o_DAT;
  
  -- Hard-wired master pins
  r_master_o.CYC <= r_master_o_CYC;
  w_master_o.CYC <= w_master_o_CYC;
  r_master_o.STB <= r_master_o_STB;
  w_master_o.STB <= w_master_o_STB;
  r_master_o.ADR <= read_issue_address;
  w_master_o.ADR <= write_issue_address;
  r_master_o.SEL <= (others => '1');
  w_master_o.SEL <= (others => '1');
  r_master_o.WE  <= '0';
  w_master_o.WE  <= '1';
  r_master_o.DAT <= (others => '0');
  w_master_o.DAT <= ring(index(write_issue_offset));
  
  main : process(clk_i)
    variable read_issue_progress   : boolean;
    variable read_result_progress  : boolean;
    variable write_issue_progress  : boolean;
    variable write_result_progress : boolean;
    
    variable new_read_issue_offset   : unsigned(logRingLen downto 0);
    variable new_read_result_offset  : unsigned(logRingLen downto 0);
    variable new_write_issue_offset  : unsigned(logRingLen downto 0);
    variable new_write_result_offset : unsigned(logRingLen downto 0);
    variable new_transfer_count      : t_wishbone_address;

    variable ring_boundary : boolean;
    variable ring_high     : boolean;
    variable ring_full     : boolean;
    variable ring_empty    : boolean;
    variable done_transfer : boolean;
  begin
    if (rising_edge(clk_i)) then
      if (rst_n_i = '0') then
        read_issue_offset   <= (others => '0');
        read_result_offset  <= (others => '0');
          write_issue_offset  <= (others => '0');
        write_result_offset <= (others => '0');
        
        read_issue_address  <= (others => '0');
        write_issue_address <= (others => '0');
        read_stride         <= (others => '0');
        write_stride        <= (others => '0');
        transfer_count      <= (others => '0');
        
        r_master_o_CYC <= '0';
        w_master_o_CYC <= '0';
        r_master_o_STB <= '0';
        w_master_o_STB <= '0';
        slave_o_ACK <= '0';
        slave_o_DAT <= (others => '0');
        interrupt_o <= '0';
      else
        -- Output any read the user requests
        case to_integer(unsigned(slave_i.ADR(4 downto 2))) is
          when 0 => slave_o_DAT <= read_issue_address;
          when 1 => slave_o_DAT <= write_issue_address;
          when 2 => slave_o_DAT <= read_stride;
          when 3 => slave_o_DAT <= write_stride;
          when 4 => slave_o_DAT <= transfer_count;
          when others => slave_o_DAT <= (others => '0');
        end case;
        
        -- Detect bus progress
        read_issue_progress   := r_master_o_STB = '1' and r_master_i.STALL = '0';
        write_issue_progress  := w_master_o_STB = '1' and w_master_i.STALL = '0';
        read_result_progress  := r_master_o_CYC = '1' and (r_master_i.ACK = '1' or r_master_i.ERR = '1' or r_master_i.RTY = '1');
        write_result_progress := w_master_o_CYC = '1' and (w_master_i.ACK = '1' or w_master_i.ERR = '1' or w_master_i.RTY = '1');
        
        -- Advance read pointers
        if read_issue_progress then
          read_issue_address <= std_logic_vector(unsigned(read_issue_address) + unsigned(read_stride));
          new_read_issue_offset := read_issue_offset + 1;
          new_transfer_count    := std_logic_vector(unsigned(transfer_count) - 1);
        else
          new_read_issue_offset := read_issue_offset;
          new_transfer_count    := transfer_count;
        end if;
        if read_result_progress then
          ring(index(read_result_offset)) <= r_master_i.DAT;
          new_read_result_offset := read_result_offset + 1;
        else
          new_read_result_offset := read_result_offset;
        end if;
        
        -- Advance write pointers
        if write_issue_progress then
          write_issue_address <= std_logic_vector(unsigned(write_issue_address) + unsigned(write_stride));
          new_write_issue_offset := write_issue_offset + 1;
        else
          new_write_issue_offset := write_issue_offset;
        end if;
        if write_result_progress then
          new_write_result_offset := write_result_offset + 1;
        else
          new_write_result_offset := write_result_offset;
        end if; 
        
        ring_boundary := index(new_read_issue_offset) = index(new_write_result_offset);
        ring_high     := new_read_issue_offset(logRingLen) /= new_write_result_offset(logRingLen);
        ring_full     := ring_boundary and ring_high;
        ring_empty    := ring_boundary and not ring_high;
        
        -- Shorten the critical path by comparing to the undecremented value
        --done_transfer := unsigned(new_transfer_count) = 0;
        done_transfer := unsigned(transfer_count(c_wishbone_address_width-1 downto 1)) = 0 
                         and (read_issue_progress or transfer_count(0) = '0');
        
        r_master_o_STB <= active_high (not ring_full and not done_transfer);
        r_master_o_CYC <= active_high((not ring_full and not done_transfer) or 
                                      (new_read_result_offset  /= new_read_issue_offset));
        w_master_o_STB <= active_high (new_write_issue_offset  /= new_read_result_offset);
        w_master_o_CYC <= active_high (new_write_result_offset /= new_read_result_offset);
        interrupt_o    <= active_high (write_result_progress and done_transfer and ring_empty);
        
        transfer_count      <= new_transfer_count;
        read_issue_offset   <= new_read_issue_offset;
        read_result_offset  <= new_read_result_offset;
        write_issue_offset  <= new_write_issue_offset;
        write_result_offset <= new_write_result_offset;
        
        -- Control logic
        if (slave_i.CYC = '1' and slave_i.STB = '1' and slave_i.WE = '1') then
          case to_integer(unsigned(slave_i.ADR(4 downto 2))) is
            when 0 => update(read_issue_address);
            when 1 => update(write_issue_address);
            when 2 => update(read_stride);
            when 3 => update(write_stride);
            when 4 => update(transfer_count);
            when others => null;
          end case;
        end if;
        
        slave_o_ACK <= slave_i.CYC and slave_i.STB;
      end if;
    end if;
  end process;
end rtl;
