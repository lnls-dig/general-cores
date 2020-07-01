//------------------------------------------------------------------------------
// Copyright CERN 2018
//------------------------------------------------------------------------------
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 2.0 (the "License"); you may not use this file except
// in compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-2.0.
// Unless required by applicable law or agreed to in writing, software,
// hardware and materials distributed under this License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
// or implied. See the License for the specific language governing permissions
// and limitations under the License.
//------------------------------------------------------------------------------

`timescale 1ps/1ps

`include "vhd_wishbone_master.svh"
`include "wb_fine_pulse_gen_regs.vh"

module dupa;
    xwb_fine_pulse_gen dut();
endmodule // dupa

class IBusDevice;

   CBusAccessor m_acc;
   uint64_t m_base;

   function new ( CBusAccessor acc, uint64_t base );
      m_acc =acc;
      m_base = base;
   endfunction // new
   
   virtual task write32( uint32_t addr, uint32_t val );
      m_acc.write(m_base +addr, val);
   endtask // write
   
   virtual task read32( uint32_t addr, output uint32_t val );
      uint64_t val64;
      
      m_acc.read(m_base +addr, val64);
      val = val64;
      
   endtask // write
   
   

endclass // BusDevice


class FinePulseGenDriver extends IBusDevice;

   protected int m_use_delayctrl = 1;
   protected real m_coarse_range = 16.0;
   protected real m_delay_tap_size = 0.078; /*ns*/
   protected int  m_fine_taps;
   
   
   

   function new(CBusAccessor acc, int base);
      super.new(acc,base);
   endfunction // new

   task automatic calibrate();
      int rv;
      real calib_time;
      int  calib_taps;

      $error("Calibrate start");
      
      write32( `ADDR_FPG_ODELAY_CALIB, `FPG_ODELAY_CALIB_EN_VTC);
      write32( `ADDR_FPG_ODELAY_CALIB, `FPG_ODELAY_CALIB_RST_IDELAYCTRL  |  `FPG_ODELAY_CALIB_RST_OSERDES | `FPG_ODELAY_CALIB_RST_ODELAY);
      #100ns;
      write32( `ADDR_FPG_ODELAY_CALIB, `FPG_ODELAY_CALIB_RST_IDELAYCTRL  | `FPG_ODELAY_CALIB_RST_OSERDES );
      #100ns;
      write32( `ADDR_FPG_ODELAY_CALIB, `FPG_ODELAY_CALIB_RST_IDELAYCTRL  );
      #100ns;
      write32( `ADDR_FPG_ODELAY_CALIB, 0 );
      #100ns;

      while(1)
	begin
	   read32( `ADDR_FPG_ODELAY_CALIB, rv );
	   $display("odelay = %x", rv);
	   
	   if ( rv & `FPG_ODELAY_CALIB_RDY )
	     break;
	   
	end

      write32(`ADDR_FPG_ODELAY_CALIB, 0);
      write32(`ADDR_FPG_ODELAY_CALIB, `FPG_ODELAY_CALIB_CAL_LATCH);

      read32( `ADDR_FPG_ODELAY_CALIB, rv );

      calib_time = real'(1.0);
      calib_taps = (rv & `FPG_ODELAY_CALIB_TAPS) >> `FPG_ODELAY_CALIB_TAPS_OFFSET;
      
      $display("FPG ODELAY calibration done, val %.1f/%d\n", calib_time, calib_taps );

      m_delay_tap_size = calib_time / real'(calib_taps);
            
   endtask // calibrate
   

   task automatic pulse( int out, int polarity, int cont, real delta, int tr_force = 0 );
      uint64_t rv;
      
      int coarse_par = int'($floor (delta / 16.0));
      int coarse_ser = int'($floor (delta / 1.0) - coarse_par * 16);
      int fine = int'((delta / 1.0 - $floor(delta / 1.0)) * 1.0 / m_delay_tap_size);
      int mask = coarse_ser;
      uint32_t ocr;

      $display("Tapsize %.5f Fine %d", m_delay_tap_size, fine);
      

      ocr = (coarse_par << `FPG_OCR0_PPS_OFFS_OFFSET)
	| (mask << `FPG_OCR0_MASK_OFFSET)
      | (fine << `FPG_OCR0_FINE_OFFSET)
      | (cont ? `FPG_OCR0_CONT : 0)
      | (polarity ? `FPG_OCR0_POL : 0 );
      
      m_acc.write( m_base + `ADDR_FPG_OCR0 + 4 * out, ocr );

      if(tr_force)
	m_acc.write( m_base + `ADDR_FPG_CSR, 1<< (6 + out) );
      else
	m_acc.write( m_base + `ADDR_FPG_CSR, 1<< (out) );

//      $display("triggered");

      forever begin
	 m_acc.read(m_base + `ADDR_FPG_CSR, rv);
	 
	 if( rv & ( 1 << (`FPG_CSR_READY_OFFSET + out ) ) )
	   break;
      end
      
	
    
   endtask

   
endclass // FinePulseGenDriver



  
	   
module main;

   reg rst_n = 0;
   reg clk_125m = 0;
   reg clk_250m = 0;
   reg clk_62m5 = 0;
   reg clk_dmtd = 0;
   
   always #2ns clk_250m <= ~clk_250m;
   always @(posedge clk_250m) clk_125m <= ~clk_125m;
   always #(7.9ns) clk_dmtd <= ~clk_dmtd;
   always @(posedge clk_125m) clk_62m5 <= ~clk_62m5;

   initial begin
      repeat(20) @(posedge clk_125m);
      rst_n = 1;
   end

   wire loop_p, loop_n;

   reg 	pps_p = 0;

   initial forever begin
      repeat(100) @(posedge clk_62m5);
      pps_p <= 1;
      @(posedge clk_62m5);
      pps_p <= 0;
   end
   
   time t_pps, t_pulse;

   real dlys[$];
   time first_delay = 0;
   time delta_prev = 0,delta;
   

   int 	t_pps_valid = 0;
   
 
   always@(posedge pps_p)
     begin
	t_pps = $time;
	t_pps_valid = 1;
     end
   

   always@(posedge DUT.pulse_o[0])
     begin
	t_pulse = $time;

	if( dlys.size() && t_pps_valid )
	  begin
	    automatic real t_req = dlys.pop_front();
	     automatic time dly = t_pulse - t_pps;

	     t_pps_valid = 0;
	     
	     if(!first_delay)
	       first_delay = dly;


	     $display("t_pps %t t_pulse %t delta %.2f", t_pps, t_pulse, real'(t_pulse - t_pps) / real'(1ns) );
	     
	     
/*	     delta = dly-first_delay;
	     
	     $display("delta: %-20d ps, ddelta : %-20d ps", delta, delta-delta_prev );

	     delta_prev = delta;*/
	     

	  end
	
     end
   
   
   
   
   

   
   // the Device Under Test
   xwb_fine_pulse_gen
     #(
       .g_target_platform("KintexUltrascale"),
       .g_use_external_serdes_clock(0),
       .g_num_channels(1),
       .g_use_odelay(6'b1)
       )
   DUT
     (
      .rst_sys_n_i(rst_n),

//      .clk_ser_ext_i(clk_250m),
      .clk_sys_i (clk_62m5),
      .clk_ref_i (clk_62m5),
      
      .pps_p_i(pps_p),
      
      .slave_i            (Host.out),
      .slave_o            (Host.in)
   );

      
   IVHDWishboneMaster Host
     (
      .clk_i   (clk_62m5),
      .rst_n_i (rst_n));




   
   initial begin
      real t;
      
      CWishboneAccessor acc;
      FinePulseGenDriver drv;
      
      @(posedge rst_n);
      @(posedge clk_62m5);
      @(posedge pps_p);

      #1us;
      
      acc = Host.get_accessor();
      acc.set_mode(PIPELINED);
      
      drv = new( acc, 0 );      

      drv.calibrate();
      
      


/* -----\/----- EXCLUDED -----\/-----
      drv.pulse(1, 0, 1, 100);
      drv.pulse(4, 0, 0, 100, 1);
 -----/\----- EXCLUDED -----/\----- */


      for (t = 1.0; t <= 200.9; t+=0.1)
	begin
	   $display("Pulse @ %f", t );
	   
	   dlys.push_back(t);
	   drv.pulse(0, 1, 0, t);
	end
      
      

      
      #1us;

      

   end // initial begin

endmodule // main
