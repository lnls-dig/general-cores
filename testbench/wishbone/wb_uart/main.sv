//------------------------------------------------------------------------------
// Copyright CERN 2018
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

`timescale 1ps/1ps

`include "vhd_wishbone_master.svh"
`include "wb_uart_regs.vh"

import wishbone_pkg::*;


module dupa;
    xwb_simple_uart dut();
endmodule // dupa

class IBusDevice;

   CBusAccessor m_acc;
   uint64_t m_base;

   function new ( CBusAccessor acc, uint64_t base );
      m_acc =acc;
      m_base = base;
   endfunction // new
   
   virtual task write32( uint32_t addr, uint32_t val );
      m_acc.write(m_base +addr, val);
   endtask // write
   
   virtual task read32( uint32_t addr, output uint32_t val );
      uint64_t val64;
      
      m_acc.read(m_base +addr, val64);
      val = val64;
   endtask // write
endclass // BusDevice

class WBUartDriver extends IBusDevice;
   function new(CBusAccessor bus, uint64_t base);
      super.new(bus, base);
   endfunction // new

   protected bit m_with_fifo;

   protected byte m_tx_queue[$];
   protected byte m_rx_queue[$];

   protected bit  m_tx_idle;
   
   function automatic uint32_t calc_baudrate( uint64_t baudrate, uint64_t base_clock);
      return ( ((( baudrate << 12)) + (base_clock >> 8)) / (base_clock >> 7) );
   endfunction

   
   task automatic init( uint32_t baudrate, uint32_t clock_freq, int fifo_en );
      uint32_t rv;
      read32( `ADDR_UART_SR, rv );

      $display("uart_init SR %b", rv);
      
      
      write32(`ADDR_UART_BCR, calc_baudrate( baudrate, clock_freq) );
      
      
      if(!fifo_en)
	m_with_fifo = 0;
      else
	m_with_fifo = (rv & `UART_SR_RX_FIFO_SUPPORTED) ? 1 : 0;

      m_tx_idle = 0;
      
      $display("wb_simple_uart: FIFO supported = %d", m_with_fifo);
      
   endtask // init
   
   
   task automatic send( byte value );
      
      m_tx_queue.push_back(value);
      m_tx_idle = 0;
      update();
   endtask // send

   function automatic byte recv();
      if( rx_count() == 0 )
	return -1;
      return m_rx_queue.pop_front();
   endfunction // recv
   
   function automatic int rx_count();
      return m_rx_queue.size();
   endfunction // rx_count
   
   function automatic bit poll();
      return m_rx_queue.size() > 0;
   endfunction // has_data

   function automatic bit tx_idle();

      return m_tx_idle;
   endfunction // tx_idle

   function automatic bit rx_overflow();
   endfunction // rx_overflow
   
   task automatic update();
      automatic uint32_t sr;
      automatic time ts = $time;
      
      read32( `ADDR_UART_SR, sr );




      
      if( m_with_fifo ) begin
	 if( sr & `UART_SR_RX_RDY ) begin
	    automatic uint32_t d;
	    read32(`ADDR_UART_RDR, d);
//	    $display("FifoRx: %x", d);
	    m_rx_queue.push_back(d);
	 end

	 if( ! ( sr & `UART_SR_TX_FIFO_FULL )  && m_tx_queue.size() > 0 ) begin

	    byte d = m_tx_queue.pop_front();
//	    $display("-> FifoTX %x", d);
	    write32(`ADDR_UART_TDR, d);
	 end else if ( !m_tx_queue.size() ) begin
	   m_tx_idle = 1;
	 end
	 
	 
      end else begin
	 if( ! ( sr & `UART_SR_TX_BUSY ) && m_tx_queue.size() > 0) begin
	    byte d = m_tx_queue.pop_front();
//	    $display("NoFifoTX");
	    write32(`ADDR_UART_TDR, d);
	 end else if ( !m_tx_queue.size() ) begin
	   m_tx_idle = 1;
	 end
	 
	 
	 
	 if( sr & `UART_SR_RX_RDY ) begin
	    automatic uint32_t d;
	    read32(`ADDR_UART_RDR, d);
//	    $display("NoFifoRx: %x", d);
	    m_rx_queue.push_back(d);
	 end
	 

      end




   endtask // update
   
   
endclass // WBUartDriver



  
	   
module main;

   reg rst_n = 0;
   reg clk_62m5 = 0;
   
   always #8ns clk_62m5 <= ~clk_62m5;

   initial begin
      repeat(20) @(posedge clk_62m5);
      rst_n = 1;
   end

   
   // the Device Under Test
   xwb_simple_uart
     #(
       .g_WITH_PHYSICAL_UART(1'b1),
       .g_WITH_PHYSICAL_UART_FIFO(1'b1),
       .g_TX_FIFO_SIZE(64),
       .g_RX_FIFO_SIZE(64),
       .g_INTERFACE_MODE(PIPELINED),
       .g_ADDRESS_GRANULARITY(0)
       )
   DUT_FIFO
     (
      .rst_n_i(rst_n),
      .clk_sys_i (clk_62m5),
      
      .slave_i            (Host1.out),
      .slave_o            (Host1.in),
 
      .uart_txd_o(loop),
      .uart_rxd_i(loop)
  );
  
   
   // the Device Under Test
   xwb_simple_uart
     #(
       .g_WITH_PHYSICAL_UART(1'b1),
       .g_WITH_PHYSICAL_UART_FIFO(1'b0),
       .g_INTERFACE_MODE(PIPELINED),
       .g_ADDRESS_GRANULARITY(0)
       )
   DUT_NO_FIFO
     (
      .rst_n_i(rst_n),
      .clk_sys_i (clk_62m5),
      
      .slave_i            (Host2.out),
      .slave_o            (Host2.in),

      .uart_txd_o(rxd),
      .uart_rxd_i(txd)

   );

    
   IVHDWishboneMaster Host1
     (
      .clk_i   (clk_62m5),
      .rst_n_i (rst_n));

   IVHDWishboneMaster Host2
     (
      .clk_i   (clk_62m5),
      .rst_n_i (rst_n));


   const int n_tx_bytes = 1024;

   
   initial begin
      real t;
      
      automatic CWishboneAccessor acc1 = Host1.get_accessor();
      automatic       WBUartDriver drv_fifo = new( acc1, 0 );
//      automatic       CWishboneAccessor acc2 = Host2.get_accessor();
//      automatic       WBUartDriver drv_no_fifo = new( acc2, 0 );

      automatic 	    int i;

      acc1.set_mode(PIPELINED); 
      //acc2.set_mode(PIPELINED); 
    
      
      #100ns;

    //  $stop;
      
      @(posedge rst_n);
      @(posedge clk_62m5);
      

      drv_fifo.init(9216000, 62500000, 1);
//      drv_no_fifo.init(9216000, 62500000, 0);

      #1us;
      
      for(i=0;i<n_tx_bytes;i++)
	begin
//	   drv_no_fifo.send(i);
	   drv_fifo.send(i);
//	   drv_no_fifo.update();
	   drv_fifo.update();
	end

      forever
	begin
//	   $display("%d %d", drv_fifo.tx_idle(), drv_no_fifo.tx_idle() );
	   
	   drv_fifo.update();
//	   drv_no_fifo.update();
	   if( drv_fifo.tx_idle() /* &&  drv_no_fifo.tx_idle() */ )
	     break;
	end

      $display("TX Complete");
      
      for(i=0;i<500;i++)
	begin
	   drv_fifo.update();
	   #1us;
	   
//	   drv_no_fifo.update();
	end
      

      $display("TX Idle!");

      for(i=0;i<100;i++)
	begin
//	   automatic int rx = drv_no_fifo.recv();
//	   if( rx != i )
//	     $error("NoFifo err %x vs %x", i, rx );
	   automatic int rx = drv_fifo.recv();
	   $display("Fifo %02x vs %02x %s", i, rx, (i == rx) ? "OK" : "ERROR" );
	   if( i != rx )
	     $error("");
	   
	   
	end
      
      $display("Test complete");
      
      
      $stop;
      
      
   end // initial begin

endmodule // main
