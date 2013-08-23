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

`include "spi_bidir_defines.v"
`include "timescale.v"

module spi_bidir_shift (clk, rst, latch, byte_sel, len, lsb, go,
                  pos_edge, neg_edge, rx_negedge, tx_negedge,
                  tip, last,
                  p_in, p_out, p_out_miso, s_clk, s_in_miso, s_in_mosi, s_out,
                  bidir, mosi_out_en, bidir_send_bit_num);

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
  input                   [31:0] p_in;         // parallel in
  output     [`SPI_MAX_CHAR-1:0] p_out;        // parallel out
  output     [`SPI_MAX_CHAR-1:0] p_out_miso;   // parallel out (dane z linii MISO)
  input                          s_clk;        // serial clock
  input                          s_in_miso;    // serial in miso
  input                          s_in_mosi;    // serial in mosi
  output                         s_out;        // serial out
  input                 bidir;
  output                  mosi_out_en;
  input               [6:0] bidir_send_bit_num;

  reg                            s_out;
  reg                            tip;

  reg     [`SPI_CHAR_LEN_BITS:0] cnt;          // data bit count
  reg        [`SPI_MAX_CHAR-1:0] data;         // shift register
  reg        [`SPI_MAX_CHAR-1:0] data_mosi;    // shift register (dane z linii dwukierunkowej)
  reg        [`SPI_MAX_CHAR-1:0] data_miso;    // shift register
  wire    [`SPI_CHAR_LEN_BITS:0] tx_bit_pos;   // next bit position
  wire    [`SPI_CHAR_LEN_BITS:0] rx_bit_pos;   // next bit position
  wire                           rx_clk;       // rx clock enable
  wire                           tx_clk;       // tx clock enable

  assign p_out = data_mosi;
  assign p_out_miso = data_miso;

  assign tx_bit_pos = lsb ? {!(|len), len} - cnt : cnt - {{`SPI_CHAR_LEN_BITS{1'b0}},1'b1};
  assign rx_bit_pos = lsb ? {!(|len), len} - (rx_negedge ? cnt + {{`SPI_CHAR_LEN_BITS{1'b0}},1'b1} : cnt) :
                            (rx_negedge ? cnt : cnt - {{`SPI_CHAR_LEN_BITS{1'b0}},1'b1});

  assign last = !(|cnt);

  assign rx_clk = (rx_negedge ? neg_edge : pos_edge) && (!last || s_clk);
  assign tx_clk = (tx_negedge ? neg_edge : pos_edge) && !last;

  reg [11:0] send_bit_cnt = 12'h000;

  // Character bit counter
  // dodatkowo liczenie bitow wyslanych
  always @(posedge clk or posedge rst)
  begin
    if(rst)
   begin
      cnt <= #Tp {`SPI_CHAR_LEN_BITS+1{1'b0}};
    send_bit_cnt <= #Tp {12{1'b0}};
   end
    else
      begin
        if(tip)
      begin
          cnt <= #Tp pos_edge ? (cnt - {{`SPI_CHAR_LEN_BITS{1'b0}}, 1'b1}) : cnt;
       send_bit_cnt <= #Tp pos_edge ? (send_bit_cnt + 1'b1) : send_bit_cnt;
      end
        else
      begin
          cnt <= #Tp !(|len) ? {1'b1, {`SPI_CHAR_LEN_BITS{1'b0}}} : {1'b0, len};
       send_bit_cnt <= #Tp {12{1'b0}};
      end
      end
  end

  // bidir transfer control
  // depending on tx mode (negedge posedge)
  // warning! tx on negedge stable, rx on posegde stable, one bit in reading missing!
  reg mosi_out_en = 1'b0;

  always @(posedge clk or posedge rst)
  begin
    if(rst || !bidir)
      mosi_out_en <= #Tp 1'b0;
    else
        if(tip)
        if ( (send_bit_cnt >= {5'b0, bidir_send_bit_num[6:0]}) && tx_negedge)
          mosi_out_en <= #Tp 1'b1;
        else if ( (send_bit_cnt > {5'b0, bidir_send_bit_num[6:0]}) && !tx_negedge)
          mosi_out_en <= #Tp 1'b1;
        else
          mosi_out_en <= #Tp 1'b0;
        else
        mosi_out_en <= #Tp 1'b0;
  end

  // Transfer in progress
  always @(posedge clk or posedge rst)
  begin
    if(rst)
      tip <= #Tp 1'b0;
  else if(go && ~tip)
    tip <= #Tp 1'b1;
  else if(tip && last && pos_edge)
    tip <= #Tp 1'b0;
  end

  // Sending bits to the line
  always @(posedge clk or posedge rst)
  begin
    if (rst)
      s_out   <= #Tp 1'b0;
    else
      s_out <= #Tp (tx_clk || !tip) ? data[tx_bit_pos[`SPI_CHAR_LEN_BITS-1:0]] : s_out;
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

  end

  always @(posedge clk)
  begin
     if (rst)
    begin
      data_miso   <= #Tp {`SPI_MAX_CHAR{1'b0}};
      data_mosi   <= #Tp {`SPI_MAX_CHAR{1'b0}};
    end
    else
    begin
      if (rx_clk && bidir)
        data_mosi[rx_bit_pos[`SPI_CHAR_LEN_BITS-1:0]] <= #Tp s_in_mosi;
      else if (rx_clk)
        data_miso[rx_bit_pos[`SPI_CHAR_LEN_BITS-1:0]] <= #Tp s_in_miso;
      else
      begin
        data_miso[rx_bit_pos[`SPI_CHAR_LEN_BITS-1:0]] <= #Tp data_miso[rx_bit_pos[`SPI_CHAR_LEN_BITS-1:0]];
        data_mosi[rx_bit_pos[`SPI_CHAR_LEN_BITS-1:0]] <= #Tp data_mosi[rx_bit_pos[`SPI_CHAR_LEN_BITS-1:0]];
      end
    end
  end

endmodule
