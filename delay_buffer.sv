`timescale 1ns / 1ps

/* Delays a stream of values by the specified delay */
module delay_buffer
    #(
    parameter WIDTH = 8,    // Width of values held in buffer
    parameter DELAY = 10    // Depth of the buffer (MIN = 2)
    )
    (
    input clk,
    input reg [WIDTH-1:0] data_in,
    output wire [WIDTH-1:0] data_out
    );
    
    reg [DELAY-2:0][WIDTH-1:0] buffer;

    /* Assign input and output to start and end of buffer */
    assign data_out = buffer[DELAY-2];

    /* Clears the buffer */
    initial begin
        for(integer i = 0; i < DELAY-1; i=i+1) begin
            buffer[i][WIDTH-1:0] = {WIDTH{1'b0}};
        end
    end 

    /* Shifts the data in the delay buffer */
    always @(posedge clk) begin
        buffer[0] <= data_in;
        buffer[DELAY-2:1] <= buffer[DELAY-3:0];
    end

endmodule