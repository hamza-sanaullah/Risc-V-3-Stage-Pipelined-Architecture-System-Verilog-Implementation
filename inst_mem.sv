module inst_mem (
    input logic [31:0] addr,
    output logic [31:0] data
);
    //instruction memory of row width of 32 bits and total 100 rows: 32 bits x 100 rows
    logic [31:0] mem [100];

    always_comb 
    begin
        //doing right shift as pc is adding 4, to make it +1 as we want to do word addressing
        data = mem[addr[31:2]];
        //$display("Data at addr %b", data);
    end
endmodule
