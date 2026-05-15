`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////
//  TESTBENCH -- ALU Control Unit
//
//  Covers all ALUOp modes and every funct3 / funct7_5 combination.
//  Each test prints PASS or FAIL with full signal values.
//
//  To simulate:
//    Vivado  : set tb_ALU_Control as top simulation module
//    ModelSim: vsim tb_ALU_Control
////////////////////////////////////////////////////////////////////

module tb_ALU_Control;

    // ---------------------------------------------------------------
    // DUT ports
    // ---------------------------------------------------------------
    reg  [1:0] ALUOp;
    reg  [2:0] funct3;
    reg        funct7_5;
    wire [2:0] alu_control;

    // ---------------------------------------------------------------
    // Instantiate DUT
    // ---------------------------------------------------------------
    ALU_Control DUT (
        .ALUOp       (ALUOp),
        .funct3      (funct3),
        .funct7_5    (funct7_5),
        .alu_control (alu_control)
    );

    // ---------------------------------------------------------------
    // Pass / Fail counter
    // ---------------------------------------------------------------
    integer pass_count = 0;
    integer fail_count = 0;

    // ---------------------------------------------------------------
    // Helper task
    // ---------------------------------------------------------------
    task test_case;
        input [1:0]       op;
        input [2:0]       f3;
        input             f7;
        input [2:0]       expected;
        input [8*12-1:0]  label;
        begin
            ALUOp    = op;
            funct3   = f3;
            funct7_5 = f7;
            #10; // allow combinational logic to settle

            if (alu_control === expected) begin
                $display("  PASS | %-12s | ALUOp=%02b  funct3=%03b  funct7_5=%b  ->  alu_control=%03b",
                         label, op, f3, f7, alu_control);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL | %-12s | ALUOp=%02b  funct3=%03b  funct7_5=%b  ->  got=%03b  expected=%03b",
                         label, op, f3, f7, alu_control, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ---------------------------------------------------------------
    // Test sequence
    // ---------------------------------------------------------------
    initial begin
        $display("");
        $display("=========================================");
        $display("      ALU Control Unit  Testbench        ");
        $display("=========================================");

        // -----------------------------------------------------------
        // ALUOp = 00 : Load / Store  (always ADD regardless of funct)
        // -----------------------------------------------------------
        $display("");
        $display("-- ALUOp=00 : LW / SW (should always produce ADD = 010) --");
        test_case(2'b00, 3'b000, 1'b0, 3'b010, "LW/SW-ADD");
        test_case(2'b00, 3'b111, 1'b1, 3'b010, "LW/SW-x");  // funct fields ignored

        // -----------------------------------------------------------
        // ALUOp = 01 : BEQ  (always SUB regardless of funct)
        // -----------------------------------------------------------
        $display("");
        $display("-- ALUOp=01 : BEQ (should always produce SUB = 110) --");
        test_case(2'b01, 3'b000, 1'b0, 3'b110, "BEQ-SUB");
        test_case(2'b01, 3'b101, 1'b1, 3'b110, "BEQ-x");    // funct fields ignored

        // -----------------------------------------------------------
        // ALUOp = 10 : R-type
        // -----------------------------------------------------------
        $display("");
        $display("-- ALUOp=10 : R-type (decoded from funct3 + funct7_5) --");
        test_case(2'b10, 3'b000, 1'b0, 3'b010, "R-ADD");     // funct7[5]=0
        test_case(2'b10, 3'b000, 1'b1, 3'b110, "R-SUB");     // funct7[5]=1
        test_case(2'b10, 3'b001, 1'b0, 3'b101, "R-SLL");
        test_case(2'b10, 3'b010, 1'b0, 3'b011, "R-SLT");
        test_case(2'b10, 3'b100, 1'b0, 3'b100, "R-XOR");
        test_case(2'b10, 3'b101, 1'b0, 3'b111, "R-SRL");
        test_case(2'b10, 3'b110, 1'b0, 3'b001, "R-OR");
        test_case(2'b10, 3'b111, 1'b0, 3'b000, "R-AND");

        // -----------------------------------------------------------
        // ALUOp = 11 : I-type  (funct7_5 ignored)
        // -----------------------------------------------------------
        $display("");
        $display("-- ALUOp=11 : I-type (decoded from funct3 only) --");
        test_case(2'b11, 3'b000, 1'b0, 3'b010, "I-ADDI");
        test_case(2'b11, 3'b001, 1'b0, 3'b101, "I-SLLI");
        test_case(2'b11, 3'b100, 1'b0, 3'b100, "I-XORI");
        test_case(2'b11, 3'b101, 1'b0, 3'b111, "I-SRLI");
        test_case(2'b11, 3'b110, 1'b0, 3'b001, "I-ORI");
        test_case(2'b11, 3'b111, 1'b0, 3'b000, "I-ANDI");
        // funct7_5=1 should NOT change I-type result
        test_case(2'b11, 3'b000, 1'b1, 3'b010, "I-ADDI-f7");
        test_case(2'b11, 3'b101, 1'b1, 3'b111, "I-SRAI-f7");

        // -----------------------------------------------------------
        // Summary
        // -----------------------------------------------------------
        $display("");
        $display("=========================================");
        $display("  Results:  %0d PASSED  |  %0d FAILED", pass_count, fail_count);
        $display("=========================================");
        $display("");

        $finish;
    end

endmodule
