library ieee;
use ieee.std_logic_1164.all;

use work.wishbone_pkg.all;

entity tb_wb16_to_wb32 is
end;

architecture behav of tb_wb16_to_wb32 is
    signal clk : std_logic;
    signal rst_n : std_logic;

    signal wb16_in : t_wishbone_master_in;
    signal wb16_out : t_wishbone_master_out;

    signal wb32_in : t_wishbone_slave_in;
    signal wb32_out : t_wishbone_slave_out;

    signal reg1 : std_logic_vector(31 downto 0);
    signal reg0 : std_logic_vector(31 downto 0);

    signal done : boolean := false;
begin
    dut: entity work.wb16_to_wb32
      port map (
        clk_i => clk,
        rst_n_i => rst_n,
        wb16_i => wb16_out,
        wb16_o => wb16_in,
        wb32_i => wb32_out,
        wb32_o => wb32_in
      );

    process
    begin
        clk <= '0';
        wait for 5 ns;
        clk <= '1';
        wait for 5 ns;
        if done then
            wait;
        end if;
    end process;

    --  Simple slave with 2 registers.
    process (clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                reg1 <= x"4400_3300";
                reg0 <= x"2200_1100";
                wb32_out.ack <= '0';
            else
                if wb32_in.cyc = '1' and wb32_in.stb = '1' then
                    if wb32_in.we = '1' then
                        if wb32_in.adr (2) = '1' then
                            reg1 <= wb32_in.dat;
                        else
                            reg0 <= wb32_in.dat;
                        end if;
                    else
                        if wb32_in.adr (2) = '1' then
                            wb32_out.dat <= reg1;
                        else
                            wb32_out.dat <= reg0;
                        end if;
                    end if;
                    wb32_out.ack <= '1';
                else
                    wb32_out.ack <= '0';
                end if;
            end if;
        end if;
    end process;

    process
        procedure wait_ack is
        begin
            loop
                wait until rising_edge (clk);
                exit when wb16_in.ack = '1';
            end loop;
        end wait_ack;

        procedure read16 (addr : std_logic_vector (31 downto 0)) is
        begin
            wb16_out.adr <= addr;
            wb16_out.we <= '0';
            wb16_out.cyc <= '1';
            wb16_out.stb <= '1';
            wait_ack;
        end read16;

        procedure write16 (addr : std_logic_vector (31 downto 0); dat : std_logic_vector(15 downto 0)) is
        begin
            wb16_out.adr <= addr;
            wb16_out.dat (15 downto 0) <= dat;
            wb16_out.we <= '1';
            wb16_out.sel <= "0011";
            wb16_out.cyc <= '1';
            wb16_out.stb <= '1';
            wait_ack;
        end write16;
    begin
        rst_n <= '0';
        wait until rising_edge (clk);
        wait until rising_edge (clk);
        rst_n <= '1';

        read16 (x"0000_0000");
        assert wb16_in.dat (15 downto 0) = x"1100" severity failure;

        read16 (x"0000_0002");
        assert wb16_in.dat (15 downto 0) = x"2200" severity failure;

        read16 (x"0000_0004");
        assert wb16_in.dat (15 downto 0) = x"3300" severity failure;

        read16 (x"0000_0006");
        assert wb16_in.dat (15 downto 0) = x"4400" severity failure;

        write16(x"0000_0002", x"0220");
        write16(x"0000_0000", x"0110");

        read16 (x"0000_0000");
        assert wb16_in.dat (15 downto 0) = x"0110" severity failure;

        read16 (x"0000_0002");
        assert wb16_in.dat (15 downto 0) = x"0220" severity failure;

        done <= true;
        report "done";
        wait;
    end process;
end behav;