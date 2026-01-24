module data_mem (
    input logic clk,
    input logic [31:0] addr,
    input logic [31:0] wdata,
    input logic [2:0] load_type,     // 000: byte, 001: halfword, 010: word
    input logic load_unsigned,       // 0: signed load, 1: unsigned load
    input logic mem_write,           // Assert to perform a store
    input logic [2:0] store_type,    // Mirrors load_type encoding for stores
    output logic [31:0] rdata
);
    logic [7:0] mem [1024];  // byte addressable memory

    // Byte address into memory array
    logic [9:0] addr_idx;
    assign addr_idx = addr[9:0];

    always_comb begin
        case(load_type)
            3'b000: begin  // byte
                if (load_unsigned)
                    rdata = {24'b0, mem[addr_idx]};          // LBU
                else
                    rdata = {{24{mem[addr_idx][7]}}, mem[addr_idx]}; // LB
            end

            3'b001: begin  // halfword
                if (load_unsigned)
                    rdata = {16'b0, mem[addr_idx+1], mem[addr_idx]};  // LHU
                else
                    rdata = {{16{mem[addr_idx+1][7]}}, mem[addr_idx+1], mem[addr_idx]};  // LH
            end

            3'b010: begin  // word
                rdata = {mem[addr_idx+3], mem[addr_idx+2], mem[addr_idx+1], mem[addr_idx]};  // LW
            end

            default: rdata = 32'b0;
        endcase
    end

    // Write side for store instructions
    always_ff @(posedge clk) begin
        if (mem_write) begin
            case (store_type)
                3'b000: begin // SB
                    mem[addr_idx] <= wdata[7:0];
                end
                3'b001: begin // SH
                    mem[addr_idx]     <= wdata[7:0];
                    mem[addr_idx + 1] <= wdata[15:8];
                end
                3'b010: begin // SW
                    mem[addr_idx]     <= wdata[7:0];
                    mem[addr_idx + 1] <= wdata[15:8];
                    mem[addr_idx + 2] <= wdata[23:16];
                    mem[addr_idx + 3] <= wdata[31:24];
                end
                default: begin
                    mem[addr_idx] <= wdata[7:0];
                end
            endcase
        end
    end
endmodule