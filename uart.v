`default_nettype none

module single_port_sync_ram
  ( 	input 		clk,
        input [1:0] addr,
        inout [3:0] data,
        input       we,
        input       oe
        );

   reg [3:0]        tmp_data;
   reg [3:0]        mem [4];

   initial begin
      mem[0] = 'h1;
      mem[1] = 'h2;
      mem[2] = 'h3;
      mem[3] = 'h4;
   end

   always @ (posedge clk) begin
      if (!oe & we)
        mem[addr] <= data;
   end

   always @ (posedge clk) begin
      if (oe & !we)
        tmp_data <= mem[addr];
   end

   assign data = (oe & !we) ? tmp_data : 4'bz;
endmodule

module Top(input CLK,
           // addr0, addr1, we, oe
           input PIN_14, input PIN_15, input PIN_16, input PIN_17,
           // data bus
           inout PIN_10, inout PIN_11, inout PIN_12, inout PIN_13);

   wire [3:0]    data_bus = {PIN_13, PIN_12, PIN_11, PIN_10};
   wire [1:0]    addr = {PIN_15, PIN_14};
   single_port_sync_ram  U1(.clk(CLK), .addr(addr), .data(data_bus), .we(PIN_16), .oe(PIN_17));

endmodule
