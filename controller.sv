module controller (
    input logic [6:0] opcode,
    input logic [2:0] funct3,
    input logic [6:0] funct7,
    output logic [3:0] aluop,
    output logic rf_en,
    output logic sel_b,            // 0: select reg value, 1: select immediate
    output logic is_load,          // Asserted for load operations
    output logic mem_write,        // Asserted for store operations
    output logic [2:0] load_type,  // 000: byte, 001: halfword, 010: word
    output logic load_unsigned,    // 0: signed load, 1: unsigned load
    output logic [2:0] store_type, // Width for stores (mirrors load_type)
    output logic is_branch,        // Asserted for branch instructions
    output logic is_jal,           // Asserted for JAL
    output logic is_jalr           // Asserted for JALR
);

    always_comb
    begin
        // Default values
        rf_en = 1'b0;
        sel_b = 1'b1;  // Default to immediate for I-type
        is_load = 1'b0;
        mem_write = 1'b0;
        aluop = 4'b0000;
        load_type = 3'b010;
        load_unsigned = 1'b0;
        store_type = 3'b010;
        is_branch = 1'b0;
        is_jal = 1'b0;
        is_jalr = 1'b0;

        case(opcode)
            7'b0110011: begin // R-type arithmetic
                rf_en = 1'b1;
                sel_b = 1'b0;  // Use register value (rs2) for R-type
                unique case(funct3)
                    3'b000: begin
                        unique case(funct7)
                            7'b0000000: aluop = 4'b0000; // ADD
                            7'b0100000: aluop = 4'b0001; // SUB
                            7'b0000001: aluop = 4'b1010; // MUL
                        endcase
                    end
                    3'b001: aluop = 4'b0010; // SLL
                    3'b010: aluop = 4'b0011; // SLT
                    3'b011: aluop = 4'b0100; // SLTU
                    3'b100: aluop = 4'b0101; // XOR
                    3'b101: begin
                        unique case(funct7)
                            7'b0000000: aluop = 4'b0110; // SRL
                            7'b0100000: aluop = 4'b0111; // SRA
                        endcase
                    end
                    3'b110: aluop = 4'b1000; // OR
                    3'b111: aluop = 4'b1001; // AND
                endcase
            end

            7'b0010011: begin // I-type arithmetic
                rf_en = 1'b1;
                sel_b = 1'b1;  // Use immediate value
                unique case(funct3)
                    3'b000: aluop = 4'b0000; // ADDI
                    3'b010: aluop = 4'b0011; // SLTI
                    3'b011: aluop = 4'b0100; // SLTIU
                    3'b100: aluop = 4'b0101; // XORI
                    3'b110: aluop = 4'b1000; // ORI
                    3'b111: aluop = 4'b1001; // ANDI
                    3'b001: aluop = 4'b0010; // SLLI
                    3'b101: begin
                        unique case(funct7)
                            7'b0000000: aluop = 4'b0110; // SRLI
                            7'b0100000: aluop = 4'b0111; // SRAI
                        endcase
                    end
                endcase
            end

            7'b0000011: begin // Load instructions
                rf_en = 1'b1;
                sel_b = 1'b1;  // Use immediate for address calculation
                is_load = 1'b1;
                aluop = 4'b0000; // Use ADD for address calculation

                // Load type encoding based on funct3
                unique case(funct3)
                    3'b000: begin  // LB (Load Byte)
                        load_type = 3'b000;
                        load_unsigned = 1'b0;
                    end
                    3'b001: begin  // LH (Load Halfword)
                        load_type = 3'b001;
                        load_unsigned = 1'b0;
                    end
                    3'b010: begin  // LW (Load Word)
                        load_type = 3'b010;
                        load_unsigned = 1'b0;
                    end
                    3'b100: begin  // LBU (Load Byte Unsigned)
                        load_type = 3'b000;
                        load_unsigned = 1'b1;
                    end
                    3'b101: begin  // LHU (Load Halfword Unsigned)
                        load_type = 3'b001;
                        load_unsigned = 1'b1;
                    end
                    default: begin
                        load_type = 3'b010;  // Default to word
                        load_unsigned = 1'b0;
                    end
                endcase
            end

            7'b0100011: begin // S-type stores
                sel_b = 1'b1;       // Base register + immediate
                mem_write = 1'b1;
                aluop = 4'b0000;    // ADD for address calculation
                unique case(funct3)
                    3'b000: begin store_type = 3'b000; load_type = 3'b000; end // SB
                    3'b001: begin store_type = 3'b001; load_type = 3'b001; end // SH
                    3'b010: begin store_type = 3'b010; load_type = 3'b010; end // SW
                    default: begin store_type = 3'b010; load_type = 3'b010; end
                endcase
            end

            7'b1100011: begin // B-type (Branch)
                rf_en = 1'b0;
                sel_b = 1'b0;  // Compare two registers
                is_branch = 1'b1;
                
                unique case(funct3)
                    3'b000: aluop = 4'b0001; // BEQ (SUB, check zero)
                    3'b001: aluop = 4'b0001; // BNE (SUB, check !zero)
                    3'b100: aluop = 4'b0011; // BLT (SLT, check result)
                    3'b101: aluop = 4'b0011; // BGE (SLT, check !result)
                    3'b110: aluop = 4'b0100; // BLTU (SLTU, check result)
                    3'b111: aluop = 4'b0100; // BGEU (SLTU, check !result)
                    default: aluop = 4'b0000;
                endcase
            end

            7'b1101111: begin // J-type (JAL)
                rf_en = 1'b1;
                sel_b = 1'b1; // Don't care really
                is_jal = 1'b1;
                aluop = 4'b0000; // Don't care
            end

            7'b1100111: begin // JALR
                rf_en = 1'b1;
                sel_b = 1'b1;  // Use immediate
                is_jalr = 1'b1;
                aluop = 4'b0000; // ADD for target address calculation
            end

            default: begin
                rf_en = 1'b0;
                sel_b = 1'b1;  // Keep immediate selection as default for I-type
                is_load = 1'b0;
                aluop = 4'b0000;
            end
        endcase
    end

endmodule