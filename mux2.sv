module mux2 (
    input logic [31:0] in0,    // From register file
    input logic [31:0] in1,    // From immediate generator
    input logic sel,           // Select signal
    output logic [31:0] out
);

    always_comb 
    begin
        out = sel ? in1 : in0;
    end

endmodule