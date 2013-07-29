library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pcie_tlp is
  port(
    clk_i         : in std_logic;
    rstn_i        : in std_logic;
    
    rx_wb_stb_i   : in  std_logic;
    rx_wb_dat_i   : in  std_logic_vector(31 downto 0);
    rx_wb_stall_o : out std_logic;
    rx_bar_i      : in  std_logic_vector(2 downto 0);
    
    tx_rdy_i      : in  std_logic;
    tx_alloc_o    : out std_logic;
    
    tx_wb_stb_o   : out std_logic;
    tx_wb_dat_o   : out std_logic_vector(31 downto 0);
    tx_eop_o      : out std_logic;
    
    cfg_busdev_i  : in  std_logic_vector(12 downto 0);
    
    wb_stb_o      : out std_logic;
    wb_adr_o      : out std_logic_vector(63 downto 0);
    wb_bar_o      : out std_logic_vector(2 downto 0);
    wb_we_o       : out std_logic;
    wb_dat_o      : out std_logic_vector(31 downto 0);
    wb_sel_o      : out std_logic_vector(3 downto 0);
    wb_stall_i    : in  std_logic;
    wb_ack_i      : in  std_logic;
    wb_err_i      : in  std_logic;
    wb_rty_i      : in  std_logic;
    wb_dat_i      : in  std_logic_vector(31 downto 0));
end pcie_tlp;

architecture rtl of pcie_tlp is
  type rx_state_type is (get_h0, get_h1, get_h2, get_h3, skip_pad, drop_payload, write_stall, write_first, write_middle, write_last, read_stall, read_first, read_txstall, read_middle, read_last, skip_tail);
  type tx_state_type is (put_h0, put_h1, put_h2, put_pad, flight_stall, ack_wait, put_tail);
  type tlp_type is (memory_read, memory_write, completion, ignored);
  
  signal rx_state : rx_state_type := get_h0;
  signal tx_state : tx_state_type := put_h0;
  
  -- Header registers
  signal r_h0, r_h1, r_h2, r_h3 : std_logic_vector(31 downto 0);
  
  signal r_length      : unsigned(9 downto 0);
  signal r_address     : std_logic_vector(15 downto 0);
  signal r_bar         : std_logic_vector(2 downto 0);
  signal r_bar_next    : std_logic_vector(2 downto 0);
  
  -- Common subexpressions:
  signal s_tlp_length   : std_logic_vector(9 downto 0);
  signal s_tlp_code     : std_logic_vector(6 downto 0);
  signal s_tlp_typecode : std_logic_vector(2 downto 0);
  signal s_tlp_attr     : std_logic_vector(2 downto 0);
  signal s_tlp_id       : std_logic_vector(23 downto 0);
  signal s_tlp_type     : tlp_type;
  signal s_tlp_locked   : std_logic;
  signal s_length_m1    : unsigned(9 downto 0);
  signal s_address_p4   : std_logic_vector(15 downto 0);
  
  signal s_first_be, s_last_be : std_logic_vector(3 downto 0);
  
  signal s_length_eq1, s_length_eq2, s_has_pad, s_has_tail : boolean;
  signal s_has_payload, s_has_4fields, s_no_flight : boolean;
  signal s_alignbit : std_logic;
  signal tx_tail : boolean;
  
  signal s_missing     : unsigned(2 downto 0);
  signal s_bytes       : std_logic_vector(11 downto 0);
  signal s_low_addr    : std_logic_vector(6 downto 0);
  
  -- Stall and strobe bypass mux
  signal r_always_stall, r_never_stall : std_logic;
  signal r_always_stb,   r_never_stb   : std_logic;
  
  -- Inflight reads and writes
  signal wb_stb : std_logic;
  signal r_flight_count : unsigned(4 downto 0);
  
  signal r_tx_wb_stb, r_tx_alloc, r_rx_alloc : std_logic;
  signal r_pending_ack : unsigned(9 downto 0);
  
begin
  rx_wb_stall_o <= r_always_stall or (not r_never_stall and wb_stall_i);
  wb_stb <= r_always_stb or (not r_never_stb and rx_wb_stb_i);
  wb_stb_o <= wb_stb;
  wb_bar_o <= r_bar;
  wb_dat_o <= rx_wb_dat_i;

  wb_adr_o(63 downto 32) <= 
    r_h2 when s_has_4fields else
    (others => '0');
  wb_adr_o(31 downto 16) <=
    r_h3(31 downto 16) when s_has_4fields else
    r_h2(31 downto 16);
  wb_adr_o(15 downto 0) <= r_address;
  
  s_has_payload  <= r_h0(30) = '1';
  s_has_4fields  <= r_h0(29) = '1';
  s_tlp_locked   <= r_h0(24);
  s_tlp_code     <= r_h0(30 downto 24);
  s_tlp_length   <= r_h0(9 downto 0);
  s_tlp_typecode <= r_h0(22 downto 20);
  s_tlp_attr     <= r_h0(18) & r_h0(13 downto 12);
  s_tlp_type <=
    memory_read        when std_match(s_tlp_code, "0-0000-") else -- Memory Read Request, (Locked) 32/64-Bit Addressing
    memory_read        when std_match(s_tlp_code, "0000010") else -- I/O Read Request (treat register#/etc as address)
    ignored            when std_match(s_tlp_code, "-110---") else -- Message with(out) data
    completion         when std_match(s_tlp_code, "-00101-") else -- Completion (Locked) with(out) data
    memory_write       when std_match(s_tlp_code, "1-00000") else -- Memory Write Request, 32/64-Bit Addressing
    memory_write       when std_match(s_tlp_code, "1000010") else -- I/O Write Request  (treat register#/etc as address)
    ignored;                                                      -- Shouldn't happen...
  
  -- Deal with Altera padding crap:
  s_alignbit <= 
    '0'            when s_tlp_type = ignored else
    rx_wb_dat_i(2) when rx_state = get_h2 else
    rx_wb_dat_i(2) when rx_state = get_h3 else
    r_h3(2)        when s_has_4fields else
    r_h2(2);
  s_has_pad <= (s_has_4fields xor s_alignbit = '0') and s_has_payload;
  s_has_tail <= 
    (s_tlp_length(0) = '0' xor s_alignbit = '0') when s_has_payload else
    (not s_has_4fields);
  
  s_tlp_id      <= r_h1(31 downto 8);
  s_first_be    <= r_h1(3 downto 0);
  s_last_be     <= r_h1(7 downto 4);
  
  s_length_m1   <= r_length - 1;
  s_length_eq1  <= r_length = 1;
  s_length_eq2  <= r_length = 2;
  s_no_flight   <= r_flight_count = 0;
  
  s_address_p4   <= std_logic_vector(unsigned(r_address) + to_unsigned(4, 16));
  
  rx_state_machine : process(clk_i) is
    variable next_state : rx_state_type;
    variable tx_next_read : std_logic;
    variable action : rx_state_type;
  begin
    if rising_edge(clk_i) then
      if rstn_i = '0' then
        rx_state <= get_h0;
      else
      
        ----------------- Pre-transition actions --------------------
        case rx_state is
          when get_h0 => 
            r_h0 <= rx_wb_dat_i; 
          when get_h1 => 
            r_h1 <= rx_wb_dat_i; 
            r_length <= unsigned(s_tlp_length);
          when get_h2 => 
            r_h2 <= rx_wb_dat_i; 
            r_bar_next <= rx_bar_i;
            r_address(15 downto 2) <= rx_wb_dat_i(15 downto 2);
          when get_h3 => 
            r_h3 <= rx_wb_dat_i; 
            r_address(15 downto 2) <= rx_wb_dat_i(15 downto 2);
          when others => null;
        end case;
              
        ----------------- Transition rules --------------------
        next_state := rx_state;
        r_rx_alloc <= '0';
        
        -- What sort of action is this?
        case s_tlp_type is
          when memory_read => 
            action := read_stall;
          when memory_write => 
            action := write_stall;
          when others => -- completion or ignored
            if s_has_payload then
              action := drop_payload;
            else
              if s_has_tail then
                action := skip_tail;
              else
                action := get_h0;
              end if;
            end if;
        end case;
        
        case rx_state is
          when get_h0 =>
            if rx_wb_stb_i = '1' then
              next_state := get_h1;
            end if;
          when get_h1 =>
            if rx_wb_stb_i = '1' then
              next_state := get_h2;
            end if;
          when get_h2 =>
            if rx_wb_stb_i = '1' then
              if s_has_4fields then
                next_state := get_h3;
              else
                if s_has_pad then
                  next_state := skip_pad;
                else
                  next_state := action;
                end if;
              end if;
            end if;
          when get_h3 =>
            if rx_wb_stb_i = '1' then
              
              if s_has_pad then
                next_state := skip_pad;
              else
                next_state := action;
              end if;
            end if;
          when skip_pad =>
            if rx_wb_stb_i = '1' then
              next_state := action;
            end if;
          when drop_payload =>
            if rx_wb_stb_i = '1' then
              if s_length_eq1 then
                if s_has_tail then
                  next_state := skip_tail;
                else
                  next_state := get_h0;
                end if;
              end if;
              r_length <= s_length_m1;
            end if;
          when write_stall =>
            if (s_no_flight or r_bar_next = r_bar) then
              r_bar <= r_bar_next;
              next_state := write_first;
            end if;
          when write_first | write_middle | write_last =>
            if (rx_wb_stb_i and not wb_stall_i) = '1' then
              if s_length_eq1 then
                if s_has_tail then
                  next_state := skip_tail;
                else
                  next_state := get_h0;
                end if;
              elsif s_length_eq2 then
                next_state := write_last;
              else
                next_state := write_middle;
              end if;
              r_length <= s_length_m1;
              r_address <= s_address_p4;
            end if;
          when read_stall =>
            if (s_no_flight or r_bar_next = r_bar) and
               tx_state = ack_wait and tx_rdy_i = '1' then
              r_rx_alloc <= '1';
              r_bar <= r_bar_next;
              next_state := read_first;
            end if;
          when read_first | read_middle | read_last =>
            if wb_stall_i = '0' then
              if tx_rdy_i = '0' then
                next_state := read_txstall;
              else
                if s_length_eq1 then
                  if s_has_tail then
                    next_state := skip_tail;
                  else
                    next_state := get_h0;
                  end if;
                elsif s_length_eq2 then
                  r_rx_alloc <= '1';
                  next_state := read_last;
                else
                  r_rx_alloc <= '1';
                  next_state := read_middle;
                end if;
                r_length <= s_length_m1;
                r_address <= s_address_p4;
              end if;
            end if;
          when read_txstall =>
            if tx_rdy_i = '1' then
              if s_length_eq1 then
                if s_has_tail then
                  next_state := skip_tail;
                else
                  next_state := get_h0;
                end if;
              elsif s_length_eq2 then
                r_rx_alloc <= '1';
                next_state := read_last;
              else
                r_rx_alloc <= '1';
                next_state := read_middle;
              end if;
              r_length <= s_length_m1;
              r_address <= s_address_p4;
            end if;
          when skip_tail =>
            if rx_wb_stb_i = '1' then
              next_state := get_h0;
            end if;
        end case;
        
        ----------------- Post-transition actions --------------------
        wb_we_o <= '-';
        wb_sel_o <= (others => '-');
        r_always_stall <= '0';
        r_never_stall <= '1' ;
        r_always_stb <= '0';
        r_never_stb <= '1';
        
        rx_state <= next_state;
        case next_state is
          when get_h0 => null;
          when get_h1 => null;
          when get_h2 => null;
          when get_h3 => null;
          when skip_pad => null;
          when drop_payload => null;
          when write_stall => 
            r_always_stall <= '1';
          when write_first =>
            r_never_stall <= '0';
            r_never_stb <= '0';
            wb_sel_o <= s_first_be;
            wb_we_o <= '1';
          when write_middle =>
            r_never_stall <= '0';
            r_never_stb <= '0';
            wb_sel_o <= x"f";
            wb_we_o <= '1';
          when write_last =>
            r_never_stall <= '0';
            r_never_stb <= '0';
            wb_sel_o <= s_last_be;
            wb_we_o <= '1';
          when read_stall => 
            r_always_stall <= '1';
          when read_first =>
            r_always_stall <= '1';
            r_always_stb <= '1';
            wb_sel_o <= s_first_be;
            wb_we_o <= '0';
          when read_txstall =>
            r_always_stall <= '1';
          when read_middle =>
            r_always_stall <= '1';
            r_always_stb <= '1';
            wb_sel_o <= x"f";
            wb_we_o <= '0';
          when read_last =>
            r_always_stall <= '1';
            r_always_stb <= '1';
            wb_sel_o <= s_last_be;
            wb_we_o <= '0';
          when skip_tail => null;
        end case;
      end if;
    end if;
  end process;
  
  -- These tables are copied from the PCI express standard:
  s_missing <= 
    "000" when std_match(s_first_be, "1--1") and std_match(s_last_be, "0000") else
    "001" when std_match(s_first_be, "01-1") and std_match(s_last_be, "0000") else
    "001" when std_match(s_first_be, "1-10") and std_match(s_last_be, "0000") else
    "010" when std_match(s_first_be, "0011") and std_match(s_last_be, "0000") else
    "010" when std_match(s_first_be, "0110") and std_match(s_last_be, "0000") else
    "010" when std_match(s_first_be, "1100") and std_match(s_last_be, "0000") else
    "011" when std_match(s_first_be, "0001") and std_match(s_last_be, "0000") else
    "011" when std_match(s_first_be, "0010") and std_match(s_last_be, "0000") else
    "011" when std_match(s_first_be, "0100") and std_match(s_last_be, "0000") else
    "011" when std_match(s_first_be, "1000") and std_match(s_last_be, "0000") else
    "000" when std_match(s_first_be, "---1") and std_match(s_last_be, "1---") else
    "001" when std_match(s_first_be, "---1") and std_match(s_last_be, "01--") else
    "010" when std_match(s_first_be, "---1") and std_match(s_last_be, "001-") else
    "011" when std_match(s_first_be, "---1") and std_match(s_last_be, "0001") else
    "001" when std_match(s_first_be, "--10") and std_match(s_last_be, "1---") else
    "010" when std_match(s_first_be, "--10") and std_match(s_last_be, "01--") else
    "011" when std_match(s_first_be, "--10") and std_match(s_last_be, "001-") else
    "100" when std_match(s_first_be, "--10") and std_match(s_last_be, "0001") else
    "010" when std_match(s_first_be, "-100") and std_match(s_last_be, "1---") else
    "011" when std_match(s_first_be, "-100") and std_match(s_last_be, "01--") else
    "100" when std_match(s_first_be, "-100") and std_match(s_last_be, "001-") else
    "101" when std_match(s_first_be, "-100") and std_match(s_last_be, "0001") else
    "011" when std_match(s_first_be, "1000") and std_match(s_last_be, "1---") else
    "100" when std_match(s_first_be, "1000") and std_match(s_last_be, "01--") else
    "101" when std_match(s_first_be, "1000") and std_match(s_last_be, "001-") else
    "110" when std_match(s_first_be, "1000") and std_match(s_last_be, "0001") else
    "---";
  s_bytes <= std_logic_vector(unsigned(r_length & "00") - s_missing);
  
  s_low_addr(6 downto 2) <= r_address(6 downto 2);
  s_low_addr(1 downto 0) <= 
    "00" when std_match(s_first_be, "0000") else
    "00" when std_match(s_first_be, "---1") else
    "01" when std_match(s_first_be, "--10") else
    "10" when std_match(s_first_be, "-100") else
    "11" when std_match(s_first_be, "1000") else
    "--";
  
  -- register: tx_wb_stb_o and tx_alloc_o
  tx_wb_stb_o <= r_tx_wb_stb;
  tx_alloc_o <= r_tx_alloc or r_rx_alloc;
  tx_state_machine : process(clk_i) is
    variable next_state : tx_state_type;
  begin
    if rising_edge(clk_i) then
      if rstn_i = '0' then
        tx_state <= put_h0;
        r_tx_wb_stb <= '0';
        r_tx_alloc <= '0';
      else
        ----------------- Transition rules --------------------
        next_state := tx_state;
        case tx_state is
          when put_h0 =>
            if r_tx_wb_stb = '1' then
              next_state := put_h1;
            end if;
          when put_h1 =>
            if r_tx_wb_stb = '1' then
              next_state := put_h2;
            end if;
          when put_h2 =>
            if r_tx_wb_stb = '1' then
              if s_alignbit = '0' then
                next_state := put_pad;
              else
                if s_no_flight then
                  next_state := ack_wait;
                else
                  next_state := flight_stall;
                end if;
              end if;
            end if;
          when put_pad =>
            if r_tx_wb_stb = '1' then
              if s_no_flight then
                next_state := ack_wait;
              else
                next_state := flight_stall;
              end if;
            end if;
          when flight_stall =>
            if s_no_flight then
              next_state := ack_wait;
            end if;
          when ack_wait =>
            if r_pending_ack = 0 then
              if tx_tail then
                next_state := put_tail;
              else
                next_state := put_h0;
              end if;
            end if;
          when put_tail =>
            if r_tx_wb_stb = '1' then
              next_state := put_h0;
            end if;
        end case;
        
        ----------------- Post-transition actions --------------------
        r_tx_wb_stb <= '0';
        r_tx_alloc <= '0';
        tx_eop_o <= '0';
        tx_wb_dat_o <= (others => '-');
        
        tx_state <= next_state;
        case next_state is
          when put_h0 =>
            r_pending_ack <= unsigned(s_tlp_length);
            tx_wb_dat_o <= "0100101" & s_tlp_locked -- Completion (Locked) with data
                      & "0" & s_tlp_typecode & "0" & s_tlp_attr(2 downto 2) & "00"
                      & "00" & s_tlp_attr(1 downto 0) & "00" & s_tlp_length;
            if s_tlp_type = memory_read and rx_state = read_stall and tx_rdy_i = '1' then
              r_tx_alloc <= '1';
              r_tx_wb_stb <= '1';
            end if;
          when put_h1 =>
            -- s_bytes: depends on first_be/last_be: set on exit of get_h1
            tx_wb_dat_o <= cfg_busdev_i & "0000000" & s_bytes;
            if rx_state /= get_h1 and tx_rdy_i = '1' then
              r_tx_alloc <= '1';
              r_tx_wb_stb <= '1';
            end if;
          when put_h2 =>
            -- s_low_addr: set on exit of h2 and h3
            tx_wb_dat_o <= s_tlp_id & "0" & s_low_addr;
            tx_tail <= (s_tlp_length(0) xor s_alignbit) = '1';
            if rx_state /= get_h2 and rx_state /= get_h3 and tx_rdy_i = '1' then
              r_tx_alloc <= '1';
              r_tx_wb_stb <= '1';
            end if;
          when put_pad =>
            if tx_rdy_i = '1' then
              r_tx_alloc <= '1';
              r_tx_wb_stb <= '1';
            end if;
          when flight_stall => 
            null;
          when ack_wait => 
            tx_wb_dat_o <= wb_dat_i;
            if r_pending_ack = 1 then
              tx_eop_o <= '1';
            end if;
            if (wb_ack_i or wb_err_i or wb_rty_i) = '1' then
              r_tx_wb_stb <= '1';
              r_pending_ack <= r_pending_ack - 1;
            end if;
          when put_tail =>
            if tx_rdy_i = '1' then
              r_tx_alloc <= '1';
              r_tx_wb_stb <= '1';
              tx_eop_o <= '1';
            end if;
        end case;
      end if;
    end if;
  end process;
  
  flight_counter : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rstn_i = '0' then
        r_flight_count <= (others => '0');
      else
        if (wb_ack_i or wb_err_i or wb_rty_i) = '1' then
          if (wb_stb and not wb_stall_i) = '1' then
            r_flight_count <= r_flight_count;
          else
            r_flight_count <= r_flight_count - 1;
          end if;
        else
          if (wb_stb and not wb_stall_i) = '1' then
            r_flight_count <= r_flight_count + 1;
          else
            r_flight_count <= r_flight_count;
          end if;
        end if;
      end if;
    end if;
  end process;
end rtl;
