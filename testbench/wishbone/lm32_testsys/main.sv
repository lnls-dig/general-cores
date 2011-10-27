`timescale 1ns/1ps

module main;

   reg clk_sys  =0;
   reg rst_n    = 0;

   always #5 clk_sys <= ~clk_sys;
   
   initial begin
      repeat(3) @(posedge clk_sys);
      rst_n  = 1;
   end

   
   lm32_test_system
     DUT (
          .clk_sys_i (clk_sys),
          .rst_n_i   (rst_n),
          .gpio_b ()
          );
   
                            

endmodule // main


