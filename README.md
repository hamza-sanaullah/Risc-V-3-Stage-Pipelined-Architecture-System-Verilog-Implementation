# RISC-V 3-Phase Pipelined Processor

A high-performance **3-stage pipelined RISC-V processor** designed using SystemVerilog. This implementation supports the **RV32I** base integer ISA along with the **M extension** for hardware multiplication. It incorporates advanced processor features such as **data forwarding**, **branch flushing**, and **CSR-based interrupt handling**.

---

## Table of Contents

- [Core Features](#core-features)
- [Architecture](#architecture)
- [Pipeline Stages](#pipeline-stages)
- [Supported Instruction Set](#supported-instruction-set)
- [Module Overview](#module-overview)
- [Hazard Handling](#hazard-handling)
- [Privilege and Interrupts](#privilege-and-interrupts)
- [Installation and Setup](#installation-and-setup)
- [Testing and Simulation](#testing-and-simulation)
- [Project Structure](#project-structure)

---

## Core Features

This processor is engineered for the RV32IM ISA, focusing on balancing complexity and performance.

| Feature | Specification |
|---------|---------------|
| **ISA Support** | RISC-V RV32I + M Extension (Partial) |
| **Pipeline Design**| 3 Stages (Fetch -> Decode/Execute -> Memory/Writeback) |
| **Data Path** | Full 32-bit internal architecture |
| **Hazard Mitigation** | Dynamic data forwarding for RAW hazards |
| **Control Logic** | Pipeline flushing for branches and jumps |
| **Exception Handling** | Machine-mode CSRs for traps and interrupts |
| **Memory Architecture** | Harvard-style (split Instruction and Data RAM) |

---

## Architecture

### Conceptual Pipeline

```text
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           3-STAGE PIPELINED RISC-V PROCESSOR                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌──────────────┐    ┌──────────────────────────────┐    ┌──────────────────┐  │
│  │   STAGE 1    │    │          STAGE 2             │    │     STAGE 3      │  │
│  │    FETCH     │───▶│     DECODE / EXECUTE         │───▶│   MEMORY / WB    │  │
│  └──────────────┘    └──────────────────────────────┘    └──────────────────┘  │
│         │                        │                              │              │
│    ┌────┴────┐          ┌────────┴─────────┐           ┌────────┴────────┐     │
│    │   PC    │          │  Inst Decode     │           │   Data Memory   │     │
│    │  I-Mem  │          │  Imm Gen         │           │   Writeback MUX │     │
│    │ Buffer1 │          │  Reg File (Read) │           │   Reg File (WR) │     │
│    └─────────┘          │  Controller      │           └─────────────────┘     │
│                         │  ALU             │                    ▲              │
│                         │  CSR Reg File    │                    │              │
│                         │  Hazard Unit     │        ┌───────────┴───────────┐  │
│                         │  Buffer2         │        │   Data Forwarding     │  │
│                         └──────────────────┘        └───────────────────────┘  │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Detailed Datapath

```text
                    ┌─────────────────────────────────────────────────────────────┐
                    │                                                             │
                    ▼                                                             │
       ┌────────────────────┐                                                     │
       │        PC          │◄────────────────────────────────────────┐           │
       └────────┬───────────┘                                         │           │
                │                                                     │           │
                ▼                                                     │           │
       ┌────────────────────┐                                         │           │
       │   Instruction      │                                    ┌────┴────┐      │
       │      Memory        │                                    │  MUX    │      │
       └────────┬───────────┘                                    │ (EPC)   │      │
                │                                                └────┬────┘      │
                ▼                                                     ▲           │
       ┌────────────────────┐                                         │           │
       │   IF/ID Buffer     │                               PC+4 / Branch / EPC   │
       │    (buffer1)       │                                         │           │
       └────────┬───────────┘                               ┌─────────┴─────────┐ │
                │                                           │  Branch/Jump      │ │
     ┌──────────┼──────────────────────────────┐           │   Decision        │ │
     │          ▼                              │           └─────────┬─────────┘ │
     │  ┌───────────────┐   ┌──────────────┐   │                     ▲           │
     │  │  Inst Decode  │──▶│  Controller  │   │                     │           │
     │  └───────┬───────┘   └──────────────┘   │           ┌─────────┴─────────┐ │
     │          │                              │           │   ALU Result /    │ │
     │          ▼                              │           │   Zero Flag       │ │
     │  ┌───────────────┐                      │           └─────────┬─────────┘ │
     │  │  Register     │◄─────────────────────┼─────────────────────┼───────────┘
     │  │    File       │                      │                     │
     │  └───────┬───────┘                      │                     │
     │          │                              │                     │
     │    ┌─────┴─────┐                        │                     │
     │    ▼           ▼                        │                     │
     │ rdata1      rdata2                      │                     │
     │    │           │                        │                     │
     │    ▼           ▼                        │                     │
     │ ┌─────┐     ┌─────┐      ┌─────────┐    │                     │
     │ │ FWD │     │ FWD │      │  Imm    │    │                     │
     │ │ MUX │     │ MUX │      │  Gen    │    │                     │
     │ └──┬──┘     └──┬──┘      └────┬────┘    │                     │
     │    │           │              │         │                     │
     │    │           └──────┬───────┘         │                     │
     │    │                  ▼                 │                     │
     │    │              ┌────────┐            │                     │
     │    │              │  MUX   │            │                     │
     │    │              │ sel_b  │            │                     │
     │    │              └───┬────┘            │                     │
     │    │                  │                 │                     │
     │    └───────┬──────────┘                 │                     │
     │            ▼                            │                     │
     │       ┌─────────┐                       │                     │
     │       │   ALU   │───────────────────────┼─────────────────────┘
     │       └────┬────┘                       │
     │            │                            │
     └────────────┼────────────────────────────┘
                  │
                  ▼
       ┌────────────────────┐
       │   ID/EX Buffer     │  (Control signals + Data)
       │    (buffer2)       │
       └────────┬───────────┘
                │
                ▼
       ┌────────────────────┐
       │   Data Memory      │
       │  (Load/Store)      │
       └────────┬───────────┘
                │
                ▼
       ┌────────────────────┐
       │   Writeback MUX    │
       │ (ALU/Load/JAL/CSR) │
       └────────────────────┘
```

---

## Pipeline Stages

### 1. Instruction Fetch (IF)
Retrieves instructions from memory. Key components include:
*   **PC**: Tracks the current instruction address.
*   **Instruction Memory**: A 100-word ROM containing the binary code.
*   **IF/ID Buffer**: Synchronizes the fetch stage with downstream logic.

### 2. Decode & Execute (ID/EX)
The "brain" of the processor where instructions are parsed and operations are triggered.
*   **Decoder & Imm Gen**: Extracts fields and generates sign-extended immediates.
*   **Register File**: 32 GPRs (x0-x31) with high-speed access.
*   **ALU**: Executes 11 distinct operations (Arithmetic, Logic, Multiply).
*   **Hazard Unit**: Proactively manages data dependencies via forwarding.
*   **CSR File**: Manages machine-privileged state and trap vectors.

### 3. Memory & Writeback (MEM/WB)
Handles data access and result commitment.
*   **Data Memory**: 1KB byte-addressable RAM for load/store instructions.
*   **Writeback Logic**: Selects the final result (ALU, RAM, PC+4, or CSR) to write back to the Register File.

---

## Supported Instruction Set

### Arithmetic & Logic (R/I-Type)
Supports standard operations: `ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`, `SRL`, `SRA`, `OR`, `AND`.  
Includes the **M-Extension**'s `MUL` instruction.  

### Memory Access (L/S-Type)
Full support for byte, halfword, and word operations: `LB`, `LH`, `LW`, `LBU`, `LHU`, `SB`, `SH`, `SW`.

### Control Flow (B/J-Type)
*   **Conditional**: `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU`.
*   **Unconditional**: `JAL`, `JALR`.

### System Instructions (CSR)
Provides hardware support for: `CSRRW`, `CSRRS`, `CSRRC`, `CSRRWI`, `CSRRSI`, `CSRRCI`.

---

## Hazard Handling

### Data Forwarding (RAW)
The processor utilizes a **Hazard Unit** to detect Read-After-Write (RAW) dependencies. Instead of stalling the pipeline, values are forwarded directly from the Writeback stage back to the ALU inputs, ensuring zero-stall execution for most data-dependent instructions.

### Control Flow Flushing
To handle jumps and taken branches, the pipeline implements an efficient flush mechanism. When a change in control flow is detected, the `IF/ID` buffer is cleared (injected with a NOP) to prevent the execution of stale instructions.

---

## Privilege and Interrupt Support

The implementation includes essential **Machine-Mode CSRs**:
*   `mstatus`, `misa`, `mie`, `mtvec`, `mepc`, `mcause`, `mip`.

It features gated interrupt logic that prioritizes and handles external and timer interrupts based on global and specific enable bits.

---

## Installation and Setup

### Prerequisites
*   **HDL Simulator**: ModelSim / QuestaSim (Recommended) or any SystemVerilog compliant tool.
*   **Waveform Viewer**: GTKWave (optional).

### Quick Start
1.  **Clone the Repository**:
    ```bash
    git clone https://github.com/Cyber-Programmer/RISC-V-3-Phase-Pipeline
    cd RISC-V-3-Phase-Pipeline
    ```
2.  **Compile Source Files**:
    ```bash
    vlog ./*.sv
    ```
3.  **Initiate Simulation**:
    ```bash
    vsim -c tb_processor -voptargs=+acc -do "run -all"
    ```

---

## Testing and Simulation

### Testbench Capabilities
The `tb_processor.sv` file provides a comprehensive verification environment:
*   Automatic clock and reset sequencing.
*   State dumps for all registers (`x0` - `x11`).
*   Real-time monitoring of Data Memory.
*   Validation of CSR states and interrupt handling.

### Included Demos
Switch between test scenarios in the `instruction_memory` file:
*   **Factorial (Default)**: Calculates 5! and stores 120 (0x78) in x2.
*   **R/I-Type Demos**: Verifies arithmetic and immediate operations.
*   **Memory Demo**: Validates Load/Store functionality.
*   **CSR Test**: Exercises privilege mode instructions.

---

## Project Structure

```text
RISC-V-3-Phase-Pipeline/
├── Core Modules
│   ├── processor.sv     # Top-level Integration
│   ├── controller.sv    # Control Unit Logic
│   ├── alu.sv           # Execution Unit
│   ├── reg_file.sv      # Register Storage
│   └── ...              # Other functional units
├── Pipeline Buffers
│   ├── buffer1.sv       # IF/ID Registry
│   └── buffer2.sv       # ID/EX Registry
├── Hazard & System
│   ├── hazard_unit.sv   # Dependency Management
│   └── csr_reg_file.sv  # Privileged Registers
└── Simulation
    ├── tb_processor.sv  # Verification Suite
    └── instruction_memory # Program Binary
```

---

##  Author
**University Project - Computer Architecture**  
Built with precision and SystemVerilog.

---
<p align="center">
  <b>Developed for high-efficiency embedded research.</b>
</p>
