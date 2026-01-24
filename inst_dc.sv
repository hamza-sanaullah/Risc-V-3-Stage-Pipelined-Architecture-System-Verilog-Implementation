module inst_dec (
    input logic [31:0] inst,
    output logic [6:0] opcode,
    output logic [4:0] rd,
    output logic [2:0] funct3,
    output logic [6:0] funct7,
    output logic [4:0] rs1,
    output logic [4:0] rs2
);
    //to controller
    assign opcode = inst[6:0];
    assign funct3 = inst[14:12];
    assign funct7 = inst[31:25];

    //to register
    assign rs1    = inst[19:15];
    assign rs2    = inst[24:20];
    assign rd     = inst[11:7];
   
   //printing valus for debug
    // initial begin
    // //wait for a small delay to allow signals to stabilize
    // #1;
    // $display("Data at inst: %b", inst);
    // $display("Data at opcode: %b", opcode);
    // $display("Data at rd: %b", rd);
    // $display("Data at funct3: %b", funct3);
    // $display("Data at funct7: %b", funct7);
    // $display("Data at rs1: %b", rs1);
    // $display("Data at rs2: %b", rs2);
    // end

endmodule