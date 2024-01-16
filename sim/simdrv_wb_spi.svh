//------------------------------------------------------------------------------
// CERN BE-CEM-EDL
// General Cores Library
// https://www.ohwr.org/projects/general-cores
//------------------------------------------------------------------------------
//
// unit name: CSimDrv_WB_SPI
//
// author: Grzegorz Daniluk
//
// description: SV wb_spi master driver for testbenches
//
//------------------------------------------------------------------------------
// Copyright CERN 2021
//------------------------------------------------------------------------------
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 2.0 (the "License"); you may not use this file except
// in compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-2.0.
// Unless required by applicable law or agreed to in writing, software,
// hardware and materials distributed under this License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
// or implied. See the License for the specific language governing permissions
// and limitations under the License.
//------------------------------------------------------------------------------

`ifndef __SIMDRV_WB_SPI_SVH
`define __SIMDRV_WB_SPI_SVH 1

`define SPI_REG_RX0 0
`define SPI_REG_TX0 0
`define SPI_REG_RX1 4
`define SPI_REG_TX1 4
`define SPI_REG_RX2 8
`define SPI_REG_TX2 8
`define SPI_REG_RX3 12
`define SPI_REG_TX3 12

`define SPI_REG_CTRL  16
`define SPI_REG_DIVIDER 20
`define SPI_REG_SS  24

`define SPI_CTRL_ASS      (1<<13) // automatic slave select (nCS)
`define SPI_CTRL_IE       (1<<12) // interrupt enable
`define SPI_CTRL_LSB      (1<<11) // LSB first on line
`define SPI_CTRL_TXNEG    (1<<10) // MOSI driven on negative SCLK edge
`define SPI_CTRL_RXNEG    (1<<9)  // MISO sampled on negative SCLK edge
`define SPI_CTRL_GO_BSY   (1<<8)
`define SPI_CTRL_CHAR_LEN(x)  ((x) & 'h7f)

class CSimDrv_WB_SPI;
  
  protected CBusAccessor acc;
  protected uint64_t base;

  function new(CBusAccessor busacc, uint64_t adr);
    acc = busacc;
    base = adr;
  endfunction

  task init();
    // set divider
    acc.write(base + `SPI_REG_DIVIDER, 10);
  endtask;

  task cs(int state);
    acc.write(base + `SPI_REG_SS, state);
  endtask

  task txrx(uint32_t in, int nbits, output uint32_t out);
    uint64_t rval;

    // configure transfer
    acc.write(`SPI_REG_CTRL, `SPI_CTRL_CHAR_LEN(nbits) | `SPI_CTRL_TXNEG);
    acc.write(`SPI_REG_TX0, in);
    // start transfer
    acc.write(`SPI_REG_CTRL, `SPI_CTRL_CHAR_LEN(nbits) | `SPI_CTRL_TXNEG | `SPI_CTRL_GO_BSY);
    do begin
      acc.read(`SPI_REG_CTRL, rval);
    end while (rval & `SPI_CTRL_GO_BSY);
    acc.read(`SPI_REG_RX0, rval);
    out = rval;
  endtask

endclass

`endif
