module Fifo #(parameter N_SLOTS = 8)
   (input        clk,
    input        write_trig,
    input        read_active,
    input        reset,
    input [7:0]  in,
    output [7:0] out,
    output       full,
    output       empty);

   localparam SLOT_BITS = $clog2(N_SLOTS);

   reg [7:0]                       memory [(N_SLOTS-1):0];

   reg [(SLOT_BITS-1):0] wp;
   reg [(SLOT_BITS-1):0] rp;

   reg [7:0]           out;

   assign empty = wp==rp;
   assign full = (wp+SLOT_BITS'b1)==rp;

   reg                 read_active_prev;
   wire                read_trig = read_active && !read_active_prev;

   always @(posedge clk) begin
      read_active_prev <= read_active;

      if(reset) begin
         rp <= 0;
         wp <= 0;
         out <= 0;
      end else begin
        if(read_trig && !empty) begin
            out <= memory[rp];
            rp <= rp+1;
        end

        if(write_trig) begin
            memory[wp] <= in;
            wp <= wp+1;

            // increment read ptr (dropping the oldest value)
            // this is actually fine in combination with the read condition above.
            // it only means that we actually read and return that value too.
            if(full) begin
                rp <= rp+1;
            end
        end

         // end of read
         if(!read_active && read_active_prev) out <= 0;
      end
   end
endmodule

// module TestFifo(input       clk,
//                 input       phi2,
//                 input       nwe,
//                 input       ncs,
//                 input [1:0] addr,
//                 inout [7:0] data);

//    reg [7:0] data_oe = 0;
//    reg [7:0] data_out;
//    wire [7:0] data_in;

//    SB_IO #(
//        .PIN_TYPE(6'b 1010_01), // PIN_OUTPUT_TRISTATE - PIN_INPUT
//        .PULLUP(1'b 0)
//    ) iobuf_mybuf [7:0] (
//        .PACKAGE_PIN(data),
//        .OUTPUT_ENABLE(data_oe),
//        .D_OUT_0(data_out),
//        .D_IN_0(data_in)
//    );

//    // set output enabled
//    always @(posedge clk) begin
//       if(!ncs && nwe)
//         data_oe <= ~0; // all ones
//       else
//         data_oe <= 0;
//    end

//    reg write_trig;
//    reg read_active;

//    wire [7:0] fifo_out;

//    Fifo Utx_fifo(.clk(clk),
//                  .write_trig(write_trig),
//                  .read_active(read_active),
//                  .reset(0),
//                  .in(data_in),
//                  .out(fifo_out));

//    reg phi2_prev;

//    always @(posedge clk) begin
//       phi2_prev <= phi2;

//       write_trig <= 0;
//       read_active <= 0;
//       data_out <= 0;

//       if(!ncs && !nwe && phi2 && !phi2_prev)
//         write_trig <= 1;

//       if(!ncs && nwe && phi2) begin
//          data_out <= fifo_out;
//          read_active <= 1;
//       end
//    end

// endmodule
