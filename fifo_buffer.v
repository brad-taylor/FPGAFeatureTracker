`timescale 1ns / 1ps

 /* FIFO buffer which is inferred to a block ram (BRAM) */
 /* Note: Accessing addresses larger than the depth has unknown behaviour */

module fifo_buffer
    #(
    parameter WIDTH = 8,    // Width of values held in buffer
    parameter DEPTH = 640,  // Depth of the buffer
    parameter ADDR_W = 11   // Width (bits) required to hold address
    )
    (
    input clk,
    input [WIDTH-1:0] data_in,
    output reg [WIDTH-1:0] data_out = {WIDTH{1'b0}}
    );
    
    /* Current index of the buffer */
    reg [ADDR_W-1:0] addr_in  = {ADDR_W-1{1'b0}};
    reg [ADDR_W-1:0] addr_out = {{ADDR_W-2{1'b0}}, 1'b1};
    
    /* Buffer */
    reg [WIDTH-1:0] data [DEPTH-1:0]; //2**ADDR_W-1:0
    
    /* Clears the block ram */
    integer i;
    initial begin
        for(i=0; i<DEPTH; i=i+1) data[i] = {WIDTH{1'b0}};
    end 
    
    /* Increments the address counters, resetting at DEPTH */
    always @(posedge clk) begin
        addr_in <= addr_out; // Follows the out addr with z^-1 delay
        addr_out <= addr_out==(DEPTH-1) ? 0 : addr_out+1;
    end
    
    always @(posedge clk) begin
        /* Stores input data */
        data[addr_in] <= data_in;
        /* Assigns output data */
        data_out <= data[addr_out];
    end

endmodule