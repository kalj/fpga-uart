
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
