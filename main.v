`timescale 1ns / 1ps

// --------------------------------------------------------------------------------
// Base module. Used to instantiate system module.
// --------------------------------------------------------------------------------

module main(
    input clk,
    
    // Heartbeat
    output [3:0] led,
    
    // Testing
    input BTN,
    output LED
    );
    
    reg [15:0] input_buffer = 16'b0;
    reg new_frame = 1'b0;
    wire match;
    wire [11:0] xs;
    wire [11:0] ys;
    wire [11:0] xe;
    wire [11:0] ye;
    wire [9:0] span;
    
    assign LED = input_buffer[0];

    
    system #(.IM_WIDTH(640), .IM_HEIGHT(480), .LE(20))
    system1(
        .clk(clk),
        .data_in(input_buffer[7:0]),
        .new_frame(new_frame),

        .match_xs(xs),
        .match_ys(ys),
        .match_xe(xe),
        .match_ye(ye),
        .match_flag(match),
        .match_span(span)
    );


    // Feeds in arbitraty bitstream that uses all outputs
    always @(posedge clk) begin
        new_frame <= match || span[0] || span[7];
        input_buffer <= input_buffer ^ xs ^ ys ^ xe ^ ye ^ span ^ match;

    end

    //system system1(.clk(clk), .data_in(input_buffer), .data_out(output_buffer));
    // // Feeds in arbitraty bitstream
    // always @(posedge clk) begin
    //     //input_buffer[15:0] = {input_buffer[15:1], BTN};
    //     input_buffer[15:0] = input_buffer ^ output_buffer ^ hamming;
    // end
    
    // LED proof of life
    heartbeat heartbeat1(
        .clk(clk),
        .led(led)
    );
    
endmodule
