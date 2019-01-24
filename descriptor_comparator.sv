`timescale 1ns / 1ps

/* Computes the hamming distance between two descriptors */
module descriptor_comparator #(
        localparam DW = 128, // Descriptor Bit Width
        localparam SW = 8    // Width of register that holds hamming distance (suggested log_2(DW)+1)
    )(
        input clk,
        input wire [DW-1:0] a,
        input wire [DW-1:0] b,
        output reg [SW-1:0] distance
    );

    /* XOR of the two descriptors */
    reg [DW-1:0] hxor = {DW{1'b0}};

    /* 6-input lookup table */
    reg [2:0] hlut [63:0] = '{
        6, 5, 5, 4, 5, 4, 4, 3, 5, 4, 4, 3, 4, 3, 3, 2,
        5, 4, 4, 3, 4, 3, 3, 2, 4, 3, 3, 2, 3, 2, 2, 1,
        5, 4, 4, 3, 4, 3, 3, 2, 4, 3, 3, 2, 3, 2, 2, 1,
        4, 3, 3, 2, 3, 2, 2, 1, 3, 2, 2, 1, 2, 1, 1, 0
    };

    /* Adder tree rows in format [count][bits] */
    reg [10:0][3:0] ra = {11{4'b0}};
    reg [05:0][4:0] rb = {06{5'b0}};
    reg [02:0][5:0] rc = {03{6'b0}};
    reg [01:0][6:0] rd = {02{7'b0}};

    /* Perform the XOR operation */
    always @(posedge clk) begin
        hxor <= a ^ b;
    end

    /* Computes hamming distance using 22 LUTS followed by an adder tree */
    always @(posedge clk) begin
        /* Top row using 6-input LUTS */
        ra[10] <= hlut[hxor[127:122]] + hlut[hxor[121:116]];
        ra[09] <= hlut[hxor[115:110]] + hlut[hxor[109:104]];
        ra[08] <= hlut[hxor[103:098]] + hlut[hxor[097:092]];
        ra[07] <= hlut[hxor[091:086]] + hlut[hxor[085:080]];
        ra[06] <= hlut[hxor[079:074]] + hlut[hxor[073:068]];
        ra[05] <= hlut[hxor[067:062]] + hlut[hxor[061:056]];
        ra[04] <= hlut[hxor[055:050]] + hlut[hxor[049:044]];
        ra[03] <= hlut[hxor[043:038]] + hlut[hxor[037:032]];
        ra[02] <= hlut[hxor[031:026]] + hlut[hxor[025:020]];
        ra[01] <= hlut[hxor[019:014]] + hlut[hxor[013:008]];
        ra[00] <= hlut[hxor[007:002]] + hlut[hxor[001:000]];
        /* Row 2 */
        rb[05] <= ra[10];
        rb[04] <= ra[9] + ra[8];
        rb[03] <= ra[7] + ra[6];
        rb[02] <= ra[5] + ra[4];
        rb[01] <= ra[3] + ra[2];
        rb[00] <= ra[1] + ra[0];
        /* Row 3 */
        rc[02] <= rb[5] + rb[4];
        rc[01] <= rb[3] + rb[2];
        rc[00] <= rb[1] + rb[0];
        /* Row 4 */
        rd[01] <= rc[2];
        rd[00] <= rc[1] + rc[0];
        /* Row 6 */
        distance <= rd[1] + rd[0];
    end

endmodule