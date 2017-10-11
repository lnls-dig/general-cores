`timescale 1ns/1ps

`include "simdrv_defs.svh"
`include "if_wb_master.svh"

//`include "regs/spwm_regs.vh"

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


   wb_gpio_port

     #(.g_num_pins(24), .g_with_builtin_tristates(0))
   DUT
     (
      .clk_sys_i (clk_sys),
      .rst_n_i   (rst_n),

      .wb_adr_i  (U_WB.master.adr[7:0]),
      .wb_dat_i  (U_WB.master.dat_o),
      .wb_dat_o  (U_WB.master.dat_i),
      .wb_cyc_i  (U_WB.master.cyc),
      .wb_stb_i  (U_WB.master.stb),
      .wb_we_i   (U_WB.master.we),
      .wb_ack_o  (U_WB.master.ack),
      .wb_sel_i  (U_WB.master.sel),
      .wb_stall_o(U_WB.master.stall),

      .gpio_b    (),
      .gpio_in_i (24'h 234567),
      .gpio_out_o(),
      .gpio_oen_o()
      );

   initial begin
      CWishboneAccessor acc;
      int i;

      #1000ns;
      acc = U_WB.get_accessor();
      acc.set_mode(CLASSIC);
      U_WB.settings.addr_gran = WORD;


      acc.write(8, 24'h aaaaaa);
      acc.write(4, 24'h 553311);
      acc.write(0, 24'h 001010);

      $stop;

   end // initial begin

endmodule // main
