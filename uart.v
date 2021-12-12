`default_nettype none

`include "edge_trig.v"
`include "fifo.v"

// `include "sim-primitives.v"

module BaudGenInternal(input clk, output baud, input half_reset);
   // define a counter to divide the clock down from 16MHz

   // -> 9600 Hz
   // localparam DIVISOR = 1667;
   // localparam WIDTH = 11;
   // localparam HALF_DIVISOR = 833;

   // -> 57600 Hz
   // localparam DIVISOR = 278;
   // localparam WIDTH = 9;
   // localparam HALF_DIVISOR = 139;

   // -> 115200 Hz
   localparam DIVISOR = 139;
   localparam WIDTH = 8;
   localparam HALF_DIVISOR = 69;

   reg [WIDTH-1:0] counter;
   reg             baud = 0;

   // run counter from 16MHz clock
   always @(posedge clk) begin
      counter <= counter + 1;
      baud <= 0;

      if (half_reset) begin
         counter <= HALF_DIVISOR;
      end
      else if (counter >= (DIVISOR-1)) begin
         counter <= 0;
         baud <= 1;
      end
   end

endmodule


module UartTx(input clk, output baud_edge, output tx, input [7:0] data, input latch_data, output busy);

   BaudGenInternal U1(.clk(clk), .baud(baud_edge), .half_reset(0));

   localparam REGWIDTH = 12;
   reg [(REGWIDTH-1):0] buffer;

   reg [3:0] bits_left = 0;

   always @(posedge clk) begin

      if(baud_edge) begin
         buffer <= { 1'b1, buffer[(REGWIDTH-1):1] };
         bits_left <= (bits_left>0)?(bits_left-1): 0;
      end

      if(latch_data && bits_left == 0) begin
         bits_left <= REGWIDTH;
         buffer <= { 2'b11, data, 2'b01};
      end
   end

   assign busy = bits_left != 0;
   assign tx = buffer[0];

endmodule

module UartRx(input clk, output baud_edge, input rx, output [7:0] data,
              output data_ready);

   reg              baud_reset = 0;
   BaudGenInternal U1(.clk(clk), .baud(baud_edge), .half_reset(baud_reset));

   reg [7:0] data = 0;
   reg       data_ready = 0;

   localparam STATE_READY = 0;
   localparam STATE_RECEIVING_START_BIT  = 1;
   localparam STATE_RECEIVING_DATA = 2;
   localparam STATE_RECEIVING_STOP_BIT = 3;

   reg [1:0] state = STATE_READY;
   reg [2:0] data_bits_received = 0;

   reg              cur_rx = 0;
   reg              prev_rx = 0;

   always @(posedge clk) begin
      // latch current and previous rx value into registers
      cur_rx  <= rx;
      prev_rx <= cur_rx;

      baud_reset <= 0;

      if(state == STATE_READY && !cur_rx && prev_rx) begin
         state <= STATE_RECEIVING_START_BIT;
         baud_reset <= 1;
      end

      if(baud_edge) begin
         if(state == STATE_RECEIVING_START_BIT) begin
            // rx must be low due to above
            data_bits_received <= 0;
            state <= STATE_RECEIVING_DATA;
         end

         if(state == STATE_RECEIVING_DATA) begin
            data <= { cur_rx, data[7:1] };
            if (data_bits_received != 7)
              data_bits_received <= data_bits_received+1;
            else begin
               state <= STATE_RECEIVING_STOP_BIT;
            end
         end

         if(state == STATE_RECEIVING_STOP_BIT) begin
            // only set to ready if a trailing "1" was found
            if(cur_rx) data_ready <= 1;

            state <=  STATE_READY;
         end
      end

      // data_ready is only high for one cycle
      if(data_ready) begin
         data_ready <= 0;
         data <= 0;
      end
   end
endmodule

module Uart(input       clk,
            output      tx, input rx, output tx_baud_edge, output rx_baud_edge,
            input [1:0] addr,
            input       nwe,
            input       phi2,
            input       ncs, input nrst,
            inout [7:0] data);

   reg [7:0] data_oe = 0;
   reg [7:0] data_out = 0;
   wire [7:0] data_in;

   SB_IO #(
       .PIN_TYPE(6'b 1010_01), // PIN_OUTPUT_TRISTATE - PIN_INPUT
       .PULLUP(1'b 0)
   ) iobuf_mybuf [7:0] (
       .PACKAGE_PIN(data),
       .OUTPUT_ENABLE(data_oe),
       .D_OUT_0(data_out),
       .D_IN_0(data_in)
   );

   // set output enabled
   always @(posedge clk) begin
      if(!ncs && nwe)
        data_oe <= ~0; // all ones
      else
        data_oe <= 0;
   end

   //----------------------------------------------------------------
   // handle phi2 edges
   //----------------------------------------------------------------
   reg [2:0]                phi2_dl;

   always @(posedge clk) begin
      phi2_dl <= {phi2_dl[1:0], phi2};
   end

   // maximum one cycle after actual pos edge (62.5ns)
   wire phi2_posedge = phi2_dl[0] && !phi2_dl[1];
   wire phi2_negedge = !phi2_dl[0] && phi2_dl[1];

   // one cycle later (62.5ns)
   wire phi2_posedge_p1 = phi2_dl[1] && !phi2_dl[2];
   wire phi2_negedge_p1 = !phi2_dl[1] && phi2_dl[2];

   //----------------------------------------------------------------
   // tx fifo and shift register
   //----------------------------------------------------------------

   wire [7:0]               tx_fifo_out;
   wire                     tx_fifo_full;
   wire                     tx_fifo_empty;
   reg                      tx_send_next;
   reg                      write_trig;
   Fifo #(.N_SLOTS(8)
          ) Utx_fifo (.clk(clk),
                      .write_trig(write_trig),
                      .read_trig(tx_send_next),
                      .reset(!nrst),
                      .in(data_in),
                      .out(tx_fifo_out),
                      .full(tx_fifo_full),
                      .empty(tx_fifo_empty));

   wire                   tx_busy;
   reg                    tx_latch_data;
   UartTx     Utx(.clk(clk), .baud_edge(tx_baud_edge), .tx(tx), .data(tx_fifo_out), .latch_data(tx_send_next), .busy(tx_busy));

   reg [1:0]                   ready_to_send_next_dl;
   always @(posedge clk) begin
      ready_to_send_next_dl <= {ready_to_send_next_dl[0], !tx_busy && !tx_fifo_empty};

      tx_send_next <= 0;
      if(ready_to_send_next_dl[0] && !ready_to_send_next_dl[1])
        tx_send_next <= 1;
   end

   //----------------------------------------------------------------
   // rx fifo and shift register
   //----------------------------------------------------------------

   wire                   new_rx_data_ready;
   wire [7:0]             new_rx_data;
   UartRx     Urx(.clk(clk), .baud_edge(rx_baud_edge), .rx(rx), .data(new_rx_data), .data_ready(new_rx_data_ready));

   wire [7:0]               rx_fifo_out;
   wire                     rx_fifo_full;
   wire                     rx_fifo_empty;
   wire                     rx_fifo_write = new_rx_data_ready;
   reg                      rx_fifo_read_trig;
   Fifo Urx_fifo(.clk(clk),
                 .write_trig(rx_fifo_write),
                 .read_trig(rx_fifo_read_trig),
                 .reset(!nrst),
                 .in(new_rx_data),
                 .out(rx_fifo_out),
                 .full(rx_fifo_full),
                 .empty(rx_fifo_empty));

   //----------------------------------------------------------------
   // main bus/register logic
   //----------------------------------------------------------------

   reg [7:0]                rx_data;

   always @(posedge clk) begin

      // default values
      rx_fifo_read_trig <= 0;
      write_trig <= 0;

      // write trigger
      // 25ns after pos edge, data has stabilized
      if(!ncs && !nwe && phi2_posedge_p1 && addr == 2'b10)
        write_trig <= 1;

      // start of read cycle
      if(!ncs && nwe && phi2_posedge) begin
         if (addr == 2'b00)  begin
            // status
            data_out <= { 6'b0, rx_fifo_empty, tx_fifo_full };
         end else if(addr == 2'b01 && !rx_fifo_empty) begin
            // rx data
            data_out     <= rx_fifo_out;
            rx_fifo_read_trig <= 1;
         end else
           data_out     <= 0;
      end

      // end of read cycle
      if(phi2_negedge_p1) begin
         data_out <= 0;
      end
   end

endmodule

module Top(input CLK,
           // tx & rx
           output PIN_P9, input PIN_P10,
           // addr0, addr1,
           input  PIN_A0_P8, input PIN_A1_P7,
           // ~rst, phi2, ~cs, ~we
           input  PIN_RSTB, input PIN_PHI2, input PIN_CSB, input PIN_RWB,
           // debug
           // output PIN_20, output PIN_21,
           // data bus
           inout  PIN_D0, inout PIN_D1, inout PIN_D2, inout PIN_D3, inout PIN_D4, inout PIN_D5, inout PIN_D6, inout PIN_D7);

   wire [7:0]    data_bus = {PIN_D7, PIN_D6, PIN_D5, PIN_D4, PIN_D3, PIN_D2, PIN_D1, PIN_D0};
   wire [1:0]    addr = {PIN_A1_P7, PIN_A0_P8};

   Uart U1(.clk(CLK),
           .tx(PIN_P9), .rx(PIN_P10),
           .addr(addr),
           .nrst(PIN_RSTB), .phi2(PIN_PHI2), .ncs(PIN_CSB), .nwe(PIN_RWB),
           .data(data_bus));
endmodule
