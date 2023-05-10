`timescale 1ns/1ps

import gc_dsp_pkg::*;

const real M_PI = 3.14159265358;
const real AN = 1.6467602581210656483661780066297;

typedef struct {
   int 	       value;
   bit 	       valid;
} opt_int_t;

class FIRFilterModel;

   protected int m_coefs[$];
   protected int m_delay[];
   protected int m_shift;
   protected int m_order;
   protected int m_samples;
 
   function new( int order, int coefs[$], int shift );
      m_coefs = coefs;
      m_delay = new[order];
      m_shift = shift;
      m_samples = 0;
      m_order = order;
      
   endfunction // new

   function automatic opt_int_t filter(int x);
      int 	 i;
      bit signed [63:0] 	 acc = 0;
      opt_int_t rv;

//      $display("Filter %d", x);
      
      
      for(i=m_order-2;i>=0;i--)
	m_delay[i+1] = m_delay[i];

      m_delay[0] = x;

      for(i=0;i<m_order;i++)
	begin
	   acc+=m_delay[i]*m_coefs[i];
	 //  $display("d %d c %d a %d", m_delay[i], m_coefs[i], acc);
	end
      

      acc += (1 << ( m_shift-1 ));
      acc >>= m_shift;

  //    $display("a %x", acc);
      

      m_samples++;
      rv.value = acc;
      rv.valid = 0;
      
      if( m_samples >= m_order )
	rv.valid = 1;

      return rv;
   endfunction // filter

endclass // FirFilterModel


module main;

   reg rst_n = 0;
   reg clk= 0;
   
   parameter time g_clk_period = 10.0ns; 

   always #(g_clk_period/2) clk <= ~clk;
   initial #200ns rst_n <= 1;

   
   localparam c_SYMMETRIC = 1'b1;
   
   localparam c_ORDER = 16;
   localparam c_COEF_BITS = 16;
   localparam c_OUTPUT_BITS = 16;
   localparam c_OUTPUT_SHIFT = 16;
   localparam c_DATA_BITS = 16;
   localparam c_SUM_PIPE_STAGES = 3;

   typedef logic signed [31:0] coefs_t[127:0];
      
   coefs_t coefs;
   
   function automatic coefs_t gen_some_coefs(int order, int bits, int symmetric);
      coefs_t r;
      int 				i, n = order;

      if(symmetric)
	n = (order + 1) / 2;
      
      for(i=0;i<n;i++)
	begin
	   int c = $random() % ( 1<<(bits-1) );
	   r[i] = c;
	   
	   if( symmetric )
	     r[order-1-i] = c;
	   
	end

      return r;
   endfunction // gen_some_coefs

   
   const int 	       c_PIPELINE_DELAY = 17;

   typedef struct {
      logic 	  valid;
      logic signed [c_DATA_BITS-1:0] data;
   } fir_data_t;

   fir_data_t fir_in;
   wire 			     fir_data_t fir_out;
   
   gc_pipelined_fir_filter
     #(
       .g_COEF_BITS       (c_COEF_BITS),
       .g_DATA_BITS       (c_DATA_BITS),
       .g_OUTPUT_BITS     (c_OUTPUT_BITS),
       .g_OUTPUT_SHIFT    (c_OUTPUT_SHIFT),
       .g_SUM_PIPE_STAGES (c_SUM_PIPE_STAGES),
       .g_SYMMETRIC       (c_SYMMETRIC),
       .g_ORDER           (c_ORDER)
       )
   DUT
     (
      .clk_i(clk),
      .rst_i(~rst_n),

      .coefs_i(coefs),

      .d_i(fir_in.data),
      .d_valid_i(fir_in.valid),

      .d_o(fir_out.data),
      .d_valid_o(fir_out.valid)
      );
       

   
    function int abs(int x);
      if(x<0)
	x=-x;
      return x;
   endfunction // abs
   

   task automatic run_filter_test( fir_data_t in [$], fir_data_t exp_out[$], int latency, int max_error, output int err_count );
      automatic int j;
      
      fir_data_t out[$];
      
      fork
	 begin : din
	    foreach( in[i] )
	      begin
		 fir_in <= in[i];
		 @(posedge clk);
	      end
	 end
	 begin : dout


	    for(j=0; j < in.size(); j++)
	      begin
		 @(posedge clk);
		 if( fir_out.valid )
		   begin
		      out.push_back(fir_out);
		   end
		 
	      end
	 end
      join
      
      for(j=0;j<in.size();j++)
	begin
	   fir_data_t e = exp_out[j];
	   fir_data_t o = out[j];

	   if( e !=o )
	     begin
		$error("Sample %d expected %d out %d", j, e.data, o.data);
		err_count++;
	     end
	end
   endtask // run_filter_test
   
   task automatic run_test( int nsamples );
      fir_data_t in[$], expected[$], tmp, result;
      int i, err_cnt=0;

      int my_coefs[$];
      FIRFilterModel model;
      
      for(i = 0; i < c_ORDER; i++)
	my_coefs.push_back(coefs[i]);
      
      model = new ( c_ORDER, my_coefs, c_OUTPUT_SHIFT );
      
      for(i=0; i < nsamples; i++)
	begin
	   tmp.data = $random()%32000;
	   tmp.valid = 1;
	   in.push_back(tmp);
	end
      
      foreach (in[i])
	begin
	   opt_int_t m = model.filter( in[i].data );
	   if( m.valid )
	     begin
		fir_data_t d;
		d.data = m.value;
//		$display("d %d", m.value);
		expected.push_back(d);
	     end
	   
	end

      run_filter_test( in, expected, 20, 0, err_cnt );
      $display("Test (order = %d, samples = %d): %d errors", c_ORDER, nsamples, err_cnt);
      
   endtask // run_testcase_sincos

   
	
   
   initial begin
      coefs = gen_some_coefs(c_ORDER, c_DATA_BITS, c_SYMMETRIC);
      fir_in.valid = 0;

      while(!rst_n) @(posedge clk);

      @(posedge clk);
      
      
      run_test( 50000 );
      $stop;
      
      
   end
   
   
endmodule
