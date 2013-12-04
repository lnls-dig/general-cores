library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gc_rr_arbiter is
  
  generic (
    g_size : integer := 19);

  port (
    clk_i   : in  std_logic;
    rst_n_i : in  std_logic;
    req_i   : in  std_logic_vector(g_size-1 downto 0);
    grant_o : out std_logic_vector(g_size-1 downto 0);
    grant_comb_o: out std_logic_vector(g_size-1 downto 0)
   );

  attribute opt_mode: string;
  attribute opt_mode of gc_rr_arbiter: entity is "speed";
  attribute resource_sharing: string;
  attribute resource_sharing of gc_rr_arbiter: entity is "no";
end gc_rr_arbiter;


architecture rtl of gc_rr_arbiter is



  component gc_prio_encoder
    generic (
      g_width : integer);
    port (
      d_i     : in  std_logic_vector(g_width-1 downto 0);
      therm_o : out std_logic_vector(g_width-1 downto 0));
  end component;

  signal req_m, th_m, th_u, mux_out, mask : std_logic_vector(g_size-1 downto 0);
  
begin  -- rtl

 req_m<=req_i and mask;
 
  U_PE1 : gc_prio_encoder
    generic map (
      g_width => g_size)
    port map (
      d_i     => req_m,
      therm_o => th_m);

  U_PE2 : gc_prio_encoder
    generic map (
      g_width => g_size)
    port map (
      d_i     => req_i,
      therm_o => th_u);

  
  process(th_u, th_m)
  begin
    if(th_m(th_m'length - 1) = '0') then
      mux_out <= th_u;
    else
      mux_out <= th_m;
    end if;
  end process;

 
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        mask    <= (others => '0');
        grant_o <= (others => '0');
      else
        mask <= mux_out(g_size-2 downto 0) & '0';
        grant_o <= not (mux_out(g_size-2 downto 0) & '0') and mux_out;
      end if;
    end if;
  end process;

 grant_comb_o <= not (mux_out(g_size-2 downto 0) & '0') and mux_out;

end rtl;
