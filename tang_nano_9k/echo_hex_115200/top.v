/*
  top.v for Tang Nano 9K
  Directly taken over from icesugar_nano/echo_hex/top.v
  
  Baud rate: 115200
  Clock: 27 MHz
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


module top (
    input CLK,  // global system clock 
    output [7:0] LED,   // 8 LEDs for Tang Nano 9K
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
    
  wire txfsm_i_start;
  wire txfsm_o_is_busy;
  wire txfsm_o_tx_enable;
  
  /*======================================================*/
  /*
    txhexfsm

    write a byte value from txhexfsm_data via UART.
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

  /* txhexfsm wires */
  reg [2:0] txhexfsm_state;
  wire [7:0] txhexfsm_data;
  wire txhexfsm_start;
  wire txhexfsm_o_is_busy;
  wire [7:0] txhexfsm_o_tx_data;        // output
  wire txhexfsm_o_txfsm_i_start;

  /* initial conditions */
  initial begin
    txhexfsm_state = TXHEXFSM_IDLE;
    txhexfsm_start = 0;     // input for txhexfsm
    txhexfsm_o_is_busy = 0;  // output from txhexfsm
    txhexfsm_o_tx_data = 0;
    txhexfsm_o_txfsm_i_start = 0;
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

      TXHEXFSM_HI_START2: begin                   // trigger txfsm_i_start
          if ( txfsm_o_is_busy == 0)
            txhexfsm_state <= TXHEXFSM_HI_START2;
          else
            txhexfsm_state <= TXHEXFSM_HI_WAIT;
      end
        
      TXHEXFSM_HI_WAIT: begin
          if ( txfsm_o_is_busy == 1 )
            txhexfsm_state <= TXHEXFSM_HI_WAIT;
          else
            txhexfsm_state <= TXHEXFSM_LO_START1;
      end

      TXHEXFSM_LO_START1: begin
          txhexfsm_state <= TXHEXFSM_LO_START2;
      end

      TXHEXFSM_LO_START2: begin
          if ( txfsm_o_is_busy == 0 )
            txhexfsm_state <= TXHEXFSM_LO_START2;
          else
            txhexfsm_state <= TXHEXFSM_LO_WAIT;
      end
        
      TXHEXFSM_LO_WAIT: begin
          if ( txfsm_o_is_busy == 1 )
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
        hex_4_bit_data[3:0] = 0;
        txhexfsm_o_tx_data =  0;
        txhexfsm_o_txfsm_i_start = 0;
        txhexfsm_o_is_busy = 0;
      end

      TXHEXFSM_HI_START1: begin
        hex_4_bit_data[3:0] = txhexfsm_data[7:4];
        txhexfsm_o_tx_data =  hex_char;
        txhexfsm_o_txfsm_i_start = 0;
        txhexfsm_o_is_busy = 1;
      end

      TXHEXFSM_HI_START2: begin
        hex_4_bit_data[3:0] = txhexfsm_data[7:4];
        txhexfsm_o_tx_data =  hex_char;
        txhexfsm_o_txfsm_i_start = 1;
        txhexfsm_o_is_busy = 1;
      end
        
      TXHEXFSM_HI_WAIT: begin
        hex_4_bit_data[3:0] = txhexfsm_data[7:4];
        txhexfsm_o_tx_data =  hex_char;
        txhexfsm_o_txfsm_i_start = 0;
        txhexfsm_o_is_busy = 1;
      end
        
      TXHEXFSM_LO_START1: begin
        hex_4_bit_data[3:0] = txhexfsm_data[3:0];
        txhexfsm_o_tx_data =  hex_char;
        txhexfsm_o_txfsm_i_start = 0;
        txhexfsm_o_is_busy = 1;
      end
      
      TXHEXFSM_LO_START2: begin
        hex_4_bit_data[3:0] = txhexfsm_data[3:0];
        txhexfsm_o_tx_data =  hex_char;
        txhexfsm_o_txfsm_i_start = 1;
        txhexfsm_o_is_busy = 1;
      end
        
      TXHEXFSM_LO_WAIT: begin
        hex_4_bit_data[3:0] = txhexfsm_data[3:0];
        txhexfsm_o_tx_data =  hex_char;
        txhexfsm_o_txfsm_i_start = 0;
        txhexfsm_o_is_busy = 1;
      end
        
      default: begin
        hex_4_bit_data[3:0] = 0;
        txhexfsm_o_tx_data =  0;
        txhexfsm_o_txfsm_i_start = 0;
        txhexfsm_o_is_busy = 1;
      end
    endcase
  end



  /*======================================================*/

  localparam [3:0]
    TOPFSM_IDLE = 0,
    TOPFSM_OUT_CHAR_START = 1,
    TOPFSM_OUT_CHAR_WAIT = 2,
    TOPFSM_OUT_HEX_START = 3,
    TOPFSM_OUT_HEX_WAIT = 4;
    
  reg [3:0] topfsm_state;
  wire topfsm_o_txfsm_i_start;
  wire [7:0] topfsm_o_tx_data;

  initial begin
    topfsm_state = TOPFSM_IDLE;
    topfsm_o_txfsm_i_start = 0;
    topfsm_o_tx_data = 0;
  end

  always @(posedge CLK) begin
    case (topfsm_state)
      TOPFSM_IDLE: begin
        if ( rx_valid == 0 )
          topfsm_state <= TOPFSM_IDLE;
        else begin
          if ( rx_data == 13 )
            topfsm_state <= TOPFSM_OUT_CHAR_START;
          else
            topfsm_state <= TOPFSM_OUT_HEX_START;
        end
      end

      TOPFSM_OUT_CHAR_START: begin                   // trigger txfsm_i_start
          if ( txfsm_o_is_busy == 0 )
            topfsm_state <= TOPFSM_OUT_CHAR_START;
          else
            topfsm_state <= TOPFSM_OUT_CHAR_WAIT;
      end
        
      TOPFSM_OUT_CHAR_WAIT: begin
          if ( txfsm_o_is_busy == 1 )
            topfsm_state <= TOPFSM_OUT_CHAR_WAIT;
          else
            topfsm_state <= TOPFSM_IDLE;
      end

      TOPFSM_OUT_HEX_START: begin                   // trigger txfsm_i_start
          if ( txhexfsm_o_is_busy == 0 )
            topfsm_state <= TOPFSM_OUT_HEX_START;
          else
            topfsm_state <= TOPFSM_OUT_HEX_WAIT;
      end
        
      TOPFSM_OUT_HEX_WAIT: begin
          if ( txhexfsm_o_is_busy == 1 )
            topfsm_state <= TOPFSM_OUT_HEX_WAIT;
          else
            topfsm_state <= TOPFSM_IDLE;
      end

      default: begin
        topfsm_state <= TOPFSM_IDLE;
      end
    endcase
  end

  always @(*) begin
    case (topfsm_state)
      TOPFSM_IDLE: begin
        txhexfsm_data = 0;
        txhexfsm_start = 0;
        topfsm_o_txfsm_i_start = 0;
        topfsm_o_tx_data = 0;
      end
      
      TOPFSM_OUT_CHAR_START: begin
        txhexfsm_data = 0;
        txhexfsm_start = 0;
        topfsm_o_txfsm_i_start = 1;
        topfsm_o_tx_data = rx_data;
      end
        
      TOPFSM_OUT_CHAR_WAIT: begin
        txhexfsm_data = 0;
        txhexfsm_start = 0;
        topfsm_o_txfsm_i_start = 0;
        topfsm_o_tx_data = rx_data;
      end

      TOPFSM_OUT_HEX_START: begin
        txhexfsm_data = rx_data;
        txhexfsm_start = 1;
        topfsm_o_txfsm_i_start = 0;
        topfsm_o_tx_data = 0;
      end
        
      TOPFSM_OUT_HEX_WAIT: begin
        txhexfsm_data = rx_data;
        txhexfsm_start = 0;
        topfsm_o_txfsm_i_start = 0;
        topfsm_o_tx_data = 0;
      end
                
      default: begin
        txhexfsm_data = 0;
        txhexfsm_start = 0;
        topfsm_o_txfsm_i_start = 0;
        topfsm_o_tx_data = 0;
      end
    endcase
  end


  // LED mapping for Tang Nano 9K (active low for LEDs 0-5, or direct rx_data mapping)
  assign LED[0] = ~rx_data[0];
  assign LED[1] = ~rx_data[1];
  assign LED[2] = ~rx_data[2];
  assign LED[3] = ~rx_data[3];
  assign LED[4] = ~rx_data[4];
  assign LED[5] = ~rx_data[5];
  assign LED[6] = rx_data[6];
  assign LED[7] = rx_data[7];

  /*======================================================*/
  

  /*
    txfsm
      state machine, which sends one byte via uart.
      this is a wrapper fsm to wait for the transmission
  */  
  /* txfsm state values */
  localparam [1:0]
    TXFSM_IDLE = 0,
    TXFSM_START = 1,            // assign value to tx_data
    TXFSM_WAIT_FOR_BUSY = 2,
    TXFSM_WAIT_FOR_NOT_BUSY = 3;

  /* txfsm wires */
  reg [1:0] txfsm_state;
  wire txfsm_i_start;
  wire txfsm_o_is_busy;
  wire txfsm_o_tx_enable;

  /* initial conditions */
  initial begin
    txfsm_state = TXFSM_IDLE;
    txfsm_o_is_busy = 0;
    txfsm_o_tx_enable = 0;
  end
  
  /* next state calculation */
  always @(posedge CLK) begin
    case (txfsm_state)
      TXFSM_IDLE: begin
        if ( txfsm_i_start == 1 ) 
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
        txfsm_o_tx_enable = 0;
        txfsm_o_is_busy = 0;
      end
      TXFSM_START: begin
        txfsm_o_tx_enable = 1;
        txfsm_o_is_busy = 1;
      end
      TXFSM_WAIT_FOR_BUSY: begin
        txfsm_o_tx_enable = 1;
        txfsm_o_is_busy = 1;
      end
      TXFSM_WAIT_FOR_NOT_BUSY: begin
        txfsm_o_tx_enable = 0;
        txfsm_o_is_busy = 1;
      end
      default: begin
        txfsm_o_tx_enable = 0;
        txfsm_o_is_busy = 1;
      end
    endcase
  end


  /*======================================================*/

  nibble_to_ascii i_nibble_to_ascii(
      .in(hex_4_bit_data),
      .out(hex_char)
    );

  uart_rx
    #(
      .BIT_RATE(115200),
      .CLK_HZ (27_000_000)
    )
    i_uart_rx (
      .CLK(CLK),                              // Top level system clock input.
      .RX(RX),                  // UART Recieve pin.
      .VALID(rx_valid), // Valid data recieved and available.
      .DATA(rx_data)    // The recieved data.
    );
    
  assign txfsm_i_start = txhexfsm_o_txfsm_i_start | topfsm_o_txfsm_i_start;
  assign tx_enable = txfsm_o_tx_enable;
  assign tx_data[7:0] = txhexfsm_o_tx_data[7:0] | topfsm_o_tx_data[7:0];

  uart_tx 
    #(
      .BIT_RATE(115200),
      .CLK_HZ (27_000_000)
    ) 
    i_uart_tx(
      .CLK(CLK),                            // Input: Clock pin with CLK_HZ freq
      .TX(TX),                    // Output: UART transmit pin
      .START(tx_enable),             // Input: HI pulse to start the transfer 
      .BUSY(tx_busy),           // Output to indicate transmission
      .DATA(tx_data)            //  8 data bits input for transmission
    );
    
endmodule
