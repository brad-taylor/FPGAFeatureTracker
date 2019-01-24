`timescale 1ns / 1ps

/* Fast detector with configurable data-width and threshold  */

module fast_detector #(
        parameter THRESHOLD = 50,   // Bresenham threshold
        parameter BW = 8,           // Pixel value Bit Width
        parameter IM_WIDTH = 640    // Width of image
    )(
        input clk,
        input wire [6:0] [6:0] [BW-1:0] px_window,
        output reg [BW-1:0] feature_strength = {BW{1'b0}}     // Sum of absolute differences of pixel of interest (0 if not feature)
    );
    
    integer k;
    
    reg [15:0] [BW-1:0] bres_t = {16{{BW{1'b0}}}};  // Contains the absolute differences
    reg [15:0] sign_t = 16'b0;                      // Preserves the sign of the absolute differences
    reg [1:0] [15:0] bd = {2{16'b0}};               // Denotes 16 [bright, dark] pixels
    reg [1:0] contiguity = 2'b0;                    // Flags if pixels are contiguous [bright, dark]
    
    wire [15:0] [BW-1:0] px_circle;                 // Remaps the 7x7 window to the 16 bresenham pixels
    wire [BW-1:0] px_center;
    
    localparam SW = BW + 4;                         // Bits required to sum all pixel values
    reg [SW-1:0] weight_sum = {(SW){1'b0}};         // Measure of feature strength (for nonmax suppression)
    reg [BW-1:0] weight_sum_scaled = {BW{1'b0}};    // Scales the feature strength down

    
    /* Bresenham pixel circle */
    assign px_circle[15:0] = {
        px_window[0][3], px_window[0][4], px_window[1][5], px_window[2][6],
        px_window[3][6], px_window[4][6], px_window[5][5], px_window[6][4],
        px_window[6][3], px_window[6][2], px_window[5][1], px_window[4][0],
        px_window[3][0], px_window[2][0], px_window[1][1], px_window[0][2]};
    
    
    /* Center pixel (pixel of interest) in the 7x7 window */
    assign px_center = px_window[3][3];
  

    always @(posedge clk) begin
    
        /* Iterates through all Bresenham pixels */
        for(k=0; k<16; k=k+1) begin
        
            /* Computes the absolute difference between bresenham and center 
                and preserves the 'sign' of the result */
            if(px_circle[k] > px_center) begin
                sign_t[k] <= 1'b1;
                bres_t[k] <= px_circle[k] - px_center;
            end else begin
                sign_t[k] <= 1'b0;
                bres_t[k] <= px_center - px_circle[k];
            end
            
            /* Sets the [bright, dark] bits to denote a threshold has passed */
            bd[1][k] <= (bres_t[k] > THRESHOLD) && sign_t[k];
            bd[0][k] <= (bres_t[k] > THRESHOLD) && !sign_t[k];
        end
        
    end
    
    
    always @(posedge clk) begin
        /* Determines if 9 contiguous bright/dark pixels exist */
        for(k=0; k<2; k=k+1) begin
            contiguity[k] <= !(
                (~bd[k][15:07]) && (~bd[k][14:06]) && (~bd[k][13:05]) && (~bd[k][12:04]) &&
                (~bd[k][11:03]) && (~bd[k][10:02]) && (~bd[k][09:01]) && (~bd[k][08:00]) &&
                (~{bd[k][07:00], bd[k][15:15]}) && (~{bd[k][06:00], bd[k][15:14]}) &&
                (~{bd[k][05:00], bd[k][15:13]}) && (~{bd[k][04:00], bd[k][15:12]}) &&
                (~{bd[k][03:00], bd[k][15:11]}) && (~{bd[k][02:00], bd[k][15:10]}) &&
                (~{bd[k][01:00], bd[k][15:09]}) && (~{bd[k][00:00], bd[k][15:08]}));
        end
        
        /* The sum of absolute differences of the bresenham pixels */
        weight_sum[SW-1:0] <= (
            bres_t[00] + bres_t[01] + bres_t[02] + bres_t[03] +
            bres_t[04] + bres_t[05] + bres_t[06] + bres_t[07] +
            bres_t[08] + bres_t[09] + bres_t[10] + bres_t[11] +
            bres_t[12] + bres_t[13] + bres_t[14] + bres_t[15] );
        
        /* Weight sum converted to scaled down to represent the average difference */
        /* Note - (>>4) is equivalent to (/16) */
        weight_sum_scaled[BW-1:0] <= weight_sum[SW-1:0] >> 4;

        /* Only applies weights to that which are features */
        feature_strength[BW-1:0] <= contiguity ? weight_sum_scaled[BW-1:0] : {BW{1'b0}};
    end

endmodule