/*

  top.v
  
  picocom /dev/ttyACM0 --baud 9600 --imap lfcrlf
  
  assumes 12 MHz clock

*/


`include "uart_tx.v"

/* baudrate: 9600 */
/* Top level module for keypad + UART demo */
module top (
    // input hardware clock (12 MHz)
    input CLK, 
    // all LEDs
    output LED,
    // UART lines
    output TX, 
    );

    /* Clock input */
    //input CLK;

    /* LED outputs */
    //output LED;

    /* FTDI I/O */
    //output TX;

    /* counter for sending another char */
    //reg clk_tx = 0;
    reg [31:0] cntr_tx_send = 32'b0;
    parameter period_tx_send = 50  * 12000;  // send a char every 50ms
  
    /* counter for updateing the char, which should be sent */
    reg clk_1 = 0;
    reg [31:0] cntr_1 = 32'b0;
    parameter period_1 = 6000000;

    // Note: could also use "0" or "9" below, but I wanted to
    // be clear about what the actual binary value is.
    parameter ASCII_0 = 8'd48;
    parameter ASCII_9 = 8'd57;

    /* UART registers */
    reg [7:0] uart_txbyte = ASCII_0;
    reg uart_send = 1'b0;
    wire uart_txed;

    /* LED register */
    reg ledval = 0;

    /* UART transmitter module designed for 8 bits, no parity, 1 stop bit.  */
    uart_tx 
      #(
        .BIT_RATE(9600),
        .PAYLOAD_BITS(8),
        .CLK_HZ (12_000_000)
      ) 
      i_uart_tx(
        .clk          (CLK),                            // Input: Clock pin with CLK_HZ freq
        .resetn       (1),                              // Input
        .uart_txd     (TX),                    // Output: UART transmit pin
        .uart_tx_en   (uart_send),             // Input: HI pulse to start the transfer 
        .uart_tx_busy (uart_txed),           // Output to indicate transmission
        .uart_tx_data (uart_txbyte)            //  [PAYLOAD_BITS-1:0] 
      );


    /* Wiring */
    assign LED=ledval;
    
    /* generate enable signal for transmit */
    always @ (posedge CLK) 
    begin
        cntr_tx_send <= cntr_tx_send + 1;
        if (cntr_tx_send == period_tx_send) 
          begin
            cntr_tx_send <= 32'b0;
            uart_send <= 1'b1;
          end
        else if (cntr_tx_send == 4 ) 
          begin
              uart_send <= 1'b0;
          end

        /* generate 1 Hz clock */
        cntr_1 <= cntr_1 + 1;
        if (cntr_1 == period_1) 
          begin
              clk_1 <= ~clk_1;
              cntr_1 <= 32'b0;
            end
    end

    /* Increment ASCII digit and blink LED */
    always @ (posedge clk_1 ) begin
        ledval <= ~ledval;
        if (uart_txbyte == ASCII_9) begin
            uart_txbyte <= ASCII_0;
        end else begin
            uart_txbyte <= uart_txbyte + 1;
        end
    end

endmodule
