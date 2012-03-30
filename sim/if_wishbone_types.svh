//
// Title          : Pipelined Wishbone BFM - type definitions
//
// File           : if_wishbone_types.sv
// Author         : Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
// Created        : Tue Mar 23 12:19:36 2010
// Standard       : Verilog 2001
//

`ifndef __IF_WB_TYPES_SVH
`define __IF_WB_TYPES_SVH

`include "simdrv_defs.svh"

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

typedef enum {
  WORD = 0,
  BYTE = 1
} wb_address_granularity_t;

typedef struct {
   uint64_t a;
   uint64_t d;
   int size;
   bit [7:0] sel;
} wb_xfer_t;

typedef struct  {
   int rw;
   wb_cycle_type_t ctype;
   wb_xfer_t data[$];
   wb_cycle_result_t result;
} wb_cycle_t;

typedef enum  
 {
  RETRY = 0,
  STALL,
  ERROR
} wba_sim_event_t;

typedef enum
{
  RANDOM = (1<<0),
  DELAYED = (1<<1)
 } wba_sim_behavior_t;

`endif //  `ifndef __IF_WB_TYPES_SVH

