`timescale 1ns / 1ps

/* This module uses a binary adder tree to count the number
of set bits within a bit vector */
module binary_adder_tree #(
        parameter W = 128,  // Width of the binary array
        parameter SW = 8    // Width of the summation result
    )(
        input clk,
        input wire [W-1:0] value,
        output wire [SW-1:0] result
    );

    /* Number of adder registers required = W-1 */
    localparam SZ = W-1;
    reg [SZ-1:0] [SW-1:0] pipeline = {SZ{{SW{1'b0}}}};

    /* Passes adder pipeline result to the output */
    assign result = pipeline[0];

    /* Generate the adders */
    generate
        genvar i, j;
        /* For each of the row starting positions */
        for(i=W; i>1; i=i/2) begin : adder_gen_loop
            localparam s = i/2;
            /* For each element in the current adder tree row */
            for(j=0; j<s; j=j+1) begin: adder_assign_loop
                if(i == W) begin
                    // First set of pipeline connects the the actual input
                    always @(posedge clk) begin
                        pipeline[s+j-1] <= value[2*j] + value[2*j+1];
                    end
                end else begin
                    // Successive pipelines connect to stages of the pipeline
                    always @(posedge clk) begin
                        pipeline[s+j-1] <= pipeline[i+2*j-1] + pipeline[i+2*j];
                    end
                end
            end
        end
    endgenerate

endmodule