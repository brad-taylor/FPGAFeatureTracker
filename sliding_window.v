`timescale 1ns / 1ps

/* An BW-bit WSxWS sliding window based on an input pixel stream */
module sliding_window
    #(
        parameter W = 9,            // Window width
        parameter H = 9,            // Window height
        parameter BW = 8,           // Bit Width of the values
        parameter IM_WIDTH = 640    // Width of line buffer
    )
    (
        input clk,
        input [BW-1:0] data_in,
        output reg [H-1:0] [W-1:0] [BW-1:0] px_window // WSxWS sliding window
    );

    /* Generic iterator */
    integer i;
    
    /* Connects line buffers together */
    wire [H-1:0] [BW-1:0] line_feed;
    
    /* Attach input to first line buffer in addition to window */
    assign line_feed[0] = data_in;
    
    
    /* Generates line buffers */
    genvar j;
    generate
        for(j=0; j<H-1; j=j+1) begin : gen_loop
            fifo_buffer #(.WIDTH(BW), .DEPTH(IM_WIDTH))
                fifo_x (.clk(clk), .data_in(line_feed[j]), .data_out(line_feed[j+1]));
        end
    endgenerate
    
    
    /* Initialize window registers */
    initial begin
        for(i=0; i<H; i=i+1) begin
            px_window[i][W-1:0] = {W{{BW{1'b0}}}};
        end
    end
    
    
    /* Feeds line buffer values into sliding window */
    always @(posedge clk) begin
        for(i=0; i<H; i=i+1) begin
            px_window[i][W-1:0] <= {px_window[i][W-2:0], line_feed[i]};
        end
    end

endmodule