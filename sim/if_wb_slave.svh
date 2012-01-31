`ifndef __IF_WISHBONE_SLAVE_SVH
`define __IF_WISHBONE_SLAVE_SVH

`timescale 1ns/1ps

`include "if_wishbone_types.svh"



interface IWishboneSlave
  (
   input clk_i,
   input rst_n_i
   );

   parameter g_addr_width  = 32;
   parameter g_data_width  = 32;
   
   
   wire [g_addr_width - 1: 0] adr;
   wire [g_data_width - 1: 0] dat_i;
   wire [(g_data_width/8)-1 : 0] sel; 
   logic [g_data_width - 1 : 0] dat_o;
   logic ack;
   logic stall;
   logic err;
   logic rty;
   wire	cyc;
   wire stb;
   wire we;



   time last_access_t  = 0;

   modport slave
     (
      input adr,
      input dat_o,
      input sel,
      input cyc,
      input stb,
      input we,
      output ack,
      output dat_i,
      output stall,
      output err,
      output rty
      );

   wb_cycle_t c_queue[$];
   wb_cycle_t current_cycle;

   reg cyc_prev;
   int trans_index;
   int first_transaction;

   struct {
      wb_cycle_type_t mode;
      int gen_random_stalls;
      int stall_min_duration;
      int stall_max_duration;
      real stall_prob;
   } settings;


   function automatic int _poll(); return poll(); endfunction
   task automatic _get(ref wb_cycle_t xfer); get(xfer); endtask

   class CIWBSlaveAccessor extends CWishboneAccessor;

      function automatic int poll();
         return _poll();
      endfunction
      
      task get(ref wb_cycle_t xfer);
         _get(xfer);
      endtask
      
      task clear();
      endtask // clear
      
   endclass // CIWBSlaveAccessor
   

   function CIWBSlaveAccessor get_accessor();
      CIWBSlaveAccessor tmp;
      tmp  = new;
      return tmp;
   endfunction // get_accessor
      
   
   function automatic int poll();
      return c_queue.size() != 0;
   endfunction // poll
      
   task automatic get(ref wb_cycle_t xfer);
      while(c_queue.size() <= 0)
	@(posedge clk_i);
	
      xfer 			    = c_queue.pop_front();
   endtask // pop_cycle


   always@(posedge clk_i) cyc_prev <= cyc;
   wire cyc_start 		    = !cyc_prev && cyc;
   wire cyc_end 		    = cyc_prev && !cyc;


   task gen_random_stalls();
      static int stall_remaining  = 0;
      static int seed             = 0;

//      $display("stallr: %d\n", stall_remaining);
      
      if(settings.gen_random_stalls && (probability_hit(settings.stall_prob) || stall_remaining > 0))
        begin
           
           if(stall_remaining == 0)
             stall_remaining           = $dist_uniform(seed, 
                                                    settings.stall_min_duration,
                                                    settings.stall_max_duration);
           if(stall_remaining) 
             stall_remaining--;
           
	   stall <= 1;
        end else
	  stall <= 0;
      
	
   endtask // gen_random_stalls

   function automatic int count_ones(int x, int n_bits);
      int i, cnt;
      cnt  = 0;
      for(i=0;i<n_bits;i++) if(x & (1<<i)) cnt ++;
      return cnt;
   endfunction

   function automatic int count_leading_zeroes(int x, int n_bits);
     int i;
      for(i=0;i<n_bits && !(x & (1<<i)); i++);
      return i;
   endfunction // count_leading_zeroes

    function automatic int count_trailing_zeroes(int x, int n_bits);
     int i;
      for(i=n_bits-1;i>=0 && !(x & (1<<i)); i--);
      return (n_bits-1-i);
   endfunction

   
   task pipelined_fsm();

      if(settings.gen_random_stalls)
	gen_random_stalls();
      else
        stall               <= 0;
      
/* -----\/----- EXCLUDED -----\/-----
      if(cyc) begin

	 end else
	   stall            <= 0;
 -----/\----- EXCLUDED -----/\----- */
      
      if(cyc_start) begin
	 current_cycle.data  = {};
	 trans_index        <= 0;
	 first_transaction   = 1;
      end

      if(cyc_end) begin
	 c_queue.push_back(current_cycle);
      end

      if(stb && we && !stall && cyc) begin
         int oc, lzc, tzc;
         
	 wb_xfer_t d;
         
         oc      = count_ones(sel, g_data_width/8);
         lzc     = count_leading_zeroes(sel, g_data_width/8);
         tzc     = count_trailing_zeroes(sel, g_data_width/8);
	 d.a     = adr * (g_data_width / 8);
         d.size  = oc;
	 d.d     = (dat_i>>(8*lzc)) & ((1<<(oc*8)) -1);
         
         if(lzc + tzc + oc != g_data_width/8)
           $error("IWishboneSlave [write a %x d %x sel %x]: non-contiguous sel", adr, dat_i, sel);
         
	 d.sel [g_data_width/8-1:0] = sel;
     
	 current_cycle.data.push_back(d);

//	$display("ifWb:[%d] write a %x d %x sel %x",current_cycle.data.size(), adr, dat_i, sel);
	 ack <= 1;
	 
      end else if(stb && !we && !stall) begin
//	 $error("Sorry, no pipelined read for slave yet implemented");
	ack 			<= 0;
      end else
	ack 			<= 0;


      
   endtask // pipelined_fsm
      
   always@(posedge clk_i)
     begin
	if(!rst_n_i)
	  begin
	     c_queue 		 = {};
	     current_cycle.data  = {};
	     trans_index 	 = 0;
	     ack 		<= 0;
	     rty 		<= 0;
	     err 		<= 0;
	     dat_o 		<= 0;
	     stall 		<= 0;
	     
	  end else begin
	     if(settings.mode == PIPELINED)
		  pipelined_fsm();
	     end
     end
   
   initial begin
      settings.mode                = PIPELINED;
      settings.gen_random_stalls   = 1;
      settings.stall_prob          = 0.1;
      settings.stall_min_duration  = 1;
      settings.stall_max_duration  = 2;
      
   end
   
   
   
endinterface // IWishboneSlave

`endif