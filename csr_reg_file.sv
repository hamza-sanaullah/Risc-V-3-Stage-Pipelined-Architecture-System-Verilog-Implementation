module csr_reg_file (
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] data,               // Data input (for CSR writes)
    input  logic [31:0] pc,                 // Current PC value
    input  logic        interrupt_exception, // Interrupt/exception signal (from timer or external)
    input  logic [31:0] instruction,        // Current instruction
    output logic [31:0] rdata,              // CSR read data output
    output logic [31:0] epc                 // Exception Program Counter output
);

    // CSR addresses (12-bit addresses expressed as hex using 12'h...)
    localparam logic [11:0] CSR_MSTATUS = 12'h300;
    localparam logic [11:0] CSR_MISA    = 12'h301;
    localparam logic [11:0] CSR_MIE     = 12'h304;
    localparam logic [11:0] CSR_MTVEC   = 12'h305;
    localparam logic [11:0] CSR_MEPC    = 12'h341;
    localparam logic [11:0] CSR_MCAUSE  = 12'h342;
    localparam logic [11:0] CSR_MIP     = 12'h344;

    // Standard bit positions (per RISC-V privileged spec)
    localparam int BIT_MSTATUS_MIE = 3;   // mstatus.MIE
    localparam int BIT_MIE_MEIE     = 11; // mie.MEIE
    localparam int BIT_MIE_MTIE     = 7;  // mie.MTIE
    localparam int BIT_MIP_MEIP     = 11; // mip.MEIP
    localparam int BIT_MIP_MTIP     = 7;  // mip.MTIP

    // Internal CSR registers
    logic [31:0] mstatus;
    logic [31:0] misa;
    logic [31:0] mie;
    logic [31:0] mtvec;
    logic [31:0] mepc_reg;
    logic [31:0] mcause;
    logic [31:0] mip;

    // Decode CSR address from instruction (csr field is imm[11:0] at [31:20])
    logic [11:0] csr_addr;
    logic [2:0]  funct3;
    logic        csr_insn;

    assign csr_addr = instruction[31:20];
    assign funct3   = instruction[14:12];
    assign csr_insn = (instruction[6:0] == 7'b1110011);

    // CSR write enable: support CSRRW/CSRRWI (write), CSRRS/CSRRSI (set), CSRRC/CSRRCI (clear)
    logic csr_write_en;
    logic [31:0] csr_write_data;

    always_comb begin
        csr_write_en = 1'b0;
        csr_write_data = data;
        if (csr_insn) begin
            case (funct3)
                3'b001, // CSRRW / CSRRWI (write)
                3'b101: // CSRRWI (write immediate)
                    csr_write_en = 1'b1;
                3'b010, // CSRRS / CSRRSI (set)
                3'b110: // CSRRSI
                    csr_write_en = 1'b1;
                3'b011, // CSRRC / CSRRCI (clear)
                3'b111: // CSRRCI
                    csr_write_en = 1'b1;
                default:
                    csr_write_en = 1'b0;
            endcase
        end
    end

    // CSR read multiplexing
    always_comb begin
        case (csr_addr)
            CSR_MSTATUS: rdata = mstatus;
            CSR_MISA:    rdata = misa;
            CSR_MIE:     rdata = mie;
            CSR_MTVEC:   rdata = mtvec;
            CSR_MEPC:    rdata = mepc_reg;
            CSR_MCAUSE:  rdata = mcause;
            CSR_MIP:     rdata = mip;
            default:     rdata = 32'h0;
        endcase
    end

    // Interrupt detection logic per your description:
    // AND MEIE with MEIP -> ext_pending
    // AND MTIP with MTIE -> tim_pending
    // AND each with mstatus.MIE -> gated_ext, gated_tim
    // OR them -> final_interrupt
    logic ext_pending;
    logic tim_pending;
    logic gated_ext;
    logic gated_tim;
    logic final_interrupt;

    always_comb begin
        ext_pending = (mie[BIT_MIE_MEIE] & mip[BIT_MIP_MEIP]);
        tim_pending = (mie[BIT_MIE_MTIE] & mip[BIT_MIP_MTIP]);
        gated_ext   = ext_pending & mstatus[BIT_MSTATUS_MIE];
        gated_tim   = tim_pending & mstatus[BIT_MSTATUS_MIE];
        final_interrupt = gated_ext | gated_tim;
    end

    // Synchronous CSR updates and EPC handling
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            mstatus   <= 32'h0;
            misa      <= 32'h0;
            mie       <= 32'h0;
            mtvec     <= 32'h0;
            mepc_reg  <= 32'h0;
            mcause    <= 32'h0;
            mip       <= 32'h0;
        end else begin
            // Write CSR operations
            if (csr_write_en) begin
                case (csr_addr)
                    CSR_MSTATUS: begin
                        if (funct3 == 3'b001 || funct3 == 3'b101) mstatus <= csr_write_data; // write
                        else if (funct3 == 3'b010 || funct3 == 3'b110) mstatus <= mstatus | csr_write_data; // set
                        else if (funct3 == 3'b011 || funct3 == 3'b111) mstatus <= mstatus & ~csr_write_data; // clear
                    end
                    CSR_MISA: begin
                        // Usually misa is read-only; allow write only if explicit write type
                        if (funct3 == 3'b001 || funct3 == 3'b101) misa <= csr_write_data;
                    end
                    CSR_MIE: begin
                        if (funct3 == 3'b001 || funct3 == 3'b101) mie <= csr_write_data;
                        else if (funct3 == 3'b010 || funct3 == 3'b110) mie <= mie | csr_write_data;
                        else if (funct3 == 3'b011 || funct3 == 3'b111) mie <= mie & ~csr_write_data;
                    end
                    CSR_MTVEC: begin
                        if (funct3 == 3'b001 || funct3 == 3'b101) mtvec <= csr_write_data;
                    end
                    CSR_MEPC: begin
                        if (funct3 == 3'b001 || funct3 == 3'b101) mepc_reg <= csr_write_data;
                    end
                    CSR_MCAUSE: begin
                        if (funct3 == 3'b001 || funct3 == 3'b101) mcause <= csr_write_data;
                    end
                    CSR_MIP: begin
                        // MIP typically has some read-only pending bits; allow software to write the pending bits masked
                        if (funct3 == 3'b001 || funct3 == 3'b101) mip <= csr_write_data;
                        else if (funct3 == 3'b010 || funct3 == 3'b110) mip <= mip | csr_write_data;
                        else if (funct3 == 3'b011 || funct3 == 3'b111) mip <= mip & ~csr_write_data;
                    end
                    default: ;
                endcase
            end

            // Update mepc/mcause on interrupt/exception detection
            if (final_interrupt || interrupt_exception) begin
                mepc_reg <= pc; // save EPC
                // mcause: set a simple code: 0x80000007 for external interrupt, 0x80000007 for timer - here we set a placeholder
                if (final_interrupt) mcause <= 32'h80000007;
                else mcause <= 32'h00000002; // example exception code
            end
        end
    end

    // Expose EPC output
    assign epc = mepc_reg;

endmodule

