
module RisingEdgeTrig(input clk, output reg out, input in);

   reg             prev_in = 1;

   always @(posedge clk) begin
      if(in != prev_in && in == 1) begin
         // input rising edge
         out <= 1;
      end
      else begin
         out <= 0;
      end

      prev_in <= in;
   end

endmodule

module FallingEdgeTrig(input clk, output reg out, input in);

   reg             prev_in = 1;

   always @(posedge clk) begin
      if(in != prev_in && in == 0) begin
         // input falling edge
         out <= 1;
      end
      else begin
         out <= 0;
      end

      prev_in <= in;
   end

endmodule
