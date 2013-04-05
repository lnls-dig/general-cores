library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wishbone_pkg.all;

entity xwb_streamer is
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
    -- Master reader port
    r_master_i  : in  t_wishbone_master_in;
    r_master_o  : out t_wishbone_master_out;
    -- Master writer port
    w_master_i  : in  t_wishbone_master_in;
    w_master_o  : out t_wishbone_master_out);
end xwb_streamer;

architecture rtl of xwb_streamer is
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
  
  -- Registered wishbone control signals
  signal r_master_o_CYC : std_logic;
  signal w_master_o_CYC : std_logic;
  signal r_master_o_STB : std_logic;
  signal w_master_o_STB : std_logic;
  
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
  
begin
  -- Hard-wired master pins
  r_master_o.CYC <= r_master_o_CYC;
  w_master_o.CYC <= w_master_o_CYC;
  r_master_o.STB <= r_master_o_STB;
  w_master_o.STB <= w_master_o_STB;
  r_master_o.ADR <= (others => '0');
  w_master_o.ADR <= (others => '0');
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

    variable ring_boundary : boolean;
    variable ring_high     : boolean;
    variable ring_full     : boolean;
  begin
    if (rising_edge(clk_i)) then
      if (rst_n_i = '0') then
        read_issue_offset   <= (others => '0');
        read_result_offset  <= (others => '0');
        write_issue_offset  <= (others => '0');
        write_result_offset <= (others => '0');
        
        r_master_o_CYC <= '0';
        w_master_o_CYC <= '0';
        r_master_o_STB <= '0';
        w_master_o_STB <= '0';
      else
        -- Detect bus progress
        read_issue_progress   := r_master_o_STB = '1' and r_master_i.STALL = '0';
        write_issue_progress  := w_master_o_STB = '1' and w_master_i.STALL = '0';
        read_result_progress  := r_master_o_CYC = '1' and (r_master_i.ACK = '1' or r_master_i.ERR = '1' or r_master_i.RTY = '1');
        write_result_progress := w_master_o_CYC = '1' and (w_master_i.ACK = '1' or w_master_i.ERR = '1' or w_master_i.RTY = '1');
        
        -- Advance read pointers
        if read_issue_progress then
          new_read_issue_offset := read_issue_offset + 1;
        else
          new_read_issue_offset := read_issue_offset;
        end if;
        if read_result_progress then
          ring(index(read_result_offset)) <= r_master_i.DAT;
          new_read_result_offset := read_result_offset + 1;
        else
          new_read_result_offset := read_result_offset;
        end if;
        
        -- Advance write pointers
        if write_issue_progress then
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
        
        r_master_o_STB <= active_high (not ring_full);
        r_master_o_CYC <= active_high((not ring_full) or 
                                      (new_read_result_offset  /= new_read_issue_offset));
        w_master_o_STB <= active_high (new_write_issue_offset  /= new_read_result_offset);
        w_master_o_CYC <= active_high (new_write_result_offset /= new_read_result_offset);
        
        read_issue_offset   <= new_read_issue_offset;
        read_result_offset  <= new_read_result_offset;
        write_issue_offset  <= new_write_issue_offset;
        write_result_offset <= new_write_result_offset;
      end if;
    end if;
  end process;
end rtl;
