/*
  top.v
  Command-based terminal for IceSugar Nano
  - Echoes all characters
  - Command "w <hex>\r": writes up to 32-bit hex to a register (zero-padded)
  - Command "r\r": reads the 32-bit register and prints 8 hex chars + CR
  - Command "s <addr_hex>\r": stores register to EBR memory
  - Command "l <addr_hex>\r": loads EBR memory to register
  - Command "e\r": reg32 += EP1(RAM[4])
  - Command "d\r": reg32 += EP0(RAM[0])
  - Command "c\r": reg32 += CH(RAM[4,5,6])
  - Command "m\r": reg32 += MAJ(RAM[0,1,2])
  - Command "a <addr_hex>\r": reg32 += RAM[addr]
  
  Memory Layout: 4 EBR blocks, 16 x 32-bit each.
  
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

    // Parser State
    reg [3:0] p_state = 0;
    localparam P_IDLE   = 0,
               P_W_S    = 1,
               P_W_HEX  = 2,
               P_R_CR   = 3,
               P_SL_S   = 4,
               P_SL_HEX = 5,
               P_L_WAIT = 7,
               P_E_CR   = 8,
               P_D_CR   = 9,
               P_C_CR   = 10,
               P_M_CR   = 11,
               P_ADD_S  = 12,
               P_ADD_H  = 13;

    reg trigger_resp = 0;
    reg is_store = 0;
    reg is_load = 0;

    // Echo Buffer
    reg [7:0] echo_buf;
    reg echo_pending = 0;

    // Operation FSM signals
    reg op_trigger = 0;
    reg op_busy = 0;
    reg [2:0] op_type = 0; // 0: EP1, 1: EP0, 2: CH, 3: MAJ, 4: ADD
    reg [5:0] op_addr = 0;
    reg [2:0] op_state = 0;
    reg [1:0] op_cnt = 0;
    reg [31:0] temp_op_data;
    reg [31:0] temp_op_data2;
    reg [31:0] temp_op_data3;
    localparam OP_IDLE = 0, OP_READ = 1, OP_WAIT = 2, OP_WAIT2 = 7, OP_COMPUTE = 3, OP_APPLY = 4, OP_WRITE_EN = 5, OP_WRITE_DONE = 6;

    // Embedded RAM (4 blocks of 16 x 32-bit)
    reg [31:0] ram [0:63]; 
    reg [31:0] ram_read_data;
    reg ram_we_internal = 0;
    wire [5:0] ram_addr = temp_addr[5:0];
    wire [5:0] ram_addr_mux = (op_busy) ? op_addr : ram_addr;

    // Synchronous Memory Logic
    always @(posedge CLK) begin
        if (ram_we_internal)
            ram[ram_addr_mux] <= reg32;
        else if (rx_valid && p_state == P_SL_HEX && is_store && rx_data == 8'h0D)
            ram[ram_addr_mux] <= reg32;
        ram_read_data <= ram[ram_addr_mux];
    end

    // Helper for hex parsing
    wire [3:0] rx_nibble = (rx_data >= "a" && rx_data <= "f") ? (rx_data - "a" + 10) :
                           (rx_data >= "A" && rx_data <= "F") ? (rx_data - "A" + 10) :
                           (rx_data - "0");
    wire rx_is_hex = (rx_data >= "0" && rx_data <= "9") || 
                     (rx_data >= "A" && rx_data <= "F") || 
                     (rx_data >= "a" && rx_data <= "f");

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

    // TX State Machine Signals
    reg [1:0] tx_state = 0;
    localparam ST_IDLE = 0, ST_START = 1, ST_WAIT = 2;

    // PMOD LEDs connected to reg32 (lower 8 bits, inverted for active-high behavior)
    assign PMOD2 = ~reg32[0];
    assign PMOD4 = ~reg32[1];
    assign PMOD6 = ~reg32[2];
    assign PMOD8 = ~reg32[3];
    assign PMOD1 = ~reg32[4];
    assign PMOD3 = ~reg32[5];
    assign PMOD5 = ~reg32[6];
    assign PMOD7 = ~reg32[7];

    // Combined Logic for reg32 and other registers
    always @(posedge CLK) begin
        // Default assignments
        op_trigger <= 0;
        
        // Parser Logic
        if (rx_valid) begin
            echo_buf <= rx_data;
            echo_pending <= 1;

            case (p_state)
                P_IDLE: begin
                    if (rx_data == "w") p_state <= P_W_S;
                    else if (rx_data == "r") p_state <= P_R_CR;
                    else if (rx_data == "e") p_state <= P_E_CR;
                    else if (rx_data == "d") p_state <= P_D_CR;
                    else if (rx_data == "c") p_state <= P_C_CR;
                    else if (rx_data == "m") p_state <= P_M_CR;
                    else if (rx_data == "a") p_state <= P_ADD_S;
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
                    if (rx_data == " ") begin
                        p_state <= P_SL_HEX;
                        temp_addr <= 0;
                    end else p_state <= P_IDLE;
                end
                P_SL_HEX: begin
                    if (rx_is_hex) begin
                        temp_addr <= {temp_addr[3:0], rx_nibble};
                        p_state <= P_SL_HEX;
                    end else if (rx_data == 8'h0D) begin
                        if (is_load) p_state <= P_L_WAIT;
                        else p_state <= P_IDLE;
                    end else p_state <= P_IDLE;
                end
                P_E_CR: begin
                    if (rx_data == 8'h0D) begin
                        op_trigger <= 1;
                        op_type <= 0;
                        op_addr <= 4;
                        p_state <= P_IDLE;
                    end else p_state <= P_IDLE;
                end
                P_D_CR: begin
                    if (rx_data == 8'h0D) begin
                        op_trigger <= 1;
                        op_type <= 1;
                        op_addr <= 0;
                        p_state <= P_IDLE;
                    end else p_state <= P_IDLE;
                end
                P_C_CR: begin
                    if (rx_data == 8'h0D) begin
                        op_trigger <= 1;
                        op_type <= 2;
                        op_addr <= 4;
                        p_state <= P_IDLE;
                    end else p_state <= P_IDLE;
                end
                P_M_CR: begin
                    if (rx_data == 8'h0D) begin
                        op_trigger <= 1;
                        op_type <= 3;
                        op_addr <= 0;
                        p_state <= P_IDLE;
                    end else p_state <= P_IDLE;
                end
                P_ADD_S: begin
                    if (rx_data == " ") begin
                        p_state <= P_ADD_H;
                        temp_addr <= 0;
                    end else p_state <= P_IDLE;
                end
                P_ADD_H: begin
                    if (rx_is_hex) begin
                        temp_addr <= {temp_addr[3:0], rx_nibble};
                    end else if (rx_data == 8'h0D) begin
                        op_trigger <= 1;
                        op_type <= 4;
                        op_addr <= temp_addr[5:0];
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

        // Operation State Machine
        case (op_state)
            OP_IDLE: begin
                ram_we_internal <= 0;
                op_cnt <= 0;
                if (op_trigger) begin
                    op_busy <= 1;
                    op_state <= OP_READ;
                end
            end
            OP_READ: op_state <= OP_WAIT;
            OP_WAIT: op_state <= OP_WAIT2;
            OP_WAIT2: op_state <= OP_COMPUTE;
            OP_COMPUTE: begin
                if (op_type == 2) begin
                    case (op_cnt)
                        0: begin temp_op_data <= ram_read_data; op_addr <= 5; op_cnt <= 1; op_state <= OP_READ; end
                        1: begin temp_op_data2 <= ram_read_data; op_addr <= 6; op_cnt <= 2; op_state <= OP_READ; end
                        2: begin temp_op_data3 <= ram_read_data; op_addr <= 4; op_state <= OP_APPLY; end
                    endcase
                end else if (op_type == 3) begin
                    case (op_cnt)
                        0: begin temp_op_data <= ram_read_data; op_addr <= 1; op_cnt <= 1; op_state <= OP_READ; end
                        1: begin temp_op_data2 <= ram_read_data; op_addr <= 2; op_cnt <= 2; op_state <= OP_READ; end
                        2: begin temp_op_data3 <= ram_read_data; op_addr <= 0; op_state <= OP_APPLY; end
                    endcase
                end else begin
                    temp_op_data <= ram_read_data;
                    op_state <= OP_APPLY;
                end
            end
            OP_APPLY: begin
                if (op_type == 0) // EP1
                    reg32 <= reg32 + ({temp_op_data[5:0], temp_op_data[31:6]} ^ {temp_op_data[10:0], temp_op_data[31:11]} ^ {temp_op_data[24:0], temp_op_data[31:25]});
                else if (op_type == 1) // EP0
                    reg32 <= reg32 + ({temp_op_data[1:0], temp_op_data[31:2]} ^ {temp_op_data[12:0], temp_op_data[31:13]} ^ {temp_op_data[21:0], temp_op_data[31:22]});
                else if (op_type == 2) // CH
                    reg32 <= reg32 + ((temp_op_data & temp_op_data2) ^ (~temp_op_data & temp_op_data3));
                else if (op_type == 3) // MAJ
                    reg32 <= reg32 + ((temp_op_data & temp_op_data2) ^ (temp_op_data & temp_op_data3) ^ (temp_op_data2 & temp_op_data3));
                else if (op_type == 4) // ADD
                    reg32 <= reg32 + temp_op_data;
                op_state <= OP_WRITE_EN;
            end
            OP_WRITE_EN: begin
                ram_we_internal <= 1;
                op_state <= OP_WRITE_DONE;
            end
            OP_WRITE_DONE: begin
                ram_we_internal <= 0;
                op_state <= OP_IDLE;
                op_busy <= 0;
            end
        endcase

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
