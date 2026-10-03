/*
*/

module to_hex(
    input wire [3:0] IN, 
    output wire [7:0] OUT
  );
  always @(*) begin
    case (IN)
      4'b0000: OUT = "0";
      4'b0001: OUT = "1";
      4'b0010: OUT = "2";
      4'b0011: OUT = "3";
      4'b0100: OUT = "4";
      4'b0101: OUT = "5";
      4'b0110: OUT = "6";
      4'b0111: OUT = "7";
      4'b1000: OUT = "8";
      4'b1001: OUT = "9";
      4'b1010: OUT = "A";
      4'b1011: OUT = "B";
      4'b1100: OUT = "C";
      4'b1101: OUT = "D";
      4'b1110: OUT = "E";
      4'b1111: OUT = "F";
      default: OUT = "0"; // fallback
    endcase
  end
endmodule

module uart_tx(  
                input wire CLK,
                output wire TX,
                output wire BUSY,
                input wire START,
                input wire [7:0] DATA,
                input wire IS_HEX
                );

  wire [7:0] tx_data;
  wire [7:0] hex_data; 
  wire tx_start;
  wire tx_busy;
  wire is_high;
  reg [2:0] state;

  localparam [2:0]
    IDLE = 7,
    HI_START = 0,
    HI_WAIT = 1,
    LO_START = 2,
    LO_WAIT = 3;

  initial begin
    state = IDLE;
  end

  always @(posedge CLK) 
  begin
    case (state)
      IDLE:
        if ( IS_HEX == 0 )
          if ( START == 1 )
           state <= LO_START;
          else
           state <= IDLE;
        else
          if ( START == 1 )
           state <= HI_START;
          else
           state <= IDLE;
      HI_START:
        if ( tx_busy == 0 )
          state <= HI_START;
        else
          state <= HI_WAIT;
      HI_WAIT:
        if ( tx_busy == 1 )
          state <= HI_WAIT;
        else
          state <= LO_START;
      LO_START:
        if ( tx_busy == 0 )
          state <= LO_START;
        else
          state <= LO_WAIT;
      LO_WAIT:
        if ( tx_busy == 1 )
          tx_start <= 0;
        else
          state <= IDLE;
      end
    endcase
  end // always

  always @(*) 
  begin
    case (state)
      IDLE: is_high = 0; 
      LO_START: is_high = 0; 
      LO_WAIT: is_high = 0; 
      HI_START: is_high = 1; 
      HI_WAIT: is_high = 1; 
    endcase
  end

  always @(*) 
  begin
    case (state)
      IDLE: tx_start = 0; 
      LO_START: tx_start  = 1; 
      LO_WAIT: tx_start  = 0; 
      HI_START: tx_start  = 1; 
      HI_WAIT: tx_start  = 0; 
    endcase
  end


  assign hex_4_bit_data[0] = is_high == 0 ? DATA[0] : DATA[4];
  assign hex_4_bit_data[1] = is_high == 0 ? DATA[1] : DATA[5];
  assign hex_4_bit_data[2] = is_high == 0 ? DATA[2] : DATA[6];
  assign hex_4_bit_data[3] = is_high == 0 ? DATA[3] : DATA[7];


  assign tx_data = IS_HEX == 0 ? DATA : hex_data;

  nibble_to_ascii i_nibble_to_ascii(
      .in(hex_4_bit_data),
      .out(hex_data)
    );

  uart_tx 
    i_uart_tx(
      .CLK(CLK),                            // Input: Clock pin with CLK_HZ freq
      .TX(TX),                    // Output: UART transmit pin
      .START(tx_start),             // Input: HI pulse to start the transfer 
      .BUSY(tx_busy),           // Output to indicate transmission
      .DATA(tx_data)            //  8 data bits input for transmission
    );
