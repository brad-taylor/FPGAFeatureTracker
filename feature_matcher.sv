`timescale 1ns / 1ps

// NOTE - The feature similarity logic needs to be verified

/* Provided a stream of features, this module is able to track their movement */
module feature_matcher #(
        parameter DW = 128,                 // Width of the descriptors
        parameter PW = 10,                  // Width of the position values    
        parameter LE = 04,                  // Number of library entries
        parameter STRW = 8,                 // Width of the strength value
        parameter MATCH_THRESHOLD = 15,     // Max matching distance
        parameter SIMILAR_THRESHOLD = 20,   // Max dist between features concidered similar
        parameter MMF = 10,                 // Maximum missed frames
        parameter MFW = 08,                 // Missed frames counter width
        parameter FCW = 10                  // Frame counter width
    )(
        input clk,
        input new_frame,

        /* New features */
        input wire feature_flag,
        input wire [DW-1:0] feature_d,
        input wire [PW-1:0] feature_x,
        input wire [PW-1:0] feature_y,
        input wire [STRW-1:0] feature_s,

        /* Feature Matches */
        output reg match_flag,
        output reg [PW-1:0] match_xs,
        output reg [PW-1:0] match_ys,
        output reg [PW-1:0] match_xe,
        output reg [PW-1:0] match_ye,
        output reg [FCW-1:0] match_span
    );

    localparam DCD = 6;                 // Descriptor comparator delay
    localparam RE = LE + DCD + 1;       // Number of entries in the shift register
    localparam SW = 8;                  // Width of the comparator summation (log2(DW) +1)
    localparam OW = 10;                 // Width of value that holds library index

    /* States of the library entry state machine */
    typedef enum{
        L_EMPTY,      // No features in this entry
        L_NEW,        // New feature added this frame
        L_OCCUPIED    // Occupied by feature
    } libstate;

    /* States of the register entry state machine */
    typedef enum{
        R_EMPTY,      // No feature
        R_DEFAULT,    // Standard comparisons
        R_SIMILAR,    // Similar to another feature
        R_SEARCHING   // Searching to be placed
    } regstate;

    /* Data shared by lib and reg */
    typedef struct packed{
        reg [PW-1:0] x;     // X position of feature
        reg [PW-1:0] y;     // y position of feature
        reg [STRW-1:0] s;   // feature strength
        reg [DW-1:0] d;     // feature descriptor
    } feature_data;

    /* Library Entry */
    typedef struct packed{
        reg[2:0] s;         // State
        reg [FCW-1:0] cf;   // Consecutive frames
        reg [MFW-1:0] mf;   // Missed frames
        feature_data data;  // Feature data
    } lib_feature;

    /* Shift Register Feature */
    typedef struct packed{
        reg[2:0] s;         // State
        feature_data data;  // Feature data
    } reg_feature;

    /* Rester component of matches stored */
    typedef struct packed{
        reg occupied;           // Flags if this struct is occupied
        reg [PW-1:0] xe;        // X position of end feature
        reg [PW-1:0] ye;        // y position of end feature
    } feature_match;

    feature_match [LE-1:0] match_list;
    /* List of the library features */
    lib_feature [LE-1:0] lib_list;
    reg [LE-1:0] [SW-1:0] hamming_dist;

    /* List if the features in the shift register */
    reg_feature [RE-1:0] reg_list;

    /* Variables used for buffering shift register input */
    reg temp_used = 0;
    reg_feature temp_reg;
    reg_feature clean_reg;
    reg_feature checker_reg;

    /* Used to loop through and output them one at a time */
    reg [OW-1:0] out_k = 0;

    generate
        /* Feed the library/register descriptors into a comparator */
        for(genvar i = 0; i < LE; i = i+1) begin: comparator_gen
            descriptor_comparator #()
                descriptor_comparator_1(.clk(clk), .a(lib_list[i].data.d), .b(reg_list[i].data.d), .distance(hamming_dist[i]));
        end
    endgenerate

    /* Clear the library and registers */
    initial begin
        /* Library entires */
        for(integer i = 0; i < LE; i = i+1) begin
            lib_list[i].s = L_EMPTY;
            lib_list[i].cf = 0;
            lib_list[i].mf = 0;
            lib_list[i].data = {{PW{1'b0}}, {PW{1'b0}}, {STRW{1'b0}}, {DW{1'b0}}};
        end
        /* Register entries */
        for(integer i = 0; i < RE; i = i+1) begin
            reg_list[i].s = R_EMPTY;
            reg_list[i].data = {{PW{1'b0}}, {PW{1'b0}}, {STRW{1'b0}}, {DW{1'b0}}};
        end
        /* Match entires */
        for(integer i = 0; i < LE; i = i+1) begin
            match_list[i].occupied = 0;
            match_list[i].xe = 0;
            match_list[i].ye = 0;
        end
        /* Temp reg used whe shift reg in use */
        temp_reg.s = R_EMPTY;
        temp_reg.data = {{PW{1'b0}}, {PW{1'b0}}, {STRW{1'b0}}, {DW{1'b0}}};
        /* Clean reg to use when no data */
        clean_reg.s = R_EMPTY;
        clean_reg.data = {{PW{1'b0}}, {PW{1'b0}}, {STRW{1'b0}}, {DW{1'b0}}};
    end

    /* Clear the match output */
    initial begin
        match_flag = 0;
        match_xs = 0;
        match_ys = 0;
        match_xe = 0;
        match_ye = 0;
        match_span = 0;
    end

    /* Responsible for placing data into the shift register */
    always @(posedge clk) begin
        /* Placing an input feature into the shift register */
        if(feature_flag) begin
            reg_list[0].s <= R_DEFAULT;
            reg_list[0].data <= {feature_x, feature_y, feature_s, feature_d};
        end

        /* Place shift reg outputs into checker register for analysis */
        checker_reg <= reg_list[RE-1];

        /* If the feature is in a state that permits library placement */
        if(checker_reg.s == R_DEFAULT) begin
            /* Wait to place data becuse reg currently in use */
            if(feature_flag) begin
                temp_used <= 1;
                temp_reg.s <= R_SEARCHING;
                temp_reg.data <= checker_reg.data;
            /* Put data straight into the shift register */
            end else begin
                reg_list[0].s <= R_SEARCHING;
                reg_list[0].data <= checker_reg.data;
            end
        end

        /* Place the backlogged feature into the shift register */
        if(temp_used && !feature_flag) begin
            reg_list[0] <= temp_reg;
            temp_used <= 0;
        end

        /* Pass through clean and empty data if the shift reg is not in use */
        if(
        !(feature_flag ||
        (!feature_flag && checker_reg.s == R_DEFAULT) ||
        (temp_used && !feature_flag))) begin
            reg_list[0] <= clean_reg;
        end
    end

    /* Shift the registers not shifted by the library adder/swapper */
    always @(posedge clk) begin
        reg_list[DCD:1] <= reg_list[DCD-1:0];
    end

    /* Loops through the found matches and passes them out sequentially */
    always @(posedge clk) begin
        /* If data is ready to be passed out */
        if(match_list[out_k].occupied) begin
            match_flag <= 1;
            match_list[out_k].occupied <= 0;
            match_xs <= lib_list[out_k].data.x;
            match_ys <= lib_list[out_k].data.y;
            match_xe <= match_list[out_k].xe;
            match_ye <= match_list[out_k].ye;
            match_span <= lib_list[out_k].cf;
        end else begin
            /* Release control to the library THIS BREAKS SIMULATION */
            // match_list[out_k].occupied <= 1'bZ;
            match_flag <= 0;
        end
        /* Increment the counter and wrap back to 0 */
        out_k <= (out_k == LE-1) ? 0 : out_k + 1;
    end

    /* Adding/Swapping/Matching features in library */
    always @(posedge clk) begin
        for(integer i = 0; i < LE; i = i+1) begin
            /* Perform library upkeeping operations when a new frame is detected */
            if(new_frame) begin
                if(lib_list[i].s == L_OCCUPIED || lib_list[i].s == L_NEW) begin
                    /* Increment frame counters when a new frame starts */
                    lib_list[i].cf <= lib_list[i].cf + 1;
                    lib_list[i].mf <= lib_list[i].mf + 1;
                    /* Confirm the features state within the library at the end of the frame */
                    /* Remove frames from library if they have expired */
                    lib_list[i].s <= (lib_list[i].mf == MMF-1) ? L_EMPTY : L_OCCUPIED;
                end
                /* Shifts the shift register elements that are touched by the processor*/
                reg_list[i+DCD+1] <= reg_list[i+DCD]; // Shift reg values
            end
            /* If a feature needs to be added to or swapped into library */
            else if(
            /* If the register feature is looking to be placed */
            reg_list[i+DCD].s == R_SEARCHING &&
            /* If there is a free spot in the library or a better feature was found in the same frame*/
            (lib_list[i].s == L_EMPTY || (lib_list[i].s == L_NEW && lib_list[i].data.s < reg_list[i+DCD].data.s))) begin
                /* Set up the library entry */
                lib_list[i].s <= L_NEW;
                lib_list[i].cf <= 0;
                lib_list[i].mf <= 0;
                lib_list[i].data <= reg_list[i+DCD].data;
                /* Swap out the data (lib data garbage if L_EMPTY) */
                reg_list[i+DCD+1].data <= lib_list[i].data; // Shift reg values
                /* Keep register searching if it was a swap out (L_NEW) and not just a placement (L_EMPTY) */
                reg_list[i+DCD+1].s <= (lib_list[i].s == L_EMPTY) ? R_EMPTY : R_SEARCHING; // Shift reg values
            /* If a match has been found */
            end else if(
            /* If the register feature is looking for a match */
            (reg_list[i+DCD].s == R_DEFAULT || reg_list[i+DCD].s == R_SIMILAR) &&
            /* If the library has a feature to match */
            lib_list[i].s == L_OCCUPIED) begin
                /* If the descriptors are a match */
                if(hamming_dist[i] < MATCH_THRESHOLD) begin
                    /* Deactivate the register */
                    reg_list[i+DCD+1].s <= R_EMPTY; // Shift reg values
                    /* Number of missed frames is reset */
                    lib_list[i].mf <= 0;
                    /* Output the match */
                    if(!match_list[i].occupied) begin
                        match_list[i].occupied <= 1;
                        match_list[i].xe <= reg_list[i+DCD].data.x;
                        match_list[i].ye <= reg_list[i+DCD].data.y;
                    end else begin
                        /* Release control to the feature output system THIS BREAKS SIMULATION */
                        // match_list[out_k].occupied <= 1'bZ;
                    end
                /* Flags if detected features are too similar to the ones in the library */
                end else if(hamming_dist[i] < SIMILAR_THRESHOLD) begin
                    reg_list[i+DCD+1].s <= R_SIMILAR;
                    reg_list[i+DCD+1].data <= reg_list[i+DCD].data;
                /* Shift the register values as normal */
                end else begin
                    reg_list[i+DCD+1] <= reg_list[i+DCD];
                end
            /* Shift the register values as normal */
            end else begin
                reg_list[i+DCD+1] <= reg_list[i+DCD]; // Shift reg values
            end
        end
    end

endmodule

