module processor (
    input logic clk,
    input logic rst,
    input logic interrupt_exception  // Interrupt/exception input (from timer or external)
);
    // Internal signals
    logic [31:0] pc_out;
    logic [31:0] inst;
    // IF/ID buffer outputs
    logic [31:0] id_pc;
    logic [31:0] id_inst;
    // Decode for ID/EX stage
    logic [6:0] opcode_id;
    logic [2:0] funct3_id;
    logic [6:0] funct7_id;
    logic [4:0] rs1_id;
    logic [4:0] rs2_id;
    logic [4:0] rd_id;
    logic [31:0] rdata1;
    logic [31:0] rdata2;
    logic [31:0] wdata;
    logic [31:0] load_data;
    logic rf_en_id;
    logic [3:0] aluop_id;
    logic sel_b_id;
    logic is_load_id;
    logic mem_write_id;
    logic [2:0] load_type_id;
    logic load_unsigned_id;
    logic [2:0] store_type_id;
    logic [31:0] imm;
    logic [31:0] alu_b;
    logic [31:0] alu_res;
    logic [31:0] final_res;  // Final result from ALU
    logic zero;              // Zero flag from ALU
    logic is_branch_id;
    logic is_jal_id;
    logic is_jalr_id;
    logic branch_taken;
    logic [31:0] pc_next;
    
    // CSR signals
    logic [31:0] csr_rdata;      // CSR read data
    logic [31:0] epc;            // Exception Program Counter from CSR
    logic [31:0] pc_final;       // Final PC input after EPC mux
    logic        is_csr_id;      // CSR instruction flag in ID stage (Defined here)
    assign is_csr_id = (opcode_id == 7'b1110011);

    // EX/MEM buffer outputs (from buffer2: just PC, rd, wdata, alu_res)
    logic [31:0] mem_pc;
    logic [4:0]  mem_rd;         // destination register from buffer
    logic [31:0] mem_wdata;
    logic [31:0] mem_addr;       // buffered alu result

    // Branch condition logic
    always_comb begin
        branch_taken = 1'b0;
        if (is_branch_id) begin
            case (funct3_id)
                3'b000: branch_taken = zero;          // BEQ
                3'b001: branch_taken = ~zero;         // BNE
                3'b100: branch_taken = alu_res[0];    // BLT (SLT result)
                3'b101: branch_taken = ~alu_res[0];   // BGE (!SLT result)
                3'b110: branch_taken = alu_res[0];    // BLTU (SLTU result)
                3'b111: branch_taken = ~alu_res[0];   // BGEU (!SLTU result)
                default: branch_taken = 1'b0;
            endcase
        end
    end

    // PC Next Logic (branch/jump selection)
    always_comb begin
        if (is_jalr_id) begin
            pc_next = (rdata1 + imm) & 32'hFFFFFFFE; // JALR: (rs1 + imm) & ~1
        end else if (is_jal_id || branch_taken) begin
            pc_next = pc_out + imm;                  // JAL or Taken Branch: PC + imm
        end else begin
            pc_next = pc_out + 32'd4;                // Default: PC + 4
        end
    end

    // MUX for EPC/PC selection (before PC module)
    // When interrupt_exception is asserted, jump to trap handler (use EPC from CSR)
    // Otherwise, use normal pc_next from branch logic
    mux2 mux_epc (
        .in0(pc_next),           // Normal next PC
        .in1(epc),               // Exception PC from CSR
        .sel(interrupt_exception),
        .out(pc_final)
    );

    // Program counter instance
    pc pc_inst (
        .clk(clk),
        .rst(rst),
        .pc_in(pc_final),        // Use pc_final after EPC mux
        .pc_out(pc_out)
    );

    // Instruction memory instance
    inst_mem imem_inst (
        .addr(pc_out),
        .data(inst)
    );

    // IF/ID Buffer: latch PC and instruction for decode stage
    logic flush_if_id;
    assign flush_if_id = branch_taken | is_jal_id | is_jalr_id | interrupt_exception;

    buffer1 if_id_buf (
        .clk(clk),
        .rst(rst),
        .flush(flush_if_id),
        .pc_in(pc_out),
        .instr_in(inst),
        .pc_out(id_pc),
        .instr_out(id_inst)
    );

    // Instruction decode instance
    // Decode for ID/EX stage
    inst_dec idec_id (
        .inst(id_inst),
        .opcode(opcode_id),
        .funct3(funct3_id),
        .funct7(funct7_id),
        .rs1(rs1_id),
        .rs2(rs2_id),
        .rd(rd_id)
    );

    // Immediate generator
    imm_gen imm_gen_inst (
        .inst(id_inst),
        .imm_out(imm)
    );

    // EX/MEM stage signals (outputs from buffer2)
    logic        mem_rf_en;
    logic        mem_mem_write;
    logic [2:0]  mem_load_type;
    logic        mem_load_unsigned;
    logic        mem_is_load;
    logic        mem_is_csr;
    logic        mem_is_jal;
    logic        mem_is_jalr;
    logic [31:0] mem_csr_rdata;

    // Writeback MUX logic (Stage 3)
    // Uses pipelined control signals from buffer2
    logic [31:0] writeback_data;
    
    always_comb begin
        if (mem_is_jal || mem_is_jalr)
            writeback_data = mem_pc + 32'd4;      // Return address for JAL/JALR (from buffered PC)
        else if (mem_is_load)
            writeback_data = load_data;           // Load from data memory
        else if (mem_is_csr)
            writeback_data = mem_csr_rdata;       // CSR read data (buffered)
        else
            writeback_data = mem_addr;            // ALU result (buffered)
    end

    // Register file instance
    reg_file rfile_inst (
        .clk(clk),
        .rf_en(mem_rf_en),      // Use pipelined write enable
        .rs1(rs1_id),
        .rs2(rs2_id),
        .rd(mem_rd),
        .wdata(writeback_data), // Writeback MUX with 4 inputs
        .rdata1(rdata1),
        .rdata2(rdata2)
    );

    // Data memory instance
    data_mem dmem_inst (
        .clk(clk),
        .addr(mem_addr),      // Address from buffered final result
        .wdata(mem_wdata),    // Data from buffered rs2
        .load_type(mem_load_type), // Use pipelined load type
        .load_unsigned(mem_load_unsigned), // Use pipelined unsigned flag
        .mem_write(mem_mem_write), // Use pipelined write enable
        .store_type(mem_load_type), // Reuse pipelined load_type (funct3) for store width.
        .rdata(load_data)
    );

    // Hazard Handling Logic
    logic forward_a;
    logic forward_b;
    logic [31:0] forwarded_rdata1;
    logic [31:0] forwarded_rdata2;

    hazard_unit hazard_inst (
        .rs1(rs1_id),
        .rs2(rs2_id),
        .rd_mem(mem_rd),
        .rf_en_mem(mem_rf_en),
        .forward_a(forward_a),
        .forward_b(forward_b)
    );

    // Forwarding MUXes
    // If forward signal is high, bypass Register File and use Writeback Data from Stage 3
    assign forwarded_rdata1 = (forward_a) ? writeback_data : rdata1;
    assign forwarded_rdata2 = (forward_b) ? writeback_data : rdata2;

    // Mux for selecting between register and immediate
    mux2 mux_alu_b (
        .in0(forwarded_rdata2), // Use forwarded data
        .in1(imm),
        .sel(sel_b_id),
        .out(alu_b)
    );

    // Control logic
    // Controller for ID/EX stage
    controller ctrl_id (
        .opcode(opcode_id),
        .funct3(funct3_id),
        .funct7(funct7_id),
        .rf_en(rf_en_id),
        .aluop(aluop_id),
        .sel_b(sel_b_id),
        .is_load(is_load_id),
        .mem_write(mem_write_id),
        .load_type(load_type_id),
        .load_unsigned(load_unsigned_id),
        .store_type(store_type_id),
        .is_branch(is_branch_id),
        .is_jal(is_jal_id),
        .is_jalr(is_jalr_id)
    );

    // ALU instance
    alu alu_inst (
        .opr_a(forwarded_rdata1), // Use forwarded data
        .opr_b(alu_b),
        .aluop(aluop_id),
        .alu_res(alu_res),
        .zero(zero)
    );

    // Final result: no MOD operation; use ALU result directly
    assign final_res = alu_res;

    // EX/MEM Buffer: latch PC, rd, store data (WD), and ALU result
    // AND control signals
    buffer2 ex_mem_buf (
        .clk(clk),
        .rst(rst),
        .pc_in(id_pc),
        .rd_in(rd_id),
        .wdata_in(forwarded_rdata2), // Use forwarded data (important for STORE instructions)
        .alu_res_in(final_res),
        .csr_rdata_in(csr_rdata), // Pipeline CSR data

        // Control Inputs
        .rf_en_in(rf_en_id),
        .mem_write_in(mem_write_id),
        .load_type_in(load_type_id), // Use load_type which mirrors funct3
        .load_unsigned_in(load_unsigned_id),
        .is_load_in(is_load_id),
        .is_csr_in(is_csr_id),
        .is_jal_in(is_jal_id),
        .is_jalr_in(is_jalr_id),

        .pc_out(mem_pc),
        .rd_out(mem_rd),
        .wdata_out(mem_wdata),
        .alu_res_out(mem_addr),
        .csr_rdata_out(mem_csr_rdata),

        // Control Outputs
        .rf_en_out(mem_rf_en),
        .mem_write_out(mem_mem_write),
        .load_type_out(mem_load_type),
        .load_unsigned_out(mem_load_unsigned),
        .is_load_out(mem_is_load),
        .is_csr_out(mem_is_csr),
        .is_jal_out(mem_is_jal),
        .is_jalr_out(mem_is_jalr)
    );

    // CSR Register File instance
    csr_reg_file csr_inst (
        .clk(clk),
        .rst(rst),
        .data(rdata1),                    // Data input from rs1 for CSR writes
        .pc(pc_out),                      // Current PC
        .interrupt_exception(interrupt_exception), // Interrupt signal
        .instruction(id_inst),            // Instruction in decode stage
        .rdata(csr_rdata),                // CSR read data output
        .epc(epc)                         // Exception PC output
    );

endmodule