library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.wishbone_pkg.all;

package sim_wishbone16 is
    --  PL: pipelined versions.
    
    procedure write16_pl (signal clk : std_logic;
                          signal wb_o: out t_wishbone_master_out;
                          signal wb_i: in  t_wishbone_master_in;
                          addr : natural;
                          data : std_logic_vector (15 downto 0));
    procedure read16_pl (signal clk : std_logic;
                         signal wb_o: out t_wishbone_master_out;
                         signal wb_i: in  t_wishbone_master_in;
                         addr : natural;
                         data : out std_logic_vector (15 downto 0));
    procedure write64be_pl (signal clk : std_logic;
                         signal wb_o: out t_wishbone_master_out;
                         signal wb_i: in  t_wishbone_master_in;
                         addr : natural;
                         data : std_logic_vector (63 downto 0));
    procedure read64be_pl (signal clk : std_logic;
                        signal wb_o: out t_wishbone_master_out;
                        signal wb_i: in  t_wishbone_master_in;
                        addr : natural;
                        data : out std_logic_vector (63 downto 0));
end sim_wishbone16;

use work.sim_wishbone.all;

package body sim_wishbone16 is
    procedure write16_pl (signal clk : std_logic;
                          signal wb_o: out t_wishbone_master_out;
                          signal wb_i: in  t_wishbone_master_in;
                          addr : natural;
                          data : std_logic_vector (15 downto 0)) is
    begin
        write32_pl(clk, wb_o, wb_i, addr, x"0000" & data);
    end write16_pl;

    procedure read16_pl (signal clk : std_logic;
                         signal wb_o: out t_wishbone_master_out;
                         signal wb_i: in  t_wishbone_master_in;
                         addr : natural;
                         data : out std_logic_vector (15 downto 0))
    is
        variable t : std_logic_vector(31 downto 0);
    begin
        read32_pl(clk, wb_o, wb_i, addr, t);
        data := t(15 downto 0);
    end read16_pl;

    procedure write64be_pl (signal clk : std_logic;
                         signal wb_o: out t_wishbone_master_out;
                         signal wb_i: in  t_wishbone_master_in;
                         addr : natural;
                         data : std_logic_vector (63 downto 0)) is
    begin
        write32_pl(clk, wb_o, wb_i, addr + 0, x"0000" & data (63 downto 48));
        write32_pl(clk, wb_o, wb_i, addr + 2, x"0000" & data (47 downto 32));
        write32_pl(clk, wb_o, wb_i, addr + 4, x"0000" & data (31 downto 16));
        write32_pl(clk, wb_o, wb_i, addr + 6, x"0000" & data (15 downto 00));
    end write64be_pl;

    procedure read64be_pl (signal clk : std_logic;
                        signal wb_o: out t_wishbone_master_out;
                        signal wb_i: in  t_wishbone_master_in;
                        addr : natural;
                        data : out std_logic_vector (63 downto 0))
    is
        variable t : std_logic_vector(31 downto 0);
    begin
        read32_pl(clk, wb_o, wb_i, addr + 0, t);
        data (63 downto 48) := t(15 downto 0);
        read32_pl(clk, wb_o, wb_i, addr + 2, t);
        data (47 downto 32) := t(15 downto 0);
        read32_pl(clk, wb_o, wb_i, addr + 4, t);
        data (31 downto 16) := t(15 downto 0);
        read32_pl(clk, wb_o, wb_i, addr + 6, t);
        data (15 downto 00) := t(15 downto 0);
    end read64be_pl;
end sim_wishbone16;
