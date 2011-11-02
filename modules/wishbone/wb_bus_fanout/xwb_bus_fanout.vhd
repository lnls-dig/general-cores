library ieee;
use ieee.STD_LOGIC_1164.all;
use ieee.numeric_std.all;

use work.wishbone_pkg.all;

entity xwb_bus_fanout is
  
  generic (
    g_num_outputs          : natural;
    g_bits_per_slave       : integer := 14;
    g_address_granularity  : t_wishbone_address_granularity;
    g_slave_interface_mode : t_wishbone_interface_mode);

  port (
    clk_sys_i : in std_logic;
    rst_n_i   : in std_logic;

    slave_i : in  t_wishbone_slave_in;
    slave_o : out t_wishbone_slave_out;

    master_i : in  t_wishbone_master_in_array(0 to g_num_outputs-1);
    master_o : out t_wishbone_master_out_array(0 to g_num_outputs-1)
    );

end xwb_bus_fanout;

architecture rtl of xwb_bus_fanout is

  function f_log2_ceil(N : natural) return positive is
  begin
    if N <= 2 then
      return 1;
    elsif N mod 2 = 0 then
      return 1 + f_log2_ceil(N/2);
    else
      return 1 + f_log2_ceil((N+1)/2);
    end if;
  end;
  
  constant c_periph_addr_bits : integer := f_log2_ceil(g_num_outputs);

  signal periph_addr     : std_logic_vector(c_periph_addr_bits - 1 downto 0);
  signal periph_addr_reg : std_logic_vector(c_periph_addr_bits - 1 downto 0);

  signal periph_sel     : std_logic_vector(2**c_periph_addr_bits-1 downto 0);
  signal periph_sel_reg : std_logic_vector(2**c_periph_addr_bits-1 downto 0);

  signal ack_muxed     : std_logic;
  signal data_in_muxed : std_logic_vector(31 downto 0);

  signal cycle_in_progress : std_logic;
  signal ack_prev          : std_logic;

  signal adp_in  : t_wishbone_master_in;
  signal adp_out : t_wishbone_master_out;
begin  -- rtl


  U_Slave_Adapter : wb_slave_adapter
    generic map (
      g_master_use_struct  => true,
      g_master_mode        => CLASSIC,
      g_master_granularity => g_address_granularity,
      g_slave_use_struct   => true,
      g_slave_mode         => g_slave_interface_mode,
      g_slave_granularity  => g_address_granularity)
    port map (
      clk_sys_i => clk_sys_i,
      rst_n_i   => rst_n_i,
      slave_i   => slave_i,
      slave_o   => slave_o,
      master_i  => adp_in,
      master_o  => adp_out);

  periph_addr <= adp_out.adr(g_bits_per_slave+c_periph_addr_bits-1 downto g_bits_per_slave);

  onehot_decode : process (periph_addr)  -- periph_sel <= onehot_decode(periph_addr)
    variable temp1 : std_logic_vector (periph_sel'high downto 0);
    variable temp2 : integer range 0 to periph_sel'high;
  begin
    temp1 := (others => '0');
    temp2 := 0;
    for i in periph_addr'range loop
      if (periph_addr(i) = '1') then
        temp2 := 2*temp2+1;
      else
        temp2 := 2*temp2;
      end if;
    end loop;
    temp1(temp2) := '1';
    periph_sel   <= temp1;
  end process;


  ACK_MUX : process (periph_addr_reg, master_i)
  begin
    if(to_integer(unsigned(periph_addr_reg)) < g_num_outputs) then
      ack_muxed <= master_i(to_integer(unsigned(periph_addr_reg))).ack;
    else
      ack_muxed <= '0';
    end if;
  end process;


  DIN_MUX : process (periph_addr_reg, master_i)
  begin
    if(to_integer(unsigned(periph_addr_reg))) < g_num_outputs then
      data_in_muxed <= master_i(to_integer(unsigned(periph_addr_reg))).dat;
    else
      data_in_muxed <= (others => 'X');
    end if;
  end process;

  p_arbitrate : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        cycle_in_progress <= '0';
        ack_prev          <= '0';
        periph_addr_reg   <= (others => '0');
        periph_sel_reg    <= (others => '0');
        adp_in.dat <= (others => '0');
        adp_in.ack <= '0';
      else
        periph_sel_reg  <= periph_sel;
        periph_addr_reg <= periph_addr;

        if(cycle_in_progress = '0') then
          if(adp_out.cyc = '1' and adp_in.ack = '0') then
            cycle_in_progress <= '1';
          end if;
          ack_prev <= '0';
          adp_in.ack<='0';
        else
          adp_in.dat <= data_in_muxed;
          ack_prev   <= ack_muxed;
          if(ack_prev = '0' and ack_muxed = '1') then
            adp_in.ack <= '1';
          else
            adp_in.ack <= '0';
          end if;
          
          if(ack_muxed = '1') then
            cycle_in_progress <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;

--  adp_in.ack <= ack_prev and adp_out.stb;

  gen_outputs : for i in 0 to g_num_outputs-1 generate
    master_o(i).cyc <= adp_out.cyc and periph_sel(i);
    master_o(i).adr <= adp_out.adr;
    master_o(i).dat <= adp_out.dat;
    master_o(i).stb <= adp_out.stb and not (not cycle_in_progress and ack_prev);
    master_o(i).we  <= adp_out.we;
    master_o(i).sel <= adp_out.sel;
  end generate gen_outputs;

  adp_in.err   <= '0';
  adp_in.stall <= '0';
  adp_in.rty   <= '0';
  
end rtl;
