/*

  top.v
  
  picocom /dev/ttyACM0 --baud 9600 --imap lfcrlf
  
  assumes 12 MHz clock
  this is a test for the counter based rx module
  the incoming ascii char is displayed at the connected PMOD-LED 

*/


`include "uart_rx_cnt.v"

module top (
    input CLK,  // global system clock 
    output LED,         // LED
    output TX, 
    input RX,
    
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

  wire rx_valid;
  wire [7:0] rx_data;
  reg [7:0] my_data = 15;
  
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

  always @(posedge CLK) 
  begin
    if ( rx_valid == 1 )
      my_data <= rx_data;
  end


  assign D0 = my_data[0];
  assign D1 = my_data[1];
  assign D2 = my_data[2];
  assign D3 = my_data[3];
  assign D4 = my_data[4];
  assign D5 = my_data[5];
  assign D6 = my_data[6];
  assign D7 = my_data[7];

endmodule
    
    