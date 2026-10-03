/*
  top.v
  Command-based terminal for IceSugar Nano
  - Echoes all characters
  - Command "w <hex>\r": writes up to 32-bit hex to a register (zero-padded)
  - Command "r\r": reads the 32-bit register and prints 8 hex chars + CR
  - Command "s <addr_hex>\r": stores register to EBR memory
  - Command "l <addr_hex>\r": loads EBR memory to register
  
  Memory Layout: 4 EBR blocks, 16 x 32-bit each.
  Addr Hex: [7:4] block select (0..3), [3:0] offset (0..F)
  
  Clock: 36 MHz
  Baud: 115200
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

    // Application register (32-bit)
    reg [31:0] reg32 = 32'h00000000;
    reg [31:0] temp_val;
    reg [7:0] temp_addr;

    // Embedded RAM (4 blocks of 16 x 32-bit)
    // Forced EBR mapping using synchronous read
    reg [31:0] ram [0:63]; 
    reg [31:0] ram_read_data;
    wire [5:0] ram_addr = {temp_addr[5:4], temp_addr[3:0]};

    // Synchronous Memory Logic (Required for EBR mapping)
    always @(posedge CLK) begin
        if (rx_valid && p_state == P_SL_A2 && is_store && rx_data == 8'h0D)
            ram[ram_addr] <= reg32;
        ram_read_data <= ram[ram_addr];
    end

    // PMOD LEDs connected to reg32 (lower 8 bits, inverted for active-high behavior)
    assign PMOD2 = ~reg32[0];
    assign PMOD4 = ~reg32[1];
    assign PMOD6 = ~reg32[2];
    assign PMOD8 = ~reg32[3];
    assign PMOD1 = ~reg32[4];
    assign PMOD3 = ~reg32[5];
    assign PMOD5 = ~reg32[6];
    assign PMOD7 = ~reg32[7];

    // Parser State
    reg [3:0] p_state = 0;
    localparam P_IDLE   = 0,
               P_W_S    = 1,
               P_W_HEX  = 2,
               P_R_CR   = 3,
               P_SL_S   = 4,
               P_SL_A1  = 5,
               P_SL_A2  = 6,
               P_L_WAIT = 7,
               P_E_CR   = 8;

    reg trigger_resp = 0;
    reg is_store = 0;
    reg is_load = 0;

    // Helper for hex parsing
    wire [3:0] rx_nibble = (rx_data >= "a" && rx_data <= "f") ? (rx_data - "a" + 10) :
                           (rx_data >= "A" && rx_data <= "F") ? (rx_data - "A" + 10) :
                           (rx_data - "0");
    wire rx_is_hex = (rx_data >= "0" && rx_data <= "9") || 
                     (rx_data >= "A" && rx_data <= "F") || 
                     (rx_data >= "a" && rx_data <= "f");
    
    // Echo Buffer
    reg [7:0] echo_buf;
    reg echo_pending = 0;

    // Response Buffer (8 hex chars + CR)
    reg [7:0] resp_buf [0:8];
    reg [3:0] resp_idx = 0;
    reg [3:0] resp_count = 0;
    reg resp_active = 0;

    // Hex Conversion for Response
    wire [7:0] hex_chars [0:7];
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : gen_n2a
            nibble_to_ascii n2a (
                .in(reg32[4*i +: 4]),
                .out(hex_chars[7-i]) // MSB at index 0
            );
        end
    endgenerate

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
                    else if (rx_data == "e") p_state <= P_E_CR;
                    else if (rx_data == "s") begin p_state <= P_SL_S; is_store <= 1; is_load <= 0; end
                    else if (rx_data == "l") begin p_state <= P_SL_S; is_load <= 1; is_store <= 0; end
                end
                P_W_S: begin
                    if (rx_data == " ") begin
                        p_state <= P_W_HEX;
                        temp_val <= 0;
                    end else p_state <= P_IDLE;
                end
                P_W_HEX: begin
                    if (rx_is_hex) begin
                        temp_val <= {temp_val[27:0], rx_nibble};
                    end else if (rx_data == 8'h0D) begin
                        reg32 <= temp_val;
                        p_state <= P_IDLE;
                    end else p_state <= P_IDLE;
                end
                P_R_CR: begin
                    if (rx_data == 8'h0D) trigger_resp <= 1;
                    p_state <= P_IDLE;
                end
                P_SL_S: begin
                    if (rx_data == " ") p_state <= P_SL_A1;
                    else p_state <= P_IDLE;
                end
                P_SL_A1: begin
                    if (rx_is_hex) begin
                        temp_addr[7:4] <= rx_nibble;
                        p_state <= P_SL_A2;
                    end else p_state <= P_IDLE;
                end
                P_SL_A2: begin
                    if (rx_is_hex) begin
                        temp_addr[3:0] <= rx_nibble;
                        p_state <= P_SL_A2;
                    end else if (rx_data == 8'h0D) begin
                        if (is_load) p_state <= P_L_WAIT;
                        else p_state <= P_IDLE;
                    end else p_state <= P_IDLE;
                end
                P_E_CR: begin
                    if (rx_data == 8'h0D) begin
                        reg32 <= {reg32[5:0], reg32[31:6]} ^ {reg32[10:0], reg32[31:11]} ^ {reg32[24:0], reg32[31:25]};
                        p_state <= P_IDLE;
                    end else p_state <= P_IDLE;
                end
                default: p_state <= P_IDLE;
            endcase
        end

        // Wait for synchronous memory read
        if (p_state == P_L_WAIT) begin
            reg32 <= ram_read_data;
            p_state <= P_IDLE;
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
                    resp_buf[0] <= hex_chars[0];
                    resp_buf[1] <= hex_chars[1];
                    resp_buf[2] <= hex_chars[2];
                    resp_buf[3] <= hex_chars[3];
                    resp_buf[4] <= hex_chars[4];
                    resp_buf[5] <= hex_chars[5];
                    resp_buf[6] <= hex_chars[6];
                    resp_buf[7] <= hex_chars[7];
                    resp_buf[8] <= 8'h0D;
                    resp_count <= 9;
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
    assign LED = reg32[0];

    // UART Modules
    uart_rx #(
        .BIT_RATE(115200),
        .CLK_HZ(36000000)
    ) i_uart_rx (
        .CLK(CLK),
        .RX(RX),
        .VALID(rx_valid),
        .DATA(rx_data)
    );

    uart_tx #(
        .BIT_RATE(115200),
        .CLK_HZ(36000000)
    ) i_uart_tx (
        .CLK(CLK),
        .TX(TX),
        .BUSY(tx_busy),
        .START(tx_start),
        .DATA(tx_data)
    );

endmodule
