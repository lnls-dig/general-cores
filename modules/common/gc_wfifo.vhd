library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.gencores_pkg.all;

entity gc_wfifo is
   generic(
      sync_depth : natural := 3;
      gray_code  : boolean := true;
      addr_width : natural := 4;
      data_width : natural := 32);
   port(
      rst_n_i  : in  std_logic;
      -- write port, only set w_en when w_rdy
      w_clk_i  : in  std_logic;
      w_rdy_o  : out std_logic;
      w_en_i   : in  std_logic;
      w_data_i : in  std_logic_vector(data_width-1 downto 0);
      -- (pre)alloc port, can be unused
      a_clk_i  : in  std_logic;
      a_rdy_o  : out std_logic;
      a_en_i   : in  std_logic;
      -- read port, only set r_en when r_rdy
      -- data is valid the cycle after r_en raised
      r_clk_i  : in  std_logic;
      r_rdy_o  : out std_logic;
      r_en_i   : in  std_logic;
      r_data_o : out std_logic_vector(data_width-1 downto 0));
end gc_wfifo;

architecture rtl of gc_wfifo is
   subtype counter is unsigned(addr_width downto 0);
   type counter_shift is array(sync_depth downto 0) of counter;
   
   signal r_idx_bnry : counter;
   signal r_idx_gray : counter;
   signal w_idx_bnry : counter;
   signal w_idx_gray : counter;
   signal a_idx_bnry : counter;
   signal a_idx_gray : counter;
   
   signal r_idx_shift_w : counter_shift; -- r_idx_gray in w_clk
   signal r_idx_shift_a : counter_shift; -- r_idx_gray in a_clk
   signal w_idx_shift_r : counter_shift; -- w_idx_gray in r_clk
   
   attribute altera_attribute : string; 
   -- Quartus 11 sometimes goes crazy and infers an altshift_taps! Stop it.
   attribute altera_attribute of r_idx_shift_w : signal is "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF";
   attribute altera_attribute of r_idx_shift_a : signal is "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF";
   attribute altera_attribute of w_idx_shift_r : signal is "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF";
   
   function bin2gray(a : unsigned) return unsigned is
      variable o : unsigned(a'length downto 0);
   begin
      if gray_code then
         o := (a & '0') xor ('0' & a);
      else
         o := (a & '0');
      end if;
      return o(a'length downto 1);
   end bin2gray;
   
   function index(a : counter) return std_logic_vector is
   begin
      return std_logic_vector(a(addr_width-1 downto 0));
   end index;
   
   function empty(a, b : counter) return std_logic is
   begin
      if a = b then
         return '1';
      else
         return '0';
      end if;
   end empty;
   
   function full(a, b : counter) return std_logic is
      variable mask : counter := (others => '0');
   begin
      -- In binary a full FIFO has indexes (a XOR 1000...00) = b
      -- bin2gray is a linear function, thus:
      --   a XOR 1000..00 = b                                iff
      --   bin2gray(a XOR 1000...00) = bin2gray(b)           iff
      --   bin2gray(a) XOR bin2gray(1000...00) = bin2gray(b) iif
      --   bin2gray(a) XOR 1100..00 = bin2gray(b)
      mask(addr_width) := '1';
      mask := bin2gray(mask);
      if (a xor mask) = b then
         return '1';
      else
         return '0';
      end if;
   end full;
begin
   ram : gc_dual_clock_ram
      generic map(addr_width => addr_width, data_width => data_width)
      port map(w_clk_i => w_clk_i, w_en_i => w_en_i, w_addr_i => index(w_idx_bnry), w_data_i => w_data_i,
               r_clk_i => r_clk_i, r_en_i => r_en_i, r_addr_i => index(r_idx_bnry), r_data_o => r_data_o);
   
   read : process(r_clk_i)
      variable idx : counter;
   begin
      if rising_edge(r_clk_i) then
         if rst_n_i = '0' then
            idx := (others => '0');
         elsif r_en_i = '1' then
            idx := r_idx_bnry + 1;
         else
            idx := r_idx_bnry;
         end if;
         r_idx_bnry <= idx;
         r_idx_gray <= bin2gray(idx);
         w_idx_shift_r(sync_depth downto 1) <= w_idx_shift_r(sync_depth-1 downto 0);
      end if;
   end process;
   w_idx_shift_r(0) <= w_idx_gray;
   r_rdy_o <= not empty(r_idx_gray, w_idx_shift_r(sync_depth));
   
   write : process(w_clk_i)
     variable idx : counter;
   begin
      if rising_edge(w_clk_i) then
         if rst_n_i = '0' then
            idx := (others => '0');
         elsif w_en_i = '1' then
            idx := w_idx_bnry + 1;
         else
            idx := w_idx_bnry;
         end if;
         w_idx_bnry <= idx;
         w_idx_gray <= bin2gray(idx);
         r_idx_shift_w(sync_depth downto 1) <= r_idx_shift_w(sync_depth-1 downto 0);
      end if;
   end process;
   r_idx_shift_w(0) <= r_idx_gray;
   w_rdy_o <= not full(w_idx_gray, r_idx_shift_w(sync_depth));

   alloc : process(a_clk_i)
     variable idx : counter;
   begin
      if rising_edge(a_clk_i) then
         if rst_n_i = '0' then
            idx := (others => '0');
         elsif a_en_i = '1' then
            idx := a_idx_bnry + 1;
         else
            idx := a_idx_bnry;
         end if;
         a_idx_bnry <= idx;
         a_idx_gray <= bin2gray(idx);
         r_idx_shift_a(sync_depth downto 1) <= r_idx_shift_a(sync_depth-1 downto 0);
      end if;
   end process;
   r_idx_shift_a(0) <= r_idx_gray;
   a_rdy_o <= not full(a_idx_gray, r_idx_shift_a(sync_depth));
end rtl;
