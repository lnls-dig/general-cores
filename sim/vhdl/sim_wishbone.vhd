library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.wishbone_pkg.all;

package sim_wishbone is
    --  PL: pipelined versions.
    
    procedure write32_pl (signal clk : std_logic;
                          signal wb_o: out t_wishbone_master_out;
                          signal wb_i: in  t_wishbone_master_in;
                          addr : std_logic_vector (31 downto 0);
                          data : std_logic_vector (31 downto 0));
    procedure read32_pl (signal clk : std_logic;
                         signal wb_o: out t_wishbone_master_out;
                         signal wb_i: in  t_wishbone_master_in;
                         addr : std_logic_vector (31 downto 0);
                         data : out std_logic_vector (31 downto 0));
    procedure write32_pl (signal clk : std_logic;
                         signal wb_o: out t_wishbone_master_out;
                         signal wb_i: in  t_wishbone_master_in;
                         addr : natural;
                         data : std_logic_vector (31 downto 0));
    procedure read32_pl (signal clk : std_logic;
                         signal wb_o: out t_wishbone_master_out;
                         signal wb_i: in  t_wishbone_master_in;
                         addr : natural;
                         data : out std_logic_vector (31 downto 0));
end sim_wishbone;

package body sim_wishbone is
    --  Generate a strobe pulse.
    procedure start_pl (signal clk : std_logic;
                        signal wb_o: out t_wishbone_master_out;
                        signal wb_i: in  t_wishbone_master_in) is
    begin
        wb_o.stb <= '1';
        loop
            wait until rising_edge(clk);
            exit when wb_i.stall = '0';
        end loop;
        wb_o.stb <= '0';
    end start_pl;

    procedure wait_ack (signal clk : std_logic;
                        signal wb_o: out t_wishbone_master_out;
                        signal wb_i: in  t_wishbone_master_in) is
    begin
        loop
            exit when wb_i.ack = '1';
            wait until rising_edge(clk);
        end loop;
        wb_o.cyc <= '0';
        wb_o.adr <= (others => 'X');
        wb_o.dat <= (others => 'X');
    end wait_ack;

    procedure write32_pl (signal clk : std_logic;
                          signal wb_o: out t_wishbone_master_out;
                          signal wb_i: in  t_wishbone_master_in;
                          addr : std_logic_vector (31 downto 0);
                          data : std_logic_vector (31 downto 0)) is
    begin
        wb_o.adr <= addr;
        wb_o.dat <= data;
        wb_o.sel <= "1111";
        wb_o.we <= '1';
        wb_o.cyc <= '1';

        start_pl (clk, wb_o, wb_i);
        wait_ack (clk, wb_o, wb_i);
    end write32_pl;

    procedure read32_pl (signal clk : std_logic;
                         signal wb_o: out t_wishbone_master_out;
                         signal wb_i: in  t_wishbone_master_in;
                         addr : std_logic_vector (31 downto 0);
                         data : out std_logic_vector (31 downto 0)) is
    begin
        wb_o.adr <= addr;
        wb_o.we <= '0';
        wb_o.cyc <= '1';

        start_pl (clk, wb_o, wb_i);
        wait_ack (clk, wb_o, wb_i);
        data := wb_i.dat;
    end read32_pl;

    procedure write32_pl (signal clk : std_logic;
                         signal wb_o: out t_wishbone_master_out;
                         signal wb_i: in  t_wishbone_master_in;
                         addr : natural;
                         data : std_logic_vector (31 downto 0)) is
    begin
        write32_pl (clk, wb_o, wb_i, std_logic_vector (to_unsigned(addr, 32)), data);
    end write32_pl;

    procedure read32_pl (signal clk : std_logic;
                         signal wb_o: out t_wishbone_master_out;
                         signal wb_i: in  t_wishbone_master_in;
                         addr : natural;
                         data : out std_logic_vector (31 downto 0)) is
    begin
       read32_pl (clk, wb_o, wb_i, std_logic_vector (to_unsigned(addr, 32)), data);
    end read32_pl;
                    
end sim_wishbone;
