`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/14/2026 02:55:26 PM
// Design Name: 
// Module Name: data_mem_tb
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


module tb_data_mem;

    // Inputs
    reg clk;
    reg mem_read;
    reg mem_write;
    reg [31:0] address;
    reg [31:0] data_in;

    // Output
    wire [31:0] data_out;

    // Instantiate DUT (Device Under Test)
    data_mem uut (
        .clk(clk),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .address(address),
        .data_in(data_in),
        .data_out(data_out)
    );



    // -----------------------------
    // Clock Generation (10ns period)
    // -----------------------------
    always #5 clk = ~clk;

    // -----------------------------
    // Test Procedure
    // -----------------------------
    initial begin
       $monitor("Time=%0t | clk=%b | wr=%b | rd=%b | addr=%h | din=%h | dout=%h",
                  $time, clk, mem_write, mem_read, address, data_in, data_out);

        // Initialize signals
        clk = 0;
        mem_read = 0;
        mem_write = 0;
        address = 0;
        data_in = 0;

        // Wait a little
        #10;

        // =====================================================
        // WRITE OPERATION TEST
        // =====================================================
        mem_write = 1;
        address = 32'd100;
        data_in = 32'hA1B2C3D4;

        #10;  // wait for one clock edge

        mem_write = 0;

        // =====================================================
        // READ OPERATION TEST
        // =====================================================
        mem_read = 1;
        address = 32'd100;

        #10;  // wait for one clock edge

        mem_read = 0;

        
        // =====================================================
        // Another Test Case
        // =====================================================
        #10;

        mem_write = 1;
        address = 32'd200;
        data_in = 32'h11223344;

        #10;

        mem_write = 0;
        mem_read = 1;
        address = 32'd200;

        #10;

        

        // End simulation
        #20;
        $finish;

    end

endmodule
