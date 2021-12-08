library ieee;
use ieee.std_logic_1164.all;
use work.secded_32b_pkg.all;

entity tb_secded_32b_pkg is
end tb_secded_32b_pkg;

architecture behav of tb_secded_32b_pkg is
  function image(v : std_logic_vector) return string
  is
    alias va : std_logic_vector(1 to v'length) is v;
    variable res : string (va'range);
  begin
    for i in va'range loop
      if va (i) = '1' then
        res (i) := '1';
      else
        res (i) := '0';
      end if;
    end loop;
    return res;
  end image;

  signal data, err, data2 : std_logic_vector (31 downto 0);
  signal ecc, ecc2, syndrome : std_logic_vector(6 downto 0);
  signal cor : std_logic_vector(38 downto 0);
begin
  process
  begin
    data <= x"789a_d3f5";
    syndrome <= "0000000";
    wait for 1 ns;
    assert f_ecc_errors (syndrome) = '0' severity failure;
    assert f_ecc_one_error (syndrome) = '0' severity failure;
    ecc <= f_calc_ecc (data);

    --  Single error (detection and correction)
    for i in 0 to 38 loop
      err <= (others => '0');
      if i < 32 then
        err (i) <= '1';
        wait for 1 ns;
        data2 <= data xor err;
        wait for 1 ns;
        ecc2 <= f_calc_ecc (data2);
      else
        err (i - 32) <= '1';
        wait for 1 ns;
        ecc2 <= ecc xor err(6 downto 0);
        data2 <= data;
      end if;
      wait for 1 ns;
      syndrome <= ecc2 xor ecc;
      wait for 1 ns;
      assert f_ecc_errors (syndrome) = '1' severity failure;
      assert f_ecc_one_error (syndrome) = '1' severity failure;
      cor <= f_fix_error(syndrome, ecc2, data2);
      wait for 1 ns;
      report "data:  " & image (data) & ", ecc:  " & image (ecc) & ", err: " & image (err) & ", ecc/err: " & image(ecc2);
      report "cdata: " & image (cor(31 downto 0)) & ", cecc: " & image(cor(38 downto 32)) & " syndrome: " & image(syndrome);
      assert cor(31 downto 0) = data severity failure;
      assert cor(38 downto 32) = ecc severity failure;
    end loop;
    report "end of test";
    wait;
  end process;
end behav;
