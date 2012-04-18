library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pcie_tlp is
  port(
    clk_i         : in std_logic;
    rstn_i        : in std_logic;
    
    rx_wb_stb_i   : in  std_logic;
    rx_wb_bar_i   : in  std_logic;
    rx_wb_dat_i   : in  std_logic_vector(31 downto 0);
    rx_wb_stall_o : out std_logic;
    
    tx_rdy_i      : in  std_logic;
    tx_alloc_o    : out std_logic;
    tx_en_o       : out std_logic;
    tx_dat_o      : out std_logic_vector(31 downto 0);
    tx_eop_o      : out std_logic;
    
    cfg_busdev_i  : in  std_logic_vector(12 downto 0);
    
    wb_stb_o      : out std_logic;
    wb_adr_o      : out std_logic_vector(63 downto 0);
    wb_we_o       : out std_logic;
    wb_dat_o      : out std_logic_vector(31 downto 0);
    wb_sel_o      : out std_logic_vector(3 downto 0);
    wb_stall_i    : in  std_logic;
    wb_ack_i      : in  std_logic;
    wb_err_i      : in  std_logic;
    wb_dat_i      : in  std_logic_vector(31 downto 0));
end pcie_tlp;

architecture rtl of pcie_tlp is
  type rx_state_type is (h0, h_completion1, h_completion2, h_request, h_high_addr, h_low_addr, p_w0, p_wx, p_we, p_rs, p_r0, p_rx, p_re);
  type tx_state_type is (c0, c1, c2, c_block, c_queue);
  
  signal rx_state : rx_state_type := h0;
  signal tx_state : tx_state_type := c0;
  
  -- Bar0 Registers
  -- signal csr     : std_logic_vector(63 downto 0); -- bit0: CYC
  -- signal error   : std_logic_vector(63 downto 0);
  -- signal address : std_logic_vector(63 downto 0);
  -- signal sdwb    : std_logic_vector(63 downto 0);
  
  -- Header fields
  signal s_fmttype     : std_logic_vector(7 downto 0);
  signal s_attr        : std_logic_vector(2 downto 0);
  signal s_tc          : std_logic_vector(2 downto 0);
  signal s_length      : unsigned(9 downto 0);
  signal s_transaction : std_logic_vector(23 downto 0);
  signal s_last_be     : std_logic_vector(3 downto 0);
  signal s_first_be    : std_logic_vector(3 downto 0);
  
  signal s_missing     : unsigned(2 downto 0);
  signal s_bytes       : std_logic_vector(11 downto 0);
  signal s_low_addr    : std_logic_vector(6 downto 0);
  
  signal r_fmttype     : std_logic_vector(7 downto 0);
  signal r_attr        : std_logic_vector(2 downto 0);
  signal r_tc          : std_logic_vector(2 downto 0);
  signal r_length      : unsigned(9 downto 0);
  signal r_transaction : std_logic_vector(23 downto 0);
  signal r_last_be     : std_logic_vector(3 downto 0);
  signal r_first_be    : std_logic_vector(3 downto 0);
  signal r_address     : std_logic_vector(63 downto 0);
  
  -- Common subexpressions:
  signal s_length_m1 : unsigned(9 downto 0);
  signal s_length_eq1, s_length_eq2 : boolean;
  signal s_address_p4 : std_logic_vector(63 downto 0);
  
  -- Stall and strobe bypass mux
  signal r_always_stall, r_never_stall : std_logic;
  signal r_always_stb,   r_never_stb   : std_logic;
  
  -- Inflight reads and writes
  signal wb_stb : std_logic;
  signal r_flight_count : unsigned(4 downto 0);
  
  signal r_tx_en, r_tx_alloc, r_rx_alloc : std_logic;
  signal r_pending_ack : unsigned(9 downto 0);
begin
  rx_wb_stall_o <= r_always_stall or (not r_never_stall and wb_stall_i);
  wb_stb <= r_always_stb or (not r_never_stb and rx_wb_stb_i);
  wb_stb_o <= wb_stb;
  wb_adr_o <= r_address;
  wb_dat_o <= rx_wb_dat_i;
  
  -- Fields in the rx_data
  s_fmttype     <= rx_wb_dat_i(31 downto 24);
  s_tc          <= rx_wb_dat_i(22 downto 20);
  s_attr        <= rx_wb_dat_i(18) & rx_wb_dat_i(13 downto 12);
  s_length      <= unsigned(rx_wb_dat_i(9 downto 0));
  s_transaction <= rx_wb_dat_i(31 downto 8);
  s_last_be     <= rx_wb_dat_i(7 downto 4);
  s_first_be    <= rx_wb_dat_i(3 downto 0);
  
  s_length_m1  <= r_length - 1;
  s_length_eq1 <= r_length = 1;
  s_length_eq2 <= r_length = 2;
  
  s_address_p4 <= r_address(63 downto 24) & 
                  std_logic_vector(unsigned(r_address(23 downto 0)) + to_unsigned(4, 24));
  
  rx_state_machine : process(clk_i) is
    variable next_state : rx_state_type;
  begin
    if rising_edge(clk_i) then
      if rstn_i = '0' then
        rx_state <= h0;
      else
      
        ----------------- Pre-transition actions --------------------
        case rx_state is
          when h0 =>
            r_fmttype <= s_fmttype;
            r_length  <= s_length;
            r_attr    <= s_attr;
            r_tc      <= s_tc;
          when h_completion1 => null;
          when h_completion2 =>
            r_transaction <= s_transaction;
          when h_request =>
            r_transaction <= s_transaction;
            r_last_be     <= s_last_be;
            r_first_be    <= s_first_be;
            r_address     <= (others => '0');
          when h_high_addr =>
            r_address(63 downto 32) <= rx_wb_dat_i(31 downto 0);
          when h_low_addr =>
            -- address also stores busnum/devnum/ext/reg for IO ops
            r_address(31 downto 2) <= rx_wb_dat_i(31 downto 2);
          when p_w0 => null;
          when p_wx => null;
          when p_we => null;
          when p_rs => null;
          when p_r0 => null;
          when p_rx => null;
          when p_re => null;
        end case;
              
        ----------------- Transition rules --------------------
        next_state := rx_state;
        case rx_state is
          when h0 =>
            if rx_wb_stb_i = '1' then
              if s_fmttype(3) = '1' then
                next_state := h_completion1;
              else
                next_state := h_request;
              end if;
            end if;
          when h_completion1 =>
            if rx_wb_stb_i = '1' then
              next_state := h_completion2;
            end if;
          when h_completion2 =>
            if rx_wb_stb_i = '1' then
              if r_fmttype(6) = '1' then
                next_state := p_w0; --  !!! go to some other state
              else
                next_state := h0;
              end if;
            end if;
          when h_request =>
            if rx_wb_stb_i = '1' then
              if r_fmttype(5) = '1' then
                next_state := h_high_addr;
              else
                next_state := h_low_addr;
              end if;
            end if;
          when h_high_addr =>
            if rx_wb_stb_i = '1' then
              next_state := h_low_addr;
            end if;
          when h_low_addr =>
            if rx_wb_stb_i = '1' then
              if r_fmttype(6) = '1' then
                next_state := p_w0;
              else
                next_state := p_rs;
              end if;
            end if;
          when p_w0 =>
            if (rx_wb_stb_i and not wb_stall_i) = '1' then
              if s_length_eq1 then
                next_state := h0;
              elsif s_length_eq2 then
                next_state := p_we;
              else
                next_state := p_wx;
              end if;
              r_length <= s_length_m1;
              r_address <= s_address_p4;
            end if;
          when p_wx =>
            if (rx_wb_stb_i and not wb_stall_i) = '1' then
              if s_length_eq2 then
                next_state := p_we;
              end if;
              r_length <= s_length_m1;
              r_address <= s_address_p4;
            end if;
          when p_we =>
            if (rx_wb_stb_i and not wb_stall_i) = '1' then
              next_state := h0;
            end if;
          when p_rs =>
            if tx_state = c_queue then
              next_state := p_r0;
            end if;
          when p_r0 =>
            if (not wb_stall_i) = '1' then
              if s_length_eq1 then
                next_state := h0;
              elsif s_length_eq2 then
                next_state := p_re;
              else
                next_state := p_rx;
              end if;
              r_length <= s_length_m1;
              r_address <= s_address_p4;
            end if;
          when p_rx =>
            if (not wb_stall_i) = '1' then
              if s_length_eq2 then
                next_state := p_re;
              end if;
              r_length <= s_length_m1;
              r_address <= s_address_p4;
            end if;
          when p_re =>
            if (not wb_stall_i) = '1' then
              next_state := h0;
            end if;
        end case;
        
        ----------------- Post-transition actions --------------------
        wb_we_o <= '-';
        wb_sel_o <= (others => '-');
        r_always_stall <= '0';
        r_never_stall <= '1' ;
        r_always_stb <= '0';
        r_never_stb <= '1';
        r_rx_alloc <= '0';
        
        rx_state <= next_state;
        case next_state is
          when h0 => null;
          when h_completion1 => null;
          when h_completion2 => null;
          when h_request => null;
          when h_high_addr => null;
          when h_low_addr => null;
          when p_w0 =>
            r_never_stall <= '0';
            r_never_stb <= '0';
            wb_sel_o <= r_first_be;
            wb_we_o <= '1';
          when p_wx =>
            r_never_stall <= '0';
            r_never_stb <= '0';
            wb_sel_o <= x"f";
            wb_we_o <= '1';
          when p_we =>
            r_never_stall <= '0';
            r_never_stb <= '0';
            wb_sel_o <= r_last_be;
            wb_we_o <= '1';
          when p_rs => null;
          when p_r0 =>
            r_always_stall <= '1';
            r_always_stb <= tx_rdy_i;
            r_rx_alloc <= tx_rdy_i;
            wb_sel_o <= r_first_be;
            wb_we_o <= '0';
          when p_rx =>
            r_always_stall <= '1';
            r_always_stb <= tx_rdy_i;
            r_rx_alloc <= tx_rdy_i;
            wb_sel_o <= x"f";
            wb_we_o <= '0';
          when p_re =>
            r_always_stall <= '1';
            r_always_stb <= tx_rdy_i;
            r_rx_alloc <= tx_rdy_i;
            wb_sel_o <= r_last_be;
            wb_we_o <= '0';
        end case;
      end if;
    end if;
  end process;
  
  -- These tables are copied from the PCI express standard:
  s_missing <= 
    "000" when std_match(r_first_be, "1--1") and std_match(r_last_be, "0000") else
    "001" when std_match(r_first_be, "01-1") and std_match(r_last_be, "0000") else
    "001" when std_match(r_first_be, "1-10") and std_match(r_last_be, "0000") else
    "010" when std_match(r_first_be, "0011") and std_match(r_last_be, "0000") else
    "010" when std_match(r_first_be, "0110") and std_match(r_last_be, "0000") else
    "010" when std_match(r_first_be, "1100") and std_match(r_last_be, "0000") else
    "011" when std_match(r_first_be, "0001") and std_match(r_last_be, "0000") else
    "011" when std_match(r_first_be, "0010") and std_match(r_last_be, "0000") else
    "011" when std_match(r_first_be, "0100") and std_match(r_last_be, "0000") else
    "011" when std_match(r_first_be, "1000") and std_match(r_last_be, "0000") else
    "000" when std_match(r_first_be, "---1") and std_match(r_last_be, "1---") else
    "001" when std_match(r_first_be, "---1") and std_match(r_last_be, "01--") else
    "010" when std_match(r_first_be, "---1") and std_match(r_last_be, "001-") else
    "011" when std_match(r_first_be, "---1") and std_match(r_last_be, "0001") else
    "001" when std_match(r_first_be, "--10") and std_match(r_last_be, "1---") else
    "010" when std_match(r_first_be, "--10") and std_match(r_last_be, "01--") else
    "011" when std_match(r_first_be, "--10") and std_match(r_last_be, "001-") else
    "100" when std_match(r_first_be, "--10") and std_match(r_last_be, "0001") else
    "010" when std_match(r_first_be, "-100") and std_match(r_last_be, "1---") else
    "011" when std_match(r_first_be, "-100") and std_match(r_last_be, "01--") else
    "100" when std_match(r_first_be, "-100") and std_match(r_last_be, "001-") else
    "101" when std_match(r_first_be, "-100") and std_match(r_last_be, "0001") else
    "011" when std_match(r_first_be, "1000") and std_match(r_last_be, "1---") else
    "100" when std_match(r_first_be, "1000") and std_match(r_last_be, "01--") else
    "101" when std_match(r_first_be, "1000") and std_match(r_last_be, "001-") else
    "110" when std_match(r_first_be, "1000") and std_match(r_last_be, "0001") else
    "---";
  s_bytes <= std_logic_vector(unsigned(r_length & "00") - s_missing);
  
  s_low_addr(6 downto 2) <= r_address(6 downto 2);
  s_low_addr(1 downto 0) <= 
    "00" when std_match(r_first_be, "0000") else
    "00" when std_match(r_first_be, "---1") else
    "01" when std_match(r_first_be, "--10") else
    "10" when std_match(r_first_be, "-100") else
    "11" when std_match(r_first_be, "1000") else
    "--";
  
  -- register: tx_en_o and tx_alloc_o
  tx_en_o <= r_tx_en;
  tx_alloc_o <= r_tx_alloc or r_rx_alloc;
  tx_state_machine : process(clk_i) is
    variable next_state : tx_state_type;
  begin
    if rising_edge(clk_i) then
      if rstn_i = '0' then
        tx_state <= c0;
        r_tx_en <= '0';
        r_tx_alloc <= '0';
      else
        ----------------- Transition rules --------------------
        next_state := tx_state;
        case tx_state is
          when c0 =>
            if r_tx_en = '1' then
              next_state := c1;
            end if;
          when c1 =>
            if r_tx_en = '1' then
              next_state := c2;
            end if;
          when c2 =>
            if r_tx_en = '1' then
              if r_flight_count = 0 then
                next_state := c_queue;
              else
                next_state := c_block;
              end if;
            end if;
          when c_block =>
            if r_flight_count = 0 then
              next_state := c_queue;
            end if;
          when c_queue =>
            if r_pending_ack = 0 then
              next_state := c0;
            end if;
        end case;
        
        ----------------- Post-transition actions --------------------
        r_tx_en <= '0';
        r_tx_alloc <= '0';
        tx_eop_o <= '0';
        tx_dat_o <= (others => '-');
        
        tx_state <= next_state;
        case next_state is
          when c0 =>
            r_pending_ack <= r_length;
            -- r_length, r_tc, r_attr: all set on exit of h0
            tx_dat_o <= "01001010" -- Completion with data
                      & "0" & r_tc & "0" & r_attr(2 downto 2) & "00"
                      & "00" & r_attr(1 downto 0) & "00" & std_logic_vector(r_length);
            if r_fmttype(6) = '0' and r_fmttype(3) = '0' and rx_state /= h0 and tx_rdy_i = '1' then
              r_tx_alloc <= '1';
              r_tx_en <= '1';
            end if;
          when c1 =>
            -- s_bytes: depends on first_be/last_be: set on exit of h_request
            tx_dat_o <= cfg_busdev_i & "0000000" & s_bytes;
            if rx_state /= h_request and tx_rdy_i = '1' then
              r_tx_alloc <= '1';
              r_tx_en <= '1';
            end if;
          when c2 =>
            -- s_low_addr: set on exit of h_low_addr
            tx_dat_o <= r_transaction & "0" & s_low_addr;
            if rx_state /= h_high_addr and rx_state /= h_low_addr and tx_rdy_i = '1' then
              r_tx_alloc <= '1';
              r_tx_en <= '1';
            end if;
          when c_block => 
            null;
          when c_queue => 
            tx_dat_o <= wb_dat_i;
            if r_pending_ack = 1 then
              tx_eop_o <= '1';
            end if;
            if (wb_ack_i or wb_err_i) = '1' then
              r_tx_en <= '1';
              r_pending_ack <= r_pending_ack - 1;
            end if;
        end case;
      end if;
    end if;
  end process;
  
  flight_counter : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if (wb_ack_i or wb_err_i) = '1' then
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
  end process;
end rtl;
