
interface IWishboneLink;

   parameter g_data_width 	   = 32;
   parameter g_addr_width 	   = 32;
   

   wire [g_addr_width - 1 : 0] adr;
   wire [g_data_width - 1 : 0] dat_o;
   wire [g_data_width - 1 : 0] dat_i;
   wire [(g_data_width/8)-1 : 0] sel; 
   wire ack;
   wire stall;
   wire err;
   wire rty;
   wire	cyc;
   wire stb;
   wire we;
   
   modport slave
     (
      output adr,
      output dat_o,
      input dat_i,
      output sel,
      output cyc,
      output stb,
      output we,
      input ack,
      input stall,
      input err,
      input rty
      );

   modport master
     (
      input adr,
      input dat_o,
      output dat_i,
      input sel,
      input cyc,
      input stb,
      input we,
      output ack,
      output stall,
      output err,
      output rty
      );

endinterface // IWishboneLink
