`timescale 1ns / 1ps

/* Used to remove features that have been detected
    too close to the edge of the frame */
module edge_rejector #(
        parameter WIDTH = 200,      // Width of the frame
        parameter HEIGHT = 200,     // Height of the frame
        parameter BW = 8,           // Width of the strength value
        parameter DW = 128,         // Width of the descriptor
        parameter IND_W = 10,       // Width of the pixel indexers
        parameter RADIUS = 5        // Radius of the largest sliding window
    )(
        input clk,

        input wire detected_in,
        input wire [BW-1:0] strength_in,
        input wire [DW-1:0] descriptor_in,
        input wire [IND_W-1:0] x_in,
        input wire [IND_W-1:0] y_in,

        output reg detected_out,
        output reg [BW-1:0] strength_out,
        output reg [DW-1:0] descriptor_out,
        output reg [IND_W-1:0] x_out,
        output reg [IND_W-1:0] y_out
    );
    
    /* Smallest and largest valid indices */
    localparam XMIN = RADIUS;
    localparam XMAX = WIDTH - RADIUS - 1;
    localparam YMIN = RADIUS;
    localparam YMAX = HEIGHT - RADIUS - 1;

    /* Put the output in a clean state */
    initial begin
        detected_out = 1'b0;
        x_out[IND_W-1:0] = {IND_W{1'b0}};
        y_out[IND_W-1:0] = {IND_W{1'b0}};
    end

    /* Flag a detection if the detected feature is not to close to border */
    always @(posedge clk) begin
        detected_out <= detected_in &&
            (x_in >= XMIN &&x_in <= XMAX && y_in >= YMIN && y_in <= YMAX);
    end

    /* Used to delay the inputs by one clock cycle */
    always @(posedge clk) begin
        strength_out <= strength_in;
        descriptor_out <= descriptor_in;
        x_out <= x_in;
        y_out <= y_in;        
    end

endmodule