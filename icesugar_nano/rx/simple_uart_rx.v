/*

  Implement a simple 8N1 uart
  
                output PMOD1,   // D4
                output PMOD2,   // D0
                output PMOD3,   // D5
                output PMOD4,   // D1
                output PMOD5,   // D6
                output PMOD6,   // D2
                output PMOD7,   // D7
                output PMOD8    // D3

   wire D0;
   wire D1;
   wire D2;
   wire D3;
   wire D4;
   wire D5;
   wire D6;
   wire D7;

  assign D0 = PMOD2;
  assign D1 = PMOD4;
  assign D2 = PMOD6;
  assign D3 = PMOD8;
  assign D4 = PMOD1;
  assign D5 = PMOD3;
  assign D6 = PMOD5;
  assign D7 = PMOD7;


*/

module uart(  
                input wire CLK,
                input wire RX
                output wire VALID,
                output reg [7:0] DATA
                );

// Input bit rate of the UART line.
parameter   BIT_RATE        = 9600; // bits / sec

// Clock frequency in hertz.
parameter   CLK_HZ          =    12_000_000;

// Number of clock cycles per uart bit.
localparam       CLK_PER_BIT     = CLK_HZ / BIT_RATE;

localparam       CLK_COUNTER_LEN      = 1+$clog2(CLK_PER_BIT);

reg [CLK_COUNTER_LEN-1:0] clk_counter;
reg clk_cnt_enable;
reg [2:0] bit_counter;
reg [2:0] state;

  localparam [2:0]
    Idle = 0,
    Start0 = 1,           
    Start1 = 2,
    Data0 = 3,
    Data1 = 4,
    Stop0 = 5,
    Stop1 = 6;
    
  initial begin
    state = Idle;
    clk_counter = 0;
    clk_cnt_enable = 0;
    bit_counter = 0;
  end
  
  always @(*) begin
    if ( state == Stop1 )
      VALID = 1;
    else 
      VALID = 0;
  end
  
  always @(posedge CLK) begin
    case (state)
      Idle: begin
          clk_cnt_enable <= 0;
          if ( RX == 1 ) begin
            state <= Idle;
          end else begin
            state <= Start0;
          end
      end
      
      Start0: begin
        if ( clk_counter == CLK_PER_BIT/2 ) begin
          if ( RX == 0 ) begin          // stop bit detected
            clk_cnt_enable <= 0;
            state <= Start1;
          end else begin                  // stop condition was too short, back to idle
            clk_cnt_enable <= 0;
            state <= Idle;
          end
        end else begin
          clk_cnt_enable <= 1;
          state <= Start0;
        end
      end
      
      Start1: begin
        if ( clk_counter == CLK_PER_BIT/2 ) begin
          state <= Data0;
          clk_cnt_enable <= 0;
          bit_counter <= 0;
        end else begin
          clk_cnt_enable <= 1;
          state <= Start1;
        end
      end
      
      Data0: begin
        if ( clk_counter == CLK_PER_BIT/2 ) begin
          DATA[0] <= DATA[1];
          DATA[1] <= DATA[2];
          DATA[2] <= DATA[3];
          DATA[3] <= DATA[4];
          DATA[4] <= DATA[5];
          DATA[5] <= DATA[6];
          DATA[6] <= DATA[7];
          DATA[7] = RX; 
          clk_cnt_enable <= 0;
          state <= Data1;
        end else begin
          clk_cnt_enable <= 1;
          state <= Data0;
        end
      end
      
      Data1: begin
        if ( clk_counter == CLK_PER_BIT/2 ) begin
          if ( bit_counter == 7 ) begin
            clk_cnt_enable <= 0;
            state <= Stop0;
          end else begin
            bit_counter <= bit_counter +1;
            clk_cnt_enable <= 0;
            state <= Data0;
          end
        end else begin
          clk_cnt_enable <= 1;
          state <= Data1;
        end
      end

      Stop0: begin
        if ( clk_counter == CLK_PER_BIT/2 ) begin
          if ( RX == 1 ) begin
            clk_cnt_enable <= 0;
            state <= Stop1;
          end else begin 
            clk_cnt_enable <= 0;
            state <= Idle;              // break condition detected
          end 
        end else begin
          clk_cnt_enable <= 0;
          state <= Stop0;
        end
      end
      
      Stop1: begin
        clk_cnt_enable <= 0;
        state = Idle;
      end

      default: begin
        clk_cnt_enable <= 0;
        state = Idle;
      end
      
    endcase
  end

  always @(posedge CLK) begin
    if ( clk_cnt_enable == 0 ) begin
      clk_counter <= 0;
    end else begin
      clk_counter <= clk_counter + 1;
    end
  end
  
endmodule
