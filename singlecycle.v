// ============================================================
//  Basic Single-Cycle RISC-V CPU
//  Supports: ADD, SUB, AND, OR (R-type)
//            LW (load word), SW (store word)
//            BEQ (branch if equal)
//
//  Instruction Memory : 1 KB  → 10-bit address
//  Word-addressed data RAM        : 16 KB → 14-bit address
// ============================================================


// ============================================================
// TOP MODULE
// ============================================================
module riscv_top (
    input  clk,
    input  reset
);

    // ── Next-PC path signals ────────────────────────────────
    wire [31:0] core_pc;
    wire [31:0] next_core_pc;
    wire [31:0] pc_step4;
    wire [31:0] branch_addr;
    wire        do_branch;

    assign pc_step4     = core_pc + 4;
    assign do_branch = branch_en & is_zero;
    assign next_core_pc      = do_branch ? branch_addr : pc_step4;

    // ── PC Register ──────────────────────────────────────────
    PC pc_reg (
        .clk   (clk),
        .reset (reset),
        .pc_d (next_core_pc),
        .pc_q(core_pc)
    );

    // ── Instruction Memory ───────────────────────────────────
    wire [31:0] inst_word;

    instr_mem imem (
        .byte_addr (core_pc[9:0]),
        .inst_out(inst_word)
    );

    // ── Decoded instruction fields ───────────────────────────────────
    wire [6:0] op_bits = inst_word[6:0];
    wire [4:0] dest_idx     = inst_word[11:7];
    wire [2:0] f3_bits = inst_word[14:12];
    wire [4:0] src1_idx    = inst_word[19:15];
    wire [4:0] src2_idx    = inst_word[24:20];
    wire [6:0] f7_bits = inst_word[31:25];

    // ── Control Unit ─────────────────────────────────────────
    wire       reg_wr_en;
    wire       mem_rd_en;
    wire       mem_wr_en;
    wire       wb_from_mem;
    wire       alu_uses_imm;
    wire       branch_en;
    wire [1:0] alu_mode;

    control ctrl (
        .op_bits  (op_bits),
        .reg_wr_en(reg_wr_en),
        .mem_rd_en (mem_rd_en),
        .mem_wr_en(mem_wr_en),
        .wb_from_mem(wb_from_mem),
        .alu_uses_imm  (alu_uses_imm),
        .branch_en  (branch_en),
        .alu_mode   (alu_mode)
    );

    // ── General-purpose register bank ────────────────────────────────────────
    wire [31:0] src1_data;
    wire [31:0] src2_data;
    wire [31:0] wb_data;

    reg_file rf (
        .clk       (clk),
        .reg_wr_en  (reg_wr_en),
        .src1_idx       (src1_idx),
        .src2_idx       (src2_idx),
        .dest_idx        (dest_idx),
        .wb_data(wb_data),
        .src1_data(src1_data),
        .src2_data(src2_data)
    );

    // ── Immediate decode block ──────────────────────────────────
    wire [31:0] imm_value;

    imm_gen ig (
        .inst_word(inst_word),
        .imm_value_out    (imm_value)
    );

    // ── branch_en Target ────────────────────────────────────────
    // imm_value already has bit[0]=0 baked in by imm_gen
    // so NO left shift needed here
    assign branch_addr = core_pc + imm_value;

    // ── ALU Input MUX ────────────────────────────────────────
    wire [31:0] alu_rhs;
    assign alu_rhs = alu_uses_imm ? imm_value : src2_data;

    // ── ALU Control ──────────────────────────────────────────
    wire [3:0] alu_cmd;

    alu_control ac (
        .alu_mode   (alu_mode),
        .f3_bits  (f3_bits),
        .f7_bits  (f7_bits),
        .alu_cmd(alu_cmd)
    );

    // ── ALU ──────────────────────────────────────────────────
    wire [31:0] alu_out;
    wire        is_zero;

    alu alu_unit (
        .a       (src1_data),
        .b       (alu_rhs),
        .alu_cmd(alu_cmd),
        .alu_result_out  (alu_out),
        .zero_flag    (is_zero)
    );

    // ── Word-addressed data RAM ──────────────────────────────────────────
    wire [31:0] data_mem_out;

    data_mem dmem (
        .clk       (clk),
        .mem_rd_en   (mem_rd_en),
        .mem_wr_en  (mem_wr_en),
        .byte_addr      (alu_out[13:0]),
        .wb_data(src2_data),
        .load_data (data_mem_out)
    );

    // ── Result select mux ───────────────────────────────────────
    assign wb_data = wb_from_mem ? data_mem_out : alu_out;

endmodule


// ============================================================
// PROGRAM COUNTER
// ============================================================
module PC (
    input             clk,
    input             reset,
    input      [31:0] pc_d,
    output reg [31:0] pc_q
);
    always @(posedge clk or posedge reset) begin
        if (reset)
            pc_q <= 32'b0;
        else
            pc_q <= pc_d;
    end
endmodule

// ============================================================
// INSTRUCTION MEMORY — 1 KB (256 x 32-bit words)
// ============================================================
module instr_mem (
    input      [9:0]  byte_addr,
    output     [31:0] inst_out
);
    reg [31:0] storage [0:255];

    initial begin
        // --- RISC-V Test Program ---
        // Address | Assembly                 | Action
        // ---------------------------------------------------------
        // 0x00    | lw   x4, 0(x0)           | Load 100 into x4
        // 0x04    | lw   x5, 4(x0)           | Load 200 into x5
        // 0x08    | add  x6, x4, x5          | x6 = 300
        // 0x0C    | sw   x6, 8(x0)           | Store 300 into storage byte_addr 8
        // 0x10    | beq  x4, x4, 8           | branch_en to PC+8 (Skips next inst_out)
        // 0x14    | addi x10, x0, 999        | SKIPPED (x10 should stay 0)
        // 0x18    | addi x11, x0, 42         | TARGET (x11 becomes 42)
        
        storage[0] = 32'h00002203; 
        storage[1] = 32'h00402283; 
        storage[2] = 32'h00520333; 
        storage[3] = 32'h00602423; 
        storage[4] = 32'h00420463; 
        storage[5] = 32'h3E700513; 
        storage[6] = 32'h02A00593; 
    end

    // Drop bottom 2 bits to convert byte address to word index
    assign inst_out = storage[byte_addr[9:2]];
endmodule


// ============================================================
// DATA MEMORY — 16 KB (4096 x 32-bit words)
// ============================================================
module data_mem (
    input             clk,
    input             mem_rd_en,
    input             mem_wr_en,
    input      [13:0] byte_addr,
    input      [31:0] wb_data,
    output     [31:0] load_data
);
    reg [31:0] storage [0:4095];

    initial begin
        // Pre-load data into memory for the LW instructions to read
        storage[0] = 32'd100;  // Byte Address 0
        storage[1] = 32'd200;  // Byte Address 4
        storage[2] = 32'd0;    // Byte Address 8 (SW will write '300' here later)
    end

    // Write on clock edge
    always @(posedge clk) begin
        if (mem_wr_en)
            storage[byte_addr[13:2]] <= wb_data;
    end

    // Read instantly (combinational)
    assign load_data = mem_rd_en ? storage[byte_addr[13:2]] : 32'b0;
endmodule


// ============================================================
// REGISTER FILE — 32 registers x 32-bit
// ============================================================
module reg_file (
    input             clk,
    input             reg_wr_en,
    input      [4:0]  src1_idx,
    input      [4:0]  src2_idx,
    input      [4:0]  dest_idx,
    input      [31:0] wb_data,
    output     [31:0] src1_data,
    output     [31:0] src2_data
);
    reg [31:0] gpr [0:31];

    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1)
            gpr[i] = 32'b0;
    end

    // Write on clock edge, x0 is always 0
    always @(posedge clk) begin
        if (reg_wr_en && dest_idx != 5'b0)
            gpr[dest_idx] <= wb_data;
    end

    // Read instantly (combinational)
    assign src1_data = gpr[src1_idx];
    assign src2_data = gpr[src2_idx];

endmodule


// ============================================================
// IMMEDIATE GENERATOR
// ============================================================
module imm_gen (
    input      [31:0] inst_word,
    output reg [31:0] imm_value_out
);
    wire [6:0] op_bits = inst_word[6:0];

    always @(*) begin
        case (op_bits)

            7'b0000011: begin
                // I-type: LW
                // imm = bits [31:20], sign extended
                imm_value_out = {{20{inst_word[31]}},
                             inst_word[31:20]};
            end

            7'b0010011: begin
                // I-type: ADDI
                // imm = bits [31:20], sign extended
                imm_value_out = {{20{inst_word[31]}},
                             inst_word[31:20]};
            end

            7'b0100011: begin
                // S-type: SW
                // imm = bits [31:25] and [11:7], sign extended
                imm_value_out = {{20{inst_word[31]}},
                             inst_word[31:25],
                             inst_word[11:7]};
            end

            7'b1100011: begin
                // B-type: BEQ
                // Bits are scrambled in the inst_word
                // The 1'b0 at the end means imm is already
                // a multiple of 2 — NO shift needed later
                imm_value_out = {{19{inst_word[31]}},
                             inst_word[31],
                             inst_word[7],
                             inst_word[30:25],
                             inst_word[11:8],
                             1'b0};
            end

            default: begin
                imm_value_out = 32'b0;
            end

        endcase
    end
endmodule


// ============================================================
// CONTROL UNIT
// ============================================================
module control (
    input      [6:0] op_bits,
    output reg       reg_wr_en,
    output reg       mem_rd_en,
    output reg       mem_wr_en,
    output reg       wb_from_mem,
    output reg       alu_uses_imm,
    output reg       branch_en,
    output reg [1:0] alu_mode
);
    always @(*) begin

        // Safe defaults — everything off
        reg_wr_en = 0;
        mem_rd_en  = 0;
        mem_wr_en = 0;
        wb_from_mem = 0;
        alu_uses_imm   = 0;
        branch_en   = 0;
        alu_mode    = 2'b00;

        case (op_bits)

            7'b0110011: begin
                // R-type: ADD, SUB, AND, OR
                reg_wr_en = 1;
                alu_uses_imm   = 0;
                alu_mode    = 2'b10;
            end

            7'b0000011: begin
                // LW
                reg_wr_en = 1;
                mem_rd_en  = 1;
                wb_from_mem = 1;
                alu_uses_imm   = 1;
                alu_mode    = 2'b00;
            end

            7'b0100011: begin
                // SW
                mem_wr_en = 1;
                alu_uses_imm   = 1;
                alu_mode    = 2'b00;
            end

            7'b1100011: begin
                // BEQ
                branch_en = 1;
                alu_uses_imm = 0;
                alu_mode  = 2'b01;
            end

            7'b0010011: begin
                // I-type: ADDI
                reg_wr_en = 1;
                mem_rd_en  = 0;
                mem_wr_en = 0;
                wb_from_mem = 0;
                alu_uses_imm   = 1;     // Use immediate instead of src2_idx
                branch_en   = 0;
                alu_mode    = 2'b00; // Tell ALU control to ADD
            end

            default: begin
                // NOP — all signals stay 0
            end

        endcase
    end
endmodule


// ============================================================
// ALU CONTROL
// ============================================================
module alu_control (
    input      [1:0] alu_mode,
    input      [2:0] f3_bits,
    input      [6:0] f7_bits,
    output reg [3:0] alu_cmd
);
    always @(*) begin
        case (alu_mode)

            2'b00: begin
                // LW or SW — always ADD for address calculation
                alu_cmd = 4'b0010;
            end

            2'b01: begin
                // BEQ — always SUB to compare
                alu_cmd = 4'b0110;
            end

            2'b10: begin
                // R-type — check f3_bits and f7_bits
                case (f3_bits)
                    3'b000: begin
                        if (f7_bits[5])
                            alu_cmd = 4'b0110; // SUB
                        else
                            alu_cmd = 4'b0010; // ADD
                    end
                    3'b111: alu_cmd = 4'b0000;  // AND
                    3'b110: alu_cmd = 4'b0001;  // OR
                    default: alu_cmd = 4'b0010;
                endcase
            end

            default: alu_cmd = 4'b0010;

        endcase
    end
endmodule


// ============================================================
// ALU
// ============================================================
module alu (
    input      [31:0] a,
    input      [31:0] b,
    input      [3:0]  alu_cmd,
    output reg [31:0] alu_result_out,
    output            zero_flag
);
    always @(*) begin
        case (alu_cmd)
            4'b0010: alu_result_out = a + b;   // ADD
            4'b0110: alu_result_out = a - b;   // SUB
            4'b0000: alu_result_out = a & b;   // AND
            4'b0001: alu_result_out = a | b;   // OR
            default: alu_result_out = 32'b0;
        endcase
    end

    assign zero_flag = (alu_result_out == 32'b0);

endmodule


// ============================================================
// TESTBENCH
// ============================================================
module tb_riscv;
    reg clk;
    reg reset;
    integer i;

    // Instantiate the Unit Under Test (UUT)
    riscv_top cpu_dut (
        .clk  (clk),
        .reset(reset)
    );

    // Clock Generation (10ns period)
    always #5 clk = ~clk;

    initial begin
        // 1. Configure GTKWave VCD Dumping
        $dumpfile("riscv_waveform.vcd");
        $dumpvars(0, tb_riscv); 
        
        // Explicitly dump internal registers and memory for waveforms
        for (i = 0; i < 32; i = i + 1) begin
            $dumpvars(1, cpu_dut.rf.gpr[i]);
        end
        for (i = 0; i < 4; i = i + 1) begin
            $dumpvars(1, cpu_dut.dmem.storage[i]);
        end

        // 2. Initialize
        clk = 0;
        reset = 1;

        // 3. Optional: Cycle-by-cycle console monitor
        $monitor("Time: %0t | PC: %0d | Instr: %h | x4:%0d | x5:%0d | x6:%0d | x11:%0d",
                 $time, cpu_dut.core_pc, cpu_dut.inst_word, cpu_dut.rf.gpr[4], cpu_dut.rf.gpr[5], cpu_dut.rf.gpr[6], cpu_dut.rf.gpr[11]);

        // Release reset
        #10 reset = 0;

        // 4. Wait for program execution 
        // (7 instructions * 10ns per cycle) + padding = 90ns
        #90;

        // 5. Final State Verification
        $display("\n=============================================");
        $display("          PROCESSOR EXECUTION RESULTS          ");
        $display("=============================================");
        
        $display("\n--- General-purpose register bank ---");
        $display("x4  (Loaded 100)      : %0d", cpu_dut.rf.gpr[4]);
        $display("x5  (Loaded 200)      : %0d", cpu_dut.rf.gpr[5]);
        $display("x6  (x4 + x5 = 300)   : %0d", cpu_dut.rf.gpr[6]);
        $display("x10 (Skipped, Exp 0)  : %0d", cpu_dut.rf.gpr[10]);
        $display("x11 (Branched, Exp 42): %0d", cpu_dut.rf.gpr[11]);

        $display("\n--- Word-addressed data RAM ---");
        $display("storage[0] (Address 0)    : %0d", cpu_dut.dmem.storage[0]);
        $display("storage[1] (Address 4)    : %0d", cpu_dut.dmem.storage[1]);
        $display("storage[2] (Address 8, SW): %0d", cpu_dut.dmem.storage[2]); // Should be 300
        $display("=============================================\n");

        $finish;
    end
endmodule