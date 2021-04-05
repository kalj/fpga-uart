`default_nettype none

module BaudGen(input clk, input nreset, output baud);

   // define a 24-bit counter to divide the clock down from 12MHz
   localparam WIDTH = 24;
   localparam DIVISOR = 1667; // -> 9600 Hz
   reg [WIDTH-1:0] counter;

   // run counter from 12MHz clock
   always @(posedge clk)
     begin
        counter <= counter + 1;
        if (!nreset || (counter >= (DIVISOR-1))) counter <= 0;
     end

   assign baud = counter==0;

endmodule

module Uart(input clk, output tx, input [7:0] data, input trig, output baud, output busy);

   wire baud_nreset = !trig;

   BaudGen U1(.clk(clk), .nreset(baud_nreset), .baud(baud));

   localparam REGWIDTH = 12;

   reg [3:0] busy_counter = 0;

   reg [(REGWIDTH-1):0] temp;

   always @(posedge clk) begin

      if(trig && !busy) begin
         busy_counter <= REGWIDTH;
         temp <= { 2'b11, data, 2'b01};
      end
      else if(baud) begin
         temp <= { 1'b1, temp[(REGWIDTH-1):1] };
         busy_counter <= (busy_counter>0)?(busy_counter-1): 0;
      end
   end

   assign busy = busy_counter != 0;
   assign tx = temp[0];

endmodule

module Debounce(input clk, output reg out, input button);

   localparam WIDTH = 20; // 2**20 / 12e6 s ~= 87ms

   reg [WIDTH-1:0] counter     = 0;
   reg             prev_button = 1;

   always @(posedge clk) begin
      if(button != prev_button && (counter == 0)) begin
         // button toggled and counter has reached 0
         counter <= ~0;
         if(!button) out <= 1; // button was actually depressed
         else out <= 0;

      end
      else begin

         counter <= (counter==0) ? 0 : (counter - 1); // decrement counter
         out <= 0;
      end

      prev_button <= button;
   end

endmodule

module Top(input CLK, output LED, output PIN_17, output PIN_16, input PIN_15,
           input PIN_6, input PIN_7, input PIN_8, input PIN_9,
           input PIN_10, input PIN_11, input PIN_12, input PIN_13);

   wire [7:0]    data = {PIN_6, PIN_7, PIN_8, PIN_9, PIN_10, PIN_11, PIN_12, PIN_13};
   wire          button = PIN_15;
   wire          btrig;
   wire          baud;
   wire          busy;
   wire          tx;

   Debounce U1(.clk(CLK), .out(btrig), .button(button));
   Uart     U3(.clk(CLK), .tx(tx), .data(data), .trig(btrig), .baud(baud), .busy(busy));

   assign LED = busy;
   assign PIN_16 = busy;
   assign PIN_17 = tx;

endmodule
