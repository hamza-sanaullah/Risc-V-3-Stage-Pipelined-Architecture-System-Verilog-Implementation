module imm_gen (
    input logic [31:0] inst,
    output logic [31:0] imm_out
);

    logic [6:0] opcode;
    assign opcode = inst[6:0];

    always_comb begin
        case (opcode)
            7'b0010011,
            7'b0000011,
            7'b1100111: begin
                // I-type, loads, JALR share the same immediate layout
                imm_out = {{20{inst[31]}}, inst[31:20]};
            end
            7'b0100011: begin
                // S-type immediate uses bits [31:25] and [11:7]
                imm_out = {{20{inst[31]}}, inst[31:25], inst[11:7]};
            end
            7'b1100011: begin
                // B-type immediate: [31], [7], [30:25], [11:8], 0
                imm_out = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
            end
            7'b1101111: begin
                // J-type immediate: [31], [19:12], [20], [30:21], 0
                imm_out = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
            end
            default: imm_out = 32'b0;
        endcase
    end

endmodule