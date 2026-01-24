module hazard_unit (
    input  logic [4:0] rs1,     // Source 1 from ID/EX stage
    input  logic [4:0] rs2,     // Source 2 from ID/EX stage
    input  logic [4:0] rd_mem,  // Destination from EX/MEM stage
    input  logic       rf_en_mem, // Write enable from EX/MEM stage
    output logic       forward_a, // Forward to rs1
    output logic       forward_b  // Forward to rs2
);

    always_comb begin
        // Forward A Logic
        if (rf_en_mem && (rd_mem != 5'b0) && (rd_mem == rs1)) begin
            forward_a = 1'b1;
        end else begin
            forward_a = 1'b0;
        end

        // Forward B Logic
        if (rf_en_mem && (rd_mem != 5'b0) && (rd_mem == rs2)) begin
            forward_b = 1'b1;
        end else begin
            forward_b = 1'b0;
        end
    end

endmodule
