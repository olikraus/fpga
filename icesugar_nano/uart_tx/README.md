
# UART TX

 * Send some numbers from FPGA to the host.
 * Use `picocom /dev/ttyACM0 --baud 9600 --imap lfcrlf` to receive the data
 * `uart_tx` taken from https://github.com/ben-marshall/uart/tree/master/rtl available via MIT License

# Implementation

``` 
parameter CLK_HZ = 12000000;
parameter BIT_RATE =   9600;
parameter PAYLOAD_BITS = 8;

uart_tx #(
.BIT_RATE(BIT_RATE),
.PAYLOAD_BITS(PAYLOAD_BITS),
.CLK_HZ  (CLK_HZ )
) i_uart_tx(
.clk          (clk),                            // Input: Clock pin with CLK_HZ freq
.resetn       (1),                              // Input
.uart_txd     (uart_txd),                    // Output: UART transmit pin
.uart_tx_en   (uart_tx_en),             // Input: HI pulse to start the transfer 
.uart_tx_busy (uart_tx_busy),           // Output to indicate transmission
.uart_tx_data (uart_tx_data)            //  [PAYLOAD_BITS-1:0] 
);

```