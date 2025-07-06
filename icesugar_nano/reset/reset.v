/*

  reset.v
  
  test code for the synthesis behavior of yosys
  On the attached PMOD-LED
    If A is the reset state, then tun on D0
    If B is the reset state, then tun on D7
    
  
  
  Result:
    it is required to specify the default state value via
    
      reg [1:0] state = A;

  or
    
      initial begin
        state = A;
      end

  If the init state isn't prlvided, then the state machine 
  is not created.
  
  

  Yosys behavior from https://github.com/Ashwin-Rajesh
    https://fpga-systems.ru/library/logic_synthesis/exploring_logic_synthesis_with_yosys.pdf
  

*/


module top(  input CLK,
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

  localparam [1:0]
    A = 0,
    AA = 1,           
    B = 2,
    BB = 3;

  reg [1:0] state = A;

  initial begin
    //state = A;
  end


  /* next state calculation */
  always @(posedge CLK) begin
    case (state)
      A: begin
          state <= AA;
      end
      AA: begin
          state <= AA;
      end
      B: begin
          state <= BB;
      end
      BB: begin
          state <= BB;
      end
      default: begin
          state <= A;
      end
    endcase
  end

  always @(*) begin
    case (state)
      A: begin
        D0 = 1;
        D7 = 0;
      end
      AA: begin
        D0 = 1;
        D7 = 0;
      end
      B: begin
        D0 = 0;
        D7 = 1;
      end
      BB: begin
        D0 = 0;
        D7 = 1;
      end
    endcase
  end



endmodule
