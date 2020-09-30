  library ieee;
  use ieee.std_logic_1164.all;

  entity gc_ds182x_readout_tb is
  end gc_ds182x_readout_tb;

  architecture behav of gc_ds182x_readout_tb is
    constant C_PERIOD_NS : time := 500 ns;
    constant g_CLOCK_FREQ_KHZ : integer := 1_000_000 ns / C_PERIOD_NS;
    signal clk     :  std_logic := '0';
    signal rst_n   :  std_logic;
    signal onewire :  std_logic;                     -- IO to be connected to the chip(DS1820/DS1822)
    signal onewire_b : std_logic;
    signal id      :  std_logic_vector(63 downto 0); -- id_o value
    signal temper  :  std_logic_vector(15 downto 0); -- temperature value (refreshed every second)
    signal id_read :  std_logic;                     -- id_o value is valid_o
    signal id_ok  :   std_logic;                    -- Same as id_read_o, but not reset with rst_n_i
    signal pps : std_logic := '0';
    signal pps_cnt : natural;
  begin
    dut: entity work.gc_ds182x_readout
      generic map (
        g_CLOCK_FREQ_KHZ => g_CLOCK_FREQ_KHZ,
        g_USE_INTERNAL_PPS => False)
        port map (
          clk_i => clk,
          rst_n_i => rst_n,
          pps_p_i => pps,
          onewire_b => onewire_b,
          id_o => id,
          temper_o => temper,
          id_read_o => id_read,
          id_ok_o => id_ok
        );

    clk <= not clk after C_PERIOD_NS / 2;

    process (clk) is
    begin
      if rising_edge(clk) then
        pps_cnt <= pps_cnt + 1;
        --  Cheat on pps: one pulse every 10 ms, to speed up simulation
        if pps_cnt = 10 ms / C_PERIOD_NS then
          pps <= '1';
          pps_cnt <= 0;
        else
          pps <= '0';
        end if;
      end if;
    end process;

    --  Pull-up on onewire
    onewire_b <= 'H';
    onewire <= to_x01 (onewire_b);

    process
    begin
      rst_n <= '0';
      wait for C_PERIOD_NS * 2;
      rst_n <= '1';

      wait;
    end process;

    blk_slave: block
      type ow_lstate_t is (UNSYNC, IDLE, START, WAIT_END, RESET,
                          PRESENCE_WAIT, PRESENCE_PULSE);
      signal state: ow_lstate_t := UNSYNC;
      signal count : natural;
      signal ow_byte : std_logic_vector (7 downto 0);
      signal ow_tx : std_logic_vector(7 downto 0);
      signal bit_cnt : natural;
      signal ow_rst : std_logic := '0';
      signal ow_dat : std_logic := '0';
      signal ow_rd  : std_logic := '1';

      type ow_hstate_t is (WAIT_RST, WAIT_CMD, TX_REPLY);
      signal hstate : ow_hstate_t := WAIT_RST;
      signal ow_cmd : std_logic_vector (7 downto 0);
    begin
      --  Dummy DS1852
      proc_low: process
        variable val : std_logic;
      begin
        count <= count + 1;
        onewire_b <= 'Z';
        ow_rst <= '0';
        ow_dat <= '0';
        case state is
          when UNSYNC =>
            if onewire = '1' then
              state <= IDLE;
            end if;
          when IDLE =>
            if onewire = '0' then
              --  Start of slot
              state <= START;
              count <= 0;
            end if;
          when START =>
            if ow_rd = '1' and count = 30 then
              --  Sample
              val := onewire;
              ow_byte <= onewire & ow_byte(7 downto 1);
              if bit_cnt = 7 then
                ow_dat <= '1';
                bit_cnt <= 0;
              else
                bit_cnt <= bit_cnt + 1;
              end if;
              state <= WAIT_END;
            elsif ow_rd = '0' then
              if count = 0 then
                if bit_cnt = 0 then
                  ow_byte <= ow_tx;
                end if;
              elsif count < 45 then
                if ow_byte (0) = '0' then
                  onewire_b <= '0';
                end if;
              else
                onewire_b <= 'Z';
                if bit_cnt = 7 then
                  bit_cnt <= 0;
                  ow_dat <= '1';
                else
                  ow_byte (6 downto 0) <= ow_byte (7 downto 1);
                  bit_cnt <= bit_cnt + 1;
                end if;
                state <= WAIT_END;
              end if;
            end if;
          when WAIT_END =>
            if onewire = '1' then
              state <= IDLE;
            end if;
            if count > 470 then
              state <= RESET;
              ow_rst <= '1';
            end if;
          when RESET =>
            if onewire = '1' then
              state <= PRESENCE_WAIT;
              count <= 0;
              bit_cnt <= 0;
            end if;
          when PRESENCE_WAIT =>
            if count = 40 then
              state <= PRESENCE_PULSE;
              count <= 0;
            end if;
          when PRESENCE_PULSE =>
            onewire_b <= '0';
            if count = 100 then
              onewire_b <= 'Z';
              state <= UNSYNC;
            end if;
        end case;
        wait for 1 us;
      end process;

      proc_h: process (ow_rst, ow_dat)
        variable reply : std_logic_vector (0 to 71);
        variable rep_len : natural;
      begin
        case hstate is
          when WAIT_RST =>
            if ow_rst = '1' then
              report "DS182x: reset";
              ow_rd <= '1';
              hstate <= WAIT_CMD;
            end if;
          when WAIT_CMD =>
            if ow_dat = '1' then
              report "DS182x: cmd " & to_hstring(ow_byte);
              ow_cmd <= ow_byte;
              if ow_byte = x"33" then
                --  Read ROM
                reply := x"28_12_34_56_78_9a_bc_1e_00";
                rep_len := 8;
                hstate <= TX_REPLY;
              elsif ow_byte = x"cc" then
                -- Skip ROM
                hstate <= WAIT_CMD;
              elsif ow_byte = x"44" then
                -- Convert
                -- TODO: send status.
                hstate <= WAIT_CMD;
              elsif ow_byte = x"be" then
                --  Read scratchpad
                reply := x"50_05_11_22_1f_ff_00_10_2e";
                rep_len := 9;
                hstate <= TX_REPLY;
              end if;
            end if;
          when TX_REPLY =>
            ow_tx <= reply (0 to 7);
            ow_rd <= '0';
            if ow_dat = '1' then
              reply (0 to reply'right - 8) := reply (8 to reply'right);
              rep_len := rep_len - 1;
              if rep_len = 0 then
                ow_rd <= '1';
                hstate <= WAIT_CMD;
              end if;
            end if;
        end case;
      end process;
    end block blk_slave;
  end behav;
