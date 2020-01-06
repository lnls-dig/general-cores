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
//
// Modified by Lucas Russo <lucas.russo@lnls.br> in order to support
// SPI 3-wire mode (bidirectional data pin)
//////////////////////////////////////////////////////////////////////
//  Modifications:
//      2013: by G. Daniluk, CERN
//          * Modified to use parameters (generics) for configuration
//            rather than constants from spi_defines file.
//      2016-08-24: by Jan Pospisil (j.pospisil@cern.ch)
//          * added default values for determined start-up state
//////////////////////////////////////////////////////////////////////

`include "spi_defines.v"
`include "timescale.v"

module spi_top
(
  // Wishbone signals
  wb_clk_i, wb_rst_i, wb_adr_i, wb_dat_i, wb_dat_o, wb_sel_i,
  wb_we_i, wb_stb_i, wb_cyc_i, wb_ack_o, wb_err_o,

  // Interrupt output
  int_o,

  // SPI signals
  ss_pad_o, sclk_pad_o, mosi_pad_o, miso_pad_i, miosio_oen_o
);
  // Set to 1 to generate the SPI core in 3-wire mode
  // Set to 0 to generate the SPI core in 4-wire mode
  parameter g_three_wire_mode = 0;
  parameter Tp = 1;
  parameter SPI_DIVIDER_LEN = 16;
  parameter SPI_MAX_CHAR = 128;
  parameter SPI_CHAR_LEN_BITS = 7;
  parameter SPI_SS_NB = 8;

  // Wishbone signals
  input                            wb_clk_i;         // master clock input
  input                            wb_rst_i;         // synchronous active high reset
  input                      [4:0] wb_adr_i;         // lower address bits
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
  output           [SPI_SS_NB-1:0] ss_pad_o;         // slave select
  output                           sclk_pad_o;       // serial clock
  output                           mosi_pad_o;       // master out slave in
  input                            miso_pad_i;       // master in slave out
  output                           miosio_oen_o;     // master in slave out output enable

  reg                     [32-1:0] wb_dat_o = 32'b0;
  reg                              wb_ack_o = 1'b0;
  reg                              int_o    = 1'b0;
                                               
  // Internal signals
  reg        [SPI_DIVIDER_LEN-1:0] divider;          // Divider register
  reg       [`SPI_CTRL_BIT_NB-1:0] ctrl = {`SPI_CTRL_BIT_NB{1'b0}};
                                                     // Control and status register
  reg              [SPI_SS_NB-1:0] ss = {SPI_SS_NB{1'b0}};
                                                     // Slave select register
  reg                     [32-1:0] wb_dat;           // wb data out
  wire          [SPI_MAX_CHAR-1:0] rx;               // Rx register
  wire                             rx_negedge;       // miso is sampled on negative edge
  wire                             tx_negedge;       // mosi is driven on negative edge
  wire     [SPI_CHAR_LEN_BITS-1:0] char_len;         // char len
  wire                             go;               // go
  wire                             lsb;              // lsb first on line
  wire                             ie;               // interrupt enable
  wire                             ass;              // automatic slave select
  wire                             dir;              // data pin direction (only for three_wire mode)
  wire                             three_mode;       // spi three-wire mode indication (only for three_wire mode)
  wire                             spi_divider_sel;  // divider register select
  wire                             spi_ctrl_sel;     // ctrl register select
  wire                       [3:0] spi_tx_sel;       // tx_l register select
  wire                             spi_ss_sel;       // ss register select
  wire                             tip;              // transfer in progress
  wire                             pos_edge;         // recognize posedge of sclk
  wire                             neg_edge;         // recognize negedge of sclk
  wire                             last_bit;         // marks last character bit
  wire                             miosio_oen_o;

  // Address decoder
  assign spi_divider_sel = wb_cyc_i & wb_stb_i & (wb_adr_i[`SPI_OFS_BITS] == `SPI_DEVIDE);
  assign spi_ctrl_sel    = wb_cyc_i & wb_stb_i & (wb_adr_i[`SPI_OFS_BITS] == `SPI_CTRL);
  assign spi_tx_sel[0]   = wb_cyc_i & wb_stb_i & (wb_adr_i[`SPI_OFS_BITS] == `SPI_TX_0);
  assign spi_tx_sel[1]   = wb_cyc_i & wb_stb_i & (wb_adr_i[`SPI_OFS_BITS] == `SPI_TX_1);
  assign spi_tx_sel[2]   = wb_cyc_i & wb_stb_i & (wb_adr_i[`SPI_OFS_BITS] == `SPI_TX_2);
  assign spi_tx_sel[3]   = wb_cyc_i & wb_stb_i & (wb_adr_i[`SPI_OFS_BITS] == `SPI_TX_3);
  assign spi_ss_sel      = wb_cyc_i & wb_stb_i & (wb_adr_i[`SPI_OFS_BITS] == `SPI_SS);
  
  // Read from registers
  generate if (SPI_MAX_CHAR == 128)
    always @(wb_adr_i or rx or ctrl or divider or ss)
    begin
      case (wb_adr_i[`SPI_OFS_BITS])
        `SPI_RX_0:    wb_dat = rx[31:0];
        `SPI_RX_1:    wb_dat = rx[63:32];
        `SPI_RX_2:    wb_dat = rx[95:64];
        `SPI_RX_3:    wb_dat = {{128-SPI_MAX_CHAR{1'b0}}, rx[SPI_MAX_CHAR-1:96]};
        `SPI_CTRL:    wb_dat = {{32-`SPI_CTRL_BIT_NB{1'b0}}, ctrl};
        `SPI_DEVIDE:  wb_dat = {{32-SPI_DIVIDER_LEN{1'b0}}, divider};
        `SPI_SS:      wb_dat = {{32-SPI_SS_NB{1'b0}}, ss};
        default:      wb_dat = 32'bx;
      endcase
    end
  endgenerate

  generate if (SPI_MAX_CHAR == 64)
    always @(wb_adr_i or rx or ctrl or divider or ss)
    begin
      case (wb_adr_i[`SPI_OFS_BITS])
        `SPI_RX_0:    wb_dat = rx[31:0];
        `SPI_RX_1:    wb_dat = {{64-SPI_MAX_CHAR{1'b0}}, rx[SPI_MAX_CHAR-1:32]};
        `SPI_RX_2:    wb_dat = 32'b0;
        `SPI_RX_3:    wb_dat = 32'b0;
        `SPI_CTRL:    wb_dat = {{32-`SPI_CTRL_BIT_NB{1'b0}}, ctrl};
        `SPI_DEVIDE:  wb_dat = {{32-SPI_DIVIDER_LEN{1'b0}}, divider};
        `SPI_SS:      wb_dat = {{32-SPI_SS_NB{1'b0}}, ss};
        default:      wb_dat = 32'bx;
      endcase
    end
  endgenerate

  generate if (SPI_MAX_CHAR <=32)
    always @(wb_adr_i or rx or ctrl or divider or ss)
    begin
      case (wb_adr_i[`SPI_OFS_BITS])
        `SPI_RX_0:    wb_dat = {{32-SPI_MAX_CHAR{1'b0}}, rx[SPI_MAX_CHAR-1:0]};
        `SPI_RX_1:    wb_dat = 32'b0;
        `SPI_RX_2:    wb_dat = 32'b0;
        `SPI_RX_3:    wb_dat = 32'b0;
        `SPI_CTRL:    wb_dat = {{32-`SPI_CTRL_BIT_NB{1'b0}}, ctrl};
        `SPI_DEVIDE:  wb_dat = {{32-SPI_DIVIDER_LEN{1'b0}}, divider};
        `SPI_SS:      wb_dat = {{32-SPI_SS_NB{1'b0}}, ss};
        default:      wb_dat = 32'bx;
      endcase
    end
  endgenerate

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
  generate if (SPI_DIVIDER_LEN < 9)
    always @(posedge wb_clk_i or posedge wb_rst_i)
    begin
      if (wb_rst_i)
        divider <= #Tp {SPI_DIVIDER_LEN{1'b0}};
      else if (spi_divider_sel && wb_we_i && !tip && wb_sel_i[0])
        divider <= #Tp wb_dat_i[SPI_DIVIDER_LEN-1:0];
    end
  endgenerate

  generate if (SPI_DIVIDER_LEN >= 9 && SPI_DIVIDER_LEN <= 16)
    always @(posedge wb_clk_i or posedge wb_rst_i)
    begin
      if (wb_rst_i)
        divider <= #Tp {SPI_DIVIDER_LEN{1'b0}};
      else if (spi_divider_sel && wb_we_i && !tip)
      begin
        if (wb_sel_i[0])
          divider[7:0] <= #Tp wb_dat_i[7:0];
        if (wb_sel_i[1])
          divider[SPI_DIVIDER_LEN-1:8] <= #Tp wb_dat_i[SPI_DIVIDER_LEN-1:8];
      end
    end
  endgenerate

  generate if (SPI_DIVIDER_LEN >= 17 && SPI_DIVIDER_LEN <= 24)
    always @(posedge wb_clk_i or posedge wb_rst_i)
    begin
      if (wb_rst_i)
        divider <= #Tp {SPI_DIVIDER_LEN{1'b0}};
      else if (spi_divider_sel && wb_we_i && !tip)
      begin
        if (wb_sel_i[0])
          divider[7:0] <= #Tp wb_dat_i[7:0];
        if (wb_sel_i[1])
          divider[15:8] <= #Tp wb_dat_i[15:8];
        if (wb_sel_i[2])
          divider[SPI_DIVIDER_LEN-1:16] <= #Tp wb_dat_i[SPI_DIVIDER_LEN-1:16];
      end
    end
  endgenerate

  generate if (SPI_DIVIDER_LEN >= 25 && SPI_DIVIDER_LEN <= 32)
    always @(posedge wb_clk_i or posedge wb_rst_i)
    begin
      if (wb_rst_i)
        divider <= #Tp {SPI_DIVIDER_LEN{1'b0}};
      else if (spi_divider_sel && wb_we_i && !tip)
      begin
        if (wb_sel_i[0])
          divider[7:0] <= #Tp wb_dat_i[7:0];
        if (wb_sel_i[1])
          divider[15:8] <= #Tp wb_dat_i[15:8];
        if (wb_sel_i[2])
          divider[23:16] <= #Tp wb_dat_i[23:16];
        if (wb_sel_i[3])
          divider[SPI_DIVIDER_LEN-1:24] <= #Tp wb_dat_i[SPI_DIVIDER_LEN-1:24];
      end
    end
  endgenerate

  
  // Ctrl register
  always @(posedge wb_clk_i or posedge wb_rst_i)
  begin
    if (wb_rst_i)
      ctrl <= #Tp {`SPI_CTRL_BIT_NB{1'b0}};
    else if(spi_ctrl_sel && !tip)
      begin
        if(wb_we_i) begin
          if (wb_sel_i[0])
            ctrl[7:0] <= #Tp wb_dat_i[7:0] | {7'b0, ctrl[0]};
          if (wb_sel_i[1])
            ctrl[`SPI_CTRL_BIT_NB-1:8] <= #Tp wb_dat_i[`SPI_CTRL_BIT_NB-1:8];
        end
        ctrl[`SPI_CTRL_THREE_MODE] <= #Tp g_three_wire_mode;
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
  assign dir        = ctrl[`SPI_CTRL_DIR];
  assign three_mode = ctrl[`SPI_CTRL_THREE_MODE];
  
  // Slave select register
  generate if (SPI_SS_NB <= 8)
    always @(posedge wb_clk_i or posedge wb_rst_i)
    begin
      if (wb_rst_i)
        ss <= #Tp {SPI_SS_NB{1'b0}};
      else if(spi_ss_sel && wb_we_i && !tip && wb_sel_i[0])
        ss <= #Tp wb_dat_i[SPI_SS_NB-1:0];
    end
  endgenerate

  generate if (SPI_SS_NB >= 9 && SPI_SS_NB <= 16)
    always @(posedge wb_clk_i or posedge wb_rst_i)
    begin
      if (wb_rst_i)
        ss <= #Tp {SPI_SS_NB{1'b0}};
      else if(spi_ss_sel && wb_we_i && !tip)
      begin
        if (wb_sel_i[0])
          ss[7:0] <= #Tp wb_dat_i[7:0];
        if (wb_sel_i[1])
          ss[SPI_SS_NB-1:8] <= #Tp wb_dat_i[SPI_SS_NB-1:8];
      end
    end
  endgenerate

  generate if (SPI_SS_NB >= 17 && SPI_SS_NB <= 24)
    always @(posedge wb_clk_i or posedge wb_rst_i)
    begin
      if (wb_rst_i)
        ss <= #Tp {SPI_SS_NB{1'b0}};
      else if(spi_ss_sel && wb_we_i && !tip)
      begin
        if (wb_sel_i[0])
          ss[7:0] <= #Tp wb_dat_i[7:0];
        if (wb_sel_i[1])
          ss[15:8] <= #Tp wb_dat_i[15:8];
        if (wb_sel_i[2])
          ss[SPI_SS_NB-1:16] <= #Tp wb_dat_i[SPI_SS_NB-1:16];
      end
    end
  endgenerate

  generate if (SPI_SS_NB >= 25 && SPI_SS_NB <= 32)
    always @(posedge wb_clk_i or posedge wb_rst_i)
    begin
      if (wb_rst_i)
        ss <= #Tp {SPI_SS_NB{1'b0}};
      else if(spi_ss_sel && wb_we_i && !tip)
      begin
        if (wb_sel_i[0])
          ss[7:0] <= #Tp wb_dat_i[7:0];
        if (wb_sel_i[1])
          ss[15:8] <= #Tp wb_dat_i[15:8];
        if (wb_sel_i[2])
          ss[23:16] <= #Tp wb_dat_i[23:16];
        if (wb_sel_i[3])
          ss[SPI_SS_NB-1:24] <= #Tp wb_dat_i[SPI_SS_NB-1:24];
      end
    end
  endgenerate

  assign ss_pad_o = ~((ss & {SPI_SS_NB{tip & ass}}) | (ss & {SPI_SS_NB{!ass}}));
  
  spi_clgen #(.SPI_DIVIDER_LEN(SPI_DIVIDER_LEN)) clgen 
                  (.clk_in(wb_clk_i), .rst(wb_rst_i), .go(go), .enable(tip), .last_clk(last_bit),
                   .divider(divider), .clk_out(sclk_pad_o), .pos_edge(pos_edge), 
                   .neg_edge(neg_edge));
  
  spi_shift #(.SPI_MAX_CHAR(SPI_MAX_CHAR), .SPI_CHAR_LEN_BITS(SPI_CHAR_LEN_BITS)) shift 
                  (.clk(wb_clk_i), .rst(wb_rst_i), .len(char_len[SPI_CHAR_LEN_BITS-1:0]),
                   .latch(spi_tx_sel[3:0] & {4{wb_we_i}}), .byte_sel(wb_sel_i), .lsb(lsb), 
                   .go(go), .pos_edge(pos_edge), .neg_edge(neg_edge), 
                   .rx_negedge(rx_negedge), .tx_negedge(tx_negedge),
                   .tip(tip), .last(last_bit), .dir(dir),
                   .p_in(wb_dat_i), .p_out(rx), 
                   .s_clk(sclk_pad_o), .s_in(miso_pad_i), .s_out(mosi_pad_o),
                   .s_oe_n(miosio_oen_o));
endmodule
  
