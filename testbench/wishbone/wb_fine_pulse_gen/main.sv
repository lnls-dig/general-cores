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


class DDSSyncUnitDriver;

   protected CBusAccessor m_acc;
   protected int m_base;


   function new(CBusAccessor acc, int base);
      m_acc =acc;
      m_base =base;
   endfunction // new

   task automatic pulse( int out, int polarity, int cont, real delta, int tr_force = 0 );
      const real refclk_period = 5.0;
      const real n_fine_taps = 31;
      const real tap_size = 0.078; /* ns */
 // refclk_period/n_fine_taps;
      uint64_t rv;

      
      
      int coarse_par = int'($floor (delta / 16.0));
      int coarse_ser = int'($floor (delta / 1.0) - coarse_par * 16);
      int fine = int'((delta / 1.0 - $floor(delta / 1.0)) * 1.0 / tap_size);
      int mask = coarse_ser;
 //(1 << (7-coarse_ser+1)) - 1;
      uint32_t ocr;

  //    coarse_par = 0;
//      coarse_ser = 0;
//      $display("tapSize %f \n", tap_size);
      
//      $display("pgm %d %d %d", coarse_par, coarse_ser, fine);

      
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

   
endclass // DDSSyncUnitDriver


  
	   
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
       .g_num_channels(1)
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
      
      CBusAccessor acc = Host.get_accessor();
      DDSSyncUnitDriver drv = new( acc, 0 );
      

      @(posedge rst_n);
      @(posedge clk_62m5);
      @(posedge pps_p);

      #1us;
      
      


/* -----\/----- EXCLUDED -----\/-----
      drv.pulse(1, 0, 1, 100);
      drv.pulse(4, 0, 0, 100, 1);
 -----/\----- EXCLUDED -----/\----- */


      for (t = 1.0; t <= 200.9; t+=0.1)
	begin
//	   $display("Pulse @ %f", t );
	   
	   dlys.push_back(t);
	   drv.pulse(0, 1, 0, t);
	end
      
      

      
      #1us;

      

   end // initial begin

endmodule // main
