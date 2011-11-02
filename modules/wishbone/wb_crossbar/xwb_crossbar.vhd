-------------------------------------------------------------------------------
-- Title      : An MxS Wishbone crossbar switch
-- Project    : General Cores Library (gencores)
-------------------------------------------------------------------------------
-- File       : xwb_crossbar.vhd
-- Author     : Wesley W. Terpstra
-- Company    : GSI
-- Created    : 2011-06-08
-- Last update: 2011-09-22
-- Platform   : FPGA-generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description:
--
-- An MxS Wishbone crossbar switch
-- 
-- All masters, slaves, and the crossbar itself must share the same WB clock.
-- All participants must support the same data bus width. 
-- 
-- If a master raises STB_O with an address not mapped by the crossbar,
-- ERR_I will be raised. If the crossbar has overlapping address ranges,
-- the lowest numbered slave is selected. If two masters address the same
-- slave simultaneously, the lowest numbered master is granted access.
-- 
-- The implementation of this crossbar locks a master to a slave so long as
-- CYC_O is held high. If the master tries to address outside the slave's
-- address range, ERR_I will be raised.
--
-------------------------------------------------------------------------------
-- Copyright (c) 2011 GSI / Wesley W. Terpstra
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2011-06-08  1.0      wterpstra       import from SVN
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wishbone_pkg.all;

entity xwb_crossbar is
  generic(
    g_num_masters : integer := 2;
    g_num_slaves  : integer := 1;
    g_registered  : boolean := false
    );
  port(
    clk_sys_i     : in  std_logic;
    rst_n_i       : in  std_logic;
    -- Master connections (INTERCON is a slave)
    slave_i       : in  t_wishbone_slave_in_array(g_num_masters-1 downto 0);
    slave_o       : out t_wishbone_slave_out_array(g_num_masters-1 downto 0);
    -- Slave connections (INTERCON is a master)
    master_i      : in  t_wishbone_master_in_array(g_num_slaves-1 downto 0);
    master_o      : out t_wishbone_master_out_array(g_num_slaves-1 downto 0);
    -- Address of the slaves connected
    cfg_address_i : in  t_wishbone_address_array(g_num_slaves-1 downto 0);
    cfg_mask_i    : in  t_wishbone_address_array(g_num_slaves-1 downto 0)
    );
end xwb_crossbar;

architecture rtl of xwb_crossbar is
  type matrix is array (g_num_masters-1 downto 0, g_num_slaves downto 0) of std_logic;
  type column is array (g_num_masters-1 downto 0) of std_logic;
  type row is array (g_num_slaves downto 0) of std_logic;
  
  -- Add an 'error' device to the list of slaves
  signal master_ie : t_wishbone_master_in_array(g_num_slaves downto 0);
  signal master_oe : t_wishbone_master_out_array(g_num_slaves downto 0);
  signal virtual_ERR : std_logic;
  
  signal matrix_old : matrix; -- Registered connection matrix
  signal matrix_new : matrix; -- The new values of the matrix

  -- Either matrix_old or matrix_new, depending on g_registered
  signal granted : matrix;
  
  procedure main_logic(
    signal granted  : out matrix;
    signal slave_i  : in  t_wishbone_slave_in_array(g_num_masters-1 downto 0);
    signal previous : in  matrix) is
    variable acc, tmp : std_logic;
    variable request  : matrix;  -- Which slaves do the masters address log(S) 
    variable selected : matrix;  -- Which master wins arbitration  log(M) request
    variable sbusy    : row;  -- Does the slave's  previous connection persist?
    variable mbusy    : column;  -- Does the master's previous connection persist?
  begin
    -- A slave is busy iff it services an in-progress cycle
    for slave in g_num_slaves downto 0 loop
      acc := '0';
      for master in g_num_masters-1 downto 0 loop
        acc := acc or (previous(master, slave) and slave_i(master).CYC);
      end loop;
      sbusy(slave) := acc;
    end loop;

    -- A master is busy iff it services an in-progress cycle
    for master in g_num_masters-1 downto 0 loop
      acc := '0';
      for slave in g_num_slaves downto 0 loop
        acc := acc or previous(master, slave);
      end loop;
      mbusy(master) := acc and slave_i(master).CYC;
    end loop;

    -- Decode the request address to see if master wants access
    for master in g_num_masters-1 downto 0 loop
      acc := '0';
      for slave in g_num_slaves-1 downto 0 loop
        if (slave_i(master).ADR and  cfg_mask_i(slave)) = cfg_address_i(slave) then
          tmp := '1';
        else
          tmp := '0';
        end if;
        acc                    := acc or tmp;
        request(master, slave) := slave_i(master).CYC and slave_i(master).STB and tmp;
      end loop;
      -- If no slaves match request, bind to 'error device'
      request(master, g_num_slaves) := slave_i(master).CYC and slave_i(master).STB and not acc;
    end loop;

    -- Arbitrate among the requesting masters
    -- Policy: lowest numbered master first
    for slave in g_num_slaves downto 0 loop
      acc := '0';
      -- It is possible to break the chain of LUTs here using a sort of kogge-stone network
      -- This probably only makes sense if you have more than 32 masters
      for master in 0 to g_num_masters-1 loop
        selected(master, slave) := request(master, slave) and not acc;
        acc                     := acc or request(master, slave);
      end loop;
    end loop;

    -- Determine the master granted access
    -- Policy: if cycle still in progress, preserve the previous choice
    for slave in g_num_slaves downto 0 loop
      for master in g_num_masters-1 downto 0 loop
        if sbusy(slave) = '1' or mbusy(master) = '1' then
          granted(master, slave) <= previous(master, slave);
        else
          granted(master, slave) <= selected(master, slave);
        end if;
      end loop;
    end loop;
  end main_logic;

  -- Select the master pins the slave will receive
  procedure slave_logic(signal o       : out t_wishbone_master_out;
                        signal slave_i : in  t_wishbone_slave_in_array(g_num_masters-1 downto 0);
                        signal granted : in  matrix;
                        slave          :     integer) is
    variable acc             : t_wishbone_master_out;
    variable granted_address : t_wishbone_address;
    variable granted_select  : t_wishbone_byte_select;
    variable granted_data    : t_wishbone_data;
  begin
    acc := (
      CYC => '0',
      STB => '0',
      ADR => (others => '0'),
      SEL => (others => '0'),
      WE  => '0',
      DAT => (others => '0'));

    for master in g_num_masters-1 downto 0 loop
      granted_address := (others => granted(master, slave));
      granted_select  := (others => granted(master, slave));
      granted_data    := (others => granted(master, slave));
      acc := (
        CYC => acc.CYC or (slave_i(master).CYC and granted(master, slave)),
        STB => acc.STB or (slave_i(master).STB and granted(master, slave)),
        ADR => acc.ADR or (slave_i(master).ADR and granted_address),
        SEL => acc.SEL or (slave_i(master).SEL and granted_select),
        WE  => acc.WE or (slave_i(master).WE and granted(master, slave)),
        DAT => acc.DAT or (slave_i(master).DAT and granted_data));
    end loop;
    o <= acc;
  end slave_logic;

  -- Select the slave pins the master will receive
  procedure master_logic(signal o        : out t_wishbone_slave_out;
                         signal master_i : in  t_wishbone_master_in_array(g_num_slaves downto 0);
                         signal granted  : in  matrix;
                         master          :     integer) is
    variable acc          : t_wishbone_slave_out;
    variable granted_data : t_wishbone_data;
  begin
    acc := (
      ACK   => '0',
      ERR   => '0',
      RTY   => '0',
      STALL => '0',
      DAT   => (others => '0'),
      INT   => '0');

    -- We use inverted logic on STALL so that if no slave granted => stall
    for slave in g_num_slaves downto 0 loop
      granted_data := (others => granted(master, slave));
      acc := (
        ACK   => acc.ACK or (master_i(slave).ACK and granted(master, slave)),
        ERR   => acc.ERR or (master_i(slave).ERR and granted(master, slave)),
        RTY   => acc.RTY or (master_i(slave).RTY and granted(master, slave)),
        STALL => acc.STALL or (not master_i(slave).STALL and granted(master, slave)),
        DAT   => acc.DAT or (master_i(slave).DAT and granted_data),
        INT   => '0');
    end loop;
    acc.STALL := not acc.STALL;

    o <= acc;
  end master_logic;
begin
  -- The virtual error slave is pretty straight-forward:
  master_o <= master_oe(g_num_slaves-1 downto 0);
  master_ie(g_num_slaves-1 downto 0) <= master_i;
  
  master_ie(g_num_slaves) <= (
    ACK   => '0', 
    ERR   => virtual_ERR,
    RTY   => '0', 
    STALL => '0',
    DAT   => (others => '0'),
    INT   => '0');
  virtual_error_slave : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      virtual_ERR <= master_oe(g_num_slaves).CYC and master_oe(g_num_slaves).STB;
    end if;
  end process virtual_error_slave;
  
  -- Copy the matrix to a register:
  main : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        matrix_old <= (others => (others => '0'));
      else
        matrix_old <= matrix_new;
      end if;
    end if;
  end process main;
  
  -- Is the crossbar combinatorial or registered
  granted <= matrix_old when g_registered else matrix_new;

  -- Make the slave connections
  slave_matrix : for slave in g_num_slaves downto 0 generate
    slave_logic(master_oe(slave), slave_i, granted, slave);
  end generate;

  -- Make the master connections
  master_matrix : for master in g_num_masters-1 downto 0 generate
    master_logic(slave_o(master), master_ie, granted, master);
  end generate;

  -- The main crossbar logic:
  main_logic(matrix_new, slave_i, matrix_old);
end rtl;
