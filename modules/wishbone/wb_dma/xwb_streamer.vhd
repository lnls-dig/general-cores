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
  signal slave : t_wishbone_slave_in;
begin

  slave.cyc <= '1';
  slave.stb <= '1';
  slave.we  <= '1';
  slave.adr <= x"00000010"; -- transfer count
  slave.sel <= (others => '1');
  slave.dat <= (others => '1');
  
  dma: xwb_dma
    generic map(
      logRingLen => logRingLen)
    port map(
      clk_i       => clk_i,
      rst_n_i     => rst_n_i,
      slave_i     => slave,
      slave_o     => open,
      r_master_i  => r_master_i,
      r_master_o  => r_master_o,
      w_master_i  => w_master_i,
      w_master_o  => w_master_o,
      interrupt_o => open);

end rtl;
