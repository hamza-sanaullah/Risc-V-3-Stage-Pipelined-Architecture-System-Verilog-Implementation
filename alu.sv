module alu (
    input logic[31:0] opr_a,
    input logic[31:0] opr_b,
    input logic[3:0] aluop,
    output logic[31:0] alu_res,
    output logic zero
);

always_comb 
begin
    case(aluop)
        4'b0000: alu_res = opr_a + opr_b;                    // ADD
        4'b0001: alu_res = opr_a - opr_b;                    // SUB
        4'b0010: alu_res = opr_a << opr_b[4:0];              // SLL
        4'b0011: alu_res = ($signed(opr_a) < $signed(opr_b)) ? 32'd1 : 32'd0; // SLT (signed)
        4'b0100: alu_res = (opr_a < opr_b) ? 32'd1 : 32'd0;  // SLTU (unsigned)
        4'b0101: alu_res = opr_a ^ opr_b;                    // XOR
        4'b0110: alu_res = opr_a >> opr_b[4:0];              // SRL (logical)
        4'b0111: alu_res = $signed(opr_a) >>> opr_b[4:0];    // SRA (arithmetic)
        4'b1000: alu_res = opr_a | opr_b;                    // OR
        4'b1001: alu_res = opr_a & opr_b;                    // AND
        4'b1010: alu_res = opr_a * opr_b;                    // MUL
        // 4'b1011 reserved for MOD (handled by modulounit)
        default:  alu_res = 32'b0;                          // NOP / Undefined
    endcase
    
    // Zero flag for branch operations (set if result is 0)
    zero = (alu_res == 32'b0);
end

initial begin
    $monitor("Time: %0t | OPR_A: %h | OPR_B: %h | ALUOP: %b | ALU_RES: %h", $time, opr_a, opr_b, aluop, alu_res);
end

endmodule