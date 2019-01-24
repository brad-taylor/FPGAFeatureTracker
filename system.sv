`timescale 1ns / 1ps

module system #(
    parameter IM_WIDTH = 640,           // Width of the image
    parameter IM_HEIGHT = 480,          // Height of the image
    parameter LE = 20,                  // How many features to track
    parameter MATCH_THRESHOLD = 15,     // Mat dist between features to be concidered a match
    parameter SIMILAR_THRESHOLD = 20,   // Max dist between features concidered similar
    localparam IND_WIDTH = 12,          // Width of the pixel index registers
    localparam BW = 8,                  // Bit width of data
    localparam DW = 128,                // Descriptor width
    localparam MFW = 08,                // Matcher - Missed frames counter width
    localparam FCW = 10                 // Matcher - Frame counter width
    )(
    input clk,
    input [BW-1:0] data_in,
    input new_frame,    

    output reg feature_flag,
    output reg [IND_WIDTH-1:0] feature_x,
    output reg [IND_WIDTH-1:0] feature_y,
    output reg [BW-1:0] feature_strength,
    output reg [DW-1:0] descriptor,

    // Temp match output for dubugging (USE INTERFACE OR STRUCT)
    output wire match_flag,
    output wire [IND_WIDTH-1:0] match_xs,
    output wire [IND_WIDTH-1:0] match_ys,
    output wire [IND_WIDTH-1:0] match_xe,
    output wire [IND_WIDTH-1:0] match_ye,
    output wire [FCW-1:0] match_span,

    output wire delayed_new_frame // NOTE: for debugging with frame numbers
    );

    localparam NMR = 3;                 // Radius of non-maxima supression
    localparam WS = 9;                  // Width of the sliding window
    localparam HS = WS + NMR;           // Height of the sliding window
    localparam RS = (WS-1)/2;           // Radius of the sliding window
    localparam THRESHOLD = 50;          // Bresenham threshold

    // Clock cycles taken for input pixel to reach feature output (delay ~=~ (W+1)/2 (S_sw + S_nm - 4) + P) , P approx 7
    localparam PIPELINE_DELAY = 7;
    localparam PROP_DELAY = (IM_WIDTH + 1) * (WS + (2 * NMR + 1) - 2) / 2 + PIPELINE_DELAY;

    // Clock cycles to delay descriptor by to match the non-max output flag
    localparam D_PROP_DELAY = 9;

    /* Feeds signals between modules */
    wire [BW-1:0] feature_strength_raw;
    wire [HS-1:0] [WS-1:0] [BW-1:0] px;
    wire [6:0] [6:0] [BW-1:0] fast_px;
    wire [WS-1:0] [WS-1:0] [BW-1:0] desc_px;
    wire [DW-1:0] descriptor_initial;

    /* Feeds features to the edge rejector */
    wire [IND_WIDTH-1:0] feature_x_prelim;
    wire [IND_WIDTH-1:0] feature_y_prelim;
    wire [BW-1:0] feature_strength_prelim;
    wire [DW-1:0] descriptor_prelim;
    wire feature_flag_prelim;

    /* Assign the bottom part of the sliding window to the feature descriptor */
    assign desc_px[WS-1:0] = px[HS-1:NMR];

    /* Assigning the top centre 7x7 of the sliding window to wires fed into the FAST detector */
    // Parameters used to locate the 7x7 FAST window within the sliding window
    localparam fw_min = RS - 3;
    localparam fw_max = RS + 3;
    generate
        for(genvar i=0; i<7; i=i+1) begin
            assign fast_px[i][6:0] = px[fw_min+i][fw_max:fw_min];
        end
    endgenerate

    /* Creates a 7x7 sliding window to hold pixels for bresenham feature detection */
    sliding_window #(.W(WS), .H(HS), .BW(BW), .IM_WIDTH(IM_WIDTH))
        sliding_window_1 (.clk(clk), .data_in(data_in), .px_window(px));

    /* Creates the fast feature detector which inputs an NxN window and outputs a feature weight */
    fast_detector #(.THRESHOLD(THRESHOLD), .BW(BW), .IM_WIDTH(IM_WIDTH))
        fast_detector_1 (.clk(clk), .px_window(fast_px), .feature_strength(feature_strength_raw));

    /* NxN winow used to remove features whose sum of absolute differences are not local maximas */
    nonmax_suppression #(.WR(NMR), .BW(BW), .IM_WIDTH(IM_WIDTH))
        nonmax_suppression_1(.clk(clk), .strength_in(feature_strength_raw),
        .feature_flag(feature_flag_prelim), .strength_out(feature_strength_prelim));

    /* Feature descriptor which takes a 9x9 sliding window and returns a 128-bit binary descriptor */
    feature_descriptor #(.BW(BW)) feature_descriptor_1(.clk(clk), .px_window(desc_px), .descriptor(descriptor_initial));

    /* Delays the descriptor to match the output from the nonmax_suppression unit */
    delay_buffer #(.WIDTH(DW), .DELAY(D_PROP_DELAY))
        descriptor_delay(.clk(clk), .data_in(descriptor_initial), .data_out(descriptor_prelim));

    /* Determines the index of the pixels exiting the nonmax_suppression module */
    pixel_indexer #(.IM_WIDTH(IM_WIDTH), .PROP_DELAY(PROP_DELAY), .IND_WIDTH(IND_WIDTH))
        pixel_indexer_1(.clk(clk), .new_frame(new_frame), .ind_x(feature_x_prelim),
        .ind_y(feature_y_prelim), .delayed_new_frame(delayed_new_frame));

    /* Rejects features that have been detected too close to the edge of the frame */
    edge_rejector #(.WIDTH(IM_WIDTH), .HEIGHT(IM_HEIGHT), .BW(BW), .DW(DW), .IND_W(IND_WIDTH), .RADIUS(RS))
        edge_rejector_1(.clk(clk), .detected_in(feature_flag_prelim), .strength_in(feature_strength_prelim),
        .descriptor_in(descriptor_prelim), .x_in(feature_x_prelim), .y_in(feature_y_prelim), .detected_out(feature_flag),
        .strength_out(feature_strength), .descriptor_out(descriptor), .x_out(feature_x), .y_out(feature_y));

    /* Keeps track of quality features and outputs their movement */
    feature_matcher #(.DW(DW), .PW(IND_WIDTH), .LE(LE), .STRW(BW), .FCW(FCW), .MFW(MFW), .MATCH_THRESHOLD(MATCH_THRESHOLD), .SIMILAR_THRESHOLD(SIMILAR_THRESHOLD))
        feature_matcher_1(.clk(clk), .new_frame(new_frame), .feature_flag(feature_flag), .feature_d(descriptor),
        .feature_x(feature_x), .feature_y(feature_y), .feature_s(feature_strength),
        .match_xs(match_xs), .match_ys(match_ys), .match_xe(match_xe), .match_ye(match_ye), .match_flag(match_flag), .match_span(match_span));

endmodule