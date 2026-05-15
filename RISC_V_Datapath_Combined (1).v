`timescale 1ns / 1ps

//====================================================================
//  RISC-V Datapath — Combined Source File
//  Modules included (in order):
//    1. program_counter
//    2. INST_MEM
//    3. REG_FILE
//    4. ALU_Control          <- NEW
//    5. ALU
//    6. data_mem
//    7. RISC_V_Datapath      <- Top-level integration module
//    8. tb_ALU_Control       <- Standalone ALU Control testbench
//    9. tb_RISC_V_Datapath   <- Full datapath testbench
//====================================================================


////////////////////////////////////////////////////////////////////
//  1. PROGRAM COUNTER
////////////////////////////////////////////////////////////////////
module program_counter (
    input             clk,
    input             reset,
    output reg [31:0] count
);
    always @(posedge clk) begin
        if (reset)
            count <= 32'b0;
        else
            count <= count + 4;
    end
endmodule


////////////////////////////////////////////////////////////////////
//  2. INSTRUCTION MEMORY
//     Byte-addressable, 32-byte, loaded on reset.
////////////////////////////////////////////////////////////////////
module INST_MEM (
    input             clk,
    input             reset,
    input      [31:0] PC,
    output reg [31:0] Instruction_Code
);
    reg [7:0] Memory [31:0];

    always @(posedge clk) begin
        if (reset) begin
            // Instruction 0: add  t1, s0, s1
            Memory[0]  <= 8'h33; Memory[1]  <= 8'h03; Memory[2]  <= 8'h94; Memory[3]  <= 8'h00;
            // Instruction 1: sub  t2, s2, s3
            Memory[4]  <= 8'hb3; Memory[5]  <= 8'h03; Memory[6]  <= 8'h39; Memory[7]  <= 8'h41;
            // Instruction 2: mul  t0, s4, s5
            Memory[8]  <= 8'hb3; Memory[9]  <= 8'h02; Memory[10] <= 8'h5a; Memory[11] <= 8'h03;
            // Instruction 3: xor  t3, s6, s7
            Memory[12] <= 8'h33; Memory[13] <= 8'h4e; Memory[14] <= 8'h7b; Memory[15] <= 8'h01;
            // Instruction 4: sll  t4, s8, s9
            Memory[16] <= 8'hb3; Memory[17] <= 8'h1e; Memory[18] <= 8'h9c; Memory[19] <= 8'h01;
            // Instruction 5: srl  t5, s10, s11
            Memory[20] <= 8'h33; Memory[21] <= 8'h5f; Memory[22] <= 8'hbd; Memory[23] <= 8'h01;
            // Instruction 6: and  t6, a2, a3
            Memory[24] <= 8'hb3; Memory[25] <= 8'h7f; Memory[26] <= 8'hd6; Memory[27] <= 8'h00;
            // Instruction 7: or   a7, a4, a5
            Memory[28] <= 8'hb3; Memory[29] <= 8'h68; Memory[30] <= 8'hf7; Memory[31] <= 8'h00;

            Instruction_Code <= 32'h00000000;
        end
        else begin
            Instruction_Code <= {Memory[PC+3], Memory[PC+2], Memory[PC+1], Memory[PC]};
        end
    end
endmodule


////////////////////////////////////////////////////////////////////
//  3. REGISTER FILE  (32 x 32-bit, x0 hardwired to 0)
////////////////////////////////////////////////////////////////////
module REG_FILE (
    input  [4:0]  read_reg_num1,
    input  [4:0]  read_reg_num2,
    input  [4:0]  write_reg,
    input  [31:0] write_data,
    output [31:0] read_data1,
    output [31:0] read_data2,
    input         regwrite,
    input         clock,
    input         reset
);
    reg [31:0] reg_memory [31:0];

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            reg_memory[0]  <= 32'd0;  reg_memory[1]  <= 32'd1;
            reg_memory[2]  <= 32'd2;  reg_memory[3]  <= 32'd3;
            reg_memory[4]  <= 32'd4;  reg_memory[5]  <= 32'd5;
            reg_memory[6]  <= 32'd6;  reg_memory[7]  <= 32'd7;
            reg_memory[8]  <= 32'd8;  reg_memory[9]  <= 32'd9;
            reg_memory[10] <= 32'd10; reg_memory[11] <= 32'd11;
            reg_memory[12] <= 32'd12; reg_memory[13] <= 32'd13;
            reg_memory[14] <= 32'd14; reg_memory[15] <= 32'd15;
            reg_memory[16] <= 32'd16; reg_memory[17] <= 32'd17;
            reg_memory[18] <= 32'd18; reg_memory[19] <= 32'd19;
            reg_memory[20] <= 32'd20; reg_memory[21] <= 32'd21;
            reg_memory[22] <= 32'd22; reg_memory[23] <= 32'd23;
            reg_memory[24] <= 32'd24; reg_memory[25] <= 32'd25;
            reg_memory[26] <= 32'd26; reg_memory[27] <= 32'd27;
            reg_memory[28] <= 32'd28; reg_memory[29] <= 32'd29;
            reg_memory[30] <= 32'd30; reg_memory[31] <= 32'd31;
        end
        else if (regwrite && (write_reg != 5'd0)) begin
            reg_memory[write_reg] <= write_data;
        end
    end

    assign read_data1 = reg_memory[read_reg_num1];
    assign read_data2 = reg_memory[read_reg_num2];
endmodule


////////////////////////////////////////////////////////////////////
//  4. ALU CONTROL UNIT
//
//  Inputs:
//    ALUOp [1:0]  -- 2-bit signal from the main Control Unit:
//                    2'b00  LW / SW   -> always ADD
//                    2'b01  BEQ       -> always SUB
//                    2'b10  R-type    -> decode funct3 + funct7[5]
//                    2'b11  I-type    -> decode funct3 only
//    funct3 [2:0] -- instruction bits [14:12]
//    funct7_5     -- instruction bit  [30]  (funct7[5])
//
//  Output:
//    alu_control [2:0] -- operation sent to the ALU:
//      3'b000  AND
//      3'b001  OR
//      3'b010  ADD
//      3'b011  EQ  (0 if equal, 1 otherwise)
//      3'b100  XOR
//      3'b101  SLL
//      3'b110  SUB
//      3'b111  SRL
////////////////////////////////////////////////////////////////////
module ALU_Control (
    input      [1:0] ALUOp,
    input      [2:0] funct3,
    input            funct7_5,
    output reg [2:0] alu_control
);
    always @(*) begin
        case (ALUOp)

            // LW / SW -- always ADD to compute memory address
            2'b00: alu_control = 3'b010;

            // BEQ -- always SUB; zero_flag==1 means branch taken
            2'b01: alu_control = 3'b110;

            // R-type -- decode from funct3 and funct7[5]
            2'b10: begin
                case (funct3)
                    3'b000: alu_control = funct7_5 ? 3'b110 : 3'b010; // SUB : ADD
                    3'b001: alu_control = 3'b101; // SLL
                    3'b010: alu_control = 3'b011; // SLT  (EQ slot)
                    3'b100: alu_control = 3'b100; // XOR
                    3'b101: alu_control = 3'b111; // SRL / SRA
                    3'b110: alu_control = 3'b001; // OR
                    3'b111: alu_control = 3'b000; // AND
                    default: alu_control = 3'b010;
                endcase
            end

            // I-type ALU (addi, xori, ori, andi, slli, srli)
            2'b11: begin
                case (funct3)
                    3'b000: alu_control = 3'b010; // ADDI
                    3'b001: alu_control = 3'b101; // SLLI
                    3'b100: alu_control = 3'b100; // XORI
                    3'b101: alu_control = 3'b111; // SRLI / SRAI
                    3'b110: alu_control = 3'b001; // ORI
                    3'b111: alu_control = 3'b000; // ANDI
                    default: alu_control = 3'b010;
                endcase
            end

            default: alu_control = 3'b010;
        endcase
    end
endmodule


////////////////////////////////////////////////////////////////////
//  5. ALU
//     Extended: AND / OR / ADD / EQ / XOR / SLL / SUB / SRL
////////////////////////////////////////////////////////////////////
module ALU (
    input      [31:0] in1,
    input      [31:0] in2,
    input      [2:0]  alu_control,
    output reg [31:0] result,
    output reg        zero_flag
);
    always @(*) begin
        result = 32'b0;
        case (alu_control)
            3'b000: result = in1 & in2;                       // AND
            3'b001: result = in1 | in2;                       // OR
            3'b010: result = in1 + in2;                       // ADD
            3'b011: result = (in1 == in2) ? 32'b0 : 32'b1;   // EQ
            3'b100: result = in1 ^ in2;                       // XOR
            3'b101: result = in1 << in2[4:0];                 // SLL
            3'b110: result = in1 - in2;                       // SUB
            3'b111: result = in1 >> in2[4:0];                 // SRL
            default: result = 32'b0;
        endcase
        zero_flag = (result == 32'b0) ? 1'b1 : 1'b0;
    end
endmodule


////////////////////////////////////////////////////////////////////
//  6. DATA MEMORY  (1 KB, byte-addressable, little-endian)
////////////////////////////////////////////////////////////////////
module data_mem (
    input         clk,
    input         mem_read,
    input         mem_write,
    input  [31:0] address,
    input  [31:0] data_in,
    output reg [31:0] data_out
);
    reg [7:0] memory [1023:0];

    always @(posedge clk) begin
        if (mem_write) begin
            memory[address]     <= data_in[7:0];
            memory[address + 1] <= data_in[15:8];
            memory[address + 2] <= data_in[23:16];
            memory[address + 3] <= data_in[31:24];
        end
        if (mem_read) begin
            data_out[7:0]   <= memory[address];
            data_out[15:8]  <= memory[address + 1];
            data_out[23:16] <= memory[address + 2];
            data_out[31:24] <= memory[address + 3];
        end
    end
endmodule


////////////////////////////////////////////////////////////////////
//  7. TOP-LEVEL  --  RISC_V_Datapath
//
//  Full datapath with ALU Control Unit:
//
//  PC --> INST_MEM --> decode: rs1, rs2, rd, funct3, funct7_5, opcode
//                                               |
//                             opcode --> ALUOp (inline control)
//                                               |
//                                        ALU_Control <-- funct3, funct7_5
//                                               |
//                                         alu_control[2:0]
//                                               |
//      REG_FILE --> in1, in2 ---------------> ALU --> result --> WB MUX
//                                                           |
//                                                      data_mem (lw/sw)
////////////////////////////////////////////////////////////////////
module RISC_V_Datapath (
    input clk,
    input reset
);

    // --- 1. Program Counter ---
    wire [31:0] PC;
    program_counter PC_inst (
        .clk   (clk),
        .reset (reset),
        .count (PC)
    );

    // --- 2. Instruction Memory ---
    wire [31:0] instruction;
    INST_MEM IMEM_inst (
        .clk              (clk),
        .reset            (reset),
        .PC               (PC),
        .Instruction_Code (instruction)
    );

    // --- 3. Instruction Decode ---
    wire [6:0] opcode   = instruction[6:0];
    wire [4:0] rd       = instruction[11:7];
    wire [2:0] funct3   = instruction[14:12];
    wire [4:0] rs1      = instruction[19:15];
    wire [4:0] rs2      = instruction[24:20];
    wire       funct7_5 = instruction[30];

    // --- 4. Inline Control (ALUOp + data-path enables) ---
    wire is_rtype = (opcode == 7'b0110011);
    wire is_lw    = (opcode == 7'b0000011);
    wire is_sw    = (opcode == 7'b0100011);
    wire is_beq   = (opcode == 7'b1100011);
    wire is_itype = (opcode == 7'b0010011);

    wire [1:0] ALUOp;
    assign ALUOp = is_rtype ? 2'b10 :
                   is_beq   ? 2'b01 :
                   is_itype ? 2'b11 :
                               2'b00;  // LW / SW / default

    wire regwrite_en  = is_rtype | is_lw | is_itype;
    wire mem_read_en  = is_lw;
    wire mem_write_en = is_sw;

    // --- 5. Register File ---
    wire [31:0] reg_read1, reg_read2, reg_write_data;
    REG_FILE REGFILE_inst (
        .read_reg_num1 (rs1),
        .read_reg_num2 (rs2),
        .write_reg     (rd),
        .write_data    (reg_write_data),
        .read_data1    (reg_read1),
        .read_data2    (reg_read2),
        .regwrite      (regwrite_en),
        .clock         (clk),
        .reset         (reset)
    );

    // --- 6. ALU Control Unit ---
    wire [2:0] alu_ctrl;
    ALU_Control ALUCTL_inst (
        .ALUOp       (ALUOp),
        .funct3      (funct3),
        .funct7_5    (funct7_5),
        .alu_control (alu_ctrl)
    );

    // --- 7. ALU ---
    wire [31:0] alu_result;
    wire        alu_zero;
    ALU ALU_inst (
        .in1         (reg_read1),
        .in2         (reg_read2),
        .alu_control (alu_ctrl),
        .result      (alu_result),
        .zero_flag   (alu_zero)
    );

    // --- 8. Data Memory ---
    wire [31:0] mem_data_out;
    data_mem DMEM_inst (
        .clk       (clk),
        .mem_read  (mem_read_en),
        .mem_write (mem_write_en),
        .address   (alu_result),
        .data_in   (reg_read2),
        .data_out  (mem_data_out)
    );

    // --- 9. Write-back MUX ---
    assign reg_write_data = mem_read_en ? mem_data_out : alu_result;

    // --- 10. Debug monitor (remove for synthesis) ---
    always @(posedge clk) begin
        if (!reset) begin
            $display(
                "Time=%0t | PC=%0d | Instr=0x%08h | opcode=%07b | ALUOp=%02b | funct3=%03b | funct7_5=%b | alu_ctrl=%03b | rs1=x%0d(%0d) | rs2=x%0d(%0d) | rd=x%0d | ALU_result=%0d | zero=%b",
                $time, PC, instruction, opcode, ALUOp,
                funct3, funct7_5, alu_ctrl,
                rs1, reg_read1, rs2, reg_read2,
                rd, alu_result, alu_zero
            );
        end
    end

endmodule


////////////////////////////////////////////////////////////////////
//  8. TESTBENCH -- ALU Control Unit (standalone unit test)
////////////////////////////////////////////////////////////////////
module tb_ALU_Control;

    reg  [1:0] ALUOp;
    reg  [2:0] funct3;
    reg        funct7_5;
    wire [2:0] alu_control;

    ALU_Control DUT (
        .ALUOp       (ALUOp),
        .funct3      (funct3),
        .funct7_5    (funct7_5),
        .alu_control (alu_control)
    );

    // Helper task
    task test_case;
        input [1:0]  op;
        input [2:0]  f3;
        input        f7;
        input [2:0]  expected;
        input [8*10-1:0] name;
        begin
            ALUOp    = op;
            funct3   = f3;
            funct7_5 = f7;
            #5;
            if (alu_control === expected)
                $display("PASS | %-10s | ALUOp=%02b funct3=%03b funct7_5=%b -> alu_ctrl=%03b",
                         name, op, f3, f7, alu_control);
            else
                $display("FAIL | %-10s | ALUOp=%02b funct3=%03b funct7_5=%b -> got=%03b expected=%03b",
                         name, op, f3, f7, alu_control, expected);
        end
    endtask

    initial begin
        $display("======== ALU Control Unit Testbench ========");

        // LW / SW → ADD
        test_case(2'b00, 3'b000, 1'b0, 3'b010, "LW/SW");

        // BEQ → SUB
        test_case(2'b01, 3'b000, 1'b0, 3'b110, "BEQ");

        // R-type
        test_case(2'b10, 3'b000, 1'b0, 3'b010, "R-ADD");
        test_case(2'b10, 3'b000, 1'b1, 3'b110, "R-SUB");
        test_case(2'b10, 3'b001, 1'b0, 3'b101, "R-SLL");
        test_case(2'b10, 3'b100, 1'b0, 3'b100, "R-XOR");
        test_case(2'b10, 3'b101, 1'b0, 3'b111, "R-SRL");
        test_case(2'b10, 3'b110, 1'b0, 3'b001, "R-OR");
        test_case(2'b10, 3'b111, 1'b0, 3'b000, "R-AND");

        // I-type
        test_case(2'b11, 3'b000, 1'b0, 3'b010, "I-ADDI");
        test_case(2'b11, 3'b001, 1'b0, 3'b101, "I-SLLI");
        test_case(2'b11, 3'b100, 1'b0, 3'b100, "I-XORI");
        test_case(2'b11, 3'b101, 1'b0, 3'b111, "I-SRLI");
        test_case(2'b11, 3'b110, 1'b0, 3'b001, "I-ORI");
        test_case(2'b11, 3'b111, 1'b0, 3'b000, "I-ANDI");

        $display("============================================");
        $finish;
    end
endmodule


////////////////////////////////////////////////////////////////////
//  9. TESTBENCH -- Full integrated datapath
////////////////////////////////////////////////////////////////////
module tb_RISC_V_Datapath;

    reg clk;
    reg reset;

    RISC_V_Datapath DUT (
        .clk   (clk),
        .reset (reset)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        reset = 1;
        #20;
        reset = 0;
        // 8 instructions x 1 cycle + headroom
        #200;
        $display("Simulation complete.");
        $finish;
    end

endmodule
