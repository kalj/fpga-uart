`default_nettype none

`include "edge_trig.v"

module BaudGenInternal(input clk, output baud);

   wire intermediate;

   SB_PLL40_CORE usb_pll_inst (
                               .REFERENCECLK(clk),
                               .PLLOUTCORE(intermediate),
                               .RESETB(1),
                               .BYPASS(0)
                               );

   defparam usb_pll_inst.DIVR = 0;
   defparam usb_pll_inst.DIVF = 9-1;  // 9-1
   defparam usb_pll_inst.DIVQ = 1;  // 1, 0
   defparam usb_pll_inst.FILTER_RANGE = 3'b001;
   defparam usb_pll_inst.FEEDBACK_PATH = "SIMPLE";
   defparam usb_pll_inst.DELAY_ADJUSTMENT_MODE_FEEDBACK = "FIXED";
   defparam usb_pll_inst.FDA_FEEDBACK = 4'b0000;
   defparam usb_pll_inst.DELAY_ADJUSTMENT_MODE_RELATIVE = "FIXED";
   defparam usb_pll_inst.FDA_RELATIVE = 4'b0000;
   defparam usb_pll_inst.SHIFTREG_DIV_MODE = 2'b00;
   defparam usb_pll_inst.PLLOUT_SELECT = "GENCLK";
   defparam usb_pll_inst.ENABLE_ICEGATE = 1'b0;

   localparam WIDTH = 10;
   localparam DIVISOR = 625;
   reg [WIDTH-1:0] counter;
   reg             baud_clock;


   initial begin
      counter <= 'b0;
      baud_clock <= 'b0;
   end


   always @(posedge intermediate) begin
      counter <= counter + 1;
      if (counter >= (DIVISOR-1)) begin
         counter <= 0;
         baud_clock <= ~baud_clock;
      end
   end

   reg             baud;

   RisingEdgeTrig U2(.clk(clk), .out(baud), .in(baud_clock));

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
