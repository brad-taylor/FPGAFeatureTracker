`timescale 1ns / 1ps

/* Determines the (x,y) index of detected features */
/* WARNING - new_frames cannot occur faster than the propogation delay */

module pixel_indexer #(
        parameter IM_WIDTH = 640,   // Frame width
        parameter PROP_DELAY = 0,   // Number of clocks for input pixel to reach output
        parameter IND_WIDTH = 12,   // Number of bits in the pixel index x/y counters
        parameter COUNT_WIDTH = 16  // Number of bits in the delay counter
    )(
        input clk,
        input new_frame,
        output reg [IND_WIDTH-1:0] ind_x = {IND_WIDTH{1'b0}},
        output reg [IND_WIDTH-1:0] ind_y = {IND_WIDTH{1'b0}},
        output reg delayed_new_frame = 1'b0 // New frame flag delayed by the propogation delay
    );

    typedef enum {NONE, RUNNING, NEW_FRAME} State;

    /* Register used for counting propogation delays */
    reg [COUNT_WIDTH-1:0] delay_counter = {COUNT_WIDTH{1'b0}};

    /* Only account for propogation delay if one is configured */
    State state = PROP_DELAY ? NONE : RUNNING;

    /* Delays the pixel index counting and new_frame flag by the specified propogation delay */
    always @(posedge clk) begin
        /* If RUNNING as usual */
        if(state == RUNNING) begin
            delayed_new_frame <= 0;
            delay_counter <= 1; // Pre-empt the propagation delay
            if(new_frame) begin
                state <= NEW_FRAME;
            end
        /* If NONE or NEW_FRAME and delay has been reached */
        end else if(delay_counter == PROP_DELAY - 1) begin
            state <= RUNNING;
            delayed_new_frame <= NEW_FRAME ? 1 : 0;
        /* If NONE or NEW_FRAME and delay not yet reached */
        end else begin
            delay_counter <= delay_counter + 1;
        end
    end

    /* Count pixel (x,y) indicies once propogation delay has occurred */
    always @(posedge clk) begin
        if(delayed_new_frame || state == NONE) begin
            ind_x <= 0;
            ind_y <= 0;
        end else begin
            if(ind_x == IM_WIDTH - 1) begin
                ind_y <= ind_y + 1;
                ind_x <= 0;
            end else begin
                ind_x <= ind_x + 1;
            end
        end
    end

endmodule