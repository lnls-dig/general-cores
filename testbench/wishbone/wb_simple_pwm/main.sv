`timescale 1ns/1ps

`include "simdrv_defs.svh"
`include "if_wb_master.svh"

`include "regs/spwm_regs.vh"

module main;

   reg clk_sys=1, rst_n=0;

   always
     #5ns clk_sys <= ~clk_sys;

   initial begin 
      repeat(5) @(posedge clk_sys);
      rst_n <= 1;
   end
   

   IWishboneMaster #(32, 32) U_WB
     (
      .clk_i(clk_sys),
      .rst_n_i(rst_n)
      );

   
   wb_simple_pwm 

     #(.g_num_channels(8))
   DUT
     (
      .clk_sys_i (clk_sys),
      .rst_n_i   (rst_n),

      .wb_adr_i (U_WB.master.adr[5:0]),
      .wb_dat_i (U_WB.master.dat_o),
      .wb_dat_o (U_WB.master.dat_i),
      .wb_cyc_i (U_WB.master.cyc),
      .wb_stb_i (U_WB.master.stb),
      .wb_we_i  (U_WB.master.we),
      .wb_ack_o (U_WB.master.ack),
      .wb_sel_i (U_WB.master.sel),
      .wb_stall_o(U_WB.master.stall)

      );
   
   
   initial begin
      CWishboneAccessor acc;
      int i;
      
      #1000ns;
      acc = U_WB.get_accessor();
      acc.set_mode(PIPELINED);
      U_WB.settings.addr_gran = BYTE;

      
      acc.write(`ADDR_SPWM_CR, (2 << `SPWM_CR_PRESC_OFFSET) | (254 << `SPWM_CR_PERIOD_OFFSET));
      
      acc.write(`ADDR_SPWM_DR0, 0);
      acc.write(`ADDR_SPWM_DR1, 20);
      acc.write(`ADDR_SPWM_DR2, 40);
      acc.write(`ADDR_SPWM_DR3, 127);
      acc.write(`ADDR_SPWM_DR4, 240);
      acc.write(`ADDR_SPWM_DR5, 255);
      

      
      $stop;
     
   end // initial begin
   
endmodule // main

