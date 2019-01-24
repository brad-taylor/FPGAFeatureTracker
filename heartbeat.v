`timescale 1ns / 1ps


// --------------------------------------------------------------------------------
// Heartbeat for artix (Blinks LEDS to show operation)
// --------------------------------------------------------------------------------

module heartbeat(
    input clk,
    output [3:0] led
    );

    /* Heatbeat */
    reg [28:0] clk_counter = 29'b0;

    assign led [3:0] = clk_counter[28:25];

    always @ (posedge clk) begin
        clk_counter <= clk_counter + 1;
    end
    
endmodule
