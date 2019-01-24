`timescale 1ns / 1ps

/* Generates a 128-bit binary descriptor from a 9x9 pixel window */

module feature_descriptor
    #(
        parameter BW = 8,           // Pixel value Bit Width
        localparam DW = 128         // Descriptor width
    )(
        input clk,
        input wire [8:0] [8:0] [BW-1:0] px_window,
        output reg [DW-1:0] descriptor
    );

    localparam NODES = 17;
    wire [NODES-1:0] [BW-1:0] node;    // Vector containing all relevent pixels


    /* Remap the relevent points in the 9x9 window to a vector */
    assign node = {
        /* Outer Nodes */
        px_window[00][03], px_window[00][05], px_window[01][07], px_window[04][08],
        px_window[07][07], px_window[08][05], px_window[08][03], px_window[07][01],
        px_window[04][00], px_window[01][01],
        /* Middle Nodes */
        px_window[02][04], px_window[03][06], px_window[05][06], px_window[06][04],
        px_window[05][02], px_window[03][02],
        /* Center Node */
        px_window[04][04]
    };

    /* Clear the descriptor */
    initial begin
        descriptor[DW-1:0] = {DW{1'b0}};
    end

    /* Generate the descriptor */
    always @(posedge clk) begin
        descriptor[DW-1:0] <= {
            node[16] > node[05], node[07] > node[00], node[15] > node[07], node[03] > node[04], 
            node[14] > node[04], node[01] > node[05], node[02] > node[10], node[02] > node[08], 
            node[12] > node[15], node[09] > node[02], node[08] > node[11], node[05] > node[12], 
            node[13] > node[16], node[10] > node[11], node[13] > node[04], node[06] > node[11], 
            node[08] > node[03], node[09] > node[00], node[10] > node[07], node[01] > node[08], 
            node[13] > node[07], node[04] > node[10], node[05] > node[09], node[00] > node[12], 
            node[09] > node[07], node[11] > node[13], node[15] > node[04], node[14] > node[02], 
            node[11] > node[16], node[08] > node[05], node[14] > node[13], node[01] > node[10], 
            node[15] > node[08], node[00] > node[14], node[07] > node[02], node[16] > node[09], 
            node[08] > node[09], node[15] > node[06], node[06] > node[04], node[03] > node[14], 
            node[07] > node[14], node[10] > node[09], node[06] > node[09], node[01] > node[14], 
            node[09] > node[03], node[11] > node[07], node[01] > node[02], node[08] > node[13], 
            node[03] > node[15], node[14] > node[16], node[05] > node[04], node[08] > node[04], 
            node[00] > node[11], node[11] > node[02], node[01] > node[04], node[00] > node[01], 
            node[03] > node[05], node[11] > node[14], node[07] > node[08], node[13] > node[05], 
            node[00] > node[15], node[03] > node[02], node[06] > node[14], node[15] > node[16], 
            node[11] > node[05], node[15] > node[13], node[09] > node[04], node[08] > node[14], 
            node[06] > node[12], node[04] > node[00], node[02] > node[05], node[07] > node[05], 
            node[06] > node[13], node[07] > node[16], node[11] > node[01], node[16] > node[03], 
            node[07] > node[12], node[12] > node[14], node[02] > node[06], node[16] > node[00], 
            node[09] > node[01], node[00] > node[06], node[00] > node[13], node[07] > node[03], 
            node[09] > node[13], node[06] > node[07], node[02] > node[00], node[02] > node[16], 
            node[11] > node[09], node[16] > node[01], node[11] > node[04], node[01] > node[13], 
            node[09] > node[12], node[00] > node[05], node[15] > node[11], node[10] > node[03], 
            node[15] > node[09], node[12] > node[02], node[00] > node[08], node[13] > node[03], 
            node[06] > node[01], node[04] > node[07], node[09] > node[14], node[10] > node[15], 
            node[12] > node[04], node[03] > node[00], node[01] > node[15], node[13] > node[12], 
            node[02] > node[15], node[05] > node[06], node[05] > node[10], node[10] > node[06], 
            node[13] > node[10], node[05] > node[15], node[13] > node[02], node[01] > node[03], 
            node[12] > node[01], node[11] > node[03], node[12] > node[16], node[06] > node[08], 
            node[15] > node[14], node[10] > node[00], node[07] > node[01], node[16] > node[08], 
            node[10] > node[14], node[08] > node[10], node[04] > node[16], node[14] > node[05]
        };
    end

endmodule