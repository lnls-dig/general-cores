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

  signal orig_data, data : std_logic_vector (31 downto 0);
  signal orig_ecc, ecc, comp_ecc, syndrome : std_logic_vector(6 downto 0);
  signal err, cor : std_logic_vector(38 downto 0);

  type vectors_type is
    array (natural range <>) of std_logic_vector(31 downto 0);
  constant vectors : vectors_type :=
    (x"00001197",
     x"22c18193",
     x"00040117",
     x"ffffffff");
  
begin
  process
    variable ecc2 : std_logic_vector(6 downto 0);
  begin
    for i in vectors'range loop
      ecc2 := f_calc_ecc (vectors (i));
      report "data:  " & to_hstring (vectors (i)) & ", ecc:  " & to_hstring (ecc2);
    end loop;

    orig_data <= x"789a_d3f5";
    syndrome <= "0000000";
    wait for 1 ns;
    assert f_ecc_errors (syndrome) = '0' severity failure;
    assert f_ecc_one_error (syndrome) = '0' severity failure;
    orig_ecc <= f_calc_ecc (orig_data);

    --  Single error (detection and correction)
    for i in 0 to 38 loop
      err <= (others => '0');
      err (i) <= '1';
      wait for 1 ns;
      if i < 32 then
        --  Bit flip in data
        data <= orig_data xor err(31 downto 0);
        ecc <= orig_ecc;
      else
        --  Bit flip in ecc
        ecc <= orig_ecc xor err(38 downto 32);
        data <= orig_data;
      end if;
      wait for 1 ns;
      comp_ecc <= f_calc_ecc (data);
      wait for 1 ns;
      syndrome <= comp_ecc xor ecc;
      wait for 1 ns;
      assert f_ecc_errors (syndrome) = '1' severity failure;
      assert f_ecc_one_error (syndrome) = '1' severity failure;
      cor <= f_fix_error(syndrome, ecc, data);
      wait for 1 ns;
      report "data:  " & image (data) & ", ecc:  " & image (ecc) & ", err: " & image (err) & ", ecc/err: " & image(comp_ecc);
      report "cdata: " & image (cor(31 downto 0)) & ", cecc: " & image(cor(38 downto 32)) & " syndrome: " & image(syndrome);
      assert cor(31 downto 0) = orig_data severity failure;
      assert cor(38 downto 32) = orig_ecc severity failure;
    end loop;
    report "end of test";
    wait;
  end process;
end behav;
