`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/14/2026 02:49:35 PM
// Design Name: 
// Module Name: Data_Memory_32bit
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module data_mem (
    input clk,                // clock signal
    input mem_read,           // read enable
    input mem_write,          // write enable
    input [31:0] address,     // byte address
    input [31:0] data_in,     // data to write
    output reg [31:0] data_out // data read
);

    // 1 KB byte-addressable memory
    reg [7:0] memory [1023:0];

    always @(posedge clk) begin

        // -------------------------
        // WRITE OPERATION
        // -------------------------
        if (mem_write) begin
            memory[address]     <= data_in[7:0];
            memory[address + 1] <= data_in[15:8];
            memory[address + 2] <= data_in[23:16];
            memory[address + 3] <= data_in[31:24];
        end

        // -------------------------
        // READ OPERATION
        // -------------------------
        if (mem_read) begin                                      // READ only if not writing else if (Best Practice (Industry Style)
        // -------------------------
            data_out[7:0]   <= memory[address];
            data_out[15:8]  <= memory[address + 1];
            data_out[23:16] <= memory[address + 2];
            data_out[31:24] <= memory[address + 3];
        end

    end

endmodule


