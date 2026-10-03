/*
  top.v
  Command-based terminal for IceSugar Nano
  - Echoes all characters
  - Command "w AB\r": writes 0xAB to an 8-bit register
  - Command "r\r": reads the register and prints its value as two hex chars + CR
  
  Clock: 12 MHz
  Baud: 9600
*/

`include "uart_tx.v"
`include "uart_rx.v"

module nibble_to_ascii(
    input wire [3:0] in, 
    output reg [7:0] out
);
    always @(*) begin
        case (in)
            4'h0: out = "0";
            4'h1: out = "1";
            4'h2: out = "2";
            4'h3: out = "3";
            4'h4: out = "4";
            4'h5: out = "5";
            4'h6: out = "6";
            4'h7: out = "7";
            4'h8: out = "8";
            4'h9: out = "9";
            4'hA: out = "A";
            4'hB: out = "B";
            4'hC: out = "C";
            4'hD: out = "D";
            4'hE: out = "E";
            4'hF: out = "F";
            default: out = "0";
        endcase
    end
endmodule

module top (
    input CLK,
    output LED,
    output TX, 
    input RX,
    output PMOD1, output PMOD2, output PMOD3, output PMOD4,
    output PMOD5, output PMOD6, output PMOD7, output PMOD8
);
    // UART signals
    wire rx_valid;
    wire [7:0] rx_data;
    reg [7:0] tx_data;
    reg tx_start;
    wire tx_busy;

    // PMOD LEDs connected to rx_data for debug
    assign PMOD2 = rx_data[0];
    assign PMOD4 = rx_data[1];
    assign PMOD6 = rx_data[2];
    assign PMOD8 = rx_data[3];
    assign PMOD1 = rx_data[4];
    assign PMOD3 = rx_data[5];
    assign PMOD5 = rx_data[6];
    assign PMOD7 = rx_data[7];

    // Application register
    reg [7:0] reg8 = 8'h00;
    reg [7:0] temp_val;

    // Parser State
    reg [2:0] p_state = 0;
    localparam P_IDLE = 0,
               P_W_S  = 1,
               P_W_H1 = 2,
               P_W_H2 = 3,
               P_W_CR = 4,
               P_R_CR = 5;

    reg trigger_resp = 0;
    
    // Echo Buffer
    reg [7:0] echo_buf;
    reg echo_pending = 0;

    // Response Buffer
    reg [7:0] resp_buf [0:2];
    reg [1:0] resp_idx = 0;
    reg [1:0] resp_count = 0;
    reg resp_active = 0;

    wire [7:0] hex_char_h1, hex_char_h2;
    nibble_to_ascii n2a_h1 (.in(reg8[7:4]), .out(hex_char_h1));
    nibble_to_ascii n2a_h2 (.in(reg8[3:0]), .out(hex_char_h2));

    // Combined Control FSM
    reg [1:0] tx_state = 0;
    localparam ST_IDLE = 0, ST_START = 1, ST_WAIT = 2;

    always @(posedge CLK) begin
        // Parser Logic
        if (rx_valid) begin
            echo_buf <= rx_data;
            echo_pending <= 1;

            case (p_state)
                P_IDLE: begin
                    if (rx_data == "w") p_state <= P_W_S;
                    else if (rx_data == "r") p_state <= P_R_CR;
                end
                P_W_S: begin
                    if (rx_data == " ") p_state <= P_W_H1;
                    else p_state <= P_IDLE;
                end
                P_W_H1: begin
                    if ((rx_data >= "0" && rx_data <= "9") || (rx_data >= "A" && rx_data <= "F") || (rx_data >= "a" && rx_data <= "f")) begin
                        temp_val[7:4] <= (rx_data >= "a") ? (rx_data - "a" + 10) : (rx_data >= "A" ? rx_data - "A" + 10 : rx_data - "0");
                        p_state <= P_W_H2;
                    end else p_state <= P_IDLE;
                end
                P_W_H2: begin
                    if ((rx_data >= "0" && rx_data <= "9") || (rx_data >= "A" && rx_data <= "F") || (rx_data >= "a" && rx_data <= "f")) begin
                        temp_val[3:0] <= (rx_data >= "a") ? (rx_data - "a" + 10) : (rx_data >= "A" ? rx_data - "A" + 10 : rx_data - "0");
                        p_state <= P_W_CR;
                    end else p_state <= P_IDLE;
                end
                P_W_CR: begin
                    if (rx_data == 8'h0D) reg8 <= temp_val;
                    p_state <= P_IDLE;
                end
                P_R_CR: begin
                    if (rx_data == 8'h0D) trigger_resp <= 1;
                    p_state <= P_IDLE;
                end
                default: p_state <= P_IDLE;
            endcase
        end

        // TX State Machine
        case (tx_state)
            ST_IDLE: begin
                tx_start <= 0;
                if (echo_pending) begin
                    tx_data <= echo_buf;
                    tx_start <= 1;
                    echo_pending <= 0;
                    tx_state <= ST_START;
                end else if (trigger_resp && !resp_active) begin
                    resp_buf[0] <= hex_char_h1;
                    resp_buf[1] <= hex_char_h2;
                    resp_buf[2] <= 8'h0D;
                    resp_count <= 3;
                    resp_idx <= 0;
                    resp_active <= 1;
                    trigger_resp <= 0;
                end else if (resp_active) begin
                    if (resp_idx < resp_count) begin
                        tx_data <= resp_buf[resp_idx];
                        tx_start <= 1;
                        resp_idx <= resp_idx + 1;
                        tx_state <= ST_START;
                    end else begin
                        resp_active <= 0;
                    end
                end
            end

            ST_START: begin
                if (tx_busy) begin
                    tx_start <= 0;
                    tx_state <= ST_WAIT;
                end
            end

            ST_WAIT: begin
                if (!tx_busy) tx_state <= ST_IDLE;
            end

            default: tx_state <= ST_IDLE;
        endcase
    end

    // LED reflects bit 0 of the register
    assign LED = reg8[0];

    // UART Modules
    uart_rx #(
        .BIT_RATE(9600),
        .CLK_HZ(12000000)
    ) i_uart_rx (
        .CLK(CLK),
        .RX(RX),
        .VALID(rx_valid),
        .DATA(rx_data)
    );

    uart_tx #(
        .BIT_RATE(9600),
        .CLK_HZ(12000000)
    ) i_uart_tx (
        .CLK(CLK),
        .TX(TX),
        .BUSY(tx_busy),
        .START(tx_start),
        .DATA(tx_data)
    );

endmodule
