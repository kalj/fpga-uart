`default_nettype none

`include "edge_trig.v"

module BaudGenInternal(input clk, output baud);
   // define a 24-bit counter to divide the clock down from 16MHz
   localparam WIDTH = 24;
   localparam DIVISOR = 1667; // -> 9600 Hz
   reg [WIDTH-1:0] counter;
   reg             baud;

   // run counter from 16MHz clock
   always @(posedge clk) begin
      counter <= counter + 1;
      baud <= 0;
      if (counter >= (DIVISOR-1)) begin
         counter <= 0;
         baud <= 1;
      end
   end
endmodule

module UartTx(input clk, input baud_edge, output tx, input [7:0] data, input latch_data, output busy);

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

module Top(input CLK,
           output LED,
           // tx & rx, baud
           output PIN_23, input PIN_22, output PIN_21, output PIN_20,
           // addr0, addr1,
           input  PIN_14, input PIN_15,
           // rw, ~cs, ~rst
           input  PIN_16, input PIN_17, input PIN_18,
           // data bus
           inout  PIN_6, inout PIN_7, inout PIN_8, inout PIN_9, inout PIN_10, inout PIN_11, inout PIN_12, inout PIN_13);

   wire [7:0]    data_bus = {PIN_13, PIN_12, PIN_11, PIN_10, PIN_9, PIN_8, PIN_7, PIN_6};
   wire [1:0]    addr = {PIN_15, PIN_14};

   wire          baud_edge;
   BaudGenInternal U1(.clk(CLK), .baud(baud_edge));

   wire          btrig;
   FallingEdgeTrig U2(.clk(CLK), .out(btrig), .in(PIN_17));

   wire          busy;

   UartTx U3( .clk(CLK), .baud_edge(baud_edge), .tx(PIN_23), .data(data_bus), .latch_data(btrig), .busy(busy));

   assign LED = busy;
   assign PIN_21 = baud_edge;
   assign PIN_20 = busy;

endmodule
