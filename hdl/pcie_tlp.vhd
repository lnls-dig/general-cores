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
    
    wb_stb_o      : out std_logic;
    wb_adr_o      : out std_logic_vector(63 downto 0);
    wb_we_o       : out std_logic;
    wb_dat_o      : out std_logic_vector(31 downto 0);
    wb_sel_o      : out std_logic_vector(3 downto 0);
    wb_stall_i    : in  std_logic);
end pcie_tlp;

architecture rtl of pcie_tlp is
  type state_type is (h0, h_completion1, h_completion2, h_request, h_high_addr, h_low_addr, p_w0, p_wx, p_we, p_r0, p_rx, p_re);
  
  signal state : state_type := h0;
  signal progress : std_logic;
  
  -- Bar0 Registers
  -- signal csr     : std_logic_vector(63 downto 0); -- bit0: CYC
  -- signal error   : std_logic_vector(63 downto 0);
  -- signal address : std_logic_vector(63 downto 0);
  -- signal sdwb    : std_logic_vector(63 downto 0);
  
  -- Header fields
  signal s_fmttype     : std_logic_vector(7 downto 0);
  signal s_length      : unsigned(9 downto 0);
  signal s_transaction : std_logic_vector(23 downto 0);
  signal s_last_be     : std_logic_vector(3 downto 0);
  signal s_first_be    : std_logic_vector(3 downto 0);
  
  signal r_fmttype     : std_logic_vector(7 downto 0);
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
begin
  rx_wb_stall_o <= r_always_stall or (not r_never_stall and wb_stall_i);
  wb_stb_o <= r_always_stb or (not r_never_stb and rx_wb_stb_i);
  wb_adr_o <= r_address;
  wb_dat_o <= rx_wb_dat_i;
  
  -- Fields in the rx_data
  s_fmttype     <= rx_wb_dat_i(31 downto 24);
  s_length      <= unsigned(rx_wb_dat_i(9 downto 0));
  s_transaction <= rx_wb_dat_i(31 downto 8);
  s_last_be     <= rx_wb_dat_i(7 downto 4);
  s_first_be    <= rx_wb_dat_i(3 downto 0);
  
  s_length_m1  <= r_length - 1;
  s_length_eq1 <= r_length = 1;
  s_length_eq2 <= r_length = 2;
  
  s_address_p4 <= r_address(63 downto 24) & 
                  std_logic_vector(unsigned(r_address(23 downto 0)) + to_unsigned(4, 24));
  
  state_machine : process(clk_i) is
    variable next_state : state_type;
  begin
    if rising_edge(clk_i) then
      if rstn_i = '0' then
        state <= h0;
      else
      
        ----------------- Pre-transition actions --------------------
        case state is
          when h0 =>
            r_fmttype <= s_fmttype;
            r_length  <= s_length;
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
          when p_r0 => null;
          when p_rx => null;
          when p_re => null;
        end case;
              
        ----------------- Transition rules --------------------
        next_state := state;
        case state is
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
                next_state := p_r0;
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
        wb_we_o <= 'X';
        wb_sel_o <= (others => 'X');
        r_always_stall <= '0';
        r_never_stall <= '1' ;
        r_always_stb <= '0';
        r_never_stb <= '1';
        
        state <= next_state;
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
          when p_r0 =>
            r_always_stall <= '1';
            r_always_stb <= '1';
            wb_sel_o <= r_first_be;
            wb_we_o <= '0';
          when p_rx =>
            r_always_stall <= '1';
            r_always_stb <= '1';
            wb_sel_o <= x"f";
            wb_we_o <= '0';
          when p_re =>
            r_always_stall <= '1';
            r_always_stb <= '1';
            wb_sel_o <= r_last_be;
            wb_we_o <= '0';
        end case;
      end if;
    end if;
  end process;
end rtl;
