--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General cores: Indirect Wishbone Slave
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   xwb_indirect
--
-- description: This design is a wishbone slave that drivers a wishbone master.
--   As a slave, it has 2 registers: address and data.  An access to the data
--   register starts a transaction on the WB master side using the address of
--   the address register.  At the end of the transaction, the address
--   register is incremented by 4.
--
--------------------------------------------------------------------------------
-- Copyright CERN 2020
--------------------------------------------------------------------------------
-- Copyright and related rights are licensed under the Solderpad Hardware
-- License, Version 2.0 (the "License"); you may not use this file except
-- in compliance with the License. You may obtain a copy of the License at
-- http://solderpad.org/licenses/SHL-2.0.
-- Unless required by applicable law or agreed to in writing, software,
-- hardware and materials distributed under this License is distributed on an
-- "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
-- or implied. See the License for the specific language governing permissions
-- and limitations under the License.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wishbone_pkg.all;

entity xwb_indirect is
  generic (
    mode : t_wishbone_interface_mode := PIPELINED
  );
  port (
    rst_n_i     : in    std_logic;
    clk_i       : in    std_logic;
    wb_i        : in    t_wishbone_slave_in;
    wb_o        : out   t_wishbone_slave_out;

    master_wb_i : in    t_wishbone_master_in;
    master_wb_o : out   t_wishbone_master_out
  );
end xwb_indirect;

architecture arch of xwb_indirect is
  --  Address register.  Use a specific register to auto-increment it.
  signal addr         : std_logic_vector(31 downto 0);

  signal addr_out     : std_logic_vector(31 downto 0);
  signal addr_wr_out  : std_logic;
  signal data         : std_logic_vector(31 downto 0);
  signal data_out     : std_logic_vector(31 downto 0);
  signal data_wr_out  : std_logic;
  signal data_rd_out  : std_logic;
  signal data_wack_in : std_logic;
  signal data_rack_in : std_logic;

  type t_state is (IDLE, READ, WRITE);
  signal state : t_state;

  signal stb : std_logic;
  signal we : std_logic;
begin
  process (clk_i)
  begin
    if rising_edge (clk_i) then
      if rst_n_i = '0' then
        state <= IDLE;
        data_wack_in <= '0';
        data_rack_in <= '0';
        data <= (others => '0');
        addr <= (others => '0');
        stb <= '0';
        we <= '0';
      else
        data_wack_in <= '0';
        data_rack_in <= '0';

        --  Write to the address register.
        if addr_wr_out = '1' then
          addr <= addr_out;
        end if;

        case state is
          when IDLE =>
            if data_wr_out = '1' then
              we <= '1';
              stb <= '1';
              --  Capture the data.
              data <= data_out;
              state <= WRITE;
            elsif data_rd_out = '1' then
              we <= '1';
              stb <= '1';
              state <= READ;
            end if;
          when WRITE
            | READ =>
            if mode = PIPELINED then
              --  STB is asserted for one cycle in piplined mode.
              stb <= '0';
            end if;

            if master_wb_i.ack = '1'
              or master_wb_i.err = '1'
              or master_wb_i.rty = '1'
            then
              --  End of transaction (for classic mode).
              stb <= '0';

              --  Ack the master.
              if state = WRITE then
                data_wack_in <= '1';
              else
                --  Capture the data.
                data <= master_wb_i.dat;
                data_rack_in <= '1';
              end if;
              addr <= std_logic_vector(unsigned(addr) + 4);
              state <= IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;

  master_wb_o <= (cyc => stb,
                  stb => stb,
                  adr => addr,
                  sel => "1111",
                  we  => we,
                  dat => data);

  inst_regs: entity work.wb_indirect_regs
    port map (
      rst_n_i     => rst_n_i,
      clk_i       => clk_i,
      wb_i        => wb_i,
      wb_o        => wb_o,
      addr_i      => addr,
      addr_o      => addr_out,
      addr_wr_o   => addr_wr_out,
      data_i      => data,
      data_o      => data_out,
      data_wr_o   => data_wr_out,
      data_rd_o   => data_rd_out,
      data_wack_i => data_wack_in,
      data_rack_i => data_rack_in);
end arch;
