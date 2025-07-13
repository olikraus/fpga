/*

  top.v
  
  picocom /dev/ttyACM0 --baud 9600 --imap lfcrlf
  
  assumes 12 MHz clock
  this is a test for the counter based rx module
  the incoming ascii char is displayed at the connected PMOD-LED 

*/


`include "uart_tx_cnt.v"

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

  wire tx_busy;
  reg tx_start;                // 'reg' is better for a well defined startup
  reg [7:0] tx_data;
  reg [22:0] counter;
  
  initial begin
    tx_start = 0;
    tx_data = 64;
    counter = 0;
  end
  
  assign TX = rx_valid;               // doesn't make sense yet, just for debug
  assign LED = ~counter[22];

  always @(posedge CLK)
  begin
    counter <= counter + 1;
    if ( counter == 10 )
      begin
        tx_start <= 1;
        if ( tx_data == 90 )
          tx_data <= 64;
        else
          tx_data <= tx_data + 1;        
      end
    else
      begin
        tx_start <= 0;
      end
  end

    uart_tx
      #(
        .BIT_RATE(9600),
        .CLK_HZ (12_000_000),
      )
      i_uart_tx (
        .CLK(CLK),                              // system clock
        .TX(TX),                        // UART transmit pin
        .START(tx_start),
        .BUSY(tx_busy),        // high: transmit in progress
        .DATA(tx_data),         // data, which should be sent
      );

  assign D0 = tx_data[0];
  assign D1 = tx_data[1];
  assign D2 = tx_data[2];
  assign D3 = tx_data[3];
  assign D4 = tx_data[4];
  assign D5 = tx_data[5];
  assign D6 = tx_data[6];
  assign D7 = tx_data[7];

endmodule
    
    