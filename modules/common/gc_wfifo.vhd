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
      rst    : in  std_logic;
      -- write port, only set w_en when w_rdy
      w_clk  : in  std_logic;
      w_rdy  : out std_logic;
      w_en   : in  std_logic;
      w_data : in  std_logic_vector(data_width-1 downto 0);
      -- (pre)alloc port, can be unused
      a_clk  : in  std_logic;
      a_rdy  : out std_logic;
      a_en   : in  std_logic;
      -- read port, only set r_en when r_rdy
      -- data is valid the cycle after r_en raised
      r_clk  : in  std_logic;
      r_rdy  : out std_logic;
      r_en   : in  std_logic;
      r_data : out std_logic_vector(data_width-1 downto 0));
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
      port map(w_clk => w_clk, w_en => w_en, w_addr => index(w_idx_bnry), w_data => w_data,
               r_clk => r_clk, r_en => r_en, r_addr => index(r_idx_bnry), r_data => r_data);
   
   read : process(r_clk)
      variable idx : counter;
   begin
      if rising_edge(r_clk) then
         if rst = '1' then
            idx := (others => '0');
         elsif r_en = '1' then
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
   r_rdy <= not empty(r_idx_gray, w_idx_shift_r(sync_depth));
   
   write : process(w_clk)
     variable idx : counter;
   begin
      if rising_edge(w_clk) then
         if rst = '1' then
            idx := (others => '0');
         elsif w_en = '1' then
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
   w_rdy <= not full(w_idx_gray, r_idx_shift_w(sync_depth));

   alloc : process(a_clk)
     variable idx : counter;
   begin
      if rising_edge(a_clk) then
         if rst = '1' then
            idx := (others => '0');
         elsif a_en = '1' then
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
   a_rdy <= not full(a_idx_gray, r_idx_shift_a(sync_depth));
end rtl;
