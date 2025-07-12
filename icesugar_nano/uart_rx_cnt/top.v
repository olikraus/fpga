/*

  top.v
  
  picocom /dev/ttyACM0 --baud 9600 --imap lfcrlf
  
  assumes 12 MHz clock

*/


`include "uart_rx_cnt.v"

module top (
    input CLK,  // global system clock 
    output LED,         // LED
    output TX, 
    input RX
    );

    wire rx_valid;
    wire [7:0] rx_data;
    
    assign LED = rx_data[1];
    assign TX = rx_valid;               // doesn't make sense yet, just for debug

    uart_rx
      #(
        .BIT_RATE(9600),
        .CLK_HZ (12_000_000),
      )
      i_uart_rx (
        .CLK(CLK),                              // Top level system clock input.
        .RX(RX),                  // UART Recieve pin.
        .VALID(rx_valid), // Valid data recieved and available.
        .DATA(rx_data),   // The recieved data.
      );

    
endmodule
    
    