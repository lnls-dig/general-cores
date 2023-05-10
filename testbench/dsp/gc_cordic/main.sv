`include "sim_logger.svh"
`timescale 1ns/1ps

import gc_cordic_pkg::*;

const bit[0:0] MODE_VECTOR =1'b0;
const bit[0:0] MODE_ROTATE =1'b1;

const bit[1:0] SUBMODE_CIRCULAR = 2'b00;
const bit[1:0] SUBMODE_LINEAR  = 2'b01;
const bit[1:0] SUBMODE_HYPERBOLIC = 2'b11;

const real M_PI = 3.14159265358;
const real AN = 1.6467602581210656483661780066297;


module main;

   reg rst_n = 0;
   reg clk= 0;
   
   parameter time g_clk_period = 10.0ns; 


   always #(g_clk_period/2) clk <= ~clk;
   initial #200ns rst_n <= 1;

   logic signed [15:0] x0=0, y0=0, z0=0;
   wire signed [15:0]  xn, yn, zn;

//   ROTATE/CIRCULAR -> mag/phase -> sin/cos
//   VECTOR/CIRCULAR -> sin/soc -> mag/phase

   logic [0:0] 	       cor_mode = MODE_ROTATE;
   logic [1:0] 	       cor_submode = SUBMODE_CIRCULAR;

   const int 	       c_PHASE_BITS = 16;
   const int 	       c_PIPELINE_DELAY = 17;
   
   typedef struct {
      real 	  phase;
      real 	  mag;
      logic signed [15:0] x, y, z;
   } cordic_data_t;

   cordic_data_t cor_in, cor_out;


  
   
   gc_cordic #(
	       .g_N(16),
	       .g_M(16),
	       .g_ANGLE_FORMAT(1)
	       )
   DUT 
     (
      .clk_i(clk),
      .rst_i(~rst_n),

      .cor_mode_i    ( cor_mode ),
      .cor_submode_i ( cor_submode ),
      
      .lim_x_i(1'b0),
      .lim_y_i(1'b0),

      .x0_i(cor_in.x),
      .y0_i(cor_in.y),
      .z0_i(cor_in.z),

      .xn_o(cor_out.x),
      .yn_o(cor_out.y),
      .zn_o(cor_out.z),

      .lim_x_o(),
      .lim_y_o(),

      .rst_o()
      );

    `ifdef disabled
    CoRDICPipeHD
      #(
	    
           .N(16),
           .M(16)
         //  .AngleMode(1'b1)
           )
   DUT2
    (
     .Clk(clk),
     .RstO(),
     .Rst(~rst_n),
     .LimXin(1'b0),
     .LimX(),
     .LimY(),

     .X0(cor_in.x),
      .Y0(cor_in.y),
      .Z0(cor_in.z),

//      .Xn(cor_out.x),
//      .Yn(cor_out.y),
//      .Zn(cor_out.z),
     
//     .CorMode : in CoRDiCMode;
     .LimYin(1'b0)
        );

    `endif //  `ifdef disabled
   
    function int abs(int x);
      if(x<0)
	x=-x;
      return x;
   endfunction // abs
   

   task automatic run_cordic_testcase( cordic_data_t in [$], cordic_data_t exp_out[$], int latency, int max_error, bit check_x, bit check_y, bit check_z, output int err_count );
      automatic Logger l = Logger::get();
      automatic int j;
      
      cordic_data_t out[$];
      
      fork
	 begin : din
	    foreach( in[i] )
	      begin
		 cor_in <= in[i];
		 @(posedge clk);
	      end
	 end
	 begin : dout
	    repeat(latency) @(posedge clk);
	    for(j=0; j < in.size(); j++)
	      begin
		 @(posedge clk);
		 out.push_back(cor_out);
	      end
	 end
      join
      
      for(j=0;j<in.size();j++)
	begin
	   cordic_data_t e = exp_out[j];
	   cordic_data_t o = out[j];
	   cordic_data_t err = e;

	   err.x = abs(e.x-o.x);
	   err.y = abs(e.y-o.y);
	   err.z = abs(e.z-o.z);
	   if(check_x && err.x > max_error)
	     begin
		l.msg(1, $sformatf( "Sample %d: X expected = %d, actual = %d", j, e.x, o.x) );
		err_count++;
	     end
	   
	   if(check_y && err.y > max_error)
	     begin
		l.msg(1, $sformatf( "Sample %f: Y expected = %d, actual = %d", j, e.y, o.y) );
		err_count++;
	     end
	   
	   if(check_z && err.z > max_error)
	     begin
		l.msg(1, $sformatf( "Sample %d: Z expected = %d, actual = %d", j, e.z, o.z) );
		err_count++;
	     end
	   
	end

      
   endtask // run_cordic_testcase

  
      
      

   function int phase2fix( real phase );
      int rv;
      
      while( phase > M_PI )
	phase -= 2.0*M_PI;
      while (phase < -M_PI )
	phase += 2.0*M_PI;
      
      rv= int' ( real'((1 << (c_PHASE_BITS-1) ) - 1) * phase / M_PI );

//      $display("ph %f %d\n", phase, rv);

      
      return rv;
      
   endfunction // phase2fix

   function real rand_real(real a, real b);
      return a + (b-a)*(real'($urandom())/32'hffffffff);
   endfunction // rand_real
   
  
   task automatic run_testcase_sincos( int nsamples );
      automatic Logger l = Logger::get();
      cordic_data_t in[$], expected[$], tmp, result;
      int i, err_cnt=0;

      l.startTest("Cordic Angle/Mag -> Sin/Cos");

      cor_mode = MODE_ROTATE;
      cor_submode = SUBMODE_CIRCULAR;

      for(i=0; i < nsamples; i++)
	begin
	   tmp.mag = $random()%15000;
	   tmp.phase = rand_real(-M_PI, M_PI); //  -M_PI + (2*M_PI*real'(i)/real'(nsamples) );//rand_real(-M_PI, M_PI);
	   in.push_back(tmp);
	end
    
      
      foreach (in[i])
	begin
	   real mag = in[i].mag * AN;

	   in[i].x = int'(in[i].mag);
	   in[i].y = 0;
	   in[i].z = phase2fix( in[i].phase );
	   		    
	   result.x = int'( mag * $cos( in[i].phase ) );
	   result.y = int'( mag * $sin( in[i].phase ) );
	   
	   result.z = 0;
	   expected.push_back(result);
	   
	end

      run_cordic_testcase( in, expected, c_PIPELINE_DELAY, 20, 1, 1, 0, err_cnt );
      l.msg(0, $sformatf( "Mag/Phase->Sin/Cos: %d errors", err_cnt) );
      
      if( err_cnt )
         l.fail("Cordic/s sin/cos value mismatch with model values");
      else
         l.pass();
      
   endtask // run_testcase_sincos

    task automatic run_testcase_angle_mag( int nsamples );
      automatic Logger l = Logger::get();
      
      cordic_data_t in[$], expected[$], tmp, result;
      int i, err_cnt=0;

      l.startTest("Cordic Sin/Cos -> Angle/Mag");
      
      cor_mode = MODE_VECTOR;
      cor_submode = SUBMODE_CIRCULAR;

      for(i=0; i < nsamples; i++)
	begin
	   tmp.mag = 10000+ ( $urandom()%5000 );
	   tmp.phase =  rand_real(-M_PI, M_PI);

	   tmp.x = int'( tmp.mag * $cos( tmp.phase ) );
	   tmp.y = int'( tmp.mag * $sin( tmp.phase ) );
	   tmp.z = 0;
	   

	   in.push_back(tmp);

	   result.x = int'( real'(tmp.mag) * AN );
	   
	   result.z = phase2fix(tmp.phase);
	   expected.push_back(result);
	end

      run_cordic_testcase( in, expected, c_PIPELINE_DELAY, 20, 1, 0, 1, err_cnt );
      l.msg(0, $sformatf( "Sin/Cos->Mag/Phase: %d errors", err_cnt) );

      if( err_cnt )
         l.fail("Cordic/s mag/phase value mismatch with model values");
      else
         l.pass();

   endtask
	
   
   task setup();
      while(!rst_n) @(posedge clk);

      @(posedge clk);
   endtask

   initial begin
      automatic Logger l = Logger::get();

      setup();
      
      run_testcase_sincos( 10000 );
      run_testcase_angle_mag( 10000 );

      l.writeTestReport(1);

      $stop;
   end
   
   
endmodule
