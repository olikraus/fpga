/*

  Implement a simple 8N1 uart transmitter
  
  * baud rate as parameter
  * BUSY will be high during transmit
  * START will be checked only if BUSY is low
  * START has to be high for at least (or exactly) one CLK cycle 

*/

module uart_tx(  
                input wire CLK,
                output wire TX,
                output wire BUSY,
                input wire START,
                input wire [7:0] DATA
                );

  // input bit rate of the UART line.
  parameter   BIT_RATE        = 9600;                           // bits per second

  // clock frequency in hertz.
  parameter   CLK_HZ          =    12_000_000;

  // Number of clock cycles per uart bit.
  localparam CLK_PER_BIT     = CLK_HZ / BIT_RATE;

  // size of the baud rate counter, we need enough bits to represent the number CLK_PER_BIT
  localparam CLK_COUNTER_BIT_SIZE = $clog2(CLK_PER_BIT+1);

  // the clock counter will define the size of the each bit
  reg [CLK_COUNTER_BIT_SIZE-1:0] clk_counter;

  // the bit counter will count half bits, including start and stop bit
  // sampling will happen if the lowest bit of the bit counter is 1
  // values are:
  //      0     start bit (signal level low)
  //      1..8    data bits
  //      9        stop bit (signal level high)
  reg [3:0] bit_counter;

  // cnt enable will enable both counters
  reg cnt_enable;
  
  // implement the tx line status as a flip flop output so that we always have a well defined state
  reg tx_line;

  initial begin
    clk_counter = 0;
    bit_counter = 0;
    cnt_enable = 0;
    tx_line = 1;                // this is the idle (default) state of the TX line
  end

  assign BUSY = cnt_enable;
  assign TX = tx_line;          // the output of the tx_line flip flop drives the TX line

  // increment clk and bit counter
  // once clk counter overflows, increment the bit counter
  always @(posedge CLK) begin
    if ( cnt_enable == 0 ) 
      begin
        if ( START == 0 ) 
          begin            // wait for start
            clk_counter <= 0;
            bit_counter <= 0;
            tx_line <= 1;
          end 
        else 
          begin                    // START detected
            cnt_enable <= 1;
            clk_counter <= 0;
            bit_counter <= 0;
            tx_line <= 1;
          end
      end 
    else 
      if ( clk_counter != CLK_PER_BIT )
          clk_counter <= clk_counter + 1;
      else 
        begin
          case (bit_counter)
            0: tx_line <= 0;                           // send start
            1: tx_line <= DATA[0];
            2: tx_line <= DATA[1];
            3: tx_line <= DATA[2];
            4: tx_line <= DATA[3];
            5: tx_line <= DATA[4];
            6: tx_line <= DATA[5];
            7: tx_line <= DATA[6];
            8: tx_line <= DATA[7];
            9: tx_line <= 1;                         // send stop bit
            default: cnt_enable <= 0;   // reset counter, stop transmission 
          endcase
          clk_counter <= 0;
          bit_counter <= bit_counter +1;
        end
  end
endmodule


