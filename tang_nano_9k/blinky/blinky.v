module blinky (
    input clk,
    output reg [5:0] led
);
    reg [23:0] counter = 0;
    always @(posedge clk) begin
        counter <= counter + 1;
        led <= ~counter[23:18];
    end
endmodule