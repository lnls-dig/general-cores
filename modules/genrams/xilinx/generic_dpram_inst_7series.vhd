--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://gitlab.com/ohwr/project/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   generic_dpram_inst_7series
--
-- description: True dual-port synchronous RAM for Xilinx FPGAs using Xilinx's
-- macros with:
-- - configurable address and data bus width
-- - byte-addressing mode (data bus width restricted to multiple of 8 bits)
--
--
--------------------------------------------------------------------------------
-- Copyright Missing Link Electronics 2024
--------------------------------------------------------------------------------
-- Copyright and related rights are licensed under the CERN Open Hardware
-- Licence Version 2 - Weakly Reciprocal (the "License"); you may not use this
-- file except in compliance with the License. You may obtain a copy of the
-- License at https://ohwr.org/cern_ohl_w_v2.txt.
-- Unless required by applicable law or agreed to in writing, software,
-- hardware and materials distributed under this License is distributed on an
-- "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
-- or implied. See the License for the specific language governing permissions
-- and limitations under the License.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

library unisim;
use unisim.vcomponents.all;

library unimacro;
use unimacro.vcomponents.all;

library work;
use work.gencores_pkg.all;
use work.genram_pkg.all;
use work.memory_loader_pkg.all;

entity generic_dpram_inst_7series is
  generic (
    g_fpga_family              : string  := "kintex7";
    g_data_width               : natural := 32;
    g_size                     : natural := 16384;
    g_with_byte_enable         : boolean := false;
    g_addr_conflict_resolution : string  := "read_first";
    g_init_file                : string  := "";
    g_fail_if_file_not_found   : boolean := true;
    g_implementation_hint      : string  := "auto");
  port (
    rst_n_i: in std_logic;

    -- Port A
    clka_i : in  std_logic;
    bwea_i : in  std_logic_vector((g_data_width+7)/8-1 downto 0);
    wea_i  : in  std_logic;
    aa_i   : in  std_logic_vector(f_log2_size(g_size)-1 downto 0);
    da_i   : in  std_logic_vector(g_data_width-1 downto 0);
    qa_o   : out std_logic_vector(g_data_width-1 downto 0);

    -- Port B
    clkb_i : in  std_logic;
    bweb_i : in  std_logic_vector((g_data_width+7)/8-1 downto 0);
    web_i  : in  std_logic;
    ab_i   : in  std_logic_vector(f_log2_size(g_size)-1 downto 0);
    db_i   : in  std_logic_vector(g_data_width-1 downto 0);
    qb_o   : out std_logic_vector(g_data_width-1 downto 0));
end generic_dpram_inst_7series;

architecture syn of generic_dpram_inst_7series is
  type t_bv_array is array (integer range <>) of bit_vector(g_data_width-1 downto 0);

  impure function f_load_bv_from_file(
    file_name        : in string;
    mem_size         : in integer;
    mem_width        : in integer;
    fail_if_notfound : boolean)
  return t_bv_array is

    FILE f_in  : text;
    variable l : line;
    variable tmp_bv : bit_vector(mem_width-1 downto 0);
    variable tmp_sv : std_logic_vector(mem_width-1 downto 0);
    variable mem: t_bv_array(0 to mem_size-1) := (others => to_bitvector(std_logic_vector(to_unsigned(0, g_data_width))));
    variable status   : file_open_status;
  begin
    if f_empty_file_name(file_name) then
      return mem;
    end if;

    file_open(status, f_in, file_name, read_mode);
    f_file_open_check(file_name, status, fail_if_notfound);

    for I in 0 to mem_size-1 loop
      if not endfile(f_in) then
        readline (f_in, l);
        -- read function gives us bit_vector
        read (l, tmp_bv);
      else
        tmp_bv := (others => '0');
      end if;
      mem(I) := tmp_bv;
    end loop;

    if not endfile(f_in) then
      report "f_load_mem_from_file(): file '"&file_name&"' is bigger than available memory" severity FAILURE;
    end if;

    file_close(f_in);
    return mem;
  end f_load_bv_from_file;

  impure function f_file_to_bitvector256(
    mem       : in t_bv_array(0 to g_size-1);
    ram_idx   : in integer;
    idx       : in integer)
  return bit_vector is
    variable vec : bit_vector(255 downto 0) := (others => '0');
  begin
    -- If no file was given, there is nothing to convert, just return
    if (g_init_file = "" or g_init_file = "none") then
      return vec;
    end if;

    if 256 mod g_data_width > 0 then
      report "f_file_to_bitvector256(): 256 is not a multiple of g_data_width" severity FAILURE;
    end if;

    for J in 0 to (256 / g_data_width) - 1 loop
      vec((J+1) * g_data_width - 1 downto J * g_data_width) := mem((ram_idx * 128 + idx) * 256 / g_data_width + J);
    end loop;

    return vec;
  end f_file_to_bitvector256;

  -- https://docs.xilinx.com/r/en-US/ug953-vivado-7series-libraries/BRAM_TDP_MACRO
  impure function f_lookup_bram_size
  return string is
  begin
    if g_data_width <= 18 and g_size <= 1024 then
      return "18Kb";
    else
      return "36Kb";
    end if;
  end f_lookup_bram_size;

  impure function f_lookup_bram_write_mode
  return string is
  begin
    if (g_addr_conflict_resolution /= "read_first"
        and g_addr_conflict_resolution /= "write_first"
        and g_addr_conflict_resolution /= "no_change"
        and g_addr_conflict_resolution /= "dont_care") then
      report "f_lookup_bram_write_mode(): unsupported g_addr_conflict_resolution" severity FAILURE;
      return "";
    elsif g_addr_conflict_resolution = "dont_care" then
      return to_upper("read_first");
    else
      return to_upper(g_addr_conflict_resolution);
    end if;
  end f_lookup_bram_write_mode;

  -- https://docs.xilinx.com/r/en-US/ug953-vivado-7series-libraries/BRAM_TDP_MACRO
  impure function f_lookup_bram_depth
  return natural is
    variable ret : natural := 0;
  begin
    case g_data_width is
      when 19 to 36 => ret :=  1024;
      when 10 to 18 => ret :=  2048;
      when  5 to  9 => ret :=  4096;
      when  3 to  4 => ret :=  8192;
      when  2       => ret := 16384;
      when  1       => ret := 32768;
    end case;

    if f_lookup_bram_size = "18Kb" then
      ret := ret / 2;
    end if;
    return ret;
  end f_lookup_bram_depth;

  -- https://docs.xilinx.com/r/en-US/ug953-vivado-7series-libraries/BRAM_TDP_MACRO
  impure function f_lookup_bram_web_size
  return natural is
    variable ret : natural := 0;
  begin
    case g_data_width is
      when 19 to 36 => ret := 4;
      when 10 to 18 => ret := 2;
      when  5 to  9 => ret := 1;
      when  3 to  4 => ret := 1;
      when  2       => ret := 1;
      when  1       => ret := 1;
    end case;
    return ret;
  end f_lookup_bram_web_size;

  constant c_num_bytes  : integer := f_lookup_bram_web_size;
  constant c_ram_depth  : integer := f_lookup_bram_depth;
  constant c_ram_count  : integer := (g_size + (c_ram_depth - 1))/c_ram_depth;

  type t_do is array(0 to c_ram_count-1) of std_logic_vector(g_data_width-1 downto 0);

  constant mem : t_bv_array(0 to g_size-1) := f_load_bv_from_file(g_init_file, g_size, g_data_width, g_fail_if_file_not_found);

  signal mux_doa : t_do;
  signal mux_dob : t_do;

  signal aa_tmp : std_logic_vector(f_log2_size(g_size)-1 downto 0);
  signal ab_tmp : std_logic_vector(f_log2_size(g_size)-1 downto 0);
  signal aa_ext : std_logic_vector(f_log2_size(c_ram_depth)-1 downto 0);
  signal ab_ext : std_logic_vector(f_log2_size(c_ram_depth)-1 downto 0);

  signal ena : std_logic_vector(c_ram_count-1 downto 0);
  signal enb : std_logic_vector(c_ram_count-1 downto 0);

  signal s_we_a  : std_logic_vector(c_num_bytes-1 downto 0);
  signal s_we_b  : std_logic_vector(c_num_bytes-1 downto 0);
  signal wea_rep : std_logic_vector(c_num_bytes-1 downto 0);
  signal web_rep : std_logic_vector(c_num_bytes-1 downto 0);

  signal rst : std_logic;
begin
  rst <= not rst_n_i;

  -- combine byte-write enable with write signals
  gen_with_byte_enable: if (g_with_byte_enable = true) generate
    wea_rep <= (others => wea_i);
    web_rep <= (others => web_i);
    s_we_a <= bwea_i(c_num_bytes-1 downto 0) and wea_rep;
    s_we_b <= bweb_i(c_num_bytes-1 downto 0) and web_rep;
  end generate gen_with_byte_enable;
  gen_without_byte_enable: if (g_with_byte_enable = false) generate
    s_we_a <= (others => wea_i);
    s_we_b <= (others => web_i);
  end generate gen_without_byte_enable;

  -- address safety, for small rams (only one instance of BRAM_TDP_MACRO)
  gen_extend_addr: if c_ram_depth > g_size generate
    aa_ext <= std_logic_vector(to_unsigned(0, f_log2_size(c_ram_depth/g_size))) & aa_i;
    ab_ext <= std_logic_vector(to_unsigned(0, f_log2_size(c_ram_depth/g_size))) & ab_i;

    qa_o <= mux_doa(0);
    qb_o <= mux_dob(0);
  end generate gen_extend_addr;
  gen_shrink_addr: if c_ram_depth <= g_size generate
    aa_ext <= aa_i(f_log2_size(c_ram_depth)-1 downto 0);
    ab_ext <= ab_i(f_log2_size(c_ram_depth)-1 downto 0);

    qa_o <= mux_doa(f_check_bounds(to_integer(unsigned(aa_tmp(f_log2_size(g_size)-1 downto f_log2_size(c_ram_depth)))), 0, c_ram_count-1));
    qb_o <= mux_dob(f_check_bounds(to_integer(unsigned(ab_tmp(f_log2_size(g_size)-1 downto f_log2_size(c_ram_depth)))), 0, c_ram_count-1));
  end generate gen_shrink_addr;

  delay_addr_a: process (clka_i)
    begin
      if rising_edge(clka_i) then
        aa_tmp <= aa_i;
      end if;
  end process;

  delay_addr_b: process (clkb_i)
    begin
      if rising_edge(clkb_i) then
        ab_tmp <= ab_i;
      end if;
  end process;

  gen_RAM: for I in 0 to c_ram_count-1 generate
  begin
    gen_RAM_en0: if I = 0 generate
      ena(0) <= '1' when unsigned(aa_i) < c_ram_depth else '0';
      enb(0) <= '1' when unsigned(ab_i) < c_ram_depth else '0';
    end generate;

    gen_RAM_enx: if I > 0 generate
      ena(I) <= '1' when f_check_bounds(to_integer(unsigned(aa_i(f_log2_size(g_size)-1 downto f_log2_size(c_ram_depth)))), 0, c_ram_count-1) = I else
              '0';
      enb(I) <= '1' when f_check_bounds(to_integer(unsigned(ab_i(f_log2_size(g_size)-1 downto f_log2_size(c_ram_depth)))), 0, c_ram_count-1) = I else
              '0';
    end generate;

    -- https://docs.xilinx.com/r/en-US/ug953-vivado-7series-libraries/BRAM_TDP_MACRO
    RAM : BRAM_TDP_MACRO
    generic map (
       BRAM_SIZE => f_lookup_bram_size,          -- Target BRAM, "18Kb" or "36Kb"
       DEVICE => "7SERIES",                      -- Target Device: "VIRTEX5", "VIRTEX6", "7SERIES", "SPARTAN6"
       DOA_REG => 0,                             -- Optional port A output register (0 or 1)
       DOB_REG => 0,                             -- Optional port B output register (0 or 1)
       INIT_A => X"000000000",                   -- Initial values on A output port
       INIT_B => X"000000000",                   -- Initial values on B output port
       INIT_FILE => "NONE",
       READ_WIDTH_A => g_data_width,             -- Valid values are 1-36 (19-36 only valid when BRAM_SIZE="36Kb")
       READ_WIDTH_B => g_data_width,             -- Valid values are 1-36 (19-36 only valid when BRAM_SIZE="36Kb")
       SIM_COLLISION_CHECK => "ALL",             -- Collision check enable "ALL", "WARNING_ONLY", "GENERATE_X_ONLY" or "NONE"
       SRVAL_A => X"000000000",                  -- Set/Reset value for A port output
       SRVAL_B => X"000000000",                  -- Set/Reset value for B port output
       WRITE_MODE_A => f_lookup_bram_write_mode, -- "WRITE_FIRST", "READ_FIRST" or "NO_CHANGE"
       WRITE_MODE_B => f_lookup_bram_write_mode, -- "WRITE_FIRST", "READ_FIRST" or "NO_CHANGE"
       WRITE_WIDTH_A => g_data_width,            -- Valid values are 1-36 (19-36 only valid when BRAM_SIZE="36Kb")
       WRITE_WIDTH_B => g_data_width,            -- Valid values are 1-36 (19-36 only valid when BRAM_SIZE="36Kb")
       INIT_00 => f_file_to_bitvector256(mem, I, 0),
       INIT_01 => f_file_to_bitvector256(mem, I, 1),
       INIT_02 => f_file_to_bitvector256(mem, I, 2),
       INIT_03 => f_file_to_bitvector256(mem, I, 3),
       INIT_04 => f_file_to_bitvector256(mem, I, 4),
       INIT_05 => f_file_to_bitvector256(mem, I, 5),
       INIT_06 => f_file_to_bitvector256(mem, I, 6),
       INIT_07 => f_file_to_bitvector256(mem, I, 7),
       INIT_08 => f_file_to_bitvector256(mem, I, 8),
       INIT_09 => f_file_to_bitvector256(mem, I, 9),
       INIT_0A => f_file_to_bitvector256(mem, I, 10),
       INIT_0B => f_file_to_bitvector256(mem, I, 11),
       INIT_0C => f_file_to_bitvector256(mem, I, 12),
       INIT_0D => f_file_to_bitvector256(mem, I, 13),
       INIT_0E => f_file_to_bitvector256(mem, I, 14),
       INIT_0F => f_file_to_bitvector256(mem, I, 15),
       INIT_10 => f_file_to_bitvector256(mem, I, 16),
       INIT_11 => f_file_to_bitvector256(mem, I, 17),
       INIT_12 => f_file_to_bitvector256(mem, I, 18),
       INIT_13 => f_file_to_bitvector256(mem, I, 19),
       INIT_14 => f_file_to_bitvector256(mem, I, 20),
       INIT_15 => f_file_to_bitvector256(mem, I, 21),
       INIT_16 => f_file_to_bitvector256(mem, I, 22),
       INIT_17 => f_file_to_bitvector256(mem, I, 23),
       INIT_18 => f_file_to_bitvector256(mem, I, 24),
       INIT_19 => f_file_to_bitvector256(mem, I, 25),
       INIT_1A => f_file_to_bitvector256(mem, I, 26),
       INIT_1B => f_file_to_bitvector256(mem, I, 27),
       INIT_1C => f_file_to_bitvector256(mem, I, 28),
       INIT_1D => f_file_to_bitvector256(mem, I, 29),
       INIT_1E => f_file_to_bitvector256(mem, I, 30),
       INIT_1F => f_file_to_bitvector256(mem, I, 31),
       INIT_20 => f_file_to_bitvector256(mem, I, 32),
       INIT_21 => f_file_to_bitvector256(mem, I, 33),
       INIT_22 => f_file_to_bitvector256(mem, I, 34),
       INIT_23 => f_file_to_bitvector256(mem, I, 35),
       INIT_24 => f_file_to_bitvector256(mem, I, 36),
       INIT_25 => f_file_to_bitvector256(mem, I, 37),
       INIT_26 => f_file_to_bitvector256(mem, I, 38),
       INIT_27 => f_file_to_bitvector256(mem, I, 39),
       INIT_28 => f_file_to_bitvector256(mem, I, 40),
       INIT_29 => f_file_to_bitvector256(mem, I, 41),
       INIT_2A => f_file_to_bitvector256(mem, I, 42),
       INIT_2B => f_file_to_bitvector256(mem, I, 43),
       INIT_2C => f_file_to_bitvector256(mem, I, 44),
       INIT_2D => f_file_to_bitvector256(mem, I, 45),
       INIT_2E => f_file_to_bitvector256(mem, I, 46),
       INIT_2F => f_file_to_bitvector256(mem, I, 47),
       INIT_30 => f_file_to_bitvector256(mem, I, 48),
       INIT_31 => f_file_to_bitvector256(mem, I, 49),
       INIT_32 => f_file_to_bitvector256(mem, I, 50),
       INIT_33 => f_file_to_bitvector256(mem, I, 51),
       INIT_34 => f_file_to_bitvector256(mem, I, 52),
       INIT_35 => f_file_to_bitvector256(mem, I, 53),
       INIT_36 => f_file_to_bitvector256(mem, I, 54),
       INIT_37 => f_file_to_bitvector256(mem, I, 55),
       INIT_38 => f_file_to_bitvector256(mem, I, 56),
       INIT_39 => f_file_to_bitvector256(mem, I, 57),
       INIT_3A => f_file_to_bitvector256(mem, I, 58),
       INIT_3B => f_file_to_bitvector256(mem, I, 59),
       INIT_3C => f_file_to_bitvector256(mem, I, 60),
       INIT_3D => f_file_to_bitvector256(mem, I, 61),
       INIT_3E => f_file_to_bitvector256(mem, I, 62),
       INIT_3F => f_file_to_bitvector256(mem, I, 63),

       -- The next set of INIT_xx are valid when configured as 36Kb
       INIT_40 => f_file_to_bitvector256(mem, I, 64),
       INIT_41 => f_file_to_bitvector256(mem, I, 65),
       INIT_42 => f_file_to_bitvector256(mem, I, 66),
       INIT_43 => f_file_to_bitvector256(mem, I, 67),
       INIT_44 => f_file_to_bitvector256(mem, I, 68),
       INIT_45 => f_file_to_bitvector256(mem, I, 69),
       INIT_46 => f_file_to_bitvector256(mem, I, 70),
       INIT_47 => f_file_to_bitvector256(mem, I, 71),
       INIT_48 => f_file_to_bitvector256(mem, I, 72),
       INIT_49 => f_file_to_bitvector256(mem, I, 73),
       INIT_4A => f_file_to_bitvector256(mem, I, 74),
       INIT_4B => f_file_to_bitvector256(mem, I, 75),
       INIT_4C => f_file_to_bitvector256(mem, I, 76),
       INIT_4D => f_file_to_bitvector256(mem, I, 77),
       INIT_4E => f_file_to_bitvector256(mem, I, 78),
       INIT_4F => f_file_to_bitvector256(mem, I, 79),
       INIT_50 => f_file_to_bitvector256(mem, I, 80),
       INIT_51 => f_file_to_bitvector256(mem, I, 81),
       INIT_52 => f_file_to_bitvector256(mem, I, 82),
       INIT_53 => f_file_to_bitvector256(mem, I, 83),
       INIT_54 => f_file_to_bitvector256(mem, I, 84),
       INIT_55 => f_file_to_bitvector256(mem, I, 85),
       INIT_56 => f_file_to_bitvector256(mem, I, 86),
       INIT_57 => f_file_to_bitvector256(mem, I, 87),
       INIT_58 => f_file_to_bitvector256(mem, I, 88),
       INIT_59 => f_file_to_bitvector256(mem, I, 89),
       INIT_5A => f_file_to_bitvector256(mem, I, 90),
       INIT_5B => f_file_to_bitvector256(mem, I, 91),
       INIT_5C => f_file_to_bitvector256(mem, I, 92),
       INIT_5D => f_file_to_bitvector256(mem, I, 93),
       INIT_5E => f_file_to_bitvector256(mem, I, 94),
       INIT_5F => f_file_to_bitvector256(mem, I, 95),
       INIT_60 => f_file_to_bitvector256(mem, I, 96),
       INIT_61 => f_file_to_bitvector256(mem, I, 97),
       INIT_62 => f_file_to_bitvector256(mem, I, 98),
       INIT_63 => f_file_to_bitvector256(mem, I, 99),
       INIT_64 => f_file_to_bitvector256(mem, I, 100),
       INIT_65 => f_file_to_bitvector256(mem, I, 101),
       INIT_66 => f_file_to_bitvector256(mem, I, 102),
       INIT_67 => f_file_to_bitvector256(mem, I, 103),
       INIT_68 => f_file_to_bitvector256(mem, I, 104),
       INIT_69 => f_file_to_bitvector256(mem, I, 105),
       INIT_6A => f_file_to_bitvector256(mem, I, 106),
       INIT_6B => f_file_to_bitvector256(mem, I, 107),
       INIT_6C => f_file_to_bitvector256(mem, I, 108),
       INIT_6D => f_file_to_bitvector256(mem, I, 109),
       INIT_6E => f_file_to_bitvector256(mem, I, 110),
       INIT_6F => f_file_to_bitvector256(mem, I, 111),
       INIT_70 => f_file_to_bitvector256(mem, I, 112),
       INIT_71 => f_file_to_bitvector256(mem, I, 113),
       INIT_72 => f_file_to_bitvector256(mem, I, 114),
       INIT_73 => f_file_to_bitvector256(mem, I, 115),
       INIT_74 => f_file_to_bitvector256(mem, I, 116),
       INIT_75 => f_file_to_bitvector256(mem, I, 117),
       INIT_76 => f_file_to_bitvector256(mem, I, 118),
       INIT_77 => f_file_to_bitvector256(mem, I, 119),
       INIT_78 => f_file_to_bitvector256(mem, I, 120),
       INIT_79 => f_file_to_bitvector256(mem, I, 121),
       INIT_7A => f_file_to_bitvector256(mem, I, 122),
       INIT_7B => f_file_to_bitvector256(mem, I, 123),
       INIT_7C => f_file_to_bitvector256(mem, I, 124),
       INIT_7D => f_file_to_bitvector256(mem, I, 125),
       INIT_7E => f_file_to_bitvector256(mem, I, 126),
       INIT_7F => f_file_to_bitvector256(mem, I, 127)
    )
    port map (
       DOA => mux_doa(I),         -- Output port-A data, width defined by READ_WIDTH_A parameter
       DOB => mux_dob(I),         -- Output port-B data, width defined by READ_WIDTH_B parameter
       ADDRA => aa_ext,           -- Input port-A address, width defined by Port A depth
       ADDRB => ab_ext,           -- Input port-B address, width defined by Port B depth
       CLKA => clka_i,            -- 1-bit input port-A clock
       CLKB => clkb_i,            -- 1-bit input port-B clock
       DIA => da_i,               -- Input port-A data, width defined by WRITE_WIDTH_A parameter
       DIB => db_i,               -- Input port-B data, width defined by WRITE_WIDTH_B parameter
       ENA => ena(I),             -- 1-bit input port-A enable
       ENB => enb(I),             -- 1-bit input port-B enable
       REGCEA => '1',             -- 1-bit input port-A output register enable
       REGCEB => '1',             -- 1-bit input port-B output register enable
       RSTA => rst,               -- 1-bit input port-A reset
       RSTB => rst,               -- 1-bit input port-B reset
       WEA => s_we_a,             -- Input port-A write enable, width defined by Port A depth
       WEB => s_we_b              -- Input port-B write enable, width defined by Port B depth
    );
  end generate;

end syn;
