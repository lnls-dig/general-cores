--==============================================================================
-- CERN (BE-CO-HT)
-- Xilinx MultiBoot FSM
--==============================================================================
--
-- author: Theodor Stana (t.stana@cern.ch)
--
-- date of creation: 2013-08-19
--
-- version: 1.0
--
-- description:
--    The finite-state machine (FSM) module for the xil_multiboot module. Based
--    on input received from the MultiBoot module registers, it starts one of
--    three sequences:
--      - SPI      --  shift out up to three bytes (based on the NBYTES)
--                     value in FAR
--      - RDCFGREG --  read a configuration register from the Xilinx FPGA
--                     configuration logic
--      - IPROG    --  issue an IPROG command to the Xilinx FPGA configuration
--                     logic
--
-- references:
--  [1]   Xilinx UG380 Spartan-6 FPGA Configuration Guide v2.5
--        http://www.xilinx.com/support/documentation/user_guides/ug380.pdf
--
--==============================================================================
-- GNU LESSER GENERAL PUBLIC LICENSE
--==============================================================================
-- This source file is free software; you can redistribute it and/or modify it
-- under the terms of the GNU Lesser General Public License as published by the
-- Free Software Foundation; either version 2.1 of the License, or (at your
-- option) any later version. This source is distributed in the hope that it
-- will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
-- of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU Lesser General Public License for more details. You should have
-- received a copy of the GNU Lesser General Public License along with this
-- source; if not, download it from http://www.gnu.org/licenses/lgpl-2.1.html
--==============================================================================
-- last changes:
--    2013-08-19   Theodor Stana     t.stana@cern.ch     File created
--==============================================================================
-- TODO: -
--==============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gencores_pkg.all;

entity multiboot_fsm is
  port
  (
    -- Clock and reset inputs
    clk_i                : in  std_logic;
    rst_n_i              : in  std_logic;

    -- Control register inputs
    reg_rdcfgreg_i       : in  std_logic;
    reg_cfgregadr_i      : in  std_logic_vector(5 downto 0);
    reg_iprog_i          : in  std_logic;

    -- Multiboot and golden bitstream start addresses
    reg_gbbar_i          : in  std_logic_vector(31 downto 0);
    reg_mbbar_i          : in  std_logic_vector(31 downto 0);

    -- Outputs to status register
    reg_wdto_p_o         : out std_logic;
    reg_cfgreg_img_o     : out std_logic_vector(15 downto 0);
    reg_cfgreg_valid_o   : out std_logic;

    -- Flash access register signals
    reg_far_data_i       : in  std_logic_vector(23 downto 0);
    reg_far_data_o       : out std_logic_vector(23 downto 0);
    reg_far_nbytes_i     : in  std_logic_vector(1 downto 0);
    reg_far_xfer_i       : in  std_logic;
    reg_far_cs_i         : in  std_logic;
    reg_far_ready_o      : out std_logic;

    -- SPI master signals
    spi_xfer_o           : out std_logic;
    spi_cs_o             : out std_logic;
    spi_data_i           : in  std_logic_vector(7 downto 0);
    spi_data_o           : out std_logic_vector(7 downto 0);
    spi_ready_i          : in  std_logic;

    -- Ports for the external ICAP component
    icap_dat_i           : in  std_logic_vector(15 downto 0);
    icap_dat_o           : out std_logic_vector(15 downto 0);
    icap_busy_i          : in  std_logic;
    icap_ce_n_o          : out std_logic;
    icap_wr_n_o          : out std_logic
  );
end entity multiboot_fsm;


architecture behav of multiboot_fsm is

  --============================================================================
  -- Type declarations
  --============================================================================
  type t_state is
    (
      -- idle state
      IDLE,
      -- SPI states
      SPI_XFER1,
      SPI_XFER2,
      -- Config logic synchronization states
      DUMMY_1,
      DUMMY_2,
      SYNC_H,
      SYNC_L,
      SYNC_NOOP,
      -- IPROG states
      GEN_1,
      MBA_L,
      GEN_2,
      MBA_H,
      GEN_3,
      GBA_L,
      GEN_4,
      GBA_H,
      IPROG_CMD,
      IPROG,
      -- RDCFGREG read states
      RDCFGREG_CMD,
      RDCFGREG_NOOP_1,
      RDCFGREG_NOOP_2,
      RDCFGREG_NOOP_3,
      RDCFGREG_NOOP_4,
      RDCFGREG_SETRD_1,
      RDCFGREG_SETRD_2,
      RDCFGREG_SETRD_3,
      RDCFGREG,
      RDCFGREG_SETWR_1,
      RDCFGREG_SETWR_2,
      RDCFGREG_SETWR_3,
      DESYNC_CMD,
      DESYNC,
      -- NOOPs after RDCFGREG and IPROG sequences
      FINAL_NOOP_1,
      FINAL_NOOP_2,
      PREPARE_IDLE
    );

  --============================================================================
  -- Signal declarations
  --============================================================================
  signal state         : t_state;

  -- FSM command array (collection of trigger inputs from the MultiBoot
  -- registers) and a register to hold the command for later in the FSM
  signal fsm_cmd       : std_logic_vector(2 downto 0);
  signal fsm_cmd_reg   : std_logic_vector(2 downto 0);

  -- SPI signals
  signal spi_data_int  : std_logic_vector(23 downto 0);
  signal spi_cnt       : unsigned(1 downto 0);

  -- FSM watchdog signals
  signal rst_fr_wdt    : std_logic;
  signal rst_fr_wdt_d0 : std_logic;
  signal wdt_rst       : std_logic;

--==============================================================================
--  architecture begin
--==============================================================================
begin

  --============================================================================
  -- FSM logic
  --============================================================================
  -- Form state machine command vector from register inputs
  fsm_cmd <= reg_far_xfer_i &
             reg_iprog_i &
             reg_rdcfgreg_i;

  -- Assign SPI outputs
  spi_cs_o   <= reg_far_cs_i;
  spi_data_o <= spi_data_int(7 downto 0);

  -- The state machine process
  p_fsm : process(clk_i)
    variable v_idx : integer := 0;
  begin
    if rising_edge(clk_i) then
      if (rst_n_i = '0') or (rst_fr_wdt = '1') then
        state              <= IDLE;
        wdt_rst            <= '1';
        fsm_cmd_reg        <= (others => '0');
        icap_dat_o         <= (others => '0');
        icap_ce_n_o        <= '1';
        icap_wr_n_o        <= '1';
        reg_cfgreg_img_o   <= (others => '0');
        reg_cfgreg_valid_o <= '0';
        reg_far_ready_o    <= '1';
        reg_far_data_o     <= (others => '0');
        spi_data_int       <= (others => '0');
        spi_cnt            <= "00";
        spi_xfer_o         <= '0';

      else

        case state is

          --====================================================================
          -- IDLE: wait for a register bit to be set
          --====================================================================
          when IDLE =>
            icap_ce_n_o <= '1';
            icap_wr_n_o <= '1';
            fsm_cmd_reg <= fsm_cmd;
            wdt_rst     <= '1';
            case fsm_cmd is
              when "010" | "001" =>
                wdt_rst <= '0';
                state   <= DUMMY_1;
              when "100" =>
                spi_cnt         <= "00";
                spi_data_int    <= reg_far_data_i;
                reg_far_data_o  <= (others => '0');
                reg_far_ready_o <= '0';
                wdt_rst         <= '0';
                state           <= SPI_XFER1;
              when others =>
                state <= IDLE;
            end case;

          --====================================================================
          -- Flash read sequence
          --====================================================================
          -- set the transfer bit to the SPI master
          when SPI_XFER1 =>
            spi_xfer_o <= '1';
            state      <= SPI_XFER2;

          -- wait for SPI master to be ready and shift out new bytes, or go back
          -- to idle if we've finished the number of bytes we have to send
          when SPI_XFER2 =>
            spi_xfer_o <= '0';
            if (spi_ready_i = '1') then
              -- prepare next byte to be sent
              spi_cnt      <= spi_cnt + 1;
              spi_data_int <= x"00" & spi_data_int(23 downto 8);
              state        <= SPI_XFER1;
              -- if we've sent NBYTES, go back to IDLE
              if (spi_cnt = unsigned(reg_far_nbytes_i)) then
                reg_far_ready_o <= '1';
                state           <= IDLE;
              end if;
              -- finally, place the received byte in the appropriate position
              -- of the FAR data field
              v_idx := to_integer(unsigned(spi_cnt));
              reg_far_data_o((1+v_idx)*8 - 1 downto v_idx*8) <= spi_data_i;
            end if;

          --====================================================================
          -- Synchronization sequence + four NOOPs
          -- as per Table 6-1, p. 113 [1], steps 1-10
          --====================================================================
          -- two dummy words
          when DUMMY_1 =>
            icap_dat_o  <= x"ffff";
            icap_ce_n_o <= '0';
            icap_wr_n_o <= '0';
            state       <= DUMMY_2;

          when DUMMY_2 =>
            icap_dat_o  <= x"ffff";
            icap_ce_n_o <= '0';
            icap_wr_n_o <= '0';
            state       <= SYNC_H;

          -- now the two sync words
          when SYNC_H =>
            icap_dat_o  <= x"aa99";
            icap_ce_n_o <= '0';
            icap_wr_n_o <= '0';
            state       <= SYNC_L;

          when SYNC_L =>
            icap_dat_o  <= x"5566";
            icap_ce_n_o <= '0';
            icap_wr_n_o <= '0';
            state       <= SYNC_NOOP;

          -- and the NOOP after the sync words, after which we go to IPROG or
          -- RDCFGREG read, depending on what command we got at the beginning
          when SYNC_NOOP =>
            icap_dat_o <= x"2000";
            icap_ce_n_o <= '0';
            icap_wr_n_o <= '0';
            case fsm_cmd_reg is
              when "010" =>
                state <= GEN_1;
              when "001" =>
                state <= RDCFGREG_CMD;
              when others =>
                state <= IDLE;
            end case;

          --====================================================================
          -- IPROG sequence
          -- as per Table 7-1, p. 130 [1], starting from step 4 onward
          --====================================================================
          when GEN_1 =>
            icap_dat_o  <= x"3261";
            icap_ce_n_o <= '0';
            icap_wr_n_o <= '0';
            state       <= MBA_L;

          when MBA_L =>
            icap_dat_o  <= reg_mbbar_i(15 downto 0);
            icap_ce_n_o <= '0';
            icap_wr_n_o <= '0';
            state       <= GEN_2;

          when GEN_2 =>
            icap_dat_o  <= x"3281";
            icap_ce_n_o <= '0';
            icap_wr_n_o <= '0';
            state       <= MBA_H;

          when MBA_H =>
            icap_dat_o  <= reg_mbbar_i(31 downto 16);
            icap_ce_n_o <= '0';
            icap_wr_n_o <= '0';
            state       <= GEN_3;

          when GEN_3 =>
            icap_dat_o  <= x"32a1";
            icap_ce_n_o <= '0';
            icap_wr_n_o <= '0';
            state       <= GBA_L;

          when GBA_L =>
            icap_dat_o  <= reg_gbbar_i(15 downto 0);
            icap_ce_n_o <= '0';
            icap_wr_n_o <= '0';
            state       <= GEN_4;

          when GEN_4 =>
            icap_dat_o  <= x"32c1";
            icap_ce_n_o <= '0';
            icap_wr_n_o <= '0';
            state       <= GBA_H;

          when GBA_H =>
            icap_dat_o  <= reg_gbbar_i(31 downto 16);
            icap_ce_n_o <= '0';
            icap_wr_n_o <= '0';
            state       <= IPROG_CMD;

          when IPROG_CMD =>
            icap_dat_o  <= x"30a1";
            icap_ce_n_o <= '0';
            icap_wr_n_o <= '0';
            state       <= IPROG;

          when IPROG =>
            icap_dat_o  <= x"000e";
            icap_ce_n_o <= '0';
            icap_wr_n_o <= '0';
            state       <= FINAL_NOOP_1;

          --====================================================================
          -- RDCFGREG read sequence
          -- as per Table 6-1, p.113 [1], starting from step 6
          --====================================================================
          -- write type1 packet header to read CFGREGADR register
          -- (packet headers can be found on page 93 of [1])
          when RDCFGREG_CMD =>
            icap_ce_n_o <= '0';
            icap_wr_n_o <= '0';
            icap_dat_o  <= "001" & "01" & reg_cfgregadr_i & "00001";
            state       <= RDCFGREG_NOOP_1;

          -- then four noops
          when RDCFGREG_NOOP_1 =>
            icap_dat_o  <= x"2000";
            icap_ce_n_o <= '0';
            icap_wr_n_o <= '0';
            state       <= RDCFGREG_NOOP_2;

          when RDCFGREG_NOOP_2 =>
            icap_dat_o  <= x"2000";
            icap_ce_n_o <= '0';
            icap_wr_n_o <= '0';
            state       <= RDCFGREG_NOOP_3;

          when RDCFGREG_NOOP_3 =>
            icap_dat_o <= x"2000";
            icap_ce_n_o <= '0';
            icap_wr_n_o <= '0';
            state       <= RDCFGREG_NOOP_4;

          when RDCFGREG_NOOP_4 =>
            icap_dat_o <= x"2000";
            icap_ce_n_o <= '0';
            icap_wr_n_o <= '0';
            state       <= RDCFGREG_SETRD_1;

          -- smooth transition of the ICAP write input from write to read
          -- (keep CS high while changing WRITE)
          when RDCFGREG_SETRD_1 =>
            icap_ce_n_o <= '1';
            icap_wr_n_o <= '0';
            state       <= RDCFGREG_SETRD_2;

          when RDCFGREG_SETRD_2 =>
            icap_ce_n_o <= '1';
            icap_wr_n_o <= '1';
            state       <= RDCFGREG_SETRD_3;

          when RDCFGREG_SETRD_3 =>
            icap_ce_n_o <= '0';
            icap_wr_n_o <= '1';
            state       <= RDCFGREG;

          -- this is where we actually read the value of RDCFGREG;
          -- data retrieved by ICAP interface is valid when busy is low
          when RDCFGREG =>
            icap_ce_n_o <= '0';
            icap_wr_n_o <= '1';
            if (icap_busy_i = '0') then
              reg_cfgreg_img_o   <= icap_dat_i;
              reg_cfgreg_valid_o <= '1';
              state              <= RDCFGREG_SETWR_1;
            end if;

          -- smooth transition of the ICAP write input from read to write
          -- (keep CS high while changing WRITE)
          when RDCFGREG_SETWR_1 =>
            icap_ce_n_o <= '1';
            icap_wr_n_o <= '1';
            state       <= RDCFGREG_SETWR_2;

          when RDCFGREG_SETWR_2 =>
            icap_ce_n_o <= '1';
            icap_wr_n_o <= '0';
            state       <= RDCFGREG_SETWR_3;

          when RDCFGREG_SETWR_3 =>
            icap_ce_n_o <= '0';
            icap_wr_n_o <= '0';
            if (icap_busy_i = '0') then
              state <= DESYNC_CMD;
            end if;

          -- write 1 word to CMD register
          when DESYNC_CMD =>
            icap_ce_n_o <= '0';
            icap_wr_n_o <= '0';
            icap_dat_o  <= x"30a1";
            state       <= DESYNC;

          -- write the DESYNC command
          when DESYNC =>
            icap_ce_n_o <= '0';
            icap_wr_n_o <= '0';
            icap_dat_o  <= x"000d";
            state       <= FINAL_NOOP_1;

          --====================================================================
          -- Two NOOPs at end of all prog sequences
          --====================================================================
          when FINAL_NOOP_1 =>
            icap_ce_n_o <= '0';
            icap_wr_n_o <= '0';
            icap_dat_o  <= x"2000";
            state       <= FINAL_NOOP_2;

          when FINAL_NOOP_2 =>
            icap_ce_n_o <= '0';
            icap_wr_n_o <= '0';
            icap_dat_o  <= x"2000";
            state       <= PREPARE_IDLE;

          --====================================================================
          -- Prepare transition to CE='1', WR='1' in IDLE state
          --====================================================================
          when PREPARE_IDLE =>
            icap_ce_n_o <= '1';
            icap_wr_n_o <= '0';
            state       <= IDLE;

          --====================================================================
          -- Go to IDLE in case of state error
          --====================================================================
          when others =>
            state <= IDLE;

        end case;
      end if;
    end if;
  end process p_fsm;

  --============================================================================
  -- FSM watchdog instantiation
  --============================================================================
  -- Max. value calculation
  --    - FSM max. nr. of cycles
  --      22 cycles for states switching
  --      2x3 cycles waiting time for icap_busy_i signal (see [1], Table 6-3
  --      p.116) in the RDCFGREG states
  --      => max. ~32 cycles
  --    - SPI:
  --      8 bits per transfer
  --      3 bytes to transfer
  --      number of cycles for one transfer (resulting from simulation): 218
  --      value: 512 for safety
  cmp_fsm_watchdog : gc_fsm_watchdog
    generic map
    (
      g_wdt_max => 512
    )
    port map
    (
      clk_i     => clk_i,
      rst_n_i   => rst_n_i,
      wdt_rst_i => wdt_rst,
      fsm_rst_o => rst_fr_wdt
    );

  -- Set the watchdog timeout pulse output for a cycle when a reset occurs
  p_wdto_outp : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if (rst_n_i = '0') then
        rst_fr_wdt_d0 <= '0';
        reg_wdto_p_o  <= '0';
      else
        rst_fr_wdt_d0 <= rst_fr_wdt;
        reg_wdto_p_o  <= rst_fr_wdt and (not rst_fr_wdt_d0);
      end if;
    end if;
  end process p_wdto_outp;

end architecture behav;
--==============================================================================
--  architecture end
--==============================================================================
