/*

  top.v
  
  picocom /dev/ttyACM0 --baud 9600 --imap crcrlf
  Use ctrl-a ctrl-x to terminate picocom
  
  
  assumes 12 MHz clock

*/


`include "uart_tx.v"
`include "uart_rx.v"

module top (
    input CLK,  // global system clock 
    output LED,         // LED
    output TX, 
    input RX
  );


  reg [7:0] data_reg = 8'b0;
  
  wire tx_enable;
  wire tx_busy;
  wire [7:0] tx_data;
  
  wire rx_valid;              // output of the uart_rx block, which indicates data
  wire [7:0] rx_data;
    

   initial begin
   end

  always @(posedge clk) begin
    if ( rx_valid ) begin
      data_reg <=  rx_data[7:0];
    end
  end

  always @(*) begin
    tx_data = rx_data[7:0];     // could also use assign here
    tx_enable   = rx_valid;
  end
        
  assign LED = rx_data[0];

  uart_rx
    #(
      .BIT_RATE(9600),
      .PAYLOAD_BITS(8),
      .CLK_HZ (12_000_000),
    )
    i_uart_rx (
      .clk(CLK),                              // Top level system clock input.
      .resetn(1),                     // Asynchronous active low reset.
      .uart_rxd(RX),                  // UART Recieve pin.
      .uart_rx_en(1),                 // Recieve enable
      //.uart_rx_break(rx_break), // Did we get a BREAK message?
      .uart_rx_valid(rx_valid), // Valid data recieved and available.
      .uart_rx_data(rx_data),   // The recieved data.
    );

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
      .uart_tx_en   (tx_enable),             // Input: HI pulse to start the transfer 
      .uart_tx_busy (tx_busy),           // Output to indicate transmission
      .uart_tx_data (tx_data)            //  [PAYLOAD_BITS-1:0] 
    );
    
endmodule
    
    