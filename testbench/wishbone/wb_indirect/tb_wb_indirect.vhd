library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wishbone_pkg.all;
use work.sim_wishbone.all;

entity tb_wb_indirect is
end tb_wb_indirect;

architecture arch of tb_wb_indirect is
  signal rst_n         : std_logic;
  signal clk           : std_logic;
  signal wb_in         : t_wishbone_slave_in;
  signal wb_out        : t_wishbone_slave_out;
  signal master_wb_in  : t_wishbone_master_in;
  signal master_wb_out : t_wishbone_master_out;

  signal last_addr : std_logic_vector (31 downto 0);
  signal last_data : std_logic_vector (31 downto 0);
  --  For end of test.
  signal done : boolean := False;
begin
  --  Clock.
  process
  begin
    clk <= '0';
    wait for 4 ns;
    clk <= '1';
    wait for 4 ns;
    if done then
      report "end of test";
      wait;
    end if;
  end process;

  rst_n <= '0', '1' after 8 ns;

  --  Test process.
  process
    variable data : std_logic_vector (31 downto 0);
  begin
    wb_in.cyc <= '0';
    wb_in.stb <= '0';

    wait until rst_n = '1';
    wait until rising_edge (clk);

    --  Set the address.
    write32_pl (clk, wb_in, wb_out, x"0000_0000", x"0000_2300");

    wait until rising_edge (clk);

    --  Read data.
    read32_pl (clk, wb_in, wb_out, x"0000_0004", data);
    assert data = x"0000_2300";

    wait until rising_edge (clk);

    write32_pl (clk, wb_in, wb_out, x"0000_0004", x"1234_5678");
    assert last_addr = x"0000_2304";
    assert last_data = x"1234_5678";

    read32_pl (clk, wb_in, wb_out, x"0000_0004", data);
    assert data = x"0000_2308";
    assert last_data = x"1234_5678";

    done <= true;
    wait;
  end process;

  inst_xwb_indirect: entity work.xwb_indirect
    port map (
      rst_n_i     => rst_n,
      clk_i       => clk,
      wb_i        => wb_in,
      wb_o        => wb_out,
      master_wb_i => master_wb_in,
      master_wb_o => master_wb_out);

  --  WB slave.
  process (clk)
  begin
    if rising_edge (clk) then
      if rst_n = '0' then
        master_wb_in <= (rty => '0',
                         err => '0',
                         ack => '0',
                         stall => '0',
                         dat => (others => 'U'));
      else
        master_wb_in.ack <= '0';
        master_wb_in.stall <= '0';
        if (master_wb_out.cyc and master_wb_out.stb) = '1' then
          --  Start of transaction.
          last_addr <= master_wb_out.adr;
          if master_wb_out.we = '1' then
            last_data <= master_wb_out.dat;
          end if;
          master_wb_in.dat <= master_wb_out.adr;
          master_wb_in.ack <= '1';
          master_wb_in.stall <= '1';
        end if;
      end if;
    end if;
  end process;
end arch;
