`default_nettype none

`include "edge_trig.v"

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

   wire reading = (!ncs & nwe & nrst); // output if selected and not writing and not resetting
   wire writing = (!ncs & !nwe & nrst); // input if selected and writing and not resetting

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

   always @(posedge clk) begin
      if (reading) begin
         data_oe <= ~0; // all ones
      end
      else begin
         data_oe <= 0;
      end
   end

   wire                    write_trig;
   RisingEdgeTrig U1(.clk(clk), .out(write_trig), .in(writing));

   wire                    tx_busy;
   UartTx     U2(.clk(clk), .baud_edge(tx_baud_edge), .tx(tx), .data(data_in), .latch_data(write_trig), .busy(tx_busy));

   wire                     new_rx_data_ready;
   wire [7:0]               new_rx_data;
   UartRx     U3(.clk(clk), .rx(rx), .data(new_rx_data), .baud_edge(rx_baud_edge), .data_ready(new_rx_data_ready));

   reg                      rx_available;
   reg [7:0]                rx_data;

   wire                     reading_start;
   wire                     reading_end;
   RisingEdgeTrig U4(.clk(clk), .out(reading_start), .in(reading));
   FallingEdgeTrig U5(.clk(clk), .out(reading_end),   .in(reading));

   always @(posedge clk) begin

      if (new_rx_data_ready) begin
         rx_data      <= new_rx_data;
         rx_available <= 1;
      end

      if (reading_start) begin
         if (addr==2'b00) begin
            // status
            data_out <= { 6'b0, rx_available, tx_busy };
         end

         if (addr==2'b01 && rx_available) begin
            // rx data
            data_out     <= rx_data;
            rx_available <= 0;
         end
      end

      if (reading_end) begin
         data_out <= 0;
      end
   end

endmodule

module Top(input CLK,
           // tx & rx
           output PIN_23, input PIN_22,
           // addr0, addr1,
           input  PIN_14, input PIN_15,
           // ~rst, phi2, ~cs, ~we
           input  PIN_16, input PIN_17, input PIN_18, input PIN_19,
           // debug
           // output PIN_20, output PIN_21,
           // data bus
           inout  PIN_6, inout PIN_7, inout PIN_8, inout PIN_9, inout PIN_10, inout PIN_11, inout PIN_12, inout PIN_13);

   wire [7:0]    data_bus = {PIN_13, PIN_12, PIN_11, PIN_10, PIN_9, PIN_8, PIN_7, PIN_6};
   wire [1:0]    addr = {PIN_15, PIN_14};

   Uart U1(.clk(CLK),
           .tx(PIN_23), .rx(PIN_22),
           .addr(addr),
           .nrst(PIN_16), .phi2(PIN_17), .ncs(PIN_18), .nwe(PIN_19),
           .data(data_bus));
endmodule
