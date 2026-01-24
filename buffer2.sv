module buffer2 (
    input  logic        clk,
    input  logic        rst,
    // Data path (matching datapath diagram: PC, ALU result, WD, rd from IR)
    // Data path (matching datapath diagram: PC, ALU result, WD, rd from IR)
    input  logic [31:0] pc_in,
    input  logic [4:0]  rd_in,          // Destination register (IR[11:7])
    input  logic [31:0] wdata_in,       // Store data (rdata2) - WD in diagram
    input  logic [31:0] alu_res_in,     // ALU result / memory address
    input  logic [31:0] csr_rdata_in,   // CSR read data

    // Control signals to allow execution in EX/MEM stage
    input  logic        rf_en_in,
    input  logic        mem_write_in,
    input  logic [2:0]  load_type_in,
    input  logic        load_unsigned_in,
    input  logic        is_load_in,
    input  logic        is_csr_in,
    input  logic        is_jal_in,
    input  logic        is_jalr_in,

    output logic [31:0] pc_out,
    output logic [4:0]  rd_out,
    output logic [31:0] wdata_out,
    output logic [31:0] alu_res_out,
    output logic [31:0] csr_rdata_out,

    output logic        rf_en_out,
    output logic        mem_write_out,
    output logic [2:0]  load_type_out,
    output logic        load_unsigned_out,
    output logic        is_load_out,
    output logic        is_csr_out,
    output logic        is_jal_out,
    output logic        is_jalr_out
);

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_out            <= 32'b0;
            rd_out            <= 5'b0;
            wdata_out         <= 32'b0;
            alu_res_out       <= 32'b0;
            csr_rdata_out     <= 32'b0;
            rf_en_out         <= 1'b0;
            mem_write_out     <= 1'b0;
            load_type_out     <= 3'b010;
            load_unsigned_out <= 1'b0;
            is_load_out       <= 1'b0;
            is_csr_out        <= 1'b0;
            is_jal_out        <= 1'b0;
            is_jalr_out       <= 1'b0;
        end else begin
            pc_out            <= pc_in;
            rd_out            <= rd_in;
            wdata_out         <= wdata_in;
            alu_res_out       <= alu_res_in;
            csr_rdata_out     <= csr_rdata_in;
            rf_en_out         <= rf_en_in;
            mem_write_out     <= mem_write_in;
            load_type_out     <= load_type_in;
            load_unsigned_out <= load_unsigned_in;
            is_load_out       <= is_load_in;
            is_csr_out        <= is_csr_in;
            is_jal_out        <= is_jal_in;
            is_jalr_out       <= is_jalr_in;
        end
    end

endmodule
