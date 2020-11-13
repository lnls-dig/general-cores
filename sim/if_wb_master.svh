//------------------------------------------------------------------------------
// CERN BE-CO-HT
// General Cores Library
// https://www.ohwr.org/projects/general-cores
//------------------------------------------------------------------------------
//
// unit name: IWishboneMaster
//
// description: Software Wishbone master unit for testbenches.
//
//------------------------------------------------------------------------------
// Copyright CERN 2010-2019
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

`include "simdrv_defs.svh"
`include "if_wishbone_types.svh"
`include "if_wishbone_accessor.svh"

interface IWishboneMaster
  (
   input clk_i,
   input rst_n_i
   );

   parameter g_addr_width = 32;
   parameter g_data_width = 32;

   logic [g_addr_width - 1   : 0] adr;
   logic [g_data_width - 1   : 0] dat_o;
   logic [(g_data_width/8)-1 : 0] sel;
   wire  [g_data_width - 1   : 0] dat_i;
   wire  ack;
   wire  stall;
   wire  err;
   wire  rty;
   logic cyc;
   logic stb;
   logic we;

   wire  stall_valid = stall & cyc;

   modport master
     (
      output adr,
      output dat_o,
      output sel,
      output cyc,
      output stb,
      output we,
      input  ack,
      input  dat_i,
      input  stall,
      input  err,
      input  rty
      );

   time last_access_t = 0;

   enum {
         IDLE,
         BUSY,
         WAIT_ACK
   } xf_state;

   wb_cycle_t request_queue[$];
   wb_cycle_t result_queue[$];

   struct {
      int gen_random_throttling;
      real throttle_prob;
      int little_endian; // not supported
      int cyc_on_stall;  // not used, kept for compatibility
      wb_address_granularity_t addr_gran;
   } settings;

   function automatic logic[63:0] rev_bits(logic [63:0] x, int nbits);
      logic[63:0] tmp;
      int i;

      for (i = 0; i < nbits; i++)
        tmp[nbits-1-i] = x[i];

      return tmp;
   endfunction // rev_bits

   function automatic logic[g_addr_width-1:0] gen_addr(wb_xfer_t xfer);
      if (settings.addr_gran == WORD)
        case (g_data_width)
           8: return xfer.a;
          16: return xfer.a >> 1;
          32: return xfer.a >> 2;
          64: return xfer.a >> 3;
          default: $error("IWishbone: invalid WB data bus width [%d bits\n]", g_data_width);
        endcase
      else
        return xfer.a;
   endfunction // gen_addr

   //FIXME: little endian
   function automatic logic[(g_data_width/8)-1:0] gen_sel(wb_xfer_t xfer);
      logic [(g_data_width/8)-1:0] sel;

      sel = ((1 << xfer.size) - 1);

      return rev_bits(sel << (xfer.a % xfer.size), g_data_width/8);
   endfunction // gen_sel

   //FIXME: little endian
   function automatic logic[g_data_width-1:0] gen_data(wb_xfer_t xfer);
      const int dbytes  = (g_data_width/8-1);

      return xfer.d << (8 * (dbytes - (xfer.size - 1 - (xfer.a % xfer.size))));

   endfunction // gen_data

   function automatic uint64_t decode_data(wb_xfer_t xfer, logic[g_data_width-1:0] data);
      int rem;

      rem  = xfer.a % xfer.size;

      return (data >> (8 * rem)) & ((1 << (xfer.size * 8)) - 1);
   endfunction // decode_data

   task automatic classic_cycle(ref wb_cycle_t c);

      int i;

      int failure = 0;

      /* resynchronize, just in case */
      if ($time != last_access_t) @(posedge clk_i);

      xf_state = BUSY;

      for (i = 0; i < c.data.size(); i++) begin

         stb   <= 1'b1;
         cyc   <= 1'b1;
         adr   <= gen_addr(c.data[i]);
         we    <= (c.rw != 0);
         sel   <= gen_sel(c.data[i]);
         dat_o <= gen_data(c.data[i]);
         @(posedge clk_i);

         while (ack != 1'b1 && err != 1'b1 && rty == 1'b1) @(posedge clk_i);

         if (err || rty) begin
            c.result = (err ? R_ERROR: R_RETRY);
            failure = 1;
            break;
         end

         c.data[i].d = decode_data(c.data[i], dat_i);

         cyc <= 0;
         we  <= 0;
         stb <= 0;
         @(posedge clk_i);

      end

      if (!failure)
        c.result = R_OK;

      xf_state = IDLE;

      last_access_t = $time;
   endtask // classic_cycle

   task automatic pipelined_cycle(ref wb_cycle_t c);

      int stb_count = 0;
      int ack_count = 0;
      int failure   = 0;
      int cur_rdbk  = 0;

      /* resynchronize, just in case */
      if ($time != last_access_t) @(posedge clk_i);

      xf_state = BUSY;

      cyc <= 1'b1;
      stb <= 1'b1;
      adr <= gen_addr(c.data[stb_count]);
      if (c.rw == 1) begin
         we    <= 1'b1;
         sel   <= gen_sel(c.data[stb_count]);
         dat_o <= gen_data(c.data[stb_count]);
      end
      else begin
         we  <= 1'b0;
         sel <= 'hffffffff;
      end

      while (stall_valid || ((stb_count < c.data.size()) && !failure)) begin
         if (ack) begin
            ack_count++;
            if (c.rw == 0) begin
               c.data[cur_rdbk].d = dat_i;
               cur_rdbk++;
            end
         end
         else if (err || rty) begin
            c.result = (err ? R_ERROR: R_RETRY);
            failure = 1;
            break;
         end

         if (settings.gen_random_throttling &&
             probability_hit(settings.throttle_prob)) begin
            stb <= 1'b0;
            we  <= 1'b0;
         end
         else if (stall_valid == 1'b0) begin
            stb <= 1'b1;
            adr <= gen_addr(c.data[stb_count]);
            if (c.rw == 1) begin
               we    <= 1'b1;
               sel   <= gen_sel(c.data[stb_count]);
               dat_o <= gen_data(c.data[stb_count]);
            end
            else begin
               we  <= 1'b0;
               sel <= 'hffffffff;
            end
            stb_count++;
         end

         @(posedge clk_i);
      end

      stb <= 1'b0;
      we  <= 1'b0;

      xf_state = WAIT_ACK;

      while ((ack_count < c.data.size()) && !failure) begin
         if (ack) begin
            ack_count++;
            if (c.rw == 0) begin
               c.data[cur_rdbk].d = dat_i;
               cur_rdbk++;
            end
         end
         else if (err || rty) begin
            c.result = (err ? R_ERROR: R_RETRY);
            failure = 1;
            xf_state = IDLE;
            break;
         end
         if (ack_count == c.data.size()) begin
            cyc <= 1'b0;
            we  <= 1'b0;
            xf_state = IDLE;
         end
         @(posedge clk_i);
      end

      cyc <= 1'b0;
      we  <= 1'b0;

      if (!failure)
        c.result = R_OK;

      last_access_t = $time;

   endtask // pipelined_cycle

class CIWBMasterAccessor extends CWishboneAccessor;

   function automatic int poll();
      return 0;
   endfunction // poll

   task get(ref wb_cycle_t xfer);
      while(!result_queue.size())
        @(posedge clk_i);
      xfer = result_queue.pop_front();
   endtask // get

   task put(ref wb_cycle_t xfer);
      request_queue.push_back(xfer);
   endtask // put

   function int idle();
      return (request_queue.size() == 0) && (xf_state == IDLE);
   endfunction // idle

endclass // CIWBMasterAccessor


   CIWBMasterAccessor theAccessor;

   initial
     theAccessor = new;
   
   function automatic CIWBMasterAccessor get_accessor();
      return theAccessor;
   endfunction // get_accessor

   always@(posedge clk_i)
     if (!rst_n_i) begin
        request_queue = {};
        result_queue  = {};
        xf_state      = IDLE;
        cyc          <= 0;
        dat_o        <= 0;
        stb          <= 0;
        sel          <= 0;
        adr          <= 0;
        we           <= 0;
  end

   initial begin
      settings.gen_random_throttling  = 0;
      settings.throttle_prob          = 0.1;
      settings.addr_gran              = WORD;
   end

   initial forever begin
      @(posedge clk_i);

      if (request_queue.size() > 0) begin

         wb_cycle_t c;

         c = request_queue.pop_front();

         case(c.ctype)
           PIPELINED:
             pipelined_cycle(c);
           CLASSIC:
             classic_cycle(c);
         endcase

         result_queue.push_back(c);
      end

   end

endinterface // IWishboneMaster
