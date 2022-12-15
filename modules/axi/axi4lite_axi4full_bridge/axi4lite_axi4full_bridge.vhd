-------------------------------------------------------------------------------
-- Title      : AXI4Full64 to AXI4Lite32 bridge
-- Project    : General Cores
-------------------------------------------------------------------------------
-- File       : axi4lite32_axi4full64_bridge.vhd
-- Company    : CERN
-- Platform   : FPGA-generics
-- Standard   : VHDL '93
-------------------------------------------------------------------------------
-- Copyright (c) 2019 CERN
--
-- Copyright and related rights are licensed under the Solderpad Hardware
-- License, Version 0.51 (the "License") (which enables you, at your option,
-- to treat this file as licensed under the Apache License 2.0); you may not
-- use this file except in compliance with the License. You may obtain a copy
-- of the License at http://solderpad.org/licenses/SHL-0.51.
-- Unless required by applicable law or agreed to in writing, software,
-- hardware and materials distributed under this License is distributed on an
-- "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
-- or implied. See the License for the specific language governing permissions
-- and limitations under the License.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi4lite_axi4full_bridge is
  generic (
    g_ADDR_WIDTH : natural := 32;
    g_DATA_WIDTH : natural := 32;
    g_ID_WIDTH : natural := 4;
    g_LEN_WIDTH : natural := 8
  );
  port (
    clk_i   : in std_logic;
    rst_n_i : in std_logic;

    --  AXI4-Full slave
    s_awaddr  : in  STD_LOGIC_VECTOR (g_ADDR_WIDTH - 1 downto 0);
    s_awlen   : in  STD_LOGIC_VECTOR (g_LEN_WIDTH - 1 downto 0);
    s_awsize  : in  STD_LOGIC_VECTOR (2 downto 0);
    s_awburst : in  STD_LOGIC_VECTOR (1 downto 0);
    s_awid    : in  STD_LOGIC_VECTOR (g_ID_WIDTH - 1 downto 0);
    s_awvalid : in  STD_LOGIC;
    s_awready : out STD_LOGIC;

    s_wdata   : in  STD_LOGIC_VECTOR (g_DATA_WIDTH - 1 downto 0);
    s_wstrb   : in  STD_LOGIC_VECTOR ((g_DATA_WIDTH / 8) - 1 downto 0);
    s_wid     : in  STD_LOGIC_VECTOR (g_ID_WIDTH - 1 downto 0);
    s_wlast   : in  STD_LOGIC;
    s_wvalid  : in  STD_LOGIC;
    s_wready  : out STD_LOGIC;

    s_bid     : out STD_LOGIC_VECTOR (g_ID_WIDTH - 1 downto 0);
    s_bresp   : out STD_LOGIC_VECTOR (1 downto 0);
    s_bvalid  : out STD_LOGIC;
    s_bready  : in  STD_LOGIC;

    s_araddr  : in  STD_LOGIC_VECTOR (g_ADDR_WIDTH - 1 downto 0);
    s_arlen   : in  STD_LOGIC_VECTOR (g_LEN_WIDTH - 1 downto 0);
    s_arsize  : in  STD_LOGIC_VECTOR (2 downto 0);
    s_arburst : in  STD_LOGIC_VECTOR (1 downto 0);
    s_arid    : in  STD_LOGIC_VECTOR (g_ID_WIDTH - 1 downto 0);
    s_arvalid : in  STD_LOGIC;
    s_arready : out STD_LOGIC;

    s_rdata   : out STD_LOGIC_VECTOR (g_DATA_WIDTH - 1 downto 0);
    s_rid     : out STD_LOGIC_VECTOR (g_ID_WIDTH - 1 downto 0);
    s_rresp   : out STD_LOGIC_VECTOR (1 downto 0);
    s_rlast   : out STD_LOGIC;
    s_rvalid  : out STD_LOGIC;
    s_rready  : in  STD_LOGIC;

    --  AXI4-Lite master
    m_awaddr  : out STD_LOGIC_VECTOR (g_ADDR_WIDTH - 1 downto 0);
    m_awvalid : out STD_LOGIC;
    m_awready : in  STD_LOGIC;

    m_wdata   : out  STD_LOGIC_VECTOR (g_DATA_WIDTH - 1 downto 0);
    m_wstrb   : out  STD_LOGIC_VECTOR ((g_DATA_WIDTH / 8) - 1 downto 0);
    m_wvalid  : out  STD_LOGIC;
    m_wready  : in   STD_LOGIC;

    m_bresp   : in  STD_LOGIC_VECTOR (1 downto 0);
    m_bvalid  : in  STD_LOGIC;
    m_bready  : out STD_LOGIC;

    m_araddr  : out STD_LOGIC_VECTOR (g_ADDR_WIDTH - 1 downto 0);
    m_arvalid : out STD_LOGIC;
    m_arready : in  STD_LOGIC;

    m_rdata   : in  STD_LOGIC_VECTOR (g_DATA_WIDTH - 1 downto 0);
    m_rresp   : in  STD_LOGIC_VECTOR (1 downto 0);
    m_rvalid  : in  STD_LOGIC;
    m_rready  : out STD_LOGIC
    );
end axi4lite_axi4full_bridge;

architecture behav of axi4lite_axi4full_bridge is
  constant RSP_OKAY   : std_logic_vector(1 downto 0) := b"00";
  constant RSP_EXOKAY : std_logic_vector(1 downto 0) := b"01";
  constant RSP_SLVERR : std_logic_vector(1 downto 0) := b"10";
  constant RSP_DECERR : std_logic_vector(1 downto 0) := b"11";

  type t_wr_state is (WR_IDLE,
                      WR_MASTER, WR_SLAVE, WR_SLAVE2, WR_WAIT, WR_DONE);
  type t_rd_state is (RD_IDLE, RD_READ, RD_SLAVE);

  signal wstate : t_wr_state;
  signal rstate : t_rd_state;

  signal waddr : std_logic_vector(g_ADDR_WIDTH - 1 downto 0);
  signal wlen : std_logic_vector(g_LEN_WIDTH - 1 downto 0);
  signal wsize : std_logic_vector(2 downto 0);
  signal wdata  : std_logic_vector(g_DATA_WIDTH - 1 downto 0);
  signal wstrb : std_logic_vector((g_DATA_WIDTH / 8) - 1 downto 0);
  signal wid : std_logic_vector(g_ID_WIDTH - 1 downto 0);

  signal raddr : std_logic_vector(g_ADDR_WIDTH - 1 downto 0);
  signal rlen : std_logic_vector(g_LEN_WIDTH - 1 downto 0);
  signal rsize : std_logic_vector(2 downto 0);
  signal rdata  : std_logic_vector(g_DATA_WIDTH - 1 downto 0);
  signal rid : std_logic_vector(g_ID_WIDTH - 1 downto 0);
begin
  --  Write part.
  m_awaddr <= waddr;
  m_wdata <= wdata;
  m_wstrb <= wstrb;
  s_bid <= wid;

  process (clk_i)
  begin
    if rising_edge (clk_i) then
      if rst_n_i = '0' then
        wstate <= WR_IDLE;
        s_awready <= '1';
        s_wready <= '0';
        s_bvalid <= '0';
        m_awvalid <= '0';
        m_wvalid <= '0';
        m_bready <= '0';
      else
        case wstate is
          when WR_IDLE =>
            --  Wait until awvalid is ready.
            if s_awvalid = '1' then
              --  Save transaction parameters
              waddr <= s_awaddr;
              wlen <= s_awlen;
              wsize <= s_awsize;
              wid <= s_awid;

              --  Not anymore ready for addresses.
              s_awready <= '0';
              --  But ready for data.
              s_wready <= '1';

              wstate <= WR_MASTER;
            end if;

          when WR_MASTER =>
            --  Clear wvalid when coming from WR_SLAVE.
            m_wvalid <= '0';

            if s_wvalid = '1' then
              --  Got data from master.
              wdata <= s_wdata;
              wstrb <= s_wstrb;
              s_wready <= '0';

              --  Address cycle.
              m_awvalid <= '1';
              wstate <= WR_SLAVE;
            end if;

          when WR_SLAVE =>
            if m_awready = '1' then
              --  Wait for address ack.
              m_awvalid <= '0';
            end if;

            --  Prepare data write cycle.
            m_wvalid <= '1';
            wstate <= WR_SLAVE2;

          when WR_SLAVE2 =>
            if m_awready = '1' then
              --  Wait for address ack.
              m_awvalid <= '0';
            end if;

            if m_wready = '1' then
              --  Data ack.
              m_wvalid <= '0';
              m_bready <= '1';
              wstate <= WR_WAIT;
            end if;

          when WR_WAIT =>
            --  End of transfer ?
            if m_bvalid = '1' then
              m_bready <= '0';

              if wlen = (g_LEN_WIDTH - 1 downto 0 => '0') then
                --  End of the burst.
                s_bresp <= RSP_OKAY;
                s_bvalid <= '1';
                wstate <= WR_DONE;
              else
                wlen <= std_logic_vector(unsigned(wlen) - 1);
                --  TODO: adjust address.
                s_wready <= '1';
                wstate <= WR_MASTER;
              end if;
            end if;

          when WR_DONE =>
            if s_bready = '1' then
              s_bvalid <= '0';
              s_awready <= '1';

              wstate <= WR_IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;


  --  Read part.
  m_araddr <= raddr;
  s_rdata <= rdata;
  s_rid <= rid;

  process (clk_i)
  begin
    if rising_edge (clk_i) then
      if rst_n_i = '0' then
        rstate <= RD_IDLE;
        s_arready <= '1';
        s_rvalid <= '0';
        s_rlast <= '0';
        m_arvalid <= '0';
        m_rready <= '0';
        raddr <= (others => 'X');
        rdata <= (others => '0');
      else
        case rstate is
          when RD_IDLE =>
            --  Wait until awvalid is ready.
            if s_arvalid = '1' then
              --  Save transaction parameters
              raddr <= s_araddr;
              rlen <= s_arlen;
              rsize <= s_arsize;
              rid <= s_arid;

              --  Provide a clean result.
              rdata <= (others => '0');

              --  Not anymore ready for addresses.
              s_arready <= '0';

              --  Start transfer on the slave part.
              m_arvalid <= '1';
              m_rready <= '1';

              rstate <= RD_READ;
            end if;

          when RD_READ =>
            if m_arready = '1' then
              --  Address has been accepted.
              m_arvalid <= '0';
            end if;
            if m_rvalid = '1' then
              --  Read data.  Address must have been acked.
              --  According to A3.4.3 of AXI4 spec, the AXI4 bus is little
              --  endian.
              rdata <= m_rdata;
              --  End of transfer on the master ?
              --  To master.
              rstate <= RD_SLAVE;
              s_rresp <= RSP_OKAY;
              if rlen = (g_LEN_WIDTH - 1 downto 0 => '0') then
                s_rlast <= '1';
              else
                s_rlast <= '0';
              end if;
              s_rvalid <= '1';
            end if;

          when RD_SLAVE =>
            if s_rready = '1' then
              s_rvalid <= '0';
              if rlen = (g_LEN_WIDTH - 1 downto 0 => '0') then
                --  End of the burst.
                s_arready <= '1';
                rstate <= RD_IDLE;
              else
                rlen <= std_logic_vector(unsigned(rlen) - 1);

                --  TODO: adjust address.

                --  New beat.
                m_arvalid <= '1';
                m_rready <= '1';
                rstate <= RD_READ;
              end if;
            end if;
        end case;
      end if;
    end if;
  end process;
end behav;
