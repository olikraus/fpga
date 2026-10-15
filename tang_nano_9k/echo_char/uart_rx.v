/*
  Repository-standard 8N1 UART receiver (from echo_hex)
  * with input synchronizer flip-flops (rx_sync1, rx_sync2)
  * corrected output reg VALID
*/

module uart_rx(  
                input wire CLK,
                input wire RX,
                output reg VALID,
                output reg [7:0] DATA
                );

  parameter   BIT_RATE        = 9600; 
  parameter   CLK_HZ          = 27_000_000;
  
  localparam       CLK_PER_BIT     = CLK_HZ / BIT_RATE;
  localparam       CLK_COUNTER_LEN = $clog2(CLK_PER_BIT/2+1);

  // Input synchronizer to prevent metastability
  reg rx_sync1, rx_sync2;
  always @(posedge CLK) begin
    rx_sync1 <= RX;
    rx_sync2 <= rx_sync1;
  end

  reg [CLK_COUNTER_LEN-1:0] clk_counter;
  reg [4:0] bit_counter;
  reg cnt_enable;

  initial begin
    rx_sync1 = 1;
    rx_sync2 = 1;
    clk_counter = 0;
    bit_counter = 0;
    cnt_enable = 0;
    DATA = 0;
    VALID = 0;
  end

  always @(posedge CLK) begin
    if ( cnt_enable == 0 ) 
      begin
        if ( rx_sync2 == 1 ) 
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
            0: if ( rx_sync2 == 1 )                     // start detected... 
                cnt_enable <= 0;                     // , but start bit went back to idle, so stop everything 
            1: begin end
            2: DATA[0] <= rx_sync2;
            3: begin end
            4: DATA[1] <= rx_sync2;
            5: begin end
            6: DATA[2] <= rx_sync2;
            7: begin end
            8: DATA[3] <= rx_sync2;
            9: begin end
            10: DATA[4] <= rx_sync2;
            11: begin end
            12: DATA[5] <= rx_sync2;
            13: begin end
            14: DATA[6] <= rx_sync2;
            15: begin end
            16: DATA[7] <= rx_sync2;
            17: begin end
            18: if ( rx_sync2 == 0 )         // sample stop bit sample
                cnt_enable <= 0;        // stop bit invalid, so stop all the counting and do a reset
            19: begin end
            default: cnt_enable <= 0;   // reset counter 
          endcase
          clk_counter <= 0;
          bit_counter <= bit_counter + 1;
        end
  end

  always @(posedge CLK) begin
    if ( bit_counter == 19 && clk_counter == 0 )
      VALID <= 1;
    else 
      VALID <= 0;
  end

endmodule
