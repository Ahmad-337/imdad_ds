`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////
//  ALU CONTROL UNIT
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
//      3'b011  EQ  (result=0 if equal, 1 otherwise)
//      3'b100  XOR
//      3'b101  SLL (shift left logical)
//      3'b110  SUB
//      3'b111  SRL (shift right logical)
////////////////////////////////////////////////////////////////////

module ALU_Control (
    input      [1:0] ALUOp,
    input      [2:0] funct3,
    input            funct7_5,
    output reg [2:0] alu_control
);
    always @(*) begin
        case (ALUOp)

            // --------------------------------------------------
            // 2'b00 : LW / SW -- always ADD (base + offset)
            // --------------------------------------------------
            2'b00: alu_control = 3'b010;

            // --------------------------------------------------
            // 2'b01 : BEQ -- always SUB (zero_flag=1 -> branch)
            // --------------------------------------------------
            2'b01: alu_control = 3'b110;

            // --------------------------------------------------
            // 2'b10 : R-type -- decode funct3 and funct7[5]
            // --------------------------------------------------
            2'b10: begin
                case (funct3)
                    3'b000: alu_control = funct7_5 ? 3'b110 : 3'b010; // SUB : ADD
                    3'b001: alu_control = 3'b101; // SLL
                    3'b010: alu_control = 3'b011; // SLT  (uses EQ slot)
                    3'b100: alu_control = 3'b100; // XOR
                    3'b101: alu_control = 3'b111; // SRL / SRA
                    3'b110: alu_control = 3'b001; // OR
                    3'b111: alu_control = 3'b000; // AND
                    default: alu_control = 3'b010; // default ADD
                endcase
            end

            // --------------------------------------------------
            // 2'b11 : I-type (addi, xori, ori, andi, slli, srli)
            //         funct7[5] is part of the immediate, ignore it
            // --------------------------------------------------
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

            default: alu_control = 3'b010; // fallback ADD
        endcase
    end
endmodule
