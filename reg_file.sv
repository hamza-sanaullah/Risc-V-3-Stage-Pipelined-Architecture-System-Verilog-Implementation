module reg_file (
    input logic clk,
    input logic rf_en,
    input logic [4:0] rs1,
    input logic [4:0] rs2,
    input logic [4:0] rd,
    input logic [31:0] wdata,
    output logic [31:0] rdata1,
    output logic [31:0] rdata2
);

    logic  [31:0] reg_mem [32];

    //asynchronous read with x0 hardwired to 0
    always_comb
    begin
        rdata1 = (rs1 == 5'b0) ? 32'b0 : reg_mem[rs1];
        rdata2 = (rs2 == 5'b0) ? 32'b0 : reg_mem[rs2];    
    end
    
    // Register file contents should be initialized by the testbench ($readmemb)
    // or by a reset mechanism in higher-level design. Avoid initializing
    // the memory here to prevent multiple drivers (synthesis/simulator warnings).

    //synchronous write
    always_ff @(posedge clk)
    begin
        if (rf_en && rd != 0)  // x0 is hardwired to 0
        begin
            reg_mem[rd] <= wdata;
        end
    end

    //initial begin
    // //wait for a small delay to allow signals to settle
    // #1
    // $display("Data at rdata1: %b", rdata1);
    // $display("Data at rdata2: %b", rdata2);
    // $display("Data at wdata: %b", wdata);
    // end
endmodule
