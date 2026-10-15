/*
  top.v for Tang Nano 9K
  Ported and cleaned up from icesugar_nano echo_hex
  
  Baud rate: 9600
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
    output reg [7:0] out
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
      default: out = "0";
    endcase
  end
endmodule

module top (
    input CLK,  // 27 MHz clock
    output [7:0] LED, // 8 LEDs
    output TX, 
    input RX
  );

  // UART components
  wire tx_busy;
  reg  tx_start;
  reg  [7:0] tx_data;
  wire rx_valid;
  wire [7:0] rx_data;

  uart_rx #(
    .BIT_RATE(9600),
    .CLK_HZ(27_000_000)
  ) i_uart_rx (
    .CLK(CLK),
    .RX(RX),
    .VALID(rx_valid),
    .DATA(rx_data)
  );

  uart_tx #(
    .BIT_RATE(9600),
    .CLK_HZ(27_000_000)
  ) i_uart_tx (
    .CLK(CLK),
    .TX(TX),
    .BUSY(tx_busy),
    .START(tx_start),
    .DATA(tx_data)
  );

  // Hex conversion
  reg [3:0] hex_in;
  wire [7:0] hex_out;
  nibble_to_ascii i_n2a (.in(hex_in), .out(hex_out));

  // Main FSM
  reg [2:0] state;
  reg [7:0] data_to_send;

  localparam IDLE         = 0,
             SEND_HEX_HI  = 1,
             WAIT_HEX_HI  = 2,
             SEND_HEX_LO  = 3,
             WAIT_HEX_LO  = 4,
             SEND_CHAR    = 5,
             WAIT_CHAR    = 6;

  initial begin
    state = IDLE;
    tx_start = 0;
    tx_data = 0;
  end

  always @(posedge CLK) begin
    case (state)
      IDLE: begin
        tx_start <= 0;
        if (rx_valid) begin
          data_to_send <= rx_data;
          if (rx_data == 13 || rx_data == 10) // CR or LF
            state <= SEND_CHAR;
          else
            state <= SEND_HEX_HI;
        end
      end

      SEND_HEX_HI: begin
        if (!tx_busy) begin
          hex_in <= data_to_send[7:4];
          state <= WAIT_HEX_HI;
        end
      end

      WAIT_HEX_HI: begin
        // Wait one cycle for hex_out to be valid from hex_in
        tx_data <= hex_out;
        tx_start <= 1;
        state <= SEND_HEX_LO;
      end

      SEND_HEX_LO: begin
        tx_start <= 0;
        if (!tx_busy) begin
          hex_in <= data_to_send[3:0];
          state <= WAIT_HEX_LO;
        end
      end

      WAIT_HEX_LO: begin
        // Wait one cycle for hex_out to be valid
        tx_data <= hex_out;
        tx_start <= 1;
        state <= WAIT_CHAR; // Reuse WAIT_CHAR to return to IDLE
      end

      SEND_CHAR: begin
        if (!tx_busy) begin
          tx_data <= data_to_send;
          tx_start <= 1;
          state <= WAIT_CHAR;
        end
      end

      WAIT_CHAR: begin
        tx_start <= 0;
        if (!tx_busy) begin
          state <= IDLE;
        end
      end

      default: state <= IDLE;
    endcase
  end

  // LED Mapping (active-low for onboard LEDs 0-5)
  assign LED[0] = ~rx_data[0];
  assign LED[1] = ~rx_data[1];
  assign LED[2] = ~rx_data[2];
  assign LED[3] = ~rx_data[3];
  assign LED[4] = ~rx_data[4];
  assign LED[5] = ~rx_data[5];
  assign LED[6] = rx_data[6];  // Assuming external LEDs are active-high
  assign LED[7] = rx_data[7];

endmodule
