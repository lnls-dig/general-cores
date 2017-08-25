#!/usr/bin/python

# LM32 core generator/customizer. Produces a set of LM32 cores preconfigured according to profiles stored
# in 'lm32.profiles' file. 
# The outputs are a single Verilog file containing all customized modules and 
# a vhdl top-level wrapper with a set of generics allowing to choose the profile from within a Verilog/VHDL design

import os, glob, tokenize, copy

LM32_features = [ "CFG_PL_MULTIPLY_ENABLED",
								  "CFG_PL_BARREL_SHIFT_ENABLED",
									"CFG_SIGN_EXTEND_ENABLED",
									"CFG_MC_DIVIDE_ENABLED",
									"CFG_FAST_UNCONDITIONAL_BRANCH",
									"CFG_ICACHE_ENABLED",
									"CFG_DCACHE_ENABLED",
									"CFG_WITH_DEBUG",
									"CFG_INTERRUPTS_ENABLED",
									"CFG_BUS_ERRORS_ENABLED" ];

LM32_files = [
"src/lm32_top.v",
"src/lm32_mc_arithmetic.v",
"src/lm32_cpu.v",
"src/lm32_load_store_unit.v",
"src/lm32_decoder.v",
"src/lm32_icache.v",
"src/lm32_dcache.v",
"src/lm32_debug.v",
"src/lm32_instruction_unit.v",
"src/lm32_jtag.v",
"src/lm32_interrupt.v"];

LM32_mods = ["lm32_cpu",
									 "lm32_dcache",
									 "lm32_debug",
									 "lm32_decoder",
									 "lm32_icache",
									 "lm32_instruction_unit",
									 "lm32_interrupt",
									 "lm32_jtag",
									 "lm32_load_store_unit",
									 "lm32_mc_arithmetic",
									 "lm32_top"];


def tobin(x, count=16):
	s=""
	for i in range(count-1, -1, -1):
		if(x & (1<<i)):
			s=s+"1";
		else:
			s=s+"0";
	return s
	        
def mangle_names(string, profile_name):
	for pattern in LM32_mods:
		string = string.replace(pattern, pattern + "_"+profile_name)
	return string;

def remove_unsynthetizable(code):
  syn_on = True
  r=""
  for l in code.split("\n"):
    if l.lstrip("\t ").startswith("// synthesis translate_off"):
      syn_on = False
    elif l.lstrip("\t ").startswith("// synthesis translate_on"):
      syn_on = True

    if syn_on:
      r=r+l+"\n"

  return r
                                        
def gen_customized_version(profile_name, feats):
	print("GenCfg ", profile_name);

	tmp_dir = "/tmp/lm32-customizer";
	try:
		os.mkdir(tmp_dir);
	except:
		pass

	f = open(tmp_dir + "/system_conf.v", "w");
	f.write("`ifndef __system_conf_v\n`define __system_conf_v\n");
	
	for feat in feats:
			f.write("`define " + feat + "\n");

	f.write("`define CFG_EBA_RESET  32'h00000000\n\
	`define CFG_SDB  32'h00000000\n\
	`define CFG_DEBA_RESET 32'h10000000\n\
	`define CFG_EBR_POSEDGE_REGISTER_FILE\n\
	`define CFG_ICACHE_ASSOCIATIVITY   1\n\
	`define CFG_ICACHE_SETS            256\n\
	`define CFG_ICACHE_BYTES_PER_LINE  16\n\
	`define CFG_ICACHE_BASE_ADDRESS    32'h0\n\
	`define CFG_ICACHE_LIMIT           32'h7fffffff\n\
	`define CFG_DCACHE_ASSOCIATIVITY   1\n\
	`define CFG_DCACHE_SETS            256\n\
	`define CFG_DCACHE_BYTES_PER_LINE  16\n\
	`define CFG_DCACHE_BASE_ADDRESS    32'h0\n\
	`define CFG_DCACHE_LIMIT           32'h7fffffff\n\
	`define CFG_IRAM_BASE_ADDRESS          0\n\
	`define CFG_IRAM_LIMIT                32'h000fffff\n\
	`define CFG_BREAKPOINTS 32'h4\n\
	`define CFG_WATCHPOINTS 32'h4\n\
	`ifdef CFG_WITH_DEBUG\n\
	`define CFG_JTAG_ENABLED\n\
	`define CFG_JTAG_UART_ENABLED\n\
	`define CFG_DEBUG_ENABLED\n\
	`define CFG_HW_DEBUG_ENABLED\n\
	`endif\n");
	

	f.write("`endif\n");
	f.close();

	file_list = LM32_files;
	
	ftmp = open(tmp_dir + "/tmp.v", "w");
	
	for fname in file_list:
		f = open(fname, "r");
		contents = f.read();
		mangled = mangle_names(contents, profile_name)
		code = remove_unsynthetizable(mangled)
		ftmp.write(code);
		f.close();

	ftmp.close();		
	
	os.system("vlog -quiet -nologo -E " + tmp_dir+"/lm32_"+profile_name+".v " + tmp_dir + "/tmp.v  +incdir+" +tmp_dir+" +incdir+src");
	os.system("cat "+tmp_dir+"/lm32_*.v | egrep -v '`line' > generated/lm32_allprofiles.v")
	
def parse_profiles():
	f = open("lm32.profiles", "r")
	p = map(lambda x: x.rstrip(" \n").rsplit(' '), f.readlines())
	f.close()
	return list(p)

def gen_vhdl_component(f, profile_name):
	f.write("component lm32_top_"+profile_name+" is \n")
	f.write("generic ( eba_reset: std_logic_vector(31 downto 0);\n");
	f.write("          sdb_address: std_logic_vector(31 downto 0));\n");
	f.write("port (\n");
	f.write(""" 
  clk_i    : in  std_logic;
  rst_i    : in  std_logic;
  interrupt  : in  std_logic_vector(31 downto 0);
  I_DAT_I  : in  std_logic_vector(31 downto 0);
  I_ACK_I  : in  std_logic;
  I_ERR_I  : in  std_logic;
  I_RTY_I  : in  std_logic;
   D_DAT_I  : in  std_logic_vector(31 downto 0);
   D_ACK_I  : in  std_logic;
   D_ERR_I  : in  std_logic;
   D_RTY_I  : in  std_logic;
   I_DAT_O  : out std_logic_vector(31 downto 0);
   I_ADR_O  : out std_logic_vector(31 downto 0);
   I_CYC_O  : out std_logic;
   I_SEL_O  : out std_logic_vector(3 downto 0);
   I_STB_O  : out std_logic;
   I_WE_O   : out std_logic;
   I_CTI_O  : out std_logic_vector(2 downto 0);
   I_LOCK_O : out std_logic;
   I_BTE_O  : out std_logic_vector(1 downto 0);
   D_DAT_O  : out std_logic_vector(31 downto 0);
   D_ADR_O  : out std_logic_vector(31 downto 0);
   D_CYC_O  : out std_logic;
   D_SEL_O  : out std_logic_vector(3 downto 0);
   D_STB_O  : out std_logic;
   D_WE_O   : out std_logic;
   D_CTI_O  : out std_logic_vector(2 downto 0);
   D_LOCK_O : out std_logic;
   D_BTE_O  : out std_logic_vector(1 downto 0));
end component;
""");



def gen_burst_eval_func(f, prof, cache):
	f.write("function f_eval_"+cache+"_burst_length(profile_name:string) return natural is\nbegin\n");
	t = {True: 4, False:1}
	for p in prof:
		has_cache = any(map(lambda x: cache.upper()+"CACHE_ENABLED" in x, list(p[1:])))
		f.write("if profile_name = \""+p[0]+"\" then return "+str(t[has_cache])+"; end if; \n");
	f.write("return 0;\nend function;\n");
   
def gen_vhdl_wrapper(prof):
	f=open("generated/xwb_lm32.vhd","w");
	f.write("""--auto-generated by gen_lmcores.py. Don't hand-edit please
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wishbone_pkg.all;
entity xwb_lm32 is
generic(g_profile: string;
g_reset_vector: std_logic_vector(31 downto 0) := x"00000000";
g_sdb_address: std_logic_vector(31 downto 0) := x"00000000");
port(
clk_sys_i : in  std_logic;
rst_n_i : in  std_logic;
irq_i : in  std_logic_vector(31 downto 0);
dwb_o  : out t_wishbone_master_out;
dwb_i  : in  t_wishbone_master_in;
iwb_o  : out t_wishbone_master_out;
iwb_i  : in  t_wishbone_master_in);
end xwb_lm32;
architecture rtl of xwb_lm32 is \n""");
	gen_burst_eval_func(f, prof, "i");
	gen_burst_eval_func(f, prof, "d");

	for p in prof:
		gen_vhdl_component(f, p[0])

	f.write("""
  function pick(first : boolean;
                 a, b  : t_wishbone_address)
      return t_wishbone_address is
   begin
      if first then
         return a;
      else
         return b;
      end if;
   end pick;
   
   function b2l(val : boolean)
      return std_logic is
   begin
      if val then 
         return '1';
      else
         return '0';
      end if;
   end b2l;

 function strip_undefined
    (x           : std_logic_vector) return std_logic_vector is
    variable tmp : std_logic_vector(x'left downto 0);
  begin
    for i  in 0 to x'left loop
      if(x(i)='1') then
        tmp(i) := '1';
      else
        tmp(i) := '0';
      end if;
    end loop;  -- i
    return tmp;
  end strip_undefined;
   
   constant dcache_burst_length : natural := f_eval_d_burst_length(g_profile);
   constant icache_burst_length : natural := f_eval_i_burst_length(g_profile);
   
   -- Control pins from the LM32
   signal I_ADR : t_wishbone_address;
   signal D_ADR : t_wishbone_address;
   signal I_CYC : std_logic;
   signal D_CYC : std_logic;
   signal I_CTI : t_wishbone_cycle_type;
   signal D_CTI : t_wishbone_cycle_type;
   -- We also watch the STALL lines from the v4 slaves
   
   -- Registered logic:
   signal inst_was_busy : std_logic;
   signal data_was_busy : std_logic;
   signal inst_addr_reg : t_wishbone_address;
   signal data_addr_reg : t_wishbone_address;
   signal inst_remaining : natural range 0 to icache_burst_length;
   signal data_remaining : natural range 0 to dcache_burst_length;
   
   -- Asynchronous logic:
   signal I_STB_O : std_logic;
   signal D_STB_O : std_logic;
   signal rst:std_logic;
begin
		rst <= not rst_n_i;
""");

	for p in prof:
		f.write("gen_profile_"+p[0]+": if (g_profile = \"" + p[0]+"\") generate\n");
		f.write("U_Wrapped_LM32: lm32_top_"+p[0]+"\n");
		f.write("""
generic map (
			eba_reset => g_reset_vector,
                        sdb_address => g_sdb_address)
port map(
      clk_i	=> clk_sys_i,
      rst_i	=> rst,
      interrupt	=> irq_i,
      -- Pass slave responses through unmodified
      I_DAT_I	=> strip_undefined(iwb_i.DAT),
      I_ACK_I	=> iwb_i.ACK,
      I_ERR_I	=> iwb_i.ERR,
      I_RTY_I	=> iwb_i.RTY,
      D_DAT_I	=> strip_undefined(dwb_i.DAT),
      D_ACK_I	=> dwb_i.ACK,
      D_ERR_I	=> dwb_i.ERR,
      D_RTY_I	=> dwb_i.RTY,
      -- Writes can only happen as a single cycle
      I_DAT_O	=> iwb_o.DAT,
      D_DAT_O	=> dwb_o.DAT,
      I_WE_O	=> iwb_o.WE,
      D_WE_O	=> dwb_o.WE,
      -- SEL /= 1111 only for single cycles
      I_SEL_O	=> iwb_o.SEL,
      D_SEL_O	=> dwb_o.SEL,
      -- We can ignore BTE as we know it's always linear burst mode
      I_BTE_O	=> open,
      D_BTE_O	=> open,
      -- Lock is never flagged by LM32. Besides, WBv4 locks intercon on CYC.
      I_LOCK_O	=> open,
      D_LOCK_O	=> open,
      -- The LM32 has STB=CYC always
      I_STB_O	=> open,
      D_STB_O	=> open,
      -- We monitor these pins to direct the adapter's logic
      I_ADR_O	=> I_ADR,
      I_CYC_O	=> I_CYC,
      I_CTI_O	=> I_CTI,
      D_ADR_O	=> D_ADR,
      D_CYC_O	=> D_CYC,
      D_CTI_O	=> D_CTI);
""");
		f.write("end generate gen_profile_"+p[0]+";\n")

	f.write("""
   -- Cycle durations always match in our adapter
   iwb_o.CYC <= I_CYC;
   dwb_o.CYC <= D_CYC;
   
   iwb_o.STB <= I_STB_O;
   dwb_o.STB <= D_STB_O;
   
   I_STB_O <= (I_CYC and not inst_was_busy) or b2l(inst_remaining /= 0);
   inst : process(clk_sys_i)
      variable inst_addr : t_wishbone_address;
      variable inst_length : natural;
   begin
      if rising_edge(clk_sys_i) then
         if rst = '1' then
            inst_was_busy <= '0';
            inst_remaining <= 0;
            inst_addr_reg <= (others => '0');
         else
            inst_was_busy <= I_CYC;
            
            -- Is this the start of a new WB cycle?
            if I_CYC = '1' and inst_was_busy = '0' then
               inst_addr := I_ADR;
               if I_CTI = "010" then
                  inst_length := icache_burst_length;
               else
                  inst_length := 1;
               end if;
            else
               inst_addr := inst_addr_reg;
               inst_length := inst_remaining;
            end if;
            
            -- When stalled, we cannot advance the address
            if iwb_i.STALL = '0' and I_STB_O = '1' then
               inst_addr_reg  <= std_logic_vector(unsigned(inst_addr) + 4);
               inst_remaining <= inst_length - 1;
            else
               inst_addr_reg  <= inst_addr;
               inst_remaining <= inst_length;
            end if;
         end if;
      end if;
   end process;
   
   D_STB_O <= (D_CYC and not data_was_busy) or b2l(data_remaining /= 0);
   data : process(clk_sys_i)
      variable data_addr : t_wishbone_address;
      variable data_length : natural;
   begin
      if rising_edge(clk_sys_i) then
         if rst = '1' then
            data_was_busy <= '0';
            data_remaining <= 0;
            data_addr_reg <= (others => '0');
         else
            data_was_busy <= D_CYC;
            
            -- Is this the start of a new WB cycle?
            if D_CYC = '1' and data_was_busy = '0' then
               data_addr := D_ADR;
               if D_CTI = "010" then
                  data_length := dcache_burst_length;
               else
                  data_length := 1;
               end if;
            else
               data_addr := data_addr_reg;
               data_length := data_remaining;
            end if;
            
            -- When stalled, we cannot advance the address
            if dwb_i.STALL = '0' and D_STB_O = '1' then
               data_addr_reg  <= std_logic_vector(unsigned(data_addr) + 4);
               data_remaining <= data_length - 1;
            else
               data_addr_reg  <= data_addr;
               data_remaining <= data_length;
            end if;
         end if;
      end if;
   end process;
   
   -- The first request uses the WBv3 address, thereafter an incrementing one.
   dwb_o.ADR <= pick(data_was_busy = '0', D_ADR, data_addr_reg);
   iwb_o.ADR <= pick(inst_was_busy = '0', I_ADR, inst_addr_reg);
	end rtl;
""");

	f.close()

os.system("vlib work")

profiles = parse_profiles()

for p in profiles:
	gen_customized_version(p[0], p[1:])

gen_vhdl_wrapper(profiles)

