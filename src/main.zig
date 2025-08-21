// ========================================================================
//
// (C) Copyright 2025, Nicolas Selig, All Rights Reserved.
//
// This software is provided 'as-is', without any express or implied
// warranty. In no event will the authors be held liable for any damages
// arising from the use of this software.
//
// ========================================================================

const std = @import("std");

// const DecodeError = error{ InvalidInstruction, InvalidRegister, NotYetImplemented };

// zig fmt: off
const BinaryInstructions = enum(u8) {

    // ASM-86 MOV INSTRUCTIONS                | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 |
    // ---------------------------------------|-----------------------------------------------------------------------------------------------------------|
    // MOV: Register/memory to/from register  | 1 0 0 0 1 0|D|W | MOD| REG | R/M  |    (DISP-LO)    |    (DISP-HI)    |<---------------XXX--------------->|
    // MOV: Immediate to register/memory      | 1 1 0 0 0 1 1|W | MOD|0 0 0| R/M  |    (DISP-LO)    |    (DISP-HI)    |       data      |   data if W=1   |
    // MOV: Immediate to register             | 1 0 1 1|W| reg  |     data        |   data if W=1   |<-----------------------XXX------------------------->|
    // MOV: Memory to accumulator             | 1 0 1 0 0 0 0|W |    addr-lo      |     addr-hi     |<-----------------------XXX------------------------->|
    // MOV: Accumulator to memory             | 1 0 1 0 0 0 1|W |    addr-lo      |     addr-hi     |<-----------------------XXX------------------------->|
    // MOV: Segment reg. to register/memory   | 1 0 0 0 1 1 0 0 | MOD|0|SR | R/M  |    (DISP-LO)    |    (DISP-HI)    |<---------------XXX--------------->|
    // MOV: Register/memory to segment reg.   | 1 0 0 0 1 1 1 0 | MOD|0|SR | R/M  |    (DISP-LO)    |    (DISP-HI)    |<---------------XXX--------------->|

    /// 8 bit Register/memory to/from register with Reg defining the source
    /// and R/M defining the destination. If R/M is .DHSI_DIRECTACCESS_BPD8_BPD16
    /// (0b110) a 16 bit displacement follows, so the instruction length is 4 bytes.
    mov_source_regmem8_reg8     = 0x88,
    /// 16 bit Register/memory to/from register with Reg defining the source
    /// and R/M defining the destination for the instruction
    mov_source_regmem16_reg16   = 0x89,
    /// 8 bit Register/memory to/from register
    mov_dest_reg8_regmem8       = 0x8A,
    /// 16 bit Register/memory to/from register
    mov_dest_reg16_regmem16     = 0x8B,
    /// Immediate to register/memory
    mov_immediate_regmem8       = 0x8C,
    /// Immediate to register/memory
    mov_immediate_regmem16      = 0x8E,
    /// Memory to accumulator
    mov_mem8_acc8               = 0xA0,
    /// Memory to accumulator
    mov_mem16_acc16             = 0xA1,
    /// Accumulator to memory
    mov_acc8_mem8               = 0xA2,
    /// Accumulator to memory
    mov_acc16_mem16             = 0xA3,
    /// 8 bit Immediate to register
    mov_immediate_reg_AL        = 0xB0,
    /// 8 bit Immediate to register
    mov_immediate_reg_CL        = 0xB1,
    /// 8 bit Immediate to register
    mov_immediate_reg_DL        = 0xB2,
    /// 8 bit Immediate to register
    mov_immediate_reg_BL        = 0xB3,
    /// 8 bit Immediate to register
    mov_immediate_reg_AH        = 0xB4,
    /// 8 bit Immediate to register
    mov_immediate_reg_CH        = 0xB5,
    /// 8 bit Immediate to register
    mov_immediate_reg_DH        = 0xB6,
    /// 8 bit Immediate to register
    mov_immediate_reg_BH        = 0xB7,
    /// 8 bit Immediate to register
    mov_immediate_reg_AX        = 0xB8,
    /// 16 bit Immediate to register
    mov_immediate_reg_CX        = 0xB9,
    /// 16 bit Immediate to register
    mov_immediate_reg_DX        = 0xBA,
    /// 16 bit Immediate to register
    mov_immediate_reg_BX        = 0xBB,
    /// 16 bit Immediate to register
    mov_immediate_reg_SP        = 0xBC,
    /// 16 bit Immediate to register
    mov_immediate_reg_BP        = 0xBD,
    /// 16 bit Immediate to register
    mov_immediate_reg_SI        = 0xBE,
    /// 16 bit Immediate to register
    mov_immediate_reg_DI        = 0xBF,
    /// Segment register to register/memory if second byte of format 0x|MOD|000|R/M|
    mov_seg_regmem              = 0xC6,
    /// Register/memory to segment register if second byte of format 0x|MOD|000|R/M|
    mov_regmem_seg              = 0xC7,
};

// Error:
// register / memory to / from register: 0x88, 0x89, 0x8A, 0x8B
const DecodeMovError = error{
    DecodeError,
    NotYetImplementet,
};

// MovInstruction
// register / memory to / from register: 0x88, 0x89, 0x8A, 0x8B
const MovInstruction = struct{
    mnemonic: []const u8,
    d: DValue,
    w: WValue,
    mod: ModValue,
    reg: RegValue,
    rm: RmValue,
    disp_lo: ?u8,
    disp_hi: ?u8,
};

const DecodedPayloadIdentifier = enum{
    err,
    mov_instruction,
};

/// Payload carrying the instruction specific, decoded field values
/// (of the instruction plus all data belonging to the instruction as
/// byte data)inside a struct. If an error occured during instruction decoding its
/// value is returned in this Payload.
const DecodePayload = union(DecodedPayloadIdentifier) {
    err: DecodeMovError,
    mov_instruction: MovInstruction,
};

/// (* .memoryModeNoDisplacement has 16 Bit displacement if
/// R/M = 110)
const ModValue = enum(u2) {
    memoryModeNoDisplacement    = 0b00,
    memoryMode8BitDisplacement  = 0b01,
    memoryMode16BitDisplacement = 0b10,
    registerModeNoDisplacement  = 0b11,
};

/// Field names represent W = 0, W = 1, as in Reg 000 with w = 0 is AL,
/// with w = 1 it's AX
const RegValue = enum(u3) {
    ALAX = 0b000,
    CLCX = 0b001,
    DLDX = 0b010,
    BLBX = 0b011,
    AHSP = 0b100,
    CHBP = 0b101,
    DHSI = 0b110,
    BHDI = 0b111,
};

//         Mod = 11      |           EFFECTIVE ADDRESS CALCULATION
// -------------------------------------------------------------------------------
// R/M | W=0|  W=1 | R/M |   MOD = 00     |      MOD = 01    |      MOD = 10
// -------------------------------------------------------------------------------
// 000 | AL |  AX  | 000 | (BX) + (SI)    | (BX) + (SI) + D8 | (BX) + (SI) + D16
// 001 | CL |  CX  | 001 | (BX) + (DI)    | (BX) + (DI) + D8 | (BX) + (DI) + D16
// 010 | DL |  DX  | 010 | (BP) + (SI)    | (BP) + (SI) + D8 | (BP) + (SI) + D16
// 011 | BL |  BX  | 011 | (BP) + (DI)    | (BP) + (DI) + D8 | (BP) + (DI) + D16
// 100 | AH |  SP  | 100 | (SI)           | (SI) + D8        | (SI) + D16
// 101 | CH |  BP  | 101 | (DI)           | (DI) + D8        | (DI) + D16
// 110 | DH |  SI  | 110 | DIRECT ADDRESS | (BP) + D8        | (BP) + D16
// 111 | BH |  DI  | 111 | (BX)           | (BX) + D8        | (BX) + D16

fn getInstructionSourceAndDest(d: DValue, w: WValue, reg: RegValue, mod: ModValue, rm: RmValue) InstructionInfo {
    var dest: address = undefined;
    var source: address = undefined;
    const regIsSource: bool = if (d == DValue.source) true else false;
    switch (w) {
        .byte => {
            switch (reg) {
                .ALAX => {
                    if (regIsSource) source = address.al else dest = address.al;
                },
                .CLCX => {
                    if (regIsSource) source = address.cl else dest = address.cl;
                },
                .DLDX => {
                    if (regIsSource) source = address.dl else dest = address.dl;
                },
                .BLBX => {
                    if (regIsSource) source = address.bl else dest = address.bl;
                },
                .AHSP => {
                    if (regIsSource) source = address.ah else dest = address.ah;
                },
                .CHBP => {
                    if (regIsSource) source = address.ch else dest = address.ch;
                },
                .DHSI => {
                    if (regIsSource) source = address.dh else dest = address.dh;
                },
                .BHDI => {
                    if (regIsSource) source = address.bh else dest = address.bh;
                },
            }

            switch (mod) {
                .memoryModeNoDisplacement => {
                    switch (rm) {
                        // .ALAX_BXSI_BXSID8_BXSID16 => {},
                        // .CLCX_BXDI_BXDID8_BXDID16 => {},
                        // .DLDX_BPSI_BPSID8_BPSID16 => {},
                        // .BLBX_BPDI_BPDID8_BPDID16 => {},
                        // .AHSP_SI_SID8_SID16 => {},
                        // .CHBP_DI_DID8_DID16 => {},
                        // .DHSI_DIRECTACCESS_BPD8_BPD16 => {},
                        // .BHDI_BX_BXD8_BXD16 => {},
                        else => {
                            std.debug.print("ERROR: Mod value not yet implemented.\n", .{});
                            // std.debug.print("ERROR: R/M value not set.\n", .{});
                        },
                    }
                },
                .memoryMode8BitDisplacement => {
                    switch (rm) {
                        // .ALAX_BXSI_BXSID8_BXSID16 => {},
                        // .CLCX_BXDI_BXDID8_BXDID16 => {},
                        // .DLDX_BPSI_BPSID8_BPSID16 => {},
                        // .BLBX_BPDI_BPDID8_BPDID16 => {},
                        // .AHSP_SI_SID8_SID16 => {},
                        // .CHBP_DI_DID8_DID16 => {},
                        // .DHSI_DIRECTACCESS_BPD8_BPD16 => {},
                        // .BHDI_BX_BXD8_BXD16 => {},
                        else => {
                            std.debug.print("ERROR: Mod value not yet implemented.\n", .{});
                            // std.debug.print("ERROR: R/M value not set.\n", .{});
                        },
                    }
                },
                .memoryMode16BitDisplacement => {
                    switch (rm) {
                        // .ALAX_BXSI_BXSID8_BXSID16 => {},
                        // .CLCX_BXDI_BXDID8_BXDID16 => {},
                        // .DLDX_BPSI_BPSID8_BPSID16 => {},
                        // .BLBX_BPDI_BPDID8_BPDID16 => {},
                        // .AHSP_SI_SID8_SID16 => {},
                        // .CHBP_DI_DID8_DID16 => {},
                        // .DHSI_DIRECTACCESS_BPD8_BPD16 => {},
                        // .BHDI_BX_BXD8_BXD16 => {},
                        else => {
                            std.debug.print("ERROR: Mod value not yet implemented.\n", .{});
                            // std.debug.print("ERROR: R/M value not set.\n", .{});
                        },
                    }
                },
                .registerModeNoDisplacement => {
                    switch (rm) {
                        .ALAX_BXSI_BXSID8_BXSID16 => {
                            if (regIsSource) dest = address.al else source = address.al;
                        },
                        .CLCX_BXDI_BXDID8_BXDID16 => {
                            if (regIsSource) dest = address.cl else source = address.cl;
                        },
                        .DLDX_BPSI_BPSID8_BPSID16 => {
                            if (regIsSource) dest = address.dl else source = address.dl;
                        },
                        .BLBX_BPDI_BPDID8_BPDID16 => {
                            if (regIsSource) dest = address.bl else source = address.bl;
                        },
                        .AHSP_SI_SID8_SID16 => {
                            if (regIsSource) dest = address.ah else source = address.ah;
                        },
                        .CHBP_DI_DID8_DID16 => {
                            if (regIsSource) dest = address.ch else source = address.ch;
                        },
                        .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                            if (regIsSource) dest = address.dh else source = address.dh;
                        },
                        .BHDI_BX_BXD8_BXD16 => {
                            if (regIsSource) dest = address.bh else source = address.bh;
                        },
                    }
                },
            }
        },
        .word => {
            switch (reg) {
                .ALAX => {
                    if (regIsSource) source = address.ax else dest = address.ax;
                },
                .CLCX => {
                    if (regIsSource) source = address.cx else dest = address.cx;
                },
                .DLDX => {
                    if (regIsSource) source = address.dx else dest = address.dx;
                },
                .BLBX => {
                    if (regIsSource) source = address.bx else dest = address.bx;
                },
                .AHSP => {
                    if (regIsSource) source = address.sp else dest = address.sp;
                },
                .CHBP => {
                    if (regIsSource) source = address.bp else dest = address.bp;
                },
                .DHSI => {
                    if (regIsSource) source = address.si else dest = address.si;
                },
                .BHDI => {
                    if (regIsSource) source = address.di else dest = address.di;
                },
            }

            switch (mod) {
                .memoryModeNoDisplacement => {
                    switch (rm) {
                        // .ALAX_BXSI_BXSID8_BXSID16 => {},
                        // .CLCX_BXDI_BXDID8_BXDID16 => {},
                        // .DLDX_BPSI_BPSID8_BPSID16 => {},
                        // .BLBX_BPDI_BPDID8_BPDID16 => {},
                        // .AHSP_SI_SID8_SID16 => {},
                        // .CHBP_DI_DID8_DID16 => {},
                        // .DHSI_DIRECTACCESS_BPD8_BPD16 => {},
                        // .BHDI_BX_BXD8_BXD16 => {},
                        else => {
                            std.debug.print("ERROR: Mod value not yet implemented.\n", .{});
                            // std.debug.print("ERROR: R/M value not set.\n", .{});
                        },
                    }
                },
                .memoryMode8BitDisplacement => {
                    switch (rm) {
                        // .ALAX_BXSI_BXSID8_BXSID16 => {},
                        // .CLCX_BXDI_BXDID8_BXDID16 => {},
                        // .DLDX_BPSI_BPSID8_BPSID16 => {},
                        // .BLBX_BPDI_BPDID8_BPDID16 => {},
                        // .AHSP_SI_SID8_SID16 => {},
                        // .CHBP_DI_DID8_DID16 => {},
                        // .DHSI_DIRECTACCESS_BPD8_BPD16 => {},
                        // .BHDI_BX_BXD8_BXD16 => {},
                        else => {
                            std.debug.print("ERROR: Mod value not yet implemented.\n", .{});
                            // std.debug.print("ERROR: R/M value not set.\n", .{});
                        },
                    }
                },
                .memoryMode16BitDisplacement => {
                    switch (rm) {
                        // .ALAX_BXSI_BXSID8_BXSID16 => {},
                        // .CLCX_BXDI_BXDID8_BXDID16 => {},
                        // .DLDX_BPSI_BPSID8_BPSID16 => {},
                        // .BLBX_BPDI_BPDID8_BPDID16 => {},
                        // .AHSP_SI_SID8_SID16 => {},
                        // .CHBP_DI_DID8_DID16 => {},
                        // .DHSI_DIRECTACCESS_BPD8_BPD16 => {},
                        // .BHDI_BX_BXD8_BXD16 => {},
                        else => {
                            std.debug.print("ERROR: Mod value not yet implemented.\n", .{});
                            // std.debug.print("ERROR: R/M value not set.\n", .{});
                        },
                    }
                },
                .registerModeNoDisplacement => {
                    switch (rm) {
                        .ALAX_BXSI_BXSID8_BXSID16 => {
                            if (regIsSource) dest = address.ax else source = address.ax;
                        },
                        .CLCX_BXDI_BXDID8_BXDID16 => {
                            if (regIsSource) dest = address.cx else source = address.cx;
                        },
                        .DLDX_BPSI_BPSID8_BPSID16 => {
                            if (regIsSource) dest = address.dx else source = address.dx;
                        },
                        .BLBX_BPDI_BPDID8_BPDID16 => {
                            if (regIsSource) dest = address.bx else source = address.bx;
                        },
                        .AHSP_SI_SID8_SID16 => {
                            if (regIsSource) dest = address.sp else source = address.sp;
                        },
                        .CHBP_DI_DID8_DID16 => {
                            if (regIsSource) dest = address.bp else source = address.bp;
                        },
                        .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                            if (regIsSource) dest = address.si else source = address.si;
                        },
                        .BHDI_BX_BXD8_BXD16 => {
                            if (regIsSource) dest = address.di else source = address.di;
                        },
                    }
                },
            }
        },
    }
    return InstructionInfo{ .source = source, .destination = dest };
}


/// Field names encode all possible Register/Register or Register/Memory combinations.
/// The combinations are in the naming starting with mod=11_mod=00_mod=01_mod=10. In the
/// case of mod=11, register mode, the first two letters of the name are used if W=0,
/// while the 3rd and 4th letter are valid if W=1.
const RmValue = enum(u3) {
    ALAX_BXSI_BXSID8_BXSID16           = 0b000,
    CLCX_BXDI_BXDID8_BXDID16           = 0b001,
    DLDX_BPSI_BPSID8_BPSID16           = 0b010,
    BLBX_BPDI_BPDID8_BPDID16           = 0b011,
    AHSP_SI_SID8_SID16                 = 0b100,
    CHBP_DI_DID8_DID16                 = 0b101,
    DHSI_DIRECTACCESS_BPD8_BPD16       = 0b110,
    BHDI_BX_BXD8_BXD16                 = 0b111,
};

/// 0 for no sign extension, 1 for extending 8-bit immediate data to 16 bits if W = 1
const SValue = enum(u1) {
    no_sign             = 0b0,
    sign_extend         = 0b1
};

/// Defines if instructions operates on byte or word data
const WValue = enum(u1) {
    byte                = 0b0,
    word                = 0b1
};

/// If the Reg value holds the instruction source or destination
const DValue = enum(u1) {
    source              = 0b0,
    destination         = 0b1
};

/// Shift/Rotate count is either one or is specified in the CL register
const VValue = enum(u1) {
    one                 = 0b0,
    in_CL               = 0b1
};

/// Repeat/Loop while zero flag is clear or set
const ZValue = enum(u1) {
    clear               = 0b0,
    set                 = 0b1
};
// zig fmt: on

/// Given the Mod and R/M value of a Mov register/memory to/from register
/// instruction, this function returns the number of bytes this instruction
/// consists of.
fn movGetInstructionLength(mod: ModValue, rm: RmValue) u3 {
    switch (mod) {
        .memoryModeNoDisplacement => {
            if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) return 4 else return 2;
        },
        .memoryMode16BitDisplacement => {
            return 4;
        },
        .memoryMode8BitDisplacement => {
            return 3;
        },
        .registerModeNoDisplacement => {
            return 2;
        },
    }
}

const InstructionInfo = struct {
    destination: address = undefined,
    source: address = undefined,
};

/// Matching binary values against instruction- and register enum's. Returns names of the
/// instructions and registers as strings in an []u8.
fn decodeMov(
    mod: ModValue,
    rm: RmValue,
    input: [6]u8,
) DecodePayload {
    const mnemonic = "mov";
    const _rm = rm;
    const _mod = mod;

    switch (_mod) {
        ModValue.memoryModeNoDisplacement => {
            if (_rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) {
                // 2 byte displacement, second byte is most significant
                return DecodePayload{ .err = DecodeMovError.NotYetImplementet };
            } else {
                return DecodePayload{ .err = DecodeMovError.NotYetImplementet };
            }
        },
        ModValue.memoryMode8BitDisplacement => {
            return DecodePayload{ .err = DecodeMovError.NotYetImplementet };
        },
        ModValue.memoryMode16BitDisplacement => {
            return DecodePayload{ .err = DecodeMovError.NotYetImplementet };
        },
        ModValue.registerModeNoDisplacement => {
            // zig fmt: off
            var temp_d = input[0] >> 1;     
            temp_d = temp_d << 7;          
            temp_d = temp_d >> 7;           
            var temp_w = input[0] << 7;
            temp_w = temp_w >> 7;   
            var temp_reg = input[1] >> 3;  
            temp_reg = temp_reg << 5;      
            temp_reg = temp_reg >> 5;      
            // zig fmt: on

            // std.debug.print("DEBUG: temp_reg: {b:0>3}\n", .{temp_reg});

            const d: u1 = @intCast(temp_d);
            const w: u1 = @intCast(temp_w);
            const reg: u3 = @intCast(temp_reg);
            // std.debug.print("DEBUG: asm {s} d {b} w {b} mod {b:0>2} reg {b:0>3} rm {b:0>3}\n", .{
            //     mnemonic, d, w, _mod, reg, _rm,
            // });

            const result = DecodePayload{
                .mov_instruction = MovInstruction{
                    .mnemonic = mnemonic,
                    .d = @enumFromInt(d),
                    .w = @enumFromInt(w),
                    .mod = _mod,
                    .reg = @enumFromInt(reg),
                    .rm = _rm,
                    .disp_lo = null,
                    .disp_hi = null,
                },
            };
            return result;
            // No displacement (register mode)
        },
    }
}

/// Identifiers of the General Register of the CPU.
const address = enum { ah, al, ax, bh, bl, bx, ch, cl, cx, dh, dl, dx, sp, bp, di, si };

const RegisterPayload = union {
    value8: u8,
    value16: u16,
};

// TODO: 8086 Instruction Pointer
//  76543210 76543210
// -------------------
// |       IP        | IP - INSTRUCTION POINTER - instructions are fetched from here
// -------------------

// 16 bit pointer containing the offset (distance in bytes) of the next instruction
// in the current code segment (CS). Saves and restores to / from the Stack.

// TODO: 8086 Flags
//
// AF - Auxiliary Carry flag
// CF - Carry flag
// OF - Overflow flag
// SF - Sign flag
// PF - Parity flag
// ZF - Zero flag

// Additional flags
//
// DF - Direction flag
// IF - Interrupt-enable flag
// TF - Trap flag

// TODO: 8086 Segment Register

// Store base pointers to four segments at a time, these are the only segments
// that can be access at that point in time.
//
// |76543210 76543210|
// |--------x--------|
// |       CS        | CS - CODE SEGMENT  64kb  - Instructions are fetched from here
// |--------x--------|
// |       DS        | DS - DATA SEGMENT  64kb  - Containing mainly program variables
// |--------x--------|                     + => 128kb for data in total
// |       ES        | ES - EXTRA SEGMENT 64kb  - typically also used for data
// |--------x--------|
// |       SS        | SS - STACK SEGMENT 64kb  - Stack
// -------------------
//
// Physical address generation
// ---------------------------------------
//      0xA234 Segment base      |  Logical
//      0x0022 Offset            |  Address
// ---------------------------------------
// Bit shift left 4 bits segment base:
//     0xA2340
// Add offset
//   + 0x00022
//   = 0xA2362H <-- Physical address

/// Simulates the Segment register of the 8086 Processor
const SegmentRegister = struct {
    _CS: u16, // Pointer to Code segment base
    _DS: u16, // Pointer to Data segment base
    _ES: u16, // Pointer to Extra segment base
    _SS: u16, // Pointer to Stack segment base
    pub fn setCS(self: *SegmentRegister, value: u16) void {
        self._CS = value;
    }
    pub fn getCS(self: *SegmentRegister) RegisterPayload {
        return RegisterPayload{ .value16 = self._CS };
    }
    pub fn setDS(self: *SegmentRegister, value: u16) void {
        self._DS = value;
    }
    pub fn getDS(self: *SegmentRegister) RegisterPayload {
        return RegisterPayload{ .value16 = self._DS };
    }
    pub fn setES(self: *SegmentRegister, value: u16) void {
        self._ES = value;
    }
    pub fn getES(self: *SegmentRegister) RegisterPayload {
        return RegisterPayload{ .value16 = self._ES };
    }
    pub fn setSS(self: *SegmentRegister, value: u16) void {
        self._SS = value;
    }
    pub fn getSS(self: *SegmentRegister) RegisterPayload {
        return RegisterPayload{ .value16 = self._SS };
    }
};

// 8086 General Register
//
// |76543210 76543210|
// |--------|--------|                          AX - Word multiply, word divide, word i/o
// |   AH   |   AL   | AX - ACCUMULATOR         AL - Byte multiply, byte divide, byte i/o, translate, decimal arithmatic
// |--------|--------|                          AH - Byte multiply, byte divide
// |   BH   |   BL   | BX - BASE                BX - Translate
// |--------|--------|
// |   CH   |   CL   | CX - COUNT               CX - String operations, loops
// |--------|--------|                          CL - Variable shift and rotate
// |   DH   |   DL   | DX - DATA                DX - Word multiply, word divide, indirect i/o
// |--------|--------|
// |        SP       | SP - STACK POINTER       SP - Stack operations
// |--------X--------|
// |        BP       | BP - BASE POINTER
// |--------X--------|
// |        SI       | SI - SOURCE INDEX        SI - String operations
// |--------X--------|
// |        DI       | DI - DESTINATION INDEX   DI - String operations
// |--------X--------|
// |76543210 76543210|

/// Simulates the General register of the 8086 Processor
const GeneralRegister = struct {
    _AX: u16,
    _BX: u16,
    _CX: u16,
    _DX: u16,
    _SP: u16,
    _BP: u16,
    _DI: u16,
    _SI: u16,
    pub fn setAH(self: *GeneralRegister, value: u8) void {
        self._AX = value ++ self._AX[0..8];
    }
    pub fn setAL(self: *GeneralRegister, value: u8) void {
        self._AX = self._AX[8..] ++ value;
    }
    pub fn setAX(self: *GeneralRegister, value: u16) void {
        self._AX = value;
    }
    pub fn getAX(self: *GeneralRegister, w: WValue, hilo: []const u8) RegisterPayload {
        if (w == WValue.byte) {
            if (std.mem.eql([]const u8, hilo, "hi")) {
                return self._AX[0..8];
            } else {
                return self._AX[8..];
            }
        } else {
            return self._AX;
        }
    }
    pub fn setBH(self: *GeneralRegister, value: u8) void {
        self._BX = value ++ self._BX[0..8];
    }
    pub fn setBL(self: *GeneralRegister, value: u8) void {
        self._BX = self._BX[8..] ++ value;
    }
    pub fn setBX(self: *GeneralRegister, value: u16) void {
        self._BX = value;
    }
    pub fn getBX(self: *GeneralRegister, w: WValue, hilo: []const u8) RegisterPayload {
        if (w == WValue.byte) {
            if (std.mem.eql([]const u8, hilo, "hi")) {
                return self._BX[0..8];
            } else {
                return self._BX[8..];
            }
        } else {
            return self._BX;
        }
    }
    pub fn setCH(self: *GeneralRegister, value: u8) void {
        self._CX = value ++ self._CX[0..8];
    }
    pub fn setCL(self: *GeneralRegister, value: u8) void {
        self._CX = self._CX[8..] ++ value;
    }
    pub fn setCX(self: *GeneralRegister, value: u16) void {
        self._CX = value;
    }
    pub fn getCX(self: *GeneralRegister, w: WValue, hilo: []const u8) RegisterPayload {
        if (w == WValue.byte) {
            if (std.mem.eql([]const u8, hilo, "hi")) {
                return self._CX[0..8];
            } else {
                return self._CX[8..];
            }
        } else {
            return self._CX;
        }
    }
    pub fn setDH(self: *GeneralRegister, value: u8) void {
        self._DX = value ++ self._DX[0..8];
    }
    pub fn setDL(self: *GeneralRegister, value: u8) void {
        self._DX = self._DX[8..] ++ value;
    }
    pub fn setDX(self: *GeneralRegister, value: u16) void {
        self._DX = value;
    }
    pub fn getDX(self: *GeneralRegister, w: WValue, hilo: []const u8) RegisterPayload {
        if (w == WValue.byte) {
            if (std.mem.eql([]const u8, hilo, "hi")) {
                return self._DX[0..8];
            } else {
                return self._DX[8..];
            }
        } else {
            return self._DX;
        }
    }
    pub fn setSP(self: *GeneralRegister, value: u16) void {
        self._SP = value;
    }
    pub fn getSP(self: *GeneralRegister) u16 {
        return self._SP;
    }
    pub fn setBP(self: *GeneralRegister, value: u16) void {
        self._BP = value;
    }
    pub fn getBP(self: *GeneralRegister) u16 {
        return self._BP;
    }
    pub fn setSI(self: *GeneralRegister, value: u16) void {
        self._SI = value;
    }
    pub fn getSI(self: *GeneralRegister) u16 {
        return self._SI;
    }
    pub fn setDI(self: *GeneralRegister, value: u16) void {
        self._DI = value;
    }
    pub fn getDI(self: *GeneralRegister) u16 {
        return self._DI;
    }
};

const MemoryError = error{
    ValueError,
    OutOfBoundError,
};

const MemoryPayload = union {
    err: MemoryError,
    value8: u8,
    value16: u16,
};

// 8086 Memory
// Total Memory: 1,048,576 bytes | physical addresses range from 0x0H to 0xFFFFFH <-- 'H' signifying a physical address
// Segment: 65.536               | logical addresses consist of segment base + offset value
// A, B, C, D, E, F, G, H, I, J  |   -> for any given memory address the segment base value
// und K                         |      locates the first byte of the containing segment and
//                               |      the offset is the distance in bytes of the target
//                               |      location from the beginning of the segment.
//                               |      segment base and offset are u16

/// Simulates the memory of the 8086 Processor
const Memory = struct {
    _memory: [1_048_576]u8,

    // byte     0x0 -    0x13 = dedicated
    // byte    0x14 -    0x7F = reserved
    // byte    0x80 - 0xFFFEF = open
    // byte 0xFFFF0 - 0xFFFFB = dedicated
    // byte 0xFFFFC - 0xFFFFF = reserved

    pub fn setMemory(
        self: *Memory,
        addr: u16!u8,
        value: u16,
        w: WValue,
    ) MemoryError!void {
        if (addr <= 0x7F or addr >= 0xFFFF0) {
            return MemoryError.OutOfBoundError;
        }
        if (@TypeOf(value) == u16) {
            self._memory[addr] = value[0..8];
            self._memory[addr + 1] = value[8..];
        } else if (@TypeOf(value) == u8) {
            if (w == WValue.byte) {
                self._memory[addr] = value;
            } else {
                self._memory[addr] = value;
                self._memory[addr + 1] = value >> 8;
            }
        } else {
            return MemoryError.ValueError;
        }
    }
    pub fn getMemory(self: *Memory, addr: u16, w: WValue) MemoryPayload {
        if (0 <= addr and addr < 65536) {
            if (w == WValue.byte) {
                const payload = MemoryPayload{
                    .value8 = self._memory[addr],
                };
                return payload;
            } else {
                const payload = MemoryPayload{
                    .value16 = self._memory[addr] ++ self._memory[addr + 1],
                };
                return payload;
            }
        } else {
            const payload = MemoryPayload{
                .err = MemoryError.OutOfBoundError,
            };
            return payload;
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const args_allocator = gpa.allocator();
    const args = try std.process.argsAlloc(args_allocator);
    defer std.process.argsFree(args_allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: x86sim <input_file>\n", .{});
        std.debug.print("Examples:\n", .{});
        std.debug.print("   > x86sim my_binary\n", .{});
        std.debug.print("   > x86sim ./my_binary\n", .{});
        std.debug.print("   > x86sim ../test_data/my_binary\n", .{});
        std.process.exit(1);
    }

    const input_file_path = args[1];

    const heap_allocator = std.heap.page_allocator;
    const open_mode = std.fs.File.OpenFlags{
        .mode = .read_only,
        .lock = .none,
        .lock_nonblocking = false,
        .allow_ctty = false,
    };

    const file = std.fs.cwd().openFile(input_file_path, open_mode) catch |err| {
        switch (err) {
            error.FileNotFound => {
                std.debug.print("ERROR: Could not find file '{s}'\n", .{input_file_path});
                std.process.exit(1);
            },
            error.AccessDenied => {
                std.debug.print("ERROR: Access denies to file '{s}'\n", .{input_file_path});
                std.process.exit(1);
            },
            else => {
                std.debug.print("ERROR: Unable to open file '{s}': {any}\n", .{ input_file_path, err });
                std.process.exit(1);
            },
        }
    };
    defer file.close();
    std.debug.print("+++x86+Simulator++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n", .{});
    std.debug.print("Simulating target: {s}\n", .{input_file_path});

    if (@TypeOf(file) != std.fs.File) {
        std.debug.print("FileError: file object is not of the correct type.\n", .{});
    }

    const maxFileSizeBytes = 65535;

    var activeByte: u16 = 0;
    const InstructionQueue: *[6]u8 = undefined;
    var stepSize: u3 = 2;
    var InstructionBytes: [6]u8 = undefined;
    const file_contents = try file.readToEndAlloc(heap_allocator, maxFileSizeBytes);
    std.debug.print("Instruction byte count: {d}\n", .{file_contents.len});
    std.debug.print("+++Start+active+byte+{d}++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n", .{activeByte});

    var depleted: bool = false;

    while (!depleted and activeByte < file_contents.len) : (activeByte += stepSize) {
        const default: u8 = 0b00000000;
        InstructionQueue[0] = if (activeByte < file_contents.len) file_contents[activeByte] else default;
        InstructionQueue[1] = if (activeByte + 1 < file_contents.len) file_contents[activeByte + 1] else default;
        InstructionQueue[2] = if (activeByte + 2 < file_contents.len) file_contents[activeByte + 2] else default;
        InstructionQueue[3] = if (activeByte + 3 < file_contents.len) file_contents[activeByte + 3] else default;
        InstructionQueue[4] = if (activeByte + 4 < file_contents.len) file_contents[activeByte + 4] else default;
        InstructionQueue[5] = if (activeByte + 5 < file_contents.len) file_contents[activeByte + 5] else default;

        // std.debug.print("---Data-Range----------------------------------------------------------------\n", .{});
        // std.debug.print("1: {b:0>8} {d},\n2: {b:0>8} {d},\n3: {b:0>8} {d},\n4: {b:0>8} {d},\n5: {b:0>8} {d},\n6: {b:0>8} {d},\n", .{
        //     first_byte,  activeByte,
        //     second_byte, activeByte + 1,
        //     third_byte,  activeByte + 2,
        //     fourth_byte, activeByte + 3,
        //     fifth_byte,  activeByte + 4,
        //     sixth_byte,  activeByte + 5,
        // });

        const instruction: BinaryInstructions = @enumFromInt(InstructionQueue[0]);

        // std.debug.print("DEBUG: instruction: {any}\n", .{instruction});
        var mod: ModValue = undefined;
        var rm: RmValue = undefined;
        switch (instruction) {
            BinaryInstructions.mov_source_regmem8_reg8 => { // 0x88
                mod = @enumFromInt(InstructionQueue[1] >> 6);
                const temp_rm = InstructionQueue[1] << 5;
                rm = @enumFromInt(temp_rm >> 5);

                stepSize = movGetInstructionLength(mod, rm);
                // std.debug.print("DEBUG: 0x88: Mod {any}, R/M {any} = {d} bytes\n", .{ mod, rm, stepSize });
            },
            BinaryInstructions.mov_source_regmem16_reg16 => { // 0x89
                mod = @enumFromInt(InstructionQueue[1] >> 6);
                const temp_rm = InstructionQueue[1] << 5;
                rm = @enumFromInt(temp_rm >> 5);

                stepSize = movGetInstructionLength(mod, rm);
                // std.debug.print("DEBUG: 0x89: Mod {any}, R/M {any} = {d} bytes\n", .{ mod, rm, stepSize });
            },
            BinaryInstructions.mov_dest_reg8_regmem8 => { // 0x8A
                mod = @enumFromInt(InstructionQueue[1] >> 6);
                const temp_rm = InstructionQueue[1] << 5;
                rm = @enumFromInt(temp_rm >> 5);

                stepSize = movGetInstructionLength(mod, rm);
                // std.debug.print("DEBUG: 0x8A: Mod {any}, R/M {any} = {d} bytes\n", .{ mod, rm, stepSize });
            },
            BinaryInstructions.mov_dest_reg16_regmem16 => { // 0x8B
                mod = @enumFromInt(InstructionQueue[1] >> 6);
                const temp_rm = InstructionQueue[1] << 5;
                rm = @enumFromInt(temp_rm >> 5);

                stepSize = movGetInstructionLength(mod, rm);
                // std.debug.print("DEBUG: 0x8B: Mod {any}, R/M {any} = {d} bytes\n", .{ mod, rm, stepSize });
            },
            else => {
                std.debug.print("ERROR: Not implemented yet\n", .{});
            },
        }

        switch (stepSize) {
            2 => {
                InstructionBytes = [6]u8{
                    InstructionQueue[0],
                    InstructionQueue[1],
                    0b0000_0000,
                    0b0000_0000,
                    0b0000_0000,
                    0b0000_0000,
                };
            },
            3 => {
                InstructionBytes = [6]u8{
                    InstructionQueue[0],
                    InstructionQueue[1],
                    InstructionQueue[2],
                    0b0000_0000,
                    0b0000_0000,
                    0b0000_0000,
                };
            },
            4 => {
                InstructionBytes = [6]u8{
                    InstructionQueue[0],
                    InstructionQueue[1],
                    InstructionQueue[2],
                    InstructionQueue[3],
                    0b0000_0000,
                    0b0000_0000,
                };
            },
            5 => {
                InstructionBytes = [6]u8{
                    InstructionQueue[0],
                    InstructionQueue[1],
                    InstructionQueue[2],
                    InstructionQueue[3],
                    InstructionQueue[4],
                    0b0000_0000,
                };
            },
            6 => {
                InstructionBytes = [6]u8{
                    InstructionQueue[0],
                    InstructionQueue[1],
                    InstructionQueue[2],
                    InstructionQueue[3],
                    InstructionQueue[4],
                    InstructionQueue[5],
                };
            },
            else => {
                std.debug.print("InstructionError: Instruction size {} invalid", .{stepSize});
            },
        }

        // std.debug.print("---0x{x}-{any}-- Mod: {any}, R/M: {any}\n", .{ @intFromEnum(instruction), instruction, mod, rm });
        // std.debug.print("1: {b:0>8}, {d}\n2: {b:0>8}, {d}\n3: {b:0>8}, {d}\n4: {b:0>8}, {d}\n5: {b:0>8}, {d}\n6: {b:0>8}, {d}\n", .{
        //     instruction_bytes[0], activeByte,
        //     instruction_bytes[1], activeByte + 1,
        //     instruction_bytes[2], activeByte + 2,
        //     instruction_bytes[3], activeByte + 3,
        //     instruction_bytes[4], activeByte + 4,
        //     instruction_bytes[5], activeByte + 5,
        // });

        var payload: DecodePayload = undefined;
        switch (instruction) {
            .mov_source_regmem8_reg8 => {
                payload = decodeMov(mod, rm, InstructionBytes);
            },
            .mov_source_regmem16_reg16 => {
                payload = decodeMov(mod, rm, InstructionBytes);
            },
            .mov_dest_reg8_regmem8 => {
                payload = decodeMov(mod, rm, InstructionBytes);
            },
            .mov_dest_reg16_regmem16 => {
                payload = decodeMov(mod, rm, InstructionBytes);
            },
            else => {
                std.debug.print("ERROR: Not implemented yet\n", .{});
            },
        }

        switch (payload) {
            .err => {
                switch (payload.err) {
                    DecodeMovError.DecodeError => {
                        std.debug.print("Error: {any}\ncontinue...\n", .{payload.err});
                        continue;
                    },
                    DecodeMovError.NotYetImplementet => {
                        std.debug.print("Error: {any}\ncontinue...\n", .{payload.err});
                        continue;
                    },
                }
            },
            .mov_instruction => {
                const d: DValue = payload.mov_instruction.d;
                const w: WValue = payload.mov_instruction.w;
                const reg: RegValue = payload.mov_instruction.reg;
                // std.debug.print("Instruction: 0x{x}: Mod: {b}, Reg: {any}, R/M: {any}, DISP-LO: {b:0>8}, DISP-HI: {b:0>8}\n", .{
                //     @intFromEnum(instruction),
                //     @intFromEnum(mod),
                //     reg,
                //     rm,
                //     if (stepSize == 3 or stepSize == 4) payload.mov_instruction.disp_lo.? else instruction_bytes[2],
                //     if (stepSize == 4) payload.mov_instruction.disp_hi.? else instruction_bytes[3],
                // });

                const instruction_info: InstructionInfo = getInstructionSourceAndDest(
                    d,
                    w,
                    reg,
                    mod,
                    rm,
                );

                std.debug.print("ASM-86: {s} {any},{any}\n", .{
                    payload.mov_instruction.mnemonic,
                    instruction_info.destination,
                    instruction_info.source,
                });
            },
        }

        if (activeByte + stepSize == maxFileSizeBytes or activeByte + stepSize >= file_contents.len) {
            depleted = true;
            std.debug.print("+++Simulation+finished++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n", .{});
        } else {
            if (activeByte + stepSize > 999) {
                std.debug.print("+++Next+active+byte+{d}++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n", .{activeByte + stepSize});
            } else if (activeByte + stepSize > 99) {
                std.debug.print("+++Next+active+byte+{d}+++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n", .{activeByte + stepSize});
            } else if (activeByte + stepSize > 9) {
                std.debug.print("+++Next+active+byte+{d}++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n", .{activeByte + stepSize});
            } else {
                std.debug.print("+++Next+active+byte+{d}+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n", .{activeByte + stepSize});
            }
        }
    }
}

test "listing_0037_single_register_mov" {
    // Since the index of the byte array loaded from file needs
    // to move allong at the correct speed, meaning if a
    // instruction takes three bytes the cursor also needs to
    // move forward three bytes.

    // MOV
    // listing_0037_single_register_mov
    // 0x89
    // Mod: 0b11, R/M != 0b110,
    const test_input_0x89_mod_register_mode_no_displacement: [6]u8 = [_]u8{
        0b1000_1001, // 0x89 => mov, d=source, w=word
        0b1101_1001, // mod=registerMode, reg=BLBX, R/M=CLCX
        0b0000_0000,
        0b0000_0000,
        0b0000_0000,
        0b0000_0000,
    };
    const test_output_payload_0x89_mod_register_mode_no_displacement = DecodePayload{
        .mov_instruction = MovInstruction{
            .mnemonic = "mov",
            .d = DValue.source,
            .w = WValue.word,
            .mod = ModValue.registerModeNoDisplacement,
            .reg = RegValue.BLBX,
            .rm = RmValue.CLCX_BXDI_BXDID8_BXDID16,
            .disp_lo = null,
            .disp_hi = null,
        },
    };
    try std.testing.expectEqual(
        decodeMov(
            ModValue.registerModeNoDisplacement,
            RmValue.CLCX_BXDI_BXDID8_BXDID16,
            test_input_0x89_mod_register_mode_no_displacement,
        ).mov_instruction,
        test_output_payload_0x89_mod_register_mode_no_displacement.mov_instruction,
    );
}

test "listing_0038_many_register_mov" {
    // listing_0038_many_register_mov
    // 0x88, 0x89

    // 0x88, Mod: 0b01, R/M:
    const test_input_0x89_mod_memory_mode_8_bit_displacement: [6]u8 = [_]u8{
        0b1000_1001,
        0b0110_0010,
        0b0101_0101,
        0b0000_0000,
        0b0000_0000,
        0b0000_0000,
    };
    const test_output_payload_0x89_mod_memory_mode_8_bit_displacement = DecodePayload{ .mov_instruction = MovInstruction{
        .mnemonic = "mov",
        .d = @enumFromInt(0b0),
        .w = @enumFromInt(0b1),
        .mod = @enumFromInt(0b01),
        .reg = @enumFromInt(0b100),
        .rm = @enumFromInt(0b010),
        .disp_lo = 0b0101_0101,
        .disp_hi = null,
    } };
    try std.testing.expectEqual(
        decodeMov(
            ModValue.memoryMode8BitDisplacement,
            RmValue.AHSP_SI_SID8_SID16,
            test_input_0x89_mod_memory_mode_8_bit_displacement,
        ),
        test_output_payload_0x89_mod_memory_mode_8_bit_displacement,
    );
}
