--------------------------------------------------------------------------------
--  Modifications:
--      2016-08-24: by Jan Pospisil (j.pospisil@cern.ch)
--          * added assignments to (new) unspecified WB signals
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wishbone_pkg.all;
use work.genram_pkg.all;

-- If you reset one clock domain, you must reset BOTH!
-- Release of the reset lines may be arbitrarily out-of-phase
entity xwb_clock_crossing is
   generic(
      g_size : natural := 16);
   port(
      -- Slave control port
      slave_clk_i    : in  std_logic;
      slave_rst_n_i  : in  std_logic;
      slave_i        : in  t_wishbone_slave_in;
      slave_o        : out t_wishbone_slave_out;
      -- Master reader port
      master_clk_i   : in  std_logic;
      master_rst_n_i : in  std_logic;
      master_i       : in  t_wishbone_master_in;
      master_o       : out t_wishbone_master_out;
      -- Flow control back-channel for acks
      slave_ready_o : out std_logic;
      slave_stall_i : in  std_logic);
end xwb_clock_crossing;

architecture rtl of xwb_clock_crossing is
   constant mCYC_start : natural := 0;
   constant mCYC_end   : natural := mCYC_start;
   constant mWE_start  : natural := mCYC_end + 1;
   constant mWE_end    : natural := mWE_start;
   constant mADR_start : natural := mWE_end + 1;
   constant mADR_end   : natural := mADR_start + c_wishbone_address_width - 1;
   constant mDAT_start : natural := mADR_end + 1;
   constant mDAT_end   : natural := mDAT_start + c_wishbone_data_width - 1;
   constant mSEL_start : natural := mDAT_end + 1;
   constant mSEL_end   : natural := mSEL_start + (c_wishbone_data_width/8) - 1;
   constant mlen       : natural := mSEL_end + 1;

   signal msend, mrecv : t_wishbone_master_out;
   signal msend_vect, mrecv_vect : std_logic_vector(mlen-1 downto 0);
   signal mw_en, mr_empty, mr_en : std_logic;

   constant sACK_start : natural := 0;
   constant sACK_end   : natural := sACK_start;
   constant sRTY_start : natural := sACK_end + 1;
   constant sRTY_end   : natural := sRTY_start;
   constant sERR_start : natural := sRTY_end + 1;
   constant sERR_end   : natural := sERR_start;
   constant sDAT_start : natural := sERR_end + 1;
   constant sDAT_end   : natural := sDAT_start + c_wishbone_data_width - 1;
   constant slen       : natural := sDAT_end + 1;

   signal ssend, srecv : t_wishbone_slave_out;
   signal ssend_vect, srecv_vect : std_logic_vector(slen-1 downto 0);
   signal sw_en, sr_empty, sr_en : std_logic;

   signal slave_CYC : std_logic;
   signal master_o_STB : std_logic;
   signal slave_o_PUSH : std_logic;

   -- We need to limit the total number of incomplete Wishbone requests.
   -- Consider a slow master and fast slave.
   -- The master slowly pushes a lot of requests.
   -- The slave pops them immediately from the mfifo and queues them itself.
   -- Suddenly, the slave can do work and answers all pending requests.
   -- The slow master is unable to read the sfifo fast enough and it overflows.

   subtype t_count is unsigned(f_ceil_log2(g_size+1)-1 downto 0);

   signal mpushed : t_count;
   signal mpopped : t_count;
   signal full    : std_logic;

begin

   full <= '1' when mpushed = mpopped else '0';
   count : process(slave_clk_i, slave_rst_n_i) is
   begin
      if slave_rst_n_i = '0' then
         mpushed <= (others => '0');
         mpopped <= to_unsigned(g_size, t_count'length);
      elsif rising_edge(slave_clk_i) then
         if (not full and slave_i.CYC and slave_i.STB) = '1' then
            mpushed <= mpushed + 1;
         end if;
         if slave_o_PUSH = '1' then
            mpopped <= mpopped + 1;
         end if;
      end if;
   end process;

   mfifo : generic_async_fifo
      generic map(
         g_data_width      => mlen,
         g_size            => g_size)
      port map(
         rst_n_i           => slave_rst_n_i,
         clk_wr_i          => slave_clk_i,
         d_i               => msend_vect,
         we_i              => mw_en,
         wr_empty_o        => open,
         wr_full_o         => open,
         wr_almost_empty_o => open,
         wr_almost_full_o  => open,
         wr_count_o        => open,
         clk_rd_i          => master_clk_i,
         q_o               => mrecv_vect,
         rd_i              => mr_en,
         rd_empty_o        => mr_empty,
         rd_full_o         => open,
         rd_almost_empty_o => open,
         rd_almost_full_o  => open,
         rd_count_o        => open);

   msend_vect(mCYC_start) <= msend.CYC;
   msend_vect(mWE_start) <= msend.WE;
   msend_vect(mADR_end downto mADR_start) <= msend.ADR;
   msend_vect(mDAT_end downto mDAT_start) <= msend.DAT;
   msend_vect(mSEL_end downto mSEL_start) <= msend.SEL;

   mrecv.CYC <= mrecv_vect(mCYC_start);
   mrecv.WE  <= mrecv_vect(mWE_start);
   mrecv.ADR <= mrecv_vect(mADR_end downto mADR_start);
   mrecv.DAT <= mrecv_vect(mDAT_end downto mDAT_start);
   mrecv.SEL <= mrecv_vect(mSEL_end downto mSEL_start);

   sfifo : generic_async_fifo
      generic map(
         g_data_width      => slen,
         g_size            => g_size)
      port map(
         rst_n_i           => master_rst_n_i,
         clk_wr_i          => master_clk_i,
         d_i               => ssend_vect,
         we_i              => sw_en,
         wr_empty_o        => open,
         wr_full_o         => open,
         wr_almost_empty_o => open,
         wr_almost_full_o  => open,
         wr_count_o        => open,
         clk_rd_i          => slave_clk_i,
         q_o               => srecv_vect,
         rd_i              => sr_en,
         rd_empty_o        => sr_empty,
         rd_full_o         => open,
         rd_almost_empty_o => open,
         rd_almost_full_o  => open,
         rd_count_o        => open);

   ssend_vect(sACK_start) <= ssend.ACK;
   ssend_vect(sRTY_start) <= ssend.RTY;
   ssend_vect(sERR_start) <= ssend.ERR;
   ssend_vect(sDAT_end downto sDAT_start) <= ssend.DAT;

   srecv.ACK <= srecv_vect(sACK_start);
   srecv.RTY <= srecv_vect(sRTY_start);
   srecv.ERR <= srecv_vect(sERR_start);
   srecv.DAT <= srecv_vect(sDAT_end downto sDAT_start);

   -- Slave clock domain: slave -> mFIFO
   mw_en <= (not full and slave_i.CYC and slave_i.STB) or 
            (not slave_i.CYC and slave_CYC); -- Masters may only drop cycle if FIFOs are empty
   slave_o.STALL <= full;
   msend.CYC <= slave_i.CYC;
   msend.ADR <= slave_i.ADR;
   msend.WE  <= slave_i.WE;
   msend.SEL <= slave_i.SEL;
   msend.DAT <= slave_i.DAT;

   -- Master clock domain: mFIFO -> master
   mr_en <= not mr_empty and (not mrecv.CYC or not master_o_STB or not master_i.STALL);
   master_o.CYC <= mrecv.CYC;
   master_o.STB <= master_o_STB; -- is high outside of CYC. that's ok; it should be ignored.
   master_o.ADR <= mrecv.ADR;
   master_o.WE  <= mrecv.WE;
   master_o.SEL <= mrecv.SEL;
   master_o.DAT <= mrecv.DAT;

   drive_master_port : process(master_clk_i, master_rst_n_i)
   begin
      if master_rst_n_i = '0' then
         master_o_STB <= '0';
      elsif rising_edge(master_clk_i) then
         master_o_STB <= mr_en or (mrecv.CYC and master_o_STB and master_i.STALL);
      end if;
   end process;

   -- Master clock domain: master -> sFIFO
   sw_en <= master_i.ACK or master_i.ERR or master_i.RTY;
   ssend.ACK <= master_i.ACK;
   ssend.ERR <= master_i.ERR;
   ssend.RTY <= master_i.RTY;
   ssend.DAT <= master_i.DAT;

   -- Slave clock domain: sFIFO -> slave
   slave_ready_o <= not sr_empty;
   sr_en <= not sr_empty and not slave_stall_i;
   slave_o.DAT <= srecv.DAT;
   slave_o.ACK <= srecv.ACK and slave_o_PUSH;
   slave_o.RTY <= srecv.RTY and slave_o_PUSH;
   slave_o.ERR <= srecv.ERR and slave_o_PUSH;

   drive_slave_port : process(slave_clk_i, slave_rst_n_i)
   begin
      if slave_rst_n_i = '0' then
         slave_o_PUSH <= '0';
         slave_CYC <= '0';
      elsif rising_edge(slave_clk_i) then
         slave_o_PUSH <= sr_en;
         slave_CYC <= slave_i.CYC;
      end if;
   end process;

   slave_o.int <= '0'; -- TODO: not implemented
end rtl;
