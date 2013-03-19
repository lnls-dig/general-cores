//////////////////////////////////////////////////////////////////////
////                                                              ////
////  spi_shift.v                                                 ////
////                                                              ////
////  This file is part of the SPI IP core project                ////
////  http://www.opencores.org/projects/spi/                      ////
////                                                              ////
////  Author(s):                                                  ////
////      - Simon Srot (simons@opencores.org)                     ////
////                                                              ////
////  All additional information is avaliable in the Readme.txt   ////
////  file.                                                       ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2002 Authors                                   ////
////                                                              ////
//// This source file may be used and distributed without         ////
//// restriction provided that this copyright statement is not    ////
//// removed from the file and that any derivative work contains  ////
//// the original copyright notice and the associated disclaimer. ////
////                                                              ////
//// This source file is free software; you can redistribute it   ////
//// and/or modify it under the terms of the GNU Lesser General   ////
//// Public License as published by the Free Software Foundation; ////
//// either version 2.1 of the License, or (at your option) any   ////
//// later version.                                               ////
////                                                              ////
//// This source is distributed in the hope that it will be       ////
//// useful, but WITHOUT ANY WARRANTY; without even the implied   ////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ////
//// PURPOSE.  See the GNU Lesser General Public License for more ////
//// details.                                                     ////
////                                                              ////
//// You should have received a copy of the GNU Lesser General    ////
//// Public License along with this source; if not, download it   ////
//// from http://www.opencores.org/lgpl.shtml                     ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
//
// Modified by Lucas Russo <lucas.russo@lnls.br> in order to support
// SPI 3-wire mode (bidirectional data pin)

`include "spi_defines.v"
`include "timescale.v"

module spi_shift (clk, rst, latch, byte_sel, len, lsb, go,
                  pos_edge, neg_edge, rx_negedge, tx_negedge,
                  tip, last, dir,
                  p_in, p_out, s_clk, s_in, s_out, s_oe_n);

  // Set to 1 to generate the SPI core in 3-wire mode
  // Set to 0 to generate the SPI core in 4-wire mode
  parameter g_three_wire_mode = 0;
  parameter Tp = 1;

  input                          clk;          // system clock
  input                          rst;          // reset
  input                    [3:0] latch;        // latch signal for storing the data in shift register
  input                    [3:0] byte_sel;     // byte select signals for storing the data in shift register
  input [`SPI_CHAR_LEN_BITS-1:0] len;          // data len in bits (minus one)
  input                          lsb;          // lbs first on the line
  input                          go;           // start stansfer
  input                          pos_edge;     // recognize posedge of sclk
  input                          neg_edge;     // recognize negedge of sclk
  input                          rx_negedge;   // s_in is sampled on negative edge
  input                          tx_negedge;   // s_out is driven on negative edge
  output                         tip;          // transfer in progress
  output                         last;         // last bit
  input                          dir;          // direction bit (onyl for three-wire mode)
  input                   [31:0] p_in;         // parallel in
  output     [`SPI_MAX_CHAR-1:0] p_out;        // parallel out
  input                          s_clk;        // serial clock
  input                          s_in;         // serial in
  output                         s_out;        // serial out
  output                         s_oe_n;

  // for tristate logic
  wire                           s_oe_n;
  //reg                            s_data_oe_n_int;
  wire                           s_din;
  reg                            s_dout;

  wire                           s_out;
  reg                            tip;

  reg     [`SPI_CHAR_LEN_BITS:0] cnt;          // data bit count
  reg        [`SPI_MAX_CHAR-1:0] data;         // shift register
  wire    [`SPI_CHAR_LEN_BITS:0] tx_bit_pos;   // next bit position
  wire    [`SPI_CHAR_LEN_BITS:0] rx_bit_pos;   // next bit position
  wire                           rx_clk;       // rx clock enable
  wire                           tx_clk;       // tx clock enable

  wire                           start_t;    // start transfer will start next clock cycle

  assign p_out = data;

  assign tx_bit_pos = lsb ? {!(|len), len} - cnt : cnt - {{`SPI_CHAR_LEN_BITS{1'b0}},1'b1};
  assign rx_bit_pos = lsb ? {!(|len), len} - (rx_negedge ? cnt + {{`SPI_CHAR_LEN_BITS{1'b0}},1'b1} : cnt) :
                            (rx_negedge ? cnt : cnt - {{`SPI_CHAR_LEN_BITS{1'b0}},1'b1});

  assign last = !(|cnt);

  assign rx_clk = (rx_negedge ? neg_edge : pos_edge) && (!last || s_clk);
  assign tx_clk = (tx_negedge ? neg_edge : pos_edge) && !last;

  // Character bit counter
  always @(posedge clk or posedge rst)
  begin
    if(rst)
      cnt <= #Tp {`SPI_CHAR_LEN_BITS+1{1'b0}};
    else
      begin
        if(tip)
          cnt <= #Tp pos_edge ? (cnt - {{`SPI_CHAR_LEN_BITS{1'b0}}, 1'b1}) : cnt;
        else
          cnt <= #Tp !(|len) ? {1'b1, {`SPI_CHAR_LEN_BITS{1'b0}}} : {1'b0, len};
      end
  end

  assign start_t = go && ~tip;

  // Transfer in progress
  always @(posedge clk or posedge rst)
  begin
    if(rst)
      tip <= #Tp 1'b0;
    else if(start_t)
      tip <= #Tp 1'b1;
    else if(tip && last && pos_edge)
      tip <= #Tp 1'b0;
  end

  // Sending bits to the line
  //always @(posedge clk or posedge rst)
  //begin
  //  if (rst)
  //    s_out <= #Tp 1'b0;
  //  else
  //    s_out <= #Tp (tx_clk || !tip) ? data[tx_bit_pos[`SPI_CHAR_LEN_BITS-1:0]] : s_out;
  //end
  always @(posedge clk or posedge rst)
  begin
    if (rst)
      s_dout <= #Tp 1'b0;
    else
      s_dout <= #Tp (tx_clk || !tip) ? data[tx_bit_pos[`SPI_CHAR_LEN_BITS-1:0]] : s_dout;
  end

  // Receiving bits from the line
  always @(posedge clk or posedge rst)
  begin
    if (rst)
      data   <= #Tp {`SPI_MAX_CHAR{1'b0}};
`ifdef SPI_MAX_CHAR_128
    else if (latch[0] && !tip)
      begin
        if (byte_sel[3])
          data[31:24] <= #Tp p_in[31:24];
        if (byte_sel[2])
          data[23:16] <= #Tp p_in[23:16];
        if (byte_sel[1])
          data[15:8] <= #Tp p_in[15:8];
        if (byte_sel[0])
          data[7:0] <= #Tp p_in[7:0];
      end
    else if (latch[1] && !tip)
      begin
        if (byte_sel[3])
          data[63:56] <= #Tp p_in[31:24];
        if (byte_sel[2])
          data[55:48] <= #Tp p_in[23:16];
        if (byte_sel[1])
          data[47:40] <= #Tp p_in[15:8];
        if (byte_sel[0])
          data[39:32] <= #Tp p_in[7:0];
      end
    else if (latch[2] && !tip)
      begin
        if (byte_sel[3])
          data[95:88] <= #Tp p_in[31:24];
        if (byte_sel[2])
          data[87:80] <= #Tp p_in[23:16];
        if (byte_sel[1])
          data[79:72] <= #Tp p_in[15:8];
        if (byte_sel[0])
          data[71:64] <= #Tp p_in[7:0];
      end
    else if (latch[3] && !tip)
      begin
        if (byte_sel[3])
          data[127:120] <= #Tp p_in[31:24];
        if (byte_sel[2])
          data[119:112] <= #Tp p_in[23:16];
        if (byte_sel[1])
          data[111:104] <= #Tp p_in[15:8];
        if (byte_sel[0])
          data[103:96] <= #Tp p_in[7:0];
      end
`else
`ifdef SPI_MAX_CHAR_64
    else if (latch[0] && !tip)
      begin
        if (byte_sel[3])
          data[31:24] <= #Tp p_in[31:24];
        if (byte_sel[2])
          data[23:16] <= #Tp p_in[23:16];
        if (byte_sel[1])
          data[15:8] <= #Tp p_in[15:8];
        if (byte_sel[0])
          data[7:0] <= #Tp p_in[7:0];
      end
    else if (latch[1] && !tip)
      begin
        if (byte_sel[3])
          data[63:56] <= #Tp p_in[31:24];
        if (byte_sel[2])
          data[55:48] <= #Tp p_in[23:16];
        if (byte_sel[1])
          data[47:40] <= #Tp p_in[15:8];
        if (byte_sel[0])
          data[39:32] <= #Tp p_in[7:0];
      end
`else
    else if (latch[0] && !tip)
      begin
      `ifdef SPI_MAX_CHAR_8
        if (byte_sel[0])
          data[`SPI_MAX_CHAR-1:0] <= #Tp p_in[`SPI_MAX_CHAR-1:0];
      `endif
      `ifdef SPI_MAX_CHAR_16
        if (byte_sel[0])
          data[7:0] <= #Tp p_in[7:0];
        if (byte_sel[1])
          data[`SPI_MAX_CHAR-1:8] <= #Tp p_in[`SPI_MAX_CHAR-1:8];
      `endif
      `ifdef SPI_MAX_CHAR_24
        if (byte_sel[0])
          data[7:0] <= #Tp p_in[7:0];
        if (byte_sel[1])
          data[15:8] <= #Tp p_in[15:8];
        if (byte_sel[2])
          data[`SPI_MAX_CHAR-1:16] <= #Tp p_in[`SPI_MAX_CHAR-1:16];
      `endif
      `ifdef SPI_MAX_CHAR_32
        if (byte_sel[0])
          data[7:0] <= #Tp p_in[7:0];
        if (byte_sel[1])
          data[15:8] <= #Tp p_in[15:8];
        if (byte_sel[2])
          data[23:16] <= #Tp p_in[23:16];
        if (byte_sel[3])
          data[`SPI_MAX_CHAR-1:24] <= #Tp p_in[`SPI_MAX_CHAR-1:24];
      `endif
      end
`endif
`endif
    else
      //data[rx_bit_pos[`SPI_CHAR_LEN_BITS-1:0]] <= #Tp rx_clk ? s_in : data[rx_bit_pos[`SPI_CHAR_LEN_BITS-1:0]];
      data[rx_bit_pos[`SPI_CHAR_LEN_BITS-1:0]] <= #Tp rx_clk ? s_din : data[rx_bit_pos[`SPI_CHAR_LEN_BITS-1:0]];
  end

  // Generate output enable logic for tristate buffers
  // dir = 0 -> input data (read from external logic)
  // dir = 1 -> output data (write to external logic)
  //generate
  //  if (g_three_wire_mode == 1) begin
  //    always @(posedge clk or posedge rst) begin
  //      if (rst)
  //        s_data_oe_n_int <= #Tp 1'b0;
  //      else if (start_t) // transaction will start next cycle
  //        //s_data_oe_n_int <= #Tp tx_clk ? ~dir : s_data_oe_n_int;
  //        s_data_oe_n_int <= #Tp ~dir;
  //      else if (!go)     // end of transaction
  //        //s_data_oe_n_int <= #Tp tx_clk ? 1'b1 : s_data_oe_n_int;
  //        s_data_oe_n_int <= #Tp 1'b0;
  //    end
  //  end
  //
  //  //assign s_data_oe_n = s_data_oe_n_int;
  //endgenerate

  // Generate tristate logic
  generate
    if (g_three_wire_mode == 1) begin
      assign s_din = s_in;
      assign s_out = s_dout;
      assign s_oe_n = ~dir;
    end
    else begin  // no out enable
      assign s_din = s_in;
      assign s_out = s_dout;
    end
  endgenerate

endmodule

