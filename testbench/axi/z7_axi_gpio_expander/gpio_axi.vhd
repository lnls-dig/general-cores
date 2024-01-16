-- SPDX-FileCopyrightText: 2023 CERN (home.cern)
--
-- SPDX-License-Identifier: CERN-OHL-W-2.0+

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi_gpio is
  port (
    aclk                 : in    std_logic;
    areset_n             : in    std_logic;
    awvalid              : in    std_logic;
    awready              : out   std_logic;
    awaddr               : in    std_logic_vector(15 downto 2);
    awprot               : in    std_logic_vector(2 downto 0);
    wvalid               : in    std_logic;
    wready               : out   std_logic;
    wdata                : in    std_logic_vector(31 downto 0);
    wstrb                : in    std_logic_vector(3 downto 0);
    bvalid               : out   std_logic;
    bready               : in    std_logic;
    bresp                : out   std_logic_vector(1 downto 0);
    arvalid              : in    std_logic;
    arready              : out   std_logic;
    araddr               : in    std_logic_vector(15 downto 2);
    arprot               : in    std_logic_vector(2 downto 0);
    rvalid               : out   std_logic;
    rready               : in    std_logic;
    rdata                : out   std_logic_vector(31 downto 0);
    rresp                : out   std_logic_vector(1 downto 0);

    -- Bank0 out register
    out_b0_o             : out   std_logic_vector(31 downto 0);

    -- Bank1 out register
    out_b1_o             : out   std_logic_vector(31 downto 0);

    -- Bank0 in register
    in_b0_i              : in    std_logic_vector(31 downto 0);

    -- Bank1 in register
    in_b1_i              : in    std_logic_vector(31 downto 0);

    -- Bank0 dir register
    dir_b0_o             : out   std_logic_vector(31 downto 0);

    -- Bank0 oen register
    oen_b0_o             : out   std_logic_vector(31 downto 0);

    -- Bank1 dir register
    dir_b1_o             : out   std_logic_vector(31 downto 0);

    -- Bank1 oen register
    oen_b1_o             : out   std_logic_vector(31 downto 0)
  );
end axi_gpio;

architecture syn of axi_gpio is
  signal rd_int                         : std_logic;
  signal wr_int                         : std_logic;
  signal rd_ack_int                     : std_logic;
  signal wr_ack_int                     : std_logic;
  signal dato                           : std_logic_vector(31 downto 0);
  signal axi_wip                        : std_logic;
  signal axi_wdone                      : std_logic;
  signal axi_rip                        : std_logic;
  signal axi_rdone                      : std_logic;
  signal out_b0_reg                     : std_logic_vector(31 downto 0);
  signal out_b1_reg                     : std_logic_vector(31 downto 0);
  signal dir_b0_reg                     : std_logic_vector(31 downto 0);
  signal oen_b0_reg                     : std_logic_vector(31 downto 0);
  signal dir_b1_reg                     : std_logic_vector(31 downto 0);
  signal oen_b1_reg                     : std_logic_vector(31 downto 0);
  signal reg_rdat_int                   : std_logic_vector(31 downto 0);
  signal rd_ack1_int                    : std_logic;
begin

  -- AW, W and B channels
  wr_int <= (awvalid and wvalid) and not axi_wip;
  awready <= axi_wip and wr_ack_int;
  wready <= axi_wip and wr_ack_int;
  bvalid <= axi_wdone;
  process (aclk, areset_n) begin
    if areset_n = '0' then
      axi_wip <= '0';
      axi_wdone <= '0';
    elsif rising_edge(aclk) then
      axi_wip <= (awvalid and wvalid) and not axi_wdone;
      axi_wdone <= wr_ack_int or (axi_wdone and not bready);
    end if;
  end process;
  bresp <= "00";

  -- AR and R channels
  rd_int <= arvalid and not axi_rip;
  arready <= axi_rip and rd_ack_int;
  rvalid <= axi_rdone;
  process (aclk, areset_n) begin
    if areset_n = '0' then
      axi_rip <= '0';
      axi_rdone <= '0';
      rdata <= (others => '0');
    elsif rising_edge(aclk) then
      axi_rip <= arvalid and not axi_rdone;
      if rd_ack_int = '1' then
        rdata <= dato;
      end if;
      axi_rdone <= rd_ack_int or (axi_rdone and not rready);
    end if;
  end process;
  rresp <= "00";

  -- Assign outputs
  out_b0_o <= out_b0_reg;
  out_b1_o <= out_b1_reg;
  dir_b0_o <= dir_b0_reg;
  oen_b0_o <= oen_b0_reg;
  dir_b1_o <= dir_b1_reg;
  oen_b1_o <= oen_b1_reg;

  -- Process for write requests.
  process (aclk, areset_n) begin
    if areset_n = '0' then
      wr_ack_int <= '0';
      out_b0_reg <= "00000000000000000000000000000000";
      out_b1_reg <= "00000000000000000000000000000000";
      dir_b0_reg <= "00000000000000000000000000000000";
      oen_b0_reg <= "00000000000000000000000000000000";
      dir_b1_reg <= "00000000000000000000000000000000";
      oen_b1_reg <= "00000000000000000000000000000000";
    elsif rising_edge(aclk) then
      wr_ack_int <= '0';
      case awaddr(15 downto 2) is
      when "10100000010000" =>
        -- Register out_b0
        if wr_int = '1' then
          out_b0_reg <= wdata;
        end if;
        wr_ack_int <= wr_int;
      when "10100000010001" =>
        -- Register out_b1
        if wr_int = '1' then
          out_b1_reg <= wdata;
        end if;
        wr_ack_int <= wr_int;
      when "10100000011000" =>
        -- Register in_b0
      when "10100000011001" =>
        -- Register in_b1
      when "10100010000001" =>
        -- Register dir_b0
        if wr_int = '1' then
          dir_b0_reg <= wdata;
        end if;
        wr_ack_int <= wr_int;
      when "10100010000010" =>
        -- Register oen_b0
        if wr_int = '1' then
          oen_b0_reg <= wdata;
        end if;
        wr_ack_int <= wr_int;
      when "10100010010001" =>
        -- Register dir_b1
        if wr_int = '1' then
          dir_b1_reg <= wdata;
        end if;
        wr_ack_int <= wr_int;
      when "10100010010010" =>
        -- Register oen_b1
        if wr_int = '1' then
          oen_b1_reg <= wdata;
        end if;
        wr_ack_int <= wr_int;
      when others =>
        wr_ack_int <= wr_int;
      end case;
    end if;
  end process;

  -- Process for registers read.
  process (aclk, areset_n) begin
    if areset_n = '0' then
      rd_ack1_int <= '0';
      reg_rdat_int <= (others => 'X');
    elsif rising_edge(aclk) then
      reg_rdat_int <= (others => '0');
      case araddr(15 downto 2) is
      when "10100000010000" =>
        -- out_b0
        rd_ack1_int <= rd_int;
      when "10100000010001" =>
        -- out_b1
        rd_ack1_int <= rd_int;
      when "10100000011000" =>
        -- in_b0
        reg_rdat_int <= in_b0_i;
        rd_ack1_int <= rd_int;
      when "10100000011001" =>
        -- in_b1
        reg_rdat_int <= in_b1_i;
        rd_ack1_int <= rd_int;
      when "10100010000001" =>
        -- dir_b0
        rd_ack1_int <= rd_int;
      when "10100010000010" =>
        -- oen_b0
        rd_ack1_int <= rd_int;
      when "10100010010001" =>
        -- dir_b1
        rd_ack1_int <= rd_int;
      when "10100010010010" =>
        -- oen_b1
        rd_ack1_int <= rd_int;
      when others =>
        rd_ack1_int <= rd_int;
      end case;
    end if;
  end process;

  -- Process for read requests.
  process (araddr, reg_rdat_int, rd_ack1_int, rd_int) begin
    -- By default ack read requests
    dato <= (others => '0');
    case araddr(15 downto 2) is
    when "10100000010000" =>
      -- out_b0
      dato <= reg_rdat_int;
      rd_ack_int <= rd_ack1_int;
    when "10100000010001" =>
      -- out_b1
      dato <= reg_rdat_int;
      rd_ack_int <= rd_ack1_int;
    when "10100000011000" =>
      -- in_b0
      dato <= reg_rdat_int;
      rd_ack_int <= rd_ack1_int;
    when "10100000011001" =>
      -- in_b1
      dato <= reg_rdat_int;
      rd_ack_int <= rd_ack1_int;
    when "10100010000001" =>
      -- dir_b0
      dato <= reg_rdat_int;
      rd_ack_int <= rd_ack1_int;
    when "10100010000010" =>
      -- oen_b0
      dato <= reg_rdat_int;
      rd_ack_int <= rd_ack1_int;
    when "10100010010001" =>
      -- dir_b1
      dato <= reg_rdat_int;
      rd_ack_int <= rd_ack1_int;
    when "10100010010010" =>
      -- oen_b1
      dato <= reg_rdat_int;
      rd_ack_int <= rd_ack1_int;
    when others =>
      rd_ack_int <= rd_int;
    end case;
  end process;
end syn;
