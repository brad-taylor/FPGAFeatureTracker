`timescale 1ns / 1ps

/* Performs non-maximal suppression of features based on their associated strenghts  */

module nonmax_suppression
    #(
        parameter WR = 3,           // 'Radius' of the square non-max supressor window
        parameter BW = 8,           // Bit Width of the feature strengths
        parameter IM_WIDTH = 640    // Width of the image
    )(
        input clk,
        input wire [BW-1:0] strength_in,
        output reg [BW-1:0] strength_out,
        output reg feature_flag
    );
    
    integer i;
    genvar j, k;
    
    /* Size of the (WS x Ws) non-maxima window */
    localparam WS = 2*WR + 1;
    
    /* First row of the window (half+1) */
    reg [WR:0] [BW-1:0] px_line;
    /* Top R rows of the window */
    reg [WR-1:0] [WS-1:0] [BW-1:0] px_window;
    
    /* Connects line buffers together */
    wire [WR-1:0] [BW-1:0] line_feed_in;
    wire [WR-1:0] [BW-1:0] line_feed_out;
    
    /* Used for input/window maxima logic */
    wire [WR-1:0] [WS-2:0] maxima_window;
    wire [WR-1:0] maxima_line;
    wire [WR-1:0] maxima_feed;
    
    /* Feeds the end of the first line into a line buffer */
    assign line_feed_in[0] = px_line[WR];
    
    
    generate
        /* Assigns the line buffer input as the last element of each window row */
        for(j=0; j<WR-1; j=j+1) begin : wire_gen_loop
            assign line_feed_in[j+1] = px_window[j][WS-1];
        end
        
        /* Generates line buffers */
        for(j=0; j<WR; j=j+1) begin : gen_loop
            fifo_buffer #(.WIDTH(BW), .DEPTH(IM_WIDTH-WS)) fifo_x (.clk(clk), .data_in(line_feed_in[j]), .data_out(line_feed_out[j]));
        end
        
        /* Generates all wires required for maxima comparison */
        for(j=0; j<WR; j=j+1) begin : maxima_gen_loop
            assign maxima_line[j] = strength_in <= px_line[j];
            assign maxima_feed[j] = strength_in <= line_feed_out[j];
              
            for(k=0; k<WS-1; k=k+1) begin
                assign maxima_window[j][k] = strength_in <= px_window[j][k]; 
            end
        end
    endgenerate

    /* Initialize output registers */
    initial begin
        feature_flag = 1'b0;
        strength_out[BW-1:0] = {BW{1'b0}};
    end

    /* Initialize window registers */
    initial begin
       px_line[WR:0] = {WR+1{{BW{1'b0}}}};
       
        for(i=0; i<WR; i=i+1) begin
            px_window[i][WS-1:0] = {WS{{BW{1'b0}}}};
        end
    end


    /* Features that reach the last register in the window are successful if they are a non-zero value */
    always @(posedge clk) begin
       feature_flag <= px_window[WR-1][WS-1] > 0 ? 1'b1 : 1'b0;
       strength_out <= px_window[WR-1][WS-1];
    end


    /* Feeds line buffer values into sliding window */
   always @(posedge clk) begin
        /* If the maxima is not the new input value */
        if(maxima_line || maxima_feed || maxima_window) begin
            /* ----- Standard window shift but with the input as 0 ----- */
            px_line[WR:0] <= {px_line[WR-1:0], {BW{1'b0}}};
            for(i=0; i<WR; i=i+1) begin
                px_window[i][WS-1:0] <= {px_window[i][WS-2:0], line_feed_out[i]};
            end
        end else begin
            /* ----- Set everything to 0 but the input weight ----- */
            px_line[WR:0] <= {{WR{{BW{1'b0}}}}, strength_in};
            for(i=0; i<WR; i=i+1) begin
                px_window[i][WS-1:0] <= {WS{{BW{1'b0}}}};
            end
        end
    end

endmodule