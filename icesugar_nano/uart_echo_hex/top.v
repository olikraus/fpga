/*

  top.v
  
  picocom /dev/ttyACM0 --baud 9600 --imap crcrlf
  Use ctrl-a ctrl-x to terminate picocom
  
  
  assumes 12 MHz clock

*/

`include "uart_tx.v"
`include "uart_rx.v"


/*
  nibble_to_ascii
    logic block to convert a 4bit value into a 8bit ascii representation
*/
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
module txfsm(
  );
endmodule
*/







module top (
    input CLK,  // global system clock 
    output LED,         // LED
    output TX, 
    input RX
  );


  wire [7:0] tx_data;  
  wire tx_enable;
  wire tx_busy;
  
  wire rx_valid;              // output of the uart_rx block, which indicates data
  wire [7:0] rx_data;
  
  wire [3:0] hex_4_bit_data;
  wire [7:0] hex_char;
    
  /*======================================================*/
  /*
    txfsm
      state machine, which sends one byte via uart.
      this is a wrapper fsm to wait for the transmission
      
    input: 
      txfsm_start       from txfsm user
      tx_busy              connected to the uart block
    output: 
      txfsm_is_idle     to txfsm user
      txfsm_tx_enable         connected to the uart block
    
    It is responsibility of the txfsm user to assign a proper value to tx_data
    
  */  
  /* txfsm state values */
  localparam [1:0]
    TXFSM_IDLE = 0,
    TXFSM_START = 1,            // assign value to tx_data
    TXFSM_WAIT_FOR_BUSY = 2,
    TXFSM_WAIT_FOR_NOT_BUSY = 3;

  /* txfsm wires */
  reg [1:0] txfsm_state;
  wire txfsm_start;
  wire txfsm_is_idle;
  wire txfsm_tx_enable;

  /* initial conditions */
  initial begin
    txfsm_state = TXFSM_IDLE;
    txfsm_start = 0;     // input for txfsm
    txfsm_is_idle = 1;  // output from txfsm
    txfsm_tx_enable = 0; // output from txfsm, which should drive the tx_enable of tx_uart
  end
  
  /* next state calculation */
  always @(posedge CLK) begin
    case (txfsm_state)
      TXFSM_IDLE: begin
        if ( txfsm_start == 1 ) 
          txfsm_state <= TXFSM_START;
        else
          txfsm_state <= TXFSM_IDLE;
      end
      TXFSM_START: begin
        if ( tx_busy == 0 )
          txfsm_state <= TXFSM_WAIT_FOR_BUSY;
        else
          txfsm_state <= TXFSM_WAIT_FOR_NOT_BUSY;
      end
      TXFSM_WAIT_FOR_BUSY: begin
        if ( tx_busy == 1 )
          txfsm_state <= TXFSM_WAIT_FOR_NOT_BUSY;
        else
          txfsm_state <= TXFSM_WAIT_FOR_BUSY;
      end
      TXFSM_WAIT_FOR_NOT_BUSY: begin
        if ( tx_busy == 0 )
          txfsm_state <= TXFSM_IDLE;
        else
          txfsm_state <= TXFSM_WAIT_FOR_NOT_BUSY;
      end
      default: begin
          txfsm_state <= TXFSM_IDLE;
      end
    endcase
  end

  /* output calculation */
  always @(*) begin
    case (txfsm_state)
      TXFSM_IDLE: begin
        txfsm_tx_enable = 0;
        txfsm_is_idle = 1;
      end
      TXFSM_START: begin
        txfsm_tx_enable = 1;
        txfsm_is_idle = 0;
      end
      TXFSM_WAIT_FOR_BUSY: begin
        txfsm_tx_enable = 1;
        txfsm_is_idle = 0;
      end
      TXFSM_WAIT_FOR_NOT_BUSY: begin
        txfsm_tx_enable = 0;
        txfsm_is_idle = 0;
      end
      default: begin
        txfsm_tx_enable = 0;
        txfsm_is_idle = 0;
      end
    endcase
  end

  /*======================================================*/
  /*
    txhexfsm

    write a byte value from txhexfsm_data via UART.
  
    input:
      txhexfsm_data
      txhexfsm_start
    output:
      txhexfsm_is_idle
    
    connections:
      output the value from hex_char
    
  */

  /* txhexfsm state values */
  localparam [2:0]
    TXHEXFSM_IDLE = 0,
    TXHEXFSM_HI_START1 = 1,
    TXHEXFSM_HI_START2 = 2,
    TXHEXFSM_HI_WAIT = 3,
    TXHEXFSM_LO_START1 = 4,
    TXHEXFSM_LO_START2 = 5,
    TXHEXFSM_LO_WAIT = 6;

  /* txfsm wires */
  reg [2:0] txhexfsm_state;
  wire [7:0] txhexfsm_data;
  wire txhexfsm_start;
  wire txhexfsm_is_idle;
  wire [7:0] txhexfsm_tx_data;        // output

  /* initial conditions */
  initial begin
    txhexfsm_state = TXHEXFSM_IDLE;
    txhexfsm_start = 0;     // input for txhexfsm
    txhexfsm_is_idle = 1;  // output from txhexfsm
    txhexfsm_tx_data = 0;
  end

  always @(posedge CLK) begin
    case (txhexfsm_state)
      TXHEXFSM_IDLE: begin
        if ( txhexfsm_start == 0 )
          txhexfsm_state <= TXHEXFSM_IDLE;
        else
          txhexfsm_state <= TXHEXFSM_HI_START1;
      end

      TXHEXFSM_HI_START1: begin                   // delay by one cycle to set the tx_data
          txhexfsm_state <= TXHEXFSM_HI_START2;
      end

      TXHEXFSM_HI_START2: begin                   // trigger txfsm_start
          if ( txfsm_is_idle == 0 )
            txhexfsm_state <= TXHEXFSM_HI_START2;
          else
            txhexfsm_state <= TXHEXFSM_HI_WAIT;
      end
        
      TXHEXFSM_HI_WAIT: begin
          if ( txfsm_is_idle == 1 )
            txhexfsm_state <= TXHEXFSM_HI_WAIT;
          else
            txhexfsm_state <= TXHEXFSM_LO_START1;
      end

      TXHEXFSM_LO_START1: begin
          txhexfsm_state <= TXHEXFSM_LO_START2;
      end

      TXHEXFSM_LO_START2: begin
          if ( txfsm_is_idle == 0 )
            txhexfsm_state <= TXHEXFSM_LO_START2;
          else
            txhexfsm_state <= TXHEXFSM_LO_WAIT;
      end
        
      TXHEXFSM_LO_WAIT: begin
          if ( txfsm_is_idle == 1 )
            txhexfsm_state <= TXHEXFSM_LO_WAIT;
          else
            txhexfsm_state <= TXHEXFSM_IDLE;
      end
        
      default: begin
        txhexfsm_state <= TXHEXFSM_IDLE;
      end
    endcase
  end

  always @(*) begin
    case (txhexfsm_state)
      TXHEXFSM_IDLE: begin
        hex_4_bit_data[3:0] <= 0;
        txhexfsm_tx_data <=  0;
        txfsm_start <= 0;
        txhexfsm_is_idle <= 1;
      end

      TXHEXFSM_HI_START1: begin
        hex_4_bit_data[3:0] <= txhexfsm_data[7:4];
        txhexfsm_tx_data <=  hex_char;
        txfsm_start <=  0;
        txhexfsm_is_idle <= 0;
      end

      TXHEXFSM_HI_START2: begin
        hex_4_bit_data[3:0] <= txhexfsm_data[7:4];
        txhexfsm_tx_data <=  hex_char;
        txfsm_start <= 1;
        txhexfsm_is_idle <= 0;
      end
        
      TXHEXFSM_HI_WAIT: begin
        hex_4_bit_data[3:0] <= txhexfsm_data[7:4];
        txhexfsm_tx_data <=  hex_char;
        txfsm_start <= 0;
        txhexfsm_is_idle <= 0;
      end
        
      TXHEXFSM_LO_START1: begin
        hex_4_bit_data[3:0] <= txhexfsm_data[3:0];
        txhexfsm_tx_data <=  hex_char;
        txfsm_start <= 0;
        txhexfsm_is_idle <= 0;
      end
      
      TXHEXFSM_LO_START2: begin
        hex_4_bit_data[3:0] <= txhexfsm_data[3:0];
        txhexfsm_tx_data <=  hex_char;
        txfsm_start <= 1;
        txhexfsm_is_idle <= 0;
      end
        
      TXHEXFSM_LO_WAIT: begin
        hex_4_bit_data[3:0] <= txhexfsm_data[3:0];
        txhexfsm_tx_data <=  hex_char;
        txfsm_start <= 0;
        txhexfsm_is_idle <= 0;
      end
        
      default: begin
        hex_4_bit_data[3:0] <= 0;
        txhexfsm_tx_data <=  0;
        txfsm_start <= 0;
        txhexfsm_is_idle <= 0;
      end
    endcase
  end



  /*======================================================*/

  localparam [3:0]
    TOPFSM_IDLE = 0,
    TOPFSM_OUT_HEX_START = 1,
    TOPFSM_OUT_HEX_WAIT = 2;
    
  reg [3:0] state;

  initial begin
    state = TOPFSM_IDLE;
  end

  always @(posedge CLK) begin
    case (state)
      TOPFSM_IDLE: begin
        if ( rx_valid == 0 )
          state <= TOPFSM_IDLE;
        else begin
          state <= TOPFSM_OUT_HEX_START;
        end
      end
      
      

      TOPFSM_OUT_HEX_START: begin                   // trigger txfsm_start
          if ( txhexfsm_is_idle == 1 )
            state <= TOPFSM_OUT_HEX_START;
          else
            state <= TOPFSM_OUT_HEX_WAIT;
      end
        
      TOPFSM_OUT_HEX_WAIT: begin
          if ( txhexfsm_is_idle == 0 )
            state <= TOPFSM_OUT_HEX_WAIT;
          else
            state <= TOPFSM_IDLE;
      end

      default: begin
        state <= TOPFSM_IDLE;
      end
    endcase
  end

  always @(*) begin
    case (state)
      TOPFSM_IDLE: begin
        txhexfsm_data <= 0;
        txhexfsm_start <= 0;
      end

      TOPFSM_OUT_HEX_START: begin
          txhexfsm_data <= rx_data;
          txhexfsm_start <= 1;
      end
        
      TOPFSM_OUT_HEX_WAIT: begin
          txhexfsm_data <= rx_data;
          txhexfsm_start <= 0;
      end
                
      default: begin
        txhexfsm_data <= 0;
        txhexfsm_start <= 0;
      end
    endcase
  end


  assign LED = tx_data[0];
  //assign LED = txhexfsm_is_idle;
  //assign LED = txfsm_is_idle;
  
  assign tx_data = txhexfsm_tx_data;
  
  
  nibble_to_ascii i_nibble_to_ascii(
      .in(hex_4_bit_data),
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
    
    
  assign tx_enable = txfsm_tx_enable;

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
    
    