module tb_processor();
    logic clk;
    logic rst;
    logic interrupt_exception;  // Interrupt/exception signal for testing
    string line;
    integer fd;
    integer i;
    logic [31:0] instruction;

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Instantiate processor
    processor proc_inst (
        .clk(clk),
        .rst(rst),
        .interrupt_exception(interrupt_exception)
    );

    // Test stimulus
    initial begin
        // Initialize memories using standard $readmemb (portable and simulator-friendly)
        $readmemb("instruction_memory", proc_inst.imem_inst.mem);
        $readmemb("register_file", proc_inst.rfile_inst.reg_mem);

        // Initialize interrupt_exception to 0 (no interrupt)
        // Set to 1 to simulate timer interrupt during execution
        interrupt_exception = 1'b0;

        // Reset sequence
        rst = 1;
        @(posedge clk);
        @(posedge clk);
        rst = 0;

        // Wait for some instructions to execute normally
        repeat(10) @(posedge clk);
        
        // Optionally trigger an interrupt here for testing
        // Uncomment the following lines to test interrupt handling:
        // interrupt_exception = 1'b1;
        // @(posedge clk);
        // interrupt_exception = 1'b0;

        // Continue execution
        repeat(14) @(posedge clk);

        // Display results in binary
        $display("\nRegister File Contents:");
        for (i = 0; i < 12; i++) begin
            $display("x%0d = %b", i, proc_inst.rfile_inst.reg_mem[i]);
        end

        $display("\nMemory snapshot (addresses 16-17):");
        $display("mem[16] = %02h", proc_inst.dmem_inst.mem[16]);
        $display("mem[17] = %02h", proc_inst.dmem_inst.mem[17]);

        // ============================================
        // CSR Register Contents (for CSR testing)
        // ============================================
        $display("\n========== CSR Register Contents ==========");
        $display("mstatus (0x300) = %08h  [MIE bit3=%b]", 
                 proc_inst.csr_inst.mstatus, 
                 proc_inst.csr_inst.mstatus[3]);
        $display("misa    (0x301) = %08h", proc_inst.csr_inst.misa);
        $display("mie     (0x304) = %08h  [MEIE bit11=%b, MTIE bit7=%b]", 
                 proc_inst.csr_inst.mie,
                 proc_inst.csr_inst.mie[11],
                 proc_inst.csr_inst.mie[7]);
        $display("mtvec   (0x305) = %08h", proc_inst.csr_inst.mtvec);
        $display("mepc    (0x341) = %08h", proc_inst.csr_inst.mepc_reg);
        $display("mcause  (0x342) = %08h", proc_inst.csr_inst.mcause);
        $display("mip     (0x344) = %08h  [MEIP bit11=%b, MTIP bit7=%b]", 
                 proc_inst.csr_inst.mip,
                 proc_inst.csr_inst.mip[11],
                 proc_inst.csr_inst.mip[7]);
        $display("===========================================");
        
        // Interrupt logic status
        $display("\nInterrupt Logic Status:");
        $display("  ext_pending (MEIE & MEIP)     = %b", proc_inst.csr_inst.ext_pending);
        $display("  tim_pending (MTIE & MTIP)     = %b", proc_inst.csr_inst.tim_pending);
        $display("  gated_ext (ext & mstatus.MIE) = %b", proc_inst.csr_inst.gated_ext);
        $display("  gated_tim (tim & mstatus.MIE) = %b", proc_inst.csr_inst.gated_tim);
        $display("  final_interrupt               = %b", proc_inst.csr_inst.final_interrupt);
        $display("  EPC output                    = %08h", proc_inst.epc);

        $finish;
    end

    // Waveform dump for GTKWave visualization
    initial begin
        $dumpfile("processor.vcd");
        $dumpvars(0, tb_processor);
        
        // Also dump waveforms in WLF format for QuestaSim
        $wlfdumpvars(0, tb_processor);
        $timeformat(-9, 2, " ns", 10);
    end

endmodule