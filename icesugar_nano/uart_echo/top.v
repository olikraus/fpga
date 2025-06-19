/*

  top.v
  
  picocom /dev/ttyACM0 --baud 9600 --imap lfcrlf
  
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

    //reg [7:0] data_reg = 8'b0;
    wire [7:0] tx_data;
    
    wire rx_break;
    wire rx_valid;
    wire [7:0] rx_data;
    
    wire tx_enable;
    wire tx_busy;

   reg [25:0] counter;

   //assign LED = counter[23];
   //assign LED = ~counter[21];

   initial begin
      counter = 0;
   end

   always @(posedge CLK)
   begin
      counter <= counter + 1;
   end

    /*
    reg [2:0] fsm_state;

    localparam FSM_WAIT_RX = 0;
    localparam FSM_DO_TX = 1;
    localparam FSM_WAIT_TX = 2;



    initial begin
        fsm_state = FSM_WAIT_RX;
    end
    
    always @(posedge clk) begin
          case (fsm_state)
              FSM_WAIT_RX: 
                  if ( rx_valid == 1) begin
                      fsm_state <= FSM_DO_TX;
                      data_reg <= rx_data;
                  end
                  else begin
                      fsm_state <= FSM_WAIT_RX;
                  end
              FSM_DO_TX: 
                  if ( tx_busy == 1) begin
                      fsm_state <= FSM_WAIT_TX;
                  end
                  else begin
                      fsm_state <= FSM_DO_TX;
                  end
              FSM_WAIT_TX: 
                  if ( tx_busy == 0) begin
                      fsm_state <= FSM_WAIT_RX;
                  end
                  else begin
                      fsm_state <= FSM_WAIT_TX;
                  end
              
          endcase
    end
    
    always @(*) begin
        case (fsm_state)
            FSM_WAIT_RX: begin 
              tx_enable = 0;
            end
            FSM_DO_TX: begin 
              tx_enable = 1;
            end
            FSM_WAIT_TX: begin 
              tx_enable = 1;
            end
            default:  begin 
              tx_enable = 0;
            end
        endcase
    end    
    */

  assign tx_data = rx_data[7:0];
  assign tx_enable   = rx_valid;
  assign LED = rx_data[1];


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
        .uart_rx_break(rx_break), // Did we get a BREAK message?
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
    
    