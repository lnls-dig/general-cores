//
// Title          : Software Wishbone master unit for testbenches
//
// File           : wishbone_master_tb.v
// Author         : Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
// Created        : Tue Mar 23 12:19:36 2010
// Standard       : Verilog 2001
//

`ifndef __IF_WB_DEFS_SV
`define __IF_WB_DEFS_SV

`include "simdrv_defs.sv"

typedef enum 
{
  R_OK = 0,
  R_ERROR,
  R_RETRY
} wb_cycle_result_t;

typedef enum
{
  CLASSIC = 0,
  PIPELINED = 1
} wb_cycle_type_t;

typedef struct {
   uint64_t a;
   uint64_t d;
   bit[7:0] sel;
   int size;
} wb_xfer_t;

typedef struct {
   int rw;
   wb_cycle_type_t ctype;
   wb_xfer_t data[$];
   wb_cycle_result_t result;
} wb_cycle_t;


virtual class CWishboneAccessor;

   virtual function automatic int poll();
      return 0;
   endfunction // poll
      
   virtual task get(output wb_cycle_t xfer);
   endtask // get
   
   virtual task put(input wb_cycle_t xfer);
   endtask // put
   
   virtual function int idle();
      return 0;
   endfunction // idle
   
   virtual task clear(); endtask

endclass // CWishboneAccessor

int seed  = 0;

   function automatic int probability_hit(real prob);
     real rand_val;
      rand_val 	= real'($dist_uniform(seed, 0, 1000)) / 1000.0;
      
      if(rand_val < prob)
	return 1;
      else
	return 0;
    
   endfunction // probability_hit


`endif //  `ifndef __IF_WB_DEFS_SV
