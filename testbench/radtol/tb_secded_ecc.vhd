library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_secded_ecc is
end tb_secded_ecc;

architecture arch of tb_secded_ecc is
  constant addr_width : natural := 8;
  subtype ram_word_t is std_logic_vector (38 downto 0);

  signal clk : std_logic;
  signal rst : std_logic;

  -- to the processor/bus
  signal addr       : std_logic_vector(addr_width-1 downto 0);
  signal din        : std_logic_vector(31 downto 0);
  signal we         : std_logic;
  signal bwe        : std_logic_vector (3 downto 0);
  signal re         : std_logic;

  signal dout       : std_logic_vector(31 downto 0);
  signal done_r     : std_logic;
  signal done_w     : std_logic;

  --to the BRAM
  signal a_ram      : std_logic_vector (addr_width-1 downto 0);
  signal d_ram      : ram_word_t;
  signal q_ram      : ram_word_t;
  signal we_ram     : std_logic;
  signal re_ram     : std_logic;
  signal valid_ram  : std_logic;
  signal lock_req   : std_logic;
  signal lock_grant : std_logic;

  signal force_err  : ram_word_t := (others => '0');

  signal single_error_p : std_logic;
  signal double_error_p : std_logic;

  signal end_of_test : boolean := false;
begin
  process
  begin
    clk <= '0';
    wait for 5 ns;
    clk <= '1';
    wait for 5 ns;
    if end_of_test then
      wait;
    end if;
  end process;

  rst <= '1', '0' after 20 ns;

  process (clk)
    type mem_t is array (2**addr_width - 1 downto 0) of ram_word_t;
    variable mem : mem_t;
  begin
    if rising_edge(clk) then
      valid_ram <= '0';
      if we_ram = '1' then
        mem (to_integer(unsigned(a_ram))) := q_ram xor force_err;
        valid_ram <= '1';
      end if;
      if re_ram = '1' then
        d_ram <= mem (to_integer(unsigned(a_ram)));
        valid_ram <= '1';
      end if;
    end if;
  end process;

  inst_secded: entity work.secded_ecc
    generic map (
      g_addr_width => addr_width
    )
    port map (
      clk_i => clk,
      rst_i => rst,
      a_i => addr,
      d_i => din,
      we_i => we,
      bwe_i => bwe,
      re_i => re,
      q_o => dout,
      done_r_o => done_r,
      done_w_o => done_w,
      a_ram_o => a_ram,
      d_ram_i => d_ram,
      q_ram_o => q_ram,
      we_ram_o => we_ram,
      re_ram_o => re_ram,
      valid_ram_i => valid_ram,
      lock_req_o => lock_req,
      lock_grant_i => lock_grant,
      single_error_p_o => single_error_p,
      double_error_p_o => double_error_p
    );

  lock_grant <= lock_req;

  proc_tb: process
    constant pattern : std_logic_vector (31 downto 0) := x"0123_4567";

    variable xaddr : std_logic_vector (addr_width - 1 downto 0);
  begin
    wait until rst = '0';
    wait until rising_edge(clk);

    --  Write words.
    for i in 0 to 80 loop
      xaddr := std_logic_vector (to_unsigned(i, addr_width));
      addr <= xaddr;
      din <= pattern;
      din (addr_width - 1 downto 0) <= xaddr;
      we <= '1';
      bwe <= "1111";
      force_err <= (others => '0');
      if i >= 32 and i < 32 + 39 then
        force_err (i - 32) <= '1';
      elsif i = 71 then
        force_err (31) <= '1';
        force_err (21) <= '1';
      end if;
      re <= '0';
      wait until rising_edge(clk);
      we <= '0';
      wait until rising_edge(clk) and done_w = '1';
    end loop;

    --  Check words
    for i in 0 to 71 loop
      xaddr := std_logic_vector (to_unsigned(i, addr_width));
      addr <= xaddr;
      re <= '1';
      wait until rising_edge(clk) and done_r = '1';
      re <= '0';
      case i is
        when 0 to 31 =>
          assert dout = pattern (31 downto addr_width) & xaddr severity failure;
          assert single_error_p = '0' severity failure;
          assert double_error_p = '0' severity failure;
        when 32 to 70 =>
          assert dout = pattern (31 downto addr_width) & xaddr severity failure;
          assert single_error_p = '1' severity failure;
          assert double_error_p = '0' severity failure;
        when 71 =>
          assert single_error_p = '0' severity failure;
          assert double_error_p = '1' severity failure;
        when others =>
          assert false;
      end case;
      wait until rising_edge(clk) and done_r = '0';
    end loop;

    report "end of test";
    end_of_test <= true;
    wait;
  end process;
end;