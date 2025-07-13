/*

  Implement a simple 8N1 uart
 
  * no oversampling
  * baud rate as parameter
  * self recovery
  * VALID output line will be indicate valid DATA for 1 clock cycle

*/

module uart_rx(  
                input wire CLK,
                input wire RX,
                output wire VALID,
                output reg [7:0] DATA
                );

  // Input bit rate of the UART line.
  parameter   BIT_RATE        = 9600; // bits / sec

  // Clock frequency in hertz.
  parameter   CLK_HZ          =    12_000_000;

  // Number of clock cycles per uart bit.
  localparam       CLK_PER_BIT     = CLK_HZ / BIT_RATE;

  localparam       CLK_COUNTER_LEN      = $clog2(CLK_PER_BIT/2+1);

  // the clock counter will define the size of the each bit
  reg [CLK_COUNTER_LEN-1:0] clk_counter;

  // the bit counter will count half bits, including start and stop bit
  // sampling will happen if the lowest bit of the bit counter is 1
  // values are:
  //      0..1     start bit (signal level low)
  //      2..17    data bits
  //      18..19        stop bit (signal level high)
  reg [4:0] bit_counter;


  // cnt enable will enable both counters
  reg cnt_enable;

  initial begin
    clk_counter = 0;
    bit_counter = 0;
    cnt_enable = 0;
    DATA = 0;
  end

  // increment clk and bit counter
  // once clk counter overflows, increment the bit counter
  always @(posedge CLK) begin
    if ( cnt_enable == 0 ) 
      begin
        if ( RX == 1 ) 
          begin            // line idle state
            clk_counter <= 0;
            bit_counter <= 0;
          end 
        else 
          begin                    // start condition detected
            cnt_enable <= 1;
            clk_counter <= 0;
            bit_counter <= 0;
          end
      end 
    else 
      if ( clk_counter != CLK_PER_BIT / 2 )
          clk_counter <= clk_counter + 1;
      else 
        begin
          case (bit_counter)
            0: if ( RX == 1 )                           // start detected... 
                cnt_enable <= 0;                     // , but start bit went back to idle, so stop everything 
            1: begin end
            2: DATA[0] <= RX;
            3: begin end
            4: DATA[1] <= RX;
            5: begin end
            6: DATA[2] <= RX;
            7: begin end
            8: DATA[3] <= RX;
            9: begin end
            10: DATA[4] <= RX;
            11: begin end
            12: DATA[5] <= RX;
            13: begin end
            14: DATA[6] <= RX;
            15: begin end
            16: DATA[7] <= RX;
            17: begin end
            18: if ( RX == 0 )               // sample stop bit sample
                cnt_enable <= 0;        // stop bit invalid, so stop all the counting and do a reset
            19: begin end
            default: cnt_enable <= 0;   // reset counter 
          endcase
          clk_counter <= 0;
          bit_counter <= bit_counter +1;
        end
  end


  // in case the bit counter reaches 19, then the data is valid
  always @(posedge CLK) begin
    if ( bit_counter == 19 && clk_counter == 0 )
      VALID <= 1;
    else 
      VALID <= 0;
  end

endmodule


