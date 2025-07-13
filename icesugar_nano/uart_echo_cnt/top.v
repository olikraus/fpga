/*

  top.v
  
  picocom /dev/ttyACM0 --baud 9600 --imap crcrlf
  Use ctrl-a ctrl-x to terminate picocom
  
  assumes 12 MHz clock

  a simple UART echo test for the uart rx and uart tx modules
  data received by the rx module is send back via the tx module
  the output register of the rx module is used as input register for the tx module
  the char is shown on the connected PMOD LED
  

*/


`include "uart_tx.v"
`include "uart_rx.v"

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

  wire tx_start;
  wire tx_busy;
  wire [7:0] tx_data;
  
  wire rx_valid;              // output of the uart_rx block, which indicates data
  wire [7:0] rx_data;       // data output of the rx block is a register
  
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

  assign tx_data[7:0] = rx_data[7:0]; 
  assign tx_start = tx_busy == 0 ? rx_valid : 0;                // rx_valid is high for one clock cycle, this is good enough for tx_start
  assign LED = tx_busy;

  assign D0 = tx_data[0];
  assign D1 = tx_data[1];
  assign D2 = tx_data[2];
  assign D3 = tx_data[3];
  assign D4 = tx_data[4];
  assign D5 = tx_data[5];
  assign D6 = tx_data[6];
  assign D7 = tx_data[7];

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

  uart_tx 
    #(
      .BIT_RATE(9600),
      .CLK_HZ (12_000_000)
    ) 
    i_uart_tx(
      .CLK(CLK),                            // Input: Clock pin with CLK_HZ freq
      .TX(TX),                    // Output: UART transmit pin
      .START(tx_start),             // Input: HI pulse to start the transfer 
      .BUSY(tx_busy),           // Output to indicate transmission
      .DATA(tx_data)            //  8 data bits input for transmission
    );
    
endmodule
