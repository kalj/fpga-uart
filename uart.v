`default_nettype none

`include "edge_trig.v"

module BaudGenInternal(input clk, output baud);

   wire intermediate;

   // 115200
   // localparam DIVF = 9-1;
   // localparam DIVQ = 0;

   // 57600
   localparam DIVF = 9-1;
   localparam DIVQ = 1;

   // 9600
   // localparam DIVF = 3-1;
   // localparam DIVQ = 2;

   SB_PLL40_CORE #(.DIVF(DIVF),
                   .DIVQ(DIVQ),
                   .DIVR(0),
                   .FILTER_RANGE(3'b001),
                   .FEEDBACK_PATH("SIMPLE"),
                   .DELAY_ADJUSTMENT_MODE_FEEDBACK("FIXED"),
                   .FDA_FEEDBACK(4'b0000),
                   .DELAY_ADJUSTMENT_MODE_RELATIVE("FIXED"),
                   .FDA_RELATIVE(4'b0000),
                   .SHIFTREG_DIV_MODE(2'b00),
                   .PLLOUT_SELECT("GENCLK"),
                   .ENABLE_ICEGATE(1'b0),
                   ) usb_pll_inst (.REFERENCECLK(clk),
                                   .PLLOUTCORE(intermediate),
                                   .RESETB(1),
                                   .BYPASS(0));

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
      if (counter == (DIVISOR-1)) begin
         counter <= 0;
         baud_clock <= ~baud_clock;
      end
   end

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

module Uart(input       clk,
            output      tx, input rx, input baud_edge,
            input [1:0] addr,
            input       rw, // 1: read, 0: write
            input       ncs, input nrst,
            inout [7:0] data);

   wire reading = (!ncs & rw & nrst); // output if selected and not writing and not resetting
   wire writing = (!ncs & !rw & nrst); // input if selected and writing and not resetting

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
   UartTx     U2(.clk(clk), .baud_edge(baud_edge), .tx(tx), .data(data_in), .latch_data(write_trig), .busy(tx_busy));

   wire                    rx_available = 1;
   reg [7:0]              rx_data = "A";
   // UartRx     U3(.clk(clk), .rx(rx), .data(rx_data), .baud(baud), .available(rx_available));


   always @(posedge clk) begin
      data_out <= 0;

      if (reading && (addr==2'b00)) begin
         // status
         data_out <= { 6'b0, rx_available, tx_busy };
      end

      if (reading && rx_available && (addr==2'b01)) begin
         // rx data
         data_out <= rx_data;
      end
   end

endmodule

module Top(input CLK,
           // tx & rx, baud
           output PIN_23, input PIN_22, output PIN_21,
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

   assign PIN_21 = baud_edge;

   Uart U2(.clk(CLK),
           .tx(PIN_23), .rx(PIN_22),
           .baud_edge(baud_edge),
           .addr(addr),
           .rw(PIN_16), .ncs(PIN_17), .nrst(PIN_18),
           .data(data_bus));

endmodule
