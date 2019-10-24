library ieee;
use ieee.std_logic_1164.all;

entity tb_gc_sync_word_wr is
end;

architecture arch of tb_gc_sync_word_wr is
  signal din, dout : std_logic_vector(7 downto 0);
  signal clki, clko : std_logic := '0';
  signal rsti, rsto : std_logic;
  signal wri, wro : std_logic;
  signal ack : std_logic;
begin
  clki <= not clki after 10 ns;
  clko <= not clko after 7 ns;

  rsti <= '0', '1' after 30 ns;
  rsto <= '0', '1' after 25 ns;

  cmp_tb : entity work.gc_sync_word_wr
    generic map (
      width => 8)
    port map (
      clk_in_i => clki,
      rst_in_n_i => rsti,
      clk_out_i => clko,
      rst_out_n_i => rsto,
      data_i => din,
      wr_i => wri,
      ack_o => ack,
      data_o => dout,
      wr_o => wro);

  process
    procedure send_value (dat : std_logic_vector(7 downto 0)) is
    begin
      din <= dat;
      wait until rising_edge(clki);
      wri <= '1';
      wait until rising_edge(clki);
      wri <= '0';
    end send_value;

    --  Wait until ack.
    procedure wait_ack is
    begin
      loop
        wait until rising_edge(clki);
        exit when ack = '1';
      end loop;
    end wait_ack;
  begin
    wri <= '0';
    wait until rsti = '1';
    wait until rising_edge(clki);

    send_value(x"a5");
    wait_ack;

    send_value(x"7b");
    wait_ack;

    wait;
  end process;
end arch;
