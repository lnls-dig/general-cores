--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   secded_ecc
--
-- description: SECDED RAM controller
--
--------------------------------------------------------------------------------
-- Copyright CERN 2020-2021
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

use work.secded_32b_pkg.all;

entity secded_ecc is
  generic (
    g_addr_width : natural := 16
  );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;

    -- to the processor/bus
    a_i   : in std_logic_vector(g_addr_width-1 downto 0);
    d_i   : in std_logic_vector(31 downto 0);
    we_i  : in std_logic;
    bwe_i : in std_logic_vector (3 downto 0);
    re_i  : in std_logic;

    q_o      : out std_logic_vector(31 downto 0);
    done_r_o : out std_logic;
    done_w_o : out std_logic;

    --to the BRAM
    a_ram_o      : out std_logic_vector (g_addr_width-1 downto 0);
    d_ram_i      : in  std_logic_vector (38 downto 0);
    q_ram_o      : out std_logic_vector (38 downto 0);
    we_ram_o     : out std_logic;
    re_ram_o     : out std_logic;
    valid_ram_i  : in  std_logic;
    lock_req_o   : out std_logic;
    lock_grant_i : in  std_logic;

    single_error_p_o : out std_logic;
    double_error_p_o : out std_logic
  );
end secded_ecc;

architecture rtl of secded_ecc is
  function f_mask_word (mask : std_logic_vector (3 downto 0);
                        d1 : std_logic_vector (31 downto 0);
                        d2 : std_logic_vector (31 downto 0)) return std_logic_vector
  is
    variable masked_word : std_logic_vector (31 downto 0);
  begin
    for i in 1 to 4 loop
      if mask(i-1) = '0' then
        masked_word (i*8-1 downto (i-1)*8) := d2(i*8-1 downto (i-1)*8);
      else
        masked_word (i*8-1 downto (i-1)*8) := d1(i*8-1 downto (i-1)*8);
      end if;
    end loop;
    return masked_word;
  end f_mask_word;

  type fsm_read_states is (normal_op, check_again,  wait_lock, wait_correction);
  type fsm_write_states is (normal_op, check_write);
  type fsm_rw_states is (idle, wait_lock, wait_read, wait_write);

  signal fsm_read  : fsm_read_states  := normal_op;
  signal fsm_write : fsm_write_states := normal_op;
  signal fsm_rw    : fsm_rw_states    := idle;

  signal ecc_errors, ecc_correctable_error : std_logic;
  signal syndrome                          : std_logic_vector (6 downto 0);
  
  signal re_d, re_fsm, we_fsm, re, we, valid_ram_d   : std_logic;
  signal done_r, done_w, fsm_done_r_p, fsm_done_rw_p : std_logic;
  signal lock_req_r, lock_req_rw : std_logic;
  signal req_correction, ack_correction : std_logic;
  signal fsm_read_normal : std_logic;
  signal d, d_rw : std_logic_vector (31 downto 0);

  signal q_ram : std_logic_vector (38 downto 0);
  attribute syn_radhardlevel : string;
  attribute syn_radhardlevel of rtl : architecture is "tmr";
begin
  q_o      <= d_ram_i (31 downto 0);
  re_ram_o <= '1' when (fsm_read /= normal_op) else re;

  syndrome              <= f_calc_ecc (d_ram_i (31 downto 0)) xor d_ram_i(38 downto 32);
  ecc_errors            <= f_ecc_errors(syndrome);
  ecc_correctable_error <= f_ecc_one_error (syndrome);

  fsm_read_normal <= '1' when fsm_read = normal_op else '0';
  done_r   <= (re_d and valid_ram_d and fsm_read_normal and not ecc_errors) or fsm_done_r_p;
  done_r_o <= done_r when (fsm_rw = idle) else '0';
  done_w_o <= '1' when (fsm_done_rw_p = '1' or (done_w = '1' and (fsm_rw = idle))) else '0';

  process (rst_i, a_i, q_ram)
  begin
    -- synthesis translate_off
    if rst_i = '1' then
      a_ram_o <= (others => '0');
      q_ram_o <= (others => '0');
    else
      -- synthesis translate_on
      a_ram_o <= a_i;
      q_ram_o <= q_ram;
      -- synthesis translate_off
    end if;
    -- synthesis translate_on
  end process;

  lock_req_o <= lock_req_r or lock_req_rw;

  we <= we_i when (bwe_i = "1111") else we_fsm;
  re <= re_i or re_fsm;
  d  <= d_i  when (fsm_rw = idle)  else d_rw;

  -- this FSM is used for sub-word writing, which require a word read and a word write
  -- the read and write is atomic, dual-port thread-safe

  process (clk_i)
  begin
    if rising_edge (clk_i) then
      if rst_i = '1' then
        fsm_rw <= idle;
        lock_req_rw <= '0';
        re_fsm <= '0';
        we_fsm <= '0';
        fsm_done_rw_p <= '0';
      else
        case fsm_rw is
          when idle =>
            fsm_done_rw_p <= '0';
            if we_i = '1' and bwe_i /= "1111" then
              lock_req_rw <= '1';
              fsm_rw      <= wait_lock;
            end if;
          when wait_lock =>
            if lock_grant_i = '1' then
              re_fsm <= '1';
              fsm_rw <= wait_read;  
            end if;
          when wait_read =>
            re_fsm <= '0';
            if done_r = '1' then
              d_rw   <= f_mask_word (bwe_i, d_i, d_ram_i (31 downto 0));
              fsm_rw <= wait_write;
              we_fsm     <= '1';
            end if;
          when wait_write =>
            we_fsm <= '0';
            if done_w = '1' then
              fsm_done_rw_p <= '1';
              lock_req_rw <= '0';
              fsm_rw      <= idle;
            end if;
          when others =>
            fsm_rw <= idle;
        end case;
      end if;
    end if;
  end process;

  process (clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' then
        fsm_read <= normal_op;
        re_d <= '0';
        fsm_done_r_p <= '0';
        lock_req_r <= '0';
        req_correction <= '0';
        single_error_p_o <= '0';
        double_error_p_o <= '0';
      else
        re_d         <= re;
        valid_ram_d <= valid_ram_i;

        case fsm_read is
          when normal_op =>
            fsm_done_r_p <= '0';
            single_error_p_o <= '0';
            double_error_p_o <= '0';
            if re_d = '1' and done_r = '0' and valid_ram_d = '1' and ecc_errors = '1' then
              fsm_read <= check_again; -- SET?
            end if;
          when check_again =>
            if valid_ram_d = '1' and ecc_errors = '1' then
              if ecc_correctable_error = '0' then
                double_error_p_o <= '1';
                fsm_done_r_p     <= '1';
                fsm_read <= normal_op;
              else
                lock_req_r <= '1';
                fsm_read   <= wait_lock;
              end if;
            elsif valid_ram_d = '1' and ecc_errors = '0' then
              fsm_read <= normal_op;
            end if;
          when wait_lock =>
            if lock_grant_i = '1' then
              req_correction <= '1';
              fsm_read       <= wait_correction;
            end if;
          when wait_correction =>
            --req_correction <= '0';
            if ack_correction = '1' then
              req_correction <= '0';
              fsm_read     <= normal_op;
              fsm_done_r_p <= '1';
              single_error_p_o <= '1';
              lock_req_r <= '0';
            end if;
        end case;
      end if;
    end if;
  end process;


  process (clk_i)
  begin
    if rising_edge (clk_i) then
      if rst_i = '1' then
        fsm_write <= normal_op;
        done_w <= '0';
        we_ram_o <= '0';
      else
        ack_correction  <= '0';
        done_w          <= '0';

        case fsm_write is
          when normal_op =>
            ack_correction  <= '0';
            done_w          <= '0';
            if req_correction = '1' and ack_correction = '0' then
              q_ram        <= f_fix_error (syndrome, d_ram_i(38 downto 32), d_ram_i (31 downto 0));
              we_ram_o     <= '1';
              fsm_write    <= check_write;
            elsif we = '1' then
              q_ram(31 downto 0) <= d;
              q_ram(38 downto 32) <= f_calc_ecc(d);
              we_ram_o  <= '1';
              fsm_write <= check_write;
            end if;

          when check_write =>
            if valid_ram_i = '1' then
              we_ram_o        <= '0';

              fsm_write <= normal_op;
              if req_correction = '0' then
                done_w         <= '1';
              else
                ack_correction <= '1';
              end if;
            end if;
        end case;
      end if;
    end if;
  end process;
end architecture;
