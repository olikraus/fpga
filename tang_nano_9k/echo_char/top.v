/*
  top.v for Tang Nano 9K - Echo Char with Transparent Echo & Diagnostic LEDs
  LED Debug Mapping (using only connected LEDs 0-5):
    LED[0]: Stretched RX activity indicator (flashes ~0.5s when RX goes low)
    LED[1]: Stretched rx_valid indicator (flashes ~0.5s when valid byte received)
    LED[2]: ~tx_busy (ON when transmitting)
    LED[3]: ~rx_data[0] (received lowest bit: ON if 1, OFF if 0)
    LED[4]: System heartbeat (toggles every ~0.5s)
    LED[5]: OFF (1'b1)
    LED[6:7]: Unconnected / OFF (1'b1)
*/

`include "uart_tx.v"
`include "uart_rx.v"

module top (
    input CLK,          // 27 MHz global system clock 
    output [7:0] LED,   // 8 LEDs
    output TX, 
    input RX
  );

  wire rx_valid;
  wire [7:0] rx_data;
  
  wire tx_busy;
  reg tx_start;
  reg [7:0] tx_data;

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

  localparam [1:0]
    IDLE      = 0,
    START_TX  = 1,
    WAIT_BUSY = 2,
    WAIT_DONE = 3;

  reg [1:0] state;
  reg       send_char;
  reg [7:0] char_to_send;

  reg [23:0] rx_activity_stretch;
  reg [23:0] rx_valid_stretch;
  reg [25:0] heartbeat_counter;

  initial begin
    state = IDLE;
    tx_start = 0;
    tx_data = 8'h61;
    send_char = 0;
    char_to_send = 8'h61;
    rx_activity_stretch = 0;
    rx_valid_stretch = 0;
    heartbeat_counter = 0;
  end

  always @(posedge CLK) begin
    heartbeat_counter <= heartbeat_counter + 1;

    // RX activity detector (stretches ~0.5s when RX goes low)
    if (!RX) begin
      rx_activity_stretch <= 27_000_000 / 2;
    end else if (rx_activity_stretch != 0) begin
      rx_activity_stretch <= rx_activity_stretch - 1;
    end

    // rx_valid detector (~0.5s)
    if (rx_valid) begin
      rx_valid_stretch <= 27_000_000 / 2;
      send_char <= 1;
      // Echo the received character transparently
      char_to_send <= rx_data;
    end else if (rx_valid_stretch != 0) begin
      rx_valid_stretch <= rx_valid_stretch - 1;
    end

    case (state)
      IDLE: begin
        tx_start <= 0;
        if (send_char) begin
          tx_data <= char_to_send;
          send_char <= 0;
          state <= START_TX;
        end
      end

      START_TX: begin
        if (!tx_busy) begin
          tx_start <= 1;
          state <= WAIT_BUSY;
        end
      end

      WAIT_BUSY: begin
        tx_start <= 0;
        if (tx_busy) begin
          state <= WAIT_DONE;
        end
      end

      WAIT_DONE: begin
        if (!tx_busy) begin
          state <= IDLE;
        end
      end

      default: state <= IDLE;
    endcase
  end

  // LED mapping (active low: 0 = ON, 1 = OFF)
  // Using only connected LEDs 0 to 5
  assign LED[0] = (rx_activity_stretch == 0);  // Flashes ~0.5s on RX low (keypress)
  assign LED[1] = (rx_valid_stretch == 0);     // Flashes ~0.5s on rx_valid
  assign LED[2] = ~tx_busy;                    // ON when transmitting
  assign LED[3] = ~rx_data[0];                 // Received LSB (ON if 1, OFF if 0)
  assign LED[4] = ~heartbeat_counter[25];      // Heartbeat blink (~0.5s period)
  assign LED[5] = 1'b1;                        // OFF
  assign LED[6] = 1'b1;                        // OFF (unconnected)
  assign LED[7] = 1'b1;                        // OFF (unconnected)

endmodule
