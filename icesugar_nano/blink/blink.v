
module switch(  input CLK,
                output LED,
                output PMOD1,   // D4
                output PMOD2,   // D0
                output PMOD3,   // D5
                output PMOD4,   // D1
                output PMOD5,   // D6
                output PMOD6,   // D2
                output PMOD7,   // D7
                output PMOD8    // D3
                );
      
   reg [25:0] counter;
   
   wire D0;
   wire D1;
   wire D2;
   wire D3;
   wire D4;
   wire D5;
   wire D6;
   wire D7;

  assign D0 = PMOD2;
  assign D1 = PMOD4;
  assign D2 = PMOD6;
  assign D3 = PMOD8;
  assign D4 = PMOD1;
  assign D5 = PMOD3;
  assign D6 = PMOD5;
  assign D7 = PMOD7;

   assign D2 = ~counter[19];
   assign D3 = ~counter[20];
   assign D4 = ~counter[21];
   assign D5 = ~counter[22];
   assign D6 = ~counter[23];
   assign D7 = ~counter[24];
   assign LED = ~counter[23];
   //assign LED = ~counter[21];

   initial begin
      counter = 0;
   end

   always @(posedge CLK)
   begin
      counter <= counter + 1;
   end

/*
  always @(posedge clk or posedge reset) begin
      if (reset)
          counter <= 0;
      else
          counter <= counter + 1;
  end
  */

endmodule
