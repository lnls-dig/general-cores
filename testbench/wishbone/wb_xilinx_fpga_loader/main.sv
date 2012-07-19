`timescale 1ns/1ps

`include "simdrv_defs.svh"
`include "if_wb_master.svh"

`include "regs/xloader_regs.vh"

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


   wire cclk, din, program_b, init_b, done, suspend;
   wire [1:0] m;
   
   wb_xilinx_fpga_loader DUT 
     (
      .clk_sys_i (clk_sys),
      .rst_n_i   (rst_n),

      .boot_en_i(1'b1),
      
      .wb_adr_i (U_WB.master.adr),
      .wb_dat_i (U_WB.master.dat_o),
      .wb_dat_o (U_WB.master.dat_i),
      .wb_cyc_i (U_WB.master.cyc),
      .wb_stb_i (U_WB.master.stb),
      .wb_we_i  (U_WB.master.we),
      .wb_ack_o (U_WB.master.ack),
      .wb_sel_i (U_WB.master.sel),

      .xlx_cclk_o      (cclk),
      .xlx_din_o       (din),
      .xlx_program_b_o (program_b),
      .xlx_init_b_i     (init_b),
      .xlx_done_i       (done),
      .xlx_suspend_o (suspend),
     
      .xlx_m_o (m)
      );
   
   
   SIM_CONFIG_S6_SERIAL2
  #(
    .DEVICE_ID(32'h34000093) // xc6slx150t
    ) U_serial_sim 
    (
     .DONE(done),
     .CCLK(cclk),
     .DIN(din),
     .INITB(init_b), 
     .M(m),
     .PROGB(program_b)
     );

   task load_bitstream(CBusAccessor acc, string filename);
      int f,i;
      uint64_t csr;
      
     
      acc.write( `ADDR_XLDR_CSR, `XLDR_CSR_SWRST );
      acc.write( `ADDR_XLDR_CSR, `XLDR_CSR_START | `XLDR_CSR_MSBF);
      f  = $fopen(filename, "r");
      
      while(!$feof(f))
        begin
           uint64_t rval;
           acc.read(`ADDR_XLDR_FIFO_CSR, rval);
           
           if(!(rval&`XLDR_FIFO_CSR_FULL)) begin
              int n;
              bit [31:0] word;
              
              n  = $fread(word, f);
              acc.write(`ADDR_XLDR_FIFO_R0, (n - 1) | ($feof(f) ? `XLDR_FIFO_R0_XLAST : 0));
              acc.write(`ADDR_XLDR_FIFO_R1, word);
              end
        end

      $fclose(f);

      while(1) begin
         acc.read( `ADDR_XLDR_CSR, csr);
         if(csr & `XLDR_CSR_DONE) begin
            $display("Bitstream loaded, status: %s", (csr & `XLDR_CSR_ERROR ? "ERROR" : "OK"));
            break;
         end
      end
   endtask
   
   
   initial begin
      CBusAccessor acc;
      int i;
      
      #1000ns;
      acc = U_WB.get_accessor();

      /* Load a sample spartan-6 bitstream */

      load_bitstream(acc, "sample_bitstream/crc_gen.bin");
      $stop;
     
   end // initial begin
   
endmodule // main

