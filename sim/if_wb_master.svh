//
// Title          : Software Wishbone master unit for testbenches
//
// File           : if_wishbone.sv
// Author         : Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
// Created        : Tue Mar 23 12:19:36 2010
// Standard       : SystemVerilog
//


/* Todo:
   pipelined reads
   settings wrapped in the accessor object 
*/

`include "simdrv_defs.svh"
`include "if_wishbone_types.svh"
`include "if_wishbone_accessor.svh"

interface IWishboneMaster
  (
   input clk_i,
   input rst_n_i
   );

   parameter g_addr_width 	   = 32;
   parameter g_data_width 	   = 32;

   logic [g_addr_width - 1 : 0] adr;
   logic [g_data_width - 1 : 0] dat_o;
   logic [(g_data_width/8)-1 : 0] sel; 
   wire [g_data_width - 1 : 0] dat_i;
   wire ack;
   wire stall;
   wire err;
   wire rty;
   logic	cyc;
   logic 	stb;
   logic 	we;

   wire clk;
   wire rst_n;
 
   time last_access_t 	  = 0;

   struct {
      int gen_random_throttling;
      real throttle_prob;
      int little_endian;
      int cyc_on_stall;
      wb_address_granularity_t addr_gran;
   } settings;

   modport master 
     (
      output adr,
      output dat_o,
      output sel,
      output cyc,
      output stb,
      output we,
      input ack,
      input dat_i,
      input stall,
      input err,
      input rty
      );

   function automatic logic[g_addr_width-1:0] gen_addr(uint64_t addr, int xfer_size);
      if(settings.addr_gran == WORD)
        case(g_data_width)
	  8: return addr;
	  16: return addr >> 1;
	  32: return addr >> 2;
	  64: return addr >> 3;
	  default: $error("IWishbone: invalid WB data bus width [%d bits\n]", g_data_width);
        endcase // case (xfer_size)
      else
        return addr;
   endfunction

   function automatic logic[63:0] rev_bits(logic [63:0] x, int nbits);
      logic[63:0] tmp;
      int i;
      
      for (i=0;i<nbits;i++)
        tmp[nbits-1-i]  = x[i];

      return tmp;
   endfunction // rev_bits
   

   //FIXME: little endian
   function automatic logic[(g_data_width/8)-1:0] gen_sel(uint64_t addr, int xfer_size, int little_endian);
      logic [(g_data_width/8)-1:0] sel;
      const int dbytes  = (g_data_width/8-1);
      
      
      sel               = ((1<<xfer_size) - 1);

      return rev_bits(sel << (addr % xfer_size), g_data_width/8);
      endfunction

   function automatic logic[g_data_width-1:0] gen_data(uint64_t addr, uint64_t data, int xfer_size, int little_endian);
      const int dbytes  = (g_data_width/8-1);
      logic[g_data_width-1:0] tmp;

      tmp  = data << (8 * (dbytes - (xfer_size - 1 - (addr % xfer_size))));
      
//      $display("GenData: xs %d dbytes %d %x", tmp, xfer_size, dbytes);
    
  
      return tmp;
      
   endfunction // gen_data

   function automatic uint64_t decode_data(uint64_t addr, logic[g_data_width-1:0] data,  int xfer_size);
      int rem;

    //  $display("decode: a %x d %x xs %x", addr, data ,xfer_size);
      

      rem  = addr % xfer_size;
      return (data >> (8*rem)) & ((1<<(xfer_size*8)) - 1);
   endfunction // decode_data
   

   task automatic classic_cycle 
     (
      inout wb_xfer_t xfer[],
      input bit rw,
      input int n_xfers,
      output wb_cycle_result_t result
      );
      
      int i;
      
      if($time != last_access_t) 
	    @(posedge clk_i); /* resynchronize, just in case */
      
      for(i=0;i<n_xfers;i++)
	begin
	      
	   stb   <= 1'b1;
	   cyc   <= 1'b1;
	   adr   <= gen_addr(xfer[i].a, xfer[i].size);
	   we    <= rw;
	   sel   <= gen_sel(xfer[i].a, xfer[i].size, settings.little_endian);
//gen_sel(xfer[i].a, xfer[i].size);
	   dat_o <= gen_data(xfer[i].a, xfer[i].d, xfer[i].size, settings.little_endian);
	   
	   @(posedge clk_i);
	 	 
	   if(ack == 0) begin
	      while(ack == 0) begin @(posedge clk_i); end
	   end else if(err == 1'b1 || rty == 1'b1)
	     begin
		cyc    <= 0;
		we     <= 0;
		stb    <= 0;
		result 	= (err ==1'b1 ? R_ERROR: R_RETRY);
		break;
	     end

	   xfer[i].d 	 = decode_data(xfer[i].a, dat_i, xfer[i].size);
           
 	   cyc 		 <= 0;
	   we 		 <= 0;
	   stb 		 <= 0;
	   
	end // if (ack == 0)
      
      @(posedge clk_i);
      
      result 	     = R_OK;
      last_access_t  = $time;
   endtask // automatic

   reg xf_idle 	     = 1;
   

   int ack_cnt_int;

   always@(posedge clk_i)
     begin
        if(!cyc)
          ack_cnt_int <= 0;
        else if(stb && !stall && !ack) 
	     ack_cnt_int++;
	else if((!stb || stall) && ack) 
	     ack_cnt_int--;
     end


   task automatic count_ack(ref int ack_cnt);
//      if(stb && !stall && !ack) 
//	ack_cnt++;
      if (ack) 
	ack_cnt--;
   endtask

   task automatic handle_readback(ref wb_xfer_t xf [$], input int read, ref int cur_rdbk);
      if(ack && read)
        begin
           xf[cur_rdbk].d = dat_i;
           cur_rdbk++;
        end
   endtask // handle_readback
   
   
   task automatic pipelined_cycle 
     (
      ref wb_xfer_t xfer[$],
      input int write,
      input int n_xfers,
      output wb_cycle_result_t result
      );
      
      int i;
      int ack_count ;
      int failure ;
      int cur_rdbk;
      

      ack_count  = 0;
      failure 	 = 0;

      xf_idle 	 = 0;
      cur_rdbk = 0;
      
      
      if($time != last_access_t) 
	@(posedge clk_i); /* resynchronize, just in case */

      while(stall && !settings.cyc_on_stall)
	@(posedge clk_i);
      
      cyc       <= 1'b1;
      i          =0;

      ack_count  = n_xfers;
      
      while(i<n_xfers)
	begin 
           count_ack(ack_count);
           handle_readback(xfer, !write, cur_rdbk);
           
          
	   if(err) begin
	      result   = R_ERROR;
	      failure  = 1;
	      break;
	   end
	
	   if(rty) begin
	      result   = R_RETRY;
	      failure  = 1;
	      break;
	      end

          
           if (!stall && settings.gen_random_throttling && probability_hit(settings.throttle_prob)) begin
              stb   <= 1'b0;
              we    <= 1'b0;
              @(posedge clk_i);
              
             
	   end else begin
	      adr   <= gen_addr(xfer[i].a, xfer[i].size);
	      stb   <= 1'b1;
              if(write)
                begin
	           we    <= 1'b1;
	           sel   <= gen_sel(xfer[i].a, xfer[i].size, settings.little_endian);
	           dat_o <= gen_data(xfer[i].a, xfer[i].d, xfer[i].size, settings.little_endian);
                end else begin
                   we<=1'b0;
                   sel <= 'hffffffff;
                end
              
	      @(posedge clk_i);
              stb      <= 1'b0;
              we       <= 1'b0;
              if(stall)
                begin
                   stb <= 1'b1;
                   
                   if(write)
                     we  <= 1'b1;
                   
                   while(stall)
                     begin
                        count_ack(ack_count);
                        @(posedge clk_i);
                   

                     end
                   stb      <= 1'b0;
                   we       <= 1'b0;
                end
              i++;
	   end

	end // for (i   =0;i<n_xfers;i++)

      
      while((ack_count > 0) && !failure)
	begin
      //     $display("AckCount %d", ack_count);

	   if(err) begin
	      result   = R_ERROR;
	      failure  = 1;
	      break;
	   end
	   
	   if(rty) begin
	      result   = R_RETRY;
	      failure  = 1;
	      break;
	   end


           count_ack(ack_count);
           handle_readback(xfer, !write, cur_rdbk);

           if(stb && !ack) 
	     ack_count++;
	   else if(!stb && ack) 
	     ack_count--;
	   @(posedge clk_i);
	end

      
      
      cyc <= 1'b0;
      @(posedge clk_i);
      if(!failure)
        result 	     = R_OK;
      xf_idle 	     = 1;
      last_access_t  = $time;
   endtask // automatic

	
   wb_cycle_t request_queue[$];
   wb_cycle_t result_queue[$];

class CIWBMasterAccessor extends CWishboneAccessor;

   function automatic int poll();
      return 0;
   endfunction
   
   task get(ref wb_cycle_t xfer);
      while(!result_queue.size())
	@(posedge clk_i);
      xfer  = result_queue.pop_front();
   endtask
   
   task clear();
   endtask // clear

   task put(ref wb_cycle_t xfer);
      //       $display("WBMaster[%d]: PutCycle",g_data_width);
      request_queue.push_back(xfer);
   endtask // put

   function int idle();
      return (request_queue.size() == 0) && xf_idle;
   endfunction // idle
endclass // CIWBMasterAccessor


   function CIWBMasterAccessor get_accessor();
      CIWBMasterAccessor tmp;
      tmp  = new;
      return tmp;
      endfunction // get_accessoror

   always@(posedge clk_i)
     if(!rst_n_i)
       begin
	  request_queue 	      = {};
	  result_queue 		      = {};
	  xf_idle 		      = 1;
	  cyc 			     <= 0;
	  dat_o 		     <= 0;
	  stb 			     <= 0;
	  sel 			     <= 0;
	  adr 			     <= 0;
	  we 			     <= 0;
       end

   initial begin
      settings.gen_random_throttling  = 0;
      settings.throttle_prob 	      = 0.1;
      settings.cyc_on_stall = 0;
      settings.addr_gran = WORD;
   end

   
   initial forever
     begin
	@(posedge clk_i);


	if(request_queue.size() > 0)
	  begin

             
	     wb_cycle_t c;
	     wb_cycle_result_t res;

	     c 	= request_queue.pop_front();

             case(c.ctype)
               PIPELINED:
                 begin
		    pipelined_cycle(c.data, c.rw, c.data.size(), res);
	            c.result  =res;
                 end
               CLASSIC:
                 begin
	         //   $display("WBMaster: got classic cycle [%d, rw %d]", c.data.size(), c.rw);
                    classic_cycle(c.data, c.rw, c.data.size, res);
                    
	            c.result  =res;

                    
                 end
             endcase // case (c.ctype)
             
	     result_queue.push_back(c);
	  end
     end
   
   
endinterface // IWishbone
