/*

  top.v
  
  picocom /dev/ttyACM0 --baud 9600 --imap crcrlf
  Use ctrl-a ctrl-x to terminate picocom
  
  
  assumes 12 MHz clock

*/

`include "uart_tx.v"
`include "uart_rx.v"



module nibble_to_ascii(
    input wire [3:0] in, 
    output wire [7:0] out
  );
  always @(*) begin
    case (in)
      4'b0000: out = "0";
      4'b0001: out = "1";
      4'b0010: out = "2";
      4'b0011: out = "3";
      4'b0100: out = "4";
      4'b0101: out = "5";
      4'b0110: out = "6";
      4'b0111: out = "7";
      4'b1000: out = "8";
      4'b1001: out = "9";
      4'b1010: out = "A";
      4'b1011: out = "B";
      4'b1100: out = "C";
      4'b1101: out = "D";
      4'b1110: out = "E";
      4'b1111: out = "F";
      default: out = "0"; // fallback
    endcase
  end
endmodule

/*
module parse_and_execute(
    input wire[7:0] in,
    input wire enable,
  )
  typedef enum {
    IDLE,
    ACTIVE,
    DONE 
  } state_t;
end module
*/

module top (
    input CLK,  // global system clock 
    output LED,         // LED
    output TX, 
    input RX
  );


  reg [7:0] tx_reg;  
  wire tx_enable;
  wire tx_busy;
  
  wire rx_valid;              // output of the uart_rx block, which indicates data
  wire [7:0] rx_data;
  
  reg [3:0] hex_reg;
  wire [7:0] hex_char;
    
  
  /*
  
  localparam [1:0]
    TXFSM_IDLE = 0,
    TXFSM_START = 1,            // assign value to tx_reg
    TXFSM_WAIT_FOR_BUSY = 2,
    TXFSM_WAIT_FOR_NOT_BUSY = 3;

  reg [1:0] txfsm_state;
  wire txfsm_start;
  wire txfsm_is_idle;

  initial begin
    txfsm_state = TXFSM_IDLE;
    txfsm_start = 0;     // input for txfsm
    txfsm_is_idle = 1;  // output from txfsm
  end

  always @(posedge CLK) begin
    case (txfsm_state)
      TXFSM_IDLE: begin
          tx_enable <= 0;
          txfsm_is_idle <= 1;
        end
      TXFSM_START: begin
          tx_enable <= 1;
          txfsm_is_idle <= 0;
          if ( tx_busy == 0 )
            txfsm_state <= TXFSM_WAIT_FOR_BUSY;
          else
            txfsm_state <= TXFSM_WAIT_FOR_NOT_BUSY;
        end
      TXFSM_WAIT_FOR_BUSY: begin
          tx_enable <= 1;
          txfsm_is_idle <= 0;
          if ( tx_busy == 1 )
            txfsm_state <= TXFSM_WAIT_FOR_NOT_BUSY;
        end
      TXFSM_WAIT_FOR_NOT_BUSY: begin
          tx_enable <= 0;
          txfsm_is_idle <= 0;
          if ( tx_busy == 0 )
            txfsm_state <= TXFSM_IDLE;
        end
      endcase
    end

  */

  localparam [3:0]
    IDLE = 0,
    TX_START = 1,
    TX_WAIT = 2,
    TX_HEX_HI_START1 = 3,
    TX_HEX_HI_START2 = 4,
    TX_HEX_HI_START3 = 5,
    TX_HEX_HI_WAIT = 6,
    TX_HEX_LO_START1 = 7,
    TX_HEX_LO_START2 = 8;

  reg [3:0] state;

  initial begin
    txfsm_state = IDLE;
  end

  always @(posedge CLK) begin
    case (state)
      IDLE: begin
          tx_enable <= 0;
          if ( rx_valid ) begin            
            state <= TX_HEX_HI_START1;
          end 
        end
      TX_START: begin 
            tx_reg <=  rx_data[7:0];
            tx_enable <= 1;
            state <= TX_WAIT;
          end
      TX_WAIT: begin
          tx_enable <= 0;
          if ( tx_busy == 0 )
            state <= IDLE;
        end
      TX_HEX_HI_START1: begin
          hex_reg[3:0] <= rx_data[7:4];
          state <= TX_HEX_HI_START2;
        end
      TX_HEX_HI_START2: begin 
          tx_reg <=  hex_char;
          tx_enable <= 1;
          if ( tx_busy == 0 )
            state <= TX_HEX_HI_START3;
          else
            state <= TX_HEX_HI_WAIT;
        end
      TX_HEX_HI_START3: begin
          if ( tx_busy == 1 )
            state <= TX_HEX_HI_WAIT;
        end
      TX_HEX_HI_WAIT: begin
          tx_enable <= 0;
          if ( tx_busy == 0 )
            state <= TX_HEX_LO_START1;
        end
      TX_HEX_LO_START1: begin
          hex_reg[3:0] <= rx_data[3:0];
          state <= TX_HEX_LO_START2;
        end
      TX_HEX_LO_START2: begin 
            tx_reg <=  hex_char;
            tx_enable <= 1;
            state <= TX_WAIT;
          end
      default: 
        state <= IDLE;
    endcase
  end
  
  assign LED = tx_reg[0];
  
  
  nibble_to_ascii i_nibble_to_ascii(
      .in(hex_reg),
      .out(hex_char)
    );
    
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
      .uart_tx_data (tx_reg)            //  [PAYLOAD_BITS-1:0] 
    );
    
endmodule
    
    