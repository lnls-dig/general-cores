//////////////////////////////////////////////////////////////////////
////                                                              ////
////  spi_top.v                                                   ////
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

// Modifications: Andrzej Wojenski

`include "spi_bidir_defines.v"
`include "timescale.v"

module spi_bidir_top
(
  // Wishbone signals
  wb_clk_i, wb_rst_i, wb_adr_i, wb_dat_i, wb_dat_o, wb_sel_i,
  wb_we_i, wb_stb_i, wb_cyc_i, wb_ack_o, wb_err_o, int_o,

  // SPI signals
  ss_pad_o, sclk_pad_o, mosi_pad_o, miso_pad_i, mosi_pad_i,
  mosi_out_en_o
);

  parameter Tp = 1;

  // Wishbone signals
  input                            wb_clk_i;         // master clock input
  input                            wb_rst_i;         // synchronous active high reset
  input                      [5:0] wb_adr_i;         // lower address bits
  input                   [32-1:0] wb_dat_i;         // databus input
  output                  [32-1:0] wb_dat_o;         // databus output
  input                      [3:0] wb_sel_i;         // byte select inputs
  input                            wb_we_i;          // write enable input
  input                            wb_stb_i;         // stobe/core select signal
  input                            wb_cyc_i;         // valid bus cycle input
  output                           wb_ack_o;         // bus cycle acknowledge output
  output                           wb_err_o;         // termination w/ error
  output                           int_o;            // interrupt request signal output

  // SPI signals
  output          [`SPI_SS_NB-1:0] ss_pad_o;         // slave select
  output                           sclk_pad_o;       // serial clock
  output                           mosi_pad_o;       // master out slave in
  input                            miso_pad_i;       // master in slave out
  input                   mosi_pad_i;       // wejscie linii dwukierunkowej MOSI

  output mosi_out_en_o;
  wire mosi_out_en_o;

  reg                     [32-1:0] wb_dat_o;
  reg                              wb_ack_o;
  reg                              int_o;

  // Internal signals
  reg       [`SPI_DIVIDER_LEN-1:0] divider;          // Divider register
  reg       [`SPI_CTRL_BIT_NB-1:0] ctrl;             // Control and status register
  reg             [`SPI_SS_NB-1:0] ss;               // Slave select register
  reg                     [32-1:0] wb_dat;           // wb data out
  wire         [`SPI_MAX_CHAR-1:0] rx;               // Rx register (MOSI)
  wire         [`SPI_MAX_CHAR-1:0] rx_miso;          // Rx register (MISO)
  wire                             rx_negedge;       // miso is sampled on negative edge
  wire                             tx_negedge;       // mosi is driven on negative edge
  wire    [`SPI_CHAR_LEN_BITS-1:0] char_len;         // char len
  wire                             go;               // go
  wire                             lsb;              // lsb first on line
  wire                             ie;               // interrupt enable
  wire                             ass;              // automatic slave select
  wire                             spi_divider_sel;  // divider register select
  wire                             spi_ctrl_sel;     // ctrl register select
  wire                       [3:0] spi_tx_sel;       // tx_l register select
  wire                             spi_ss_sel;       // ss register select
  wire                             tip;              // transfer in progress
  wire                             pos_edge;         // recognize posedge of sclk
  wire                             neg_edge;         // recognize negedge of sclk
  wire                             last_bit;         // marks last character bit

  reg                   [7:0] bidir_config;     // ustawienia magistrali dwukierunkowej (najpierw wysylanie, potem odczyt)
  wire                             spi_bidir_sel;    // select rejestru bidir_config

  // Address decoder
  assign spi_divider_sel = wb_cyc_i & wb_stb_i & (wb_adr_i[`SPI_OFS_BITS] == `SPI_DEVIDE);
  assign spi_ctrl_sel    = wb_cyc_i & wb_stb_i & (wb_adr_i[`SPI_OFS_BITS] == `SPI_CTRL);
  assign spi_tx_sel[0]   = wb_cyc_i & wb_stb_i & (wb_adr_i[`SPI_OFS_BITS] == `SPI_TX_0);
  assign spi_tx_sel[1]   = wb_cyc_i & wb_stb_i & (wb_adr_i[`SPI_OFS_BITS] == `SPI_TX_1);
  assign spi_tx_sel[2]   = wb_cyc_i & wb_stb_i & (wb_adr_i[`SPI_OFS_BITS] == `SPI_TX_2);
  assign spi_tx_sel[3]   = wb_cyc_i & wb_stb_i & (wb_adr_i[`SPI_OFS_BITS] == `SPI_TX_3);
  assign spi_ss_sel      = wb_cyc_i & wb_stb_i & (wb_adr_i[`SPI_OFS_BITS] == `SPI_SS);
  assign spi_bidir_sel   = wb_cyc_i & wb_stb_i & (wb_adr_i[`SPI_OFS_BITS] == `SPI_BIDIR);

  // Read from registers
  always @(wb_adr_i or rx or rx_miso or ctrl or divider or ss or bidir_config)
  begin
    case (wb_adr_i[`SPI_OFS_BITS])
`ifdef SPI_MAX_CHAR_128
      `SPI_RX_0:    wb_dat = rx[31:0];
      `SPI_RX_1:    wb_dat = rx[63:32];
      `SPI_RX_2:    wb_dat = rx[95:64];
      `SPI_RX_3:    wb_dat = {{128-`SPI_MAX_CHAR{1'b0}}, rx[`SPI_MAX_CHAR-1:96]};

    `SPI_RX_MISO_0:    wb_dat = rx_miso[31:0];
      `SPI_RX_MISO_1:    wb_dat = rx_miso[63:32];
      `SPI_RX_MISO_2:    wb_dat = rx_miso[95:64];
      `SPI_RX_MISO_3:    wb_dat = {{128-`SPI_MAX_CHAR{1'b0}}, rx_miso[`SPI_MAX_CHAR-1:96]};
`else
`ifdef SPI_MAX_CHAR_64
      `SPI_RX_0:    wb_dat = rx[31:0];
      `SPI_RX_1:    wb_dat = {{64-`SPI_MAX_CHAR{1'b0}}, rx[`SPI_MAX_CHAR-1:32]};
      `SPI_RX_2:    wb_dat = 32'b0;
      `SPI_RX_3:    wb_dat = 32'b0;

      `SPI_RX_MISO_0:    wb_dat = rx_miso[31:0];
      `SPI_RX_MISO_1:    wb_dat = {{64-`SPI_MAX_CHAR{1'b0}}, rx_miso[`SPI_MAX_CHAR-1:32]};
      `SPI_RX_MISO_2:    wb_dat = 32'b0;
      `SPI_RX_MISO_3:    wb_dat = 32'b0;
`else
      `SPI_RX_0:    wb_dat = {{32-`SPI_MAX_CHAR{1'b0}}, rx[`SPI_MAX_CHAR-1:0]};
      `SPI_RX_1:    wb_dat = 32'b0;
      `SPI_RX_2:    wb_dat = 32'b0;
      `SPI_RX_3:    wb_dat = 32'b0;

      `SPI_RX_MISO_0:    wb_dat = {{32-`SPI_MAX_CHAR{1'b0}}, rx_miso[`SPI_MAX_CHAR-1:0]};
      `SPI_RX_MISO_1:    wb_dat = 32'b0;
      `SPI_RX_MISO_2:    wb_dat = 32'b0;
      `SPI_RX_MISO_3:    wb_dat = 32'b0;
`endif
`endif
      `SPI_CTRL:    wb_dat = {{32-`SPI_CTRL_BIT_NB{1'b0}}, ctrl};
      `SPI_DEVIDE:  wb_dat = {{32-`SPI_DIVIDER_LEN{1'b0}}, divider};
      `SPI_SS:      wb_dat = {{32-`SPI_SS_NB{1'b0}}, ss};
    `SPI_BIDIR:   wb_dat = {{32-`SPI_BIDIR_NB{1'b0}}, bidir_config};
      default:      wb_dat = 32'bx;
    endcase
  end

  // Wb data out
  always @(posedge wb_clk_i or posedge wb_rst_i)
  begin
    if (wb_rst_i)
      wb_dat_o <= #Tp 32'b0;
    else
      wb_dat_o <= #Tp wb_dat;
  end

  // Wb acknowledge
  always @(posedge wb_clk_i or posedge wb_rst_i)
  begin
    if (wb_rst_i)
      wb_ack_o <= #Tp 1'b0;
    else
      wb_ack_o <= #Tp wb_cyc_i & wb_stb_i & ~wb_ack_o;
  end

  // Wb error
  assign wb_err_o = 1'b0;

  // Interrupt
  always @(posedge wb_clk_i or posedge wb_rst_i)
  begin
    if (wb_rst_i)
      int_o <= #Tp 1'b0;
    else if (ie && tip && last_bit && pos_edge)
      int_o <= #Tp 1'b1;
    else if (wb_ack_o)
      int_o <= #Tp 1'b0;
  end

  // Divider register
  always @(posedge wb_clk_i or posedge wb_rst_i)
  begin
    if (wb_rst_i)
        divider <= #Tp {`SPI_DIVIDER_LEN{1'b0}};
    else if (spi_divider_sel && wb_we_i && !tip)
      begin
      `ifdef SPI_DIVIDER_LEN_8
        if (wb_sel_i[0])
          divider <= #Tp wb_dat_i[`SPI_DIVIDER_LEN-1:0];
      `endif
      `ifdef SPI_DIVIDER_LEN_16
        if (wb_sel_i[0])
          divider[7:0] <= #Tp wb_dat_i[7:0];
        if (wb_sel_i[1])
          divider[`SPI_DIVIDER_LEN-1:8] <= #Tp wb_dat_i[`SPI_DIVIDER_LEN-1:8];
      `endif
      `ifdef SPI_DIVIDER_LEN_24
        if (wb_sel_i[0])
          divider[7:0] <= #Tp wb_dat_i[7:0];
        if (wb_sel_i[1])
          divider[15:8] <= #Tp wb_dat_i[15:8];
        if (wb_sel_i[2])
          divider[`SPI_DIVIDER_LEN-1:16] <= #Tp wb_dat_i[`SPI_DIVIDER_LEN-1:16];
      `endif
      `ifdef SPI_DIVIDER_LEN_32
        if (wb_sel_i[0])
          divider[7:0] <= #Tp wb_dat_i[7:0];
        if (wb_sel_i[1])
          divider[15:8] <= #Tp wb_dat_i[15:8];
        if (wb_sel_i[2])
          divider[23:16] <= #Tp wb_dat_i[23:16];
        if (wb_sel_i[3])
          divider[`SPI_DIVIDER_LEN-1:24] <= #Tp wb_dat_i[`SPI_DIVIDER_LEN-1:24];
      `endif
      end
  end

  // Bidir control register
  // [6:0] - ilosc bitow do wyslania
  // bity do odczytu to roznica miedzy CHAR_LEN - [6:0]
  // [7] - wlaczenie transmisji dwukierunkowej na linii MOSI
  // najpierw wysylanie danych, potem odczyt
  // odczyt danych z linii MISO - rejestry 0x20, 0x24, 0x28, 0x2c
  // odczyt danych z linii MOSI - rejestry 0x00, 0x04, 0x08, 0x0c
  always @(posedge wb_clk_i or posedge wb_rst_i)
  begin
    if (wb_rst_i)
        bidir_config <= #Tp {`SPI_BIDIR_NB{1'b0}};
    else if (spi_bidir_sel && wb_we_i && !tip)
      begin
        if (wb_sel_i[0])
      bidir_config <= #Tp wb_dat_i[`SPI_BIDIR_NB-1:0];
      end
  end

  // Ctrl register
  always @(posedge wb_clk_i or posedge wb_rst_i)
  begin
    if (wb_rst_i)
      ctrl <= #Tp {`SPI_CTRL_BIT_NB{1'b0}};
    else if(spi_ctrl_sel && wb_we_i && !tip)
      begin
        if (wb_sel_i[0])
          ctrl[7:0] <= #Tp wb_dat_i[7:0] | {7'b0, ctrl[0]};
        if (wb_sel_i[1])
          ctrl[`SPI_CTRL_BIT_NB-1:8] <= #Tp wb_dat_i[`SPI_CTRL_BIT_NB-1:8];
      end
    else if(tip && last_bit && pos_edge)
      ctrl[`SPI_CTRL_GO] <= #Tp 1'b0;
  end

  assign rx_negedge = ctrl[`SPI_CTRL_RX_NEGEDGE];
  assign tx_negedge = ctrl[`SPI_CTRL_TX_NEGEDGE];
  assign go         = ctrl[`SPI_CTRL_GO];
  assign char_len   = ctrl[`SPI_CTRL_CHAR_LEN];
  assign lsb        = ctrl[`SPI_CTRL_LSB];
  assign ie         = ctrl[`SPI_CTRL_IE];
  assign ass        = ctrl[`SPI_CTRL_ASS];

  // Slave select register
  always @(posedge wb_clk_i or posedge wb_rst_i)
  begin
    if (wb_rst_i)
      ss <= #Tp {`SPI_SS_NB{1'b0}};
    else if(spi_ss_sel && wb_we_i && !tip)
      begin
      `ifdef SPI_SS_NB_8
        if (wb_sel_i[0])
          ss <= #Tp wb_dat_i[`SPI_SS_NB-1:0];
      `endif
      `ifdef SPI_SS_NB_16
        if (wb_sel_i[0])
          ss[7:0] <= #Tp wb_dat_i[7:0];
        if (wb_sel_i[1])
          ss[`SPI_SS_NB-1:8] <= #Tp wb_dat_i[`SPI_SS_NB-1:8];
      `endif
      `ifdef SPI_SS_NB_24
        if (wb_sel_i[0])
          ss[7:0] <= #Tp wb_dat_i[7:0];
        if (wb_sel_i[1])
          ss[15:8] <= #Tp wb_dat_i[15:8];
        if (wb_sel_i[2])
          ss[`SPI_SS_NB-1:16] <= #Tp wb_dat_i[`SPI_SS_NB-1:16];
      `endif
      `ifdef SPI_SS_NB_32
        if (wb_sel_i[0])
          ss[7:0] <= #Tp wb_dat_i[7:0];
        if (wb_sel_i[1])
          ss[15:8] <= #Tp wb_dat_i[15:8];
        if (wb_sel_i[2])
          ss[23:16] <= #Tp wb_dat_i[23:16];
        if (wb_sel_i[3])
          ss[`SPI_SS_NB-1:24] <= #Tp wb_dat_i[`SPI_SS_NB-1:24];
      `endif
      end
  end


  /* Obsluga linii MOSI w trybie dwukierunkowym */
  // Jesli TX wlaczony tryb POSEDGE to liczenie POSEDGE + 1
  assign bidir_on = bidir_config[7];

  assign ss_pad_o = ~((ss & {`SPI_SS_NB{tip & ass}}) | (ss & {`SPI_SS_NB{!ass}}));

  spi_bidir_clgen clgen (.clk_in(wb_clk_i), .rst(wb_rst_i), .go(go), .enable(tip), .last_clk(last_bit),
                   .divider(divider), .clk_out(sclk_pad_o), .pos_edge(pos_edge),
                   .neg_edge(neg_edge));

  spi_bidir_shift shift (.clk(wb_clk_i), .rst(wb_rst_i), .len(char_len[`SPI_CHAR_LEN_BITS-1:0]),
                   .latch(spi_tx_sel[3:0] & {4{wb_we_i}}), .byte_sel(wb_sel_i), .lsb(lsb),
                   .go(go), .pos_edge(pos_edge), .neg_edge(neg_edge),
                   .rx_negedge(rx_negedge), .tx_negedge(tx_negedge),
                   .tip(tip), .last(last_bit),
                   .p_in(wb_dat_i), .p_out(rx), .p_out_miso(rx_miso),
                   .s_clk(sclk_pad_o), .s_in_miso(miso_pad_i), .s_in_mosi(mosi_pad_i), .s_out(mosi_pad_o),
             .bidir(bidir_on), .mosi_out_en(mosi_out_en_o), .bidir_send_bit_num(bidir_config[6:0]) );
endmodule
