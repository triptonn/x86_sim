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
const logger = @import("log.zig");

// const DecodeError = error{ InvalidInstruction, InvalidRegister, NotYetImplemented };

// zig fmt: off
const BinaryInstructions = enum(u8) {

    // ASM-86 MOV INSTRUCTIONS                | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 |
    // ---------------------------------------|-----------------------------------------------------------------------------------------------------------|
    // MOV: Register/memory to/from register  | 1 0 0 0 1 0|D|W | MOD| REG | R/M  |    (DISP-LO)    |    (DISP-HI)    |<---------------XXX--------------->|
    // MOV: Immediate to register/memory      | 1 1 0 0 0 1 1|W | MOD|0 0 0| R/M  |    (DISP-LO)    |    (DISP-HI)    |       data      |   data if W=1   |
    // MOV: Immediate to register             | 1 0 1 1|W| reg  |      data       |   data if W=1   |<-----------------------XXX------------------------->|
    // MOV: Memory to accumulator             | 1 0 1 0 0 0 0|W |     addr-lo     |     addr-hi     |<-----------------------XXX------------------------->|
    // MOV: Accumulator to memory             | 1 0 1 0 0 0 1|W |     addr-lo     |     addr-hi     |<-----------------------XXX------------------------->|
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
    mov_immediate_reg_al        = 0xB0,
    /// 8 bit Immediate to register
    mov_immediate_reg_cl        = 0xB1,
    /// 8 bit Immediate to register
    mov_immediate_reg_dl        = 0xB2,
    /// 8 bit Immediate to register
    mov_immediate_reg_bl        = 0xB3,
    /// 8 bit Immediate to register
    mov_immediate_reg_ah        = 0xB4,
    /// 8 bit Immediate to register
    mov_immediate_reg_ch        = 0xB5,
    /// 8 bit Immediate to register
    mov_immediate_reg_dh        = 0xB6,
    /// 8 bit Immediate to register
    mov_immediate_reg_bh        = 0xB7,
    /// 8 bit Immediate to register
    mov_immediate_reg_ax        = 0xB8,
    /// 16 bit Immediate to register
    mov_immediate_reg_cx        = 0xB9,
    /// 16 bit Immediate to register
    mov_immediate_reg_dx        = 0xBA,
    /// 16 bit Immediate to register
    mov_immediate_reg_bx        = 0xBB,
    /// 16 bit Immediate to register
    mov_immediate_reg_sp        = 0xBC,
    /// 16 bit Immediate to register
    mov_immediate_reg_bp        = 0xBD,
    /// 16 bit Immediate to register
    mov_immediate_reg_si        = 0xBE,
    /// 16 bit Immediate to register
    mov_immediate_reg_di        = 0xBF,
    /// Segment register to register/memory if second byte of format 0x|MOD|000|R/M|
    mov_seg_regmem              = 0xC6,
    /// Register/memory to segment register if second byte of format 0x|MOD|000|R/M|
    mov_regmem_seg              = 0xC7,
};

// Error:
// register / memory to / from register: 0x88, 0x89, 0x8A, 0x8B
const DecodeInstructionError = error{
    DecodeError,
    NotYetImplementet,
};

const SimulatorError = error{
    FileError,
    InstructionError,
    InstructionSizeError,
};

// MovInstruction
// register / memory to / from register: 0x88, 0x89, 0x8A, 0x8B
const MovWithModInstruction = struct{
    mnemonic: []const u8,
    d: DValue,
    w: WValue,
    mod: ModValue,
    reg: RegValue,
    rm: RmValue,
    disp_lo: ?u8,
    disp_hi: ?u8,
    data: ?u8,
    w_data: ?u8,
};

const MovWithoutModInstruction = struct{
    mnemonic: []const u8,
    w: WValue,
    reg: RegValue,
    data: u8,
    w_data: ?u8,
};

const DecodedPayloadIdentifier = enum{
    err,
    mov_with_mod_instruction,
    mov_without_mod_instruction,
};

/// Payload carrying the instruction specific, decoded field values
/// (of the instruction plus all data belonging to the instruction as
/// byte data)inside a struct. If an error occured during instruction
/// decoding its value is returned in this Payload.
const DecodePayload = union(DecodedPayloadIdentifier) {
    err: DecodeInstructionError,
    mov_with_mod_instruction: MovWithModInstruction,
    mov_without_mod_instruction: MovWithoutModInstruction,
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


// zig fmt: on
fn getInstructionDest(w: WValue, reg: RegValue) InstructionInfo {
    const Address = AddressDirectory.Address;
    var dest: Address = undefined;
    switch (w) {
        .byte => {
            switch (reg) {
                .ALAX => {
                    dest = Address.al;
                },
                .BLBX => {
                    dest = Address.bl;
                },
                .CLCX => {
                    dest = Address.cl;
                },
                .DLDX => {
                    dest = Address.dl;
                },
                .AHSP => {
                    dest = Address.ah;
                },
                .BHDI => {
                    dest = Address.bh;
                },
                .CHBP => {
                    dest = Address.ch;
                },
                .DHSI => {
                    dest = Address.dh;
                },
            }
        },
        .word => {
            switch (reg) {
                .ALAX => {
                    dest = Address.ax;
                },
                .BLBX => {
                    dest = Address.bx;
                },
                .CLCX => {
                    dest = Address.cx;
                },
                .DLDX => {
                    dest = Address.dx;
                },
                .AHSP => {
                    dest = Address.sp;
                },
                .BHDI => {
                    dest = Address.di;
                },
                .CHBP => {
                    dest = Address.bp;
                },
                .DHSI => {
                    dest = Address.si;
                },
            }
        },
    }
    const destination_payload = DestinationInfo{
        .address = dest,
    };
    const source_payload = SourceInfo{
        .address = Address.none,
    };
    return InstructionInfo{
        .destination_info = destination_payload,
        .source_info = source_payload,
    };
}
// zig fmt: off

/// Given the fields decoded from the instruction bytes this function returns
/// the addresses of source and destination. These can be registers or memory
/// addresses. The values are returned as InstructionInfo.
fn getInstructionSourceAndDest(
    registers: *Register,
    d: DValue,
    w: WValue,
    reg: RegValue,
    mod: ModValue,
    rm: RmValue,
    disp_lo: ?u8,
    disp_hi: ?u8,
    // data: ?u8,
    // w_data: ?u8,
    ) InstructionInfo {
    const Address = AddressDirectory.Address;
    var dest: Address = undefined;
    var source: Address = undefined;
    var dest_effective_address: u20 = undefined;
    var source_effective_address: u20 = undefined;
    var dest_address_calculation: EffectiveAddressCalculation = undefined;
    var source_address_calculation: EffectiveAddressCalculation = undefined;
    const regIsSource: bool = if (d == DValue.source) true else false;

    // Checking what the REG field encodes
    switch (w) {
        .byte => {
            switch (reg) {
                .ALAX => {
                    if (regIsSource) source = Address.al else dest = Address.al;
                },
                .CLCX => {
                    if (regIsSource) source = Address.cl else dest = Address.cl;
                },
                .DLDX => {
                    if (regIsSource) source = Address.dl else dest = Address.dl;
                },
                .BLBX => {
                    if (regIsSource) source = Address.bl else dest = Address.bl;
                },
                .AHSP => {
                    if (regIsSource) source = Address.ah else dest = Address.ah;
                },
                .CHBP => {
                    if (regIsSource) source = Address.ch else dest = Address.ch;
                },
                .DHSI => {
                    if (regIsSource) source = Address.dh else dest = Address.dh;
                },
                .BHDI => {
                    if (regIsSource) source = Address.bh else dest = Address.bh;
                },
            }

        },
        .word => {
            switch (reg) {
                .ALAX => {
                    if (regIsSource) source = Address.ax else dest = Address.ax;
                },
                .CLCX => {
                    if (regIsSource) source = Address.cx else dest = Address.cx;
                },
                .DLDX => {
                    if (regIsSource) source = Address.dx else dest = Address.dx;
                },
                .BLBX => {
                    if (regIsSource) source = Address.bx else dest = Address.bx;
                },
                .AHSP => {
                    if (regIsSource) source = Address.sp else dest = Address.sp;
                },
                .CHBP => {
                    if (regIsSource) source = Address.bp else dest = Address.bp;
                },
                .DHSI => {
                    if (regIsSource) source = Address.si else dest = Address.si;
                },
                .BHDI => {
                    if (regIsSource) source = Address.di else dest = Address.di;
                },
            }
        },
    }

    // Effective Address Calculation
    // Segment base: 0x1000, Index (offset): 0x0022,
    // 1. Cast u16 to u20 and shift segment base left by four bits:
    //      0x01000 << 4 = 0x10000
    // 2. Add index to shifted segment base value:
    //      0x10000 + 0x0022 = 0x10022 << Physical address
    // 3. The same could be achieved by this formula:
    //      Physical address = (Segment base * 16) + Index (offset)

    // Checking what the R/M field encodes
    switch (mod) {
        .memoryModeNoDisplacement => {
            switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    const bx_value: u16 = registers.getBX(WValue.word, null).value16;
                    if (regIsSource) {
                        dest_effective_address = (@as(u20, bx_value) << 4) + registers.getSI();
                    } else {
                        source_effective_address = (@as(u20, bx_value) << 4) + registers.getSI();
                    }
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    const bx_value: u16 = registers.getBX(WValue.word, null).value16;
                    if (regIsSource) {
                        dest_effective_address = (@as(u20, bx_value) << 4) + registers.getDI();
                    } else {
                        source_effective_address = (@as(u20, bx_value) << 4) + registers.getDI();
                    }
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    if (regIsSource) {
                        dest_effective_address = (@as(u20, registers.getBP()) << 4) + registers.getSI();
                    } else {
                        source_effective_address = (@as(u20, registers.getBP()) << 4) + registers.getSI();
                    }
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    if (regIsSource) {
                        dest_effective_address = (@as(u20, registers.getBP()) << 4) + registers.getDI();
                    } else {
                        source_effective_address = (@as(u20, registers.getBP()) << 4) + registers.getDI();
                    }
                },
                .AHSP_SI_SID8_SID16 => {
                    if (regIsSource) dest_effective_address = registers.getSI() else source_effective_address = registers.getSI();
                },
                .CHBP_DI_DID8_DID16 => {
                    if (regIsSource) dest_effective_address = registers.getDI() else source_effective_address = registers.getDI();
                },
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
                    source_effective_address = displacement;
                    switch (reg) {
                        .ALAX => {
                            dest = Address.ax;
                        },
                        .BLBX => {
                            dest = Address.bx;
                        },
                        .CLCX => {
                            dest = Address.cx;
                        },
                        .DLDX => {
                            dest = Address.dx;
                        },
                        .AHSP => {
                            dest = Address.sp;
                        },
                        .BHDI => {
                            dest = Address.di;
                        },
                        .CHBP => {
                            dest = Address.bp;
                        },
                        .DHSI => {
                            dest = Address.si;
                        },
                    }
                },
                .BHDI_BX_BXD8_BXD16 => {
                    const bx_value: u16 = registers.getBX(WValue.word, null).value16;
                    if (regIsSource) {
                        dest_effective_address = (@as(u20, bx_value) << 4);
                    } else {
                        source_effective_address = (@as(u20, bx_value) << 4);
                    }
                },
            }
        },
        .memoryMode8BitDisplacement => {
            switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    const bx_value: u16 = registers.getBX(WValue.word, null).value16;
                    const effective_address_calculation: EffectiveAddressCalculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.si,
                        .displacement = DisplacementFormat.d8,
                        .effective_address = ((@as(u20, bx_value)) << 4) + registers.getSI() + disp_lo.?,
                    };
                    if (regIsSource) {
                        dest_address_calculation = effective_address_calculation; 
                    } else {
                        source_address_calculation = effective_address_calculation;
                    }
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    const bx_value: u16 = registers.getBX(WValue.word, null).value16;
                    const effective_address_calculation: EffectiveAddressCalculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.si,
                        .displacement = DisplacementFormat.d8,
                        .effective_address = ((@as(u20, bx_value)) << 4) + registers.getDI() + disp_lo.?,
                    };
                    if (regIsSource) {
                        dest_address_calculation = effective_address_calculation;
                    } else {
                        source_address_calculation = effective_address_calculation;
                    }
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    const bp_value: u16 = registers.getBP();
                    const effective_address_calculation: EffectiveAddressCalculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.si,
                        .displacement = DisplacementFormat.d8,
                        .effective_address = ((@as(u20, bp_value) << 4) + registers.getSI() + disp_lo.?),
                    };
                    if (regIsSource) {
                        dest_address_calculation = effective_address_calculation;
                    } else {
                        source_address_calculation = effective_address_calculation;
                    }
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    const bp_value: u16 = registers.getBP();
                    const effective_address_calculation: EffectiveAddressCalculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.di,
                        .displacement = DisplacementFormat.d8,
                        .effective_address = ((@as(u20, bp_value) << 4) + registers.getDI() + disp_lo.?),
                    };
                    if (regIsSource) {
                        dest_address_calculation = effective_address_calculation;
                    } else {
                        source_address_calculation = effective_address_calculation;
                    }
                },
                .AHSP_SI_SID8_SID16 => {
                    const si_value: u16 = registers.getSI();
                    const effective_address_calculation: EffectiveAddressCalculation = EffectiveAddressCalculation{
                        .base = Address.si,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d8,
                        .effective_address = ((@as(u20, si_value)) << 4) + disp_lo.?,
                    };
                    if (regIsSource) {
                        dest_address_calculation = effective_address_calculation;
                    } else {
                        source_address_calculation = effective_address_calculation;
                    }
                },
                .CHBP_DI_DID8_DID16 => {
                    const di_value: u16 = registers.getDI();
                    const effective_address_calculation: EffectiveAddressCalculation = EffectiveAddressCalculation{
                        .base = Address.di,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d8,
                        .effective_address = ((@as(u20, di_value)) << 4) + disp_lo.?,
                    };
                    if (regIsSource) {
                        dest_address_calculation = effective_address_calculation;
                    } else {
                        source_address_calculation = effective_address_calculation;
                    }
                },
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    const bp_value: u16 = registers.getBP();
                    const effective_address_calculation: EffectiveAddressCalculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d8,
                        .effective_address = ((@as(u20, bp_value) << 4) + disp_lo.?),
                    };
                    if (regIsSource) {
                        dest_address_calculation = effective_address_calculation;
                    } else {
                        source_address_calculation = effective_address_calculation;
                    }
                },
                .BHDI_BX_BXD8_BXD16 => {
                    const bx_value: u16 = registers.getBX(WValue.word, null).value16;
                    const effective_address_calculation: EffectiveAddressCalculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d8,
                        .effective_address = ((@as(u20, bx_value) << 4) + disp_lo.?),
                    };
                    if (regIsSource) {
                        dest_address_calculation = effective_address_calculation;
                    } else {
                        source_address_calculation = effective_address_calculation;
                    }
                },
            }
        },
        .memoryMode16BitDisplacement => {
            switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    const bx_value: u16 = registers.getBX(WValue.word, null).value16;
                    const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
                    if (regIsSource) {
                        dest_effective_address = (@as(u20, bx_value) << 4) + registers.getSI() + displacement;
                    } else {
                        source_effective_address = (@as(u20, bx_value) << 4) + registers.getSI() + displacement;
                    }
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    const bx_value: u16 = registers.getBX(WValue.word, null).value16;
                    const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
                    if (regIsSource) {
                        dest_effective_address = (@as(u20, bx_value) << 4) + registers.getDI() + displacement;
                    } else {
                        source_effective_address = (@as(u20, bx_value) << 4) + registers.getDI() + displacement;
                    }
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    const bp_value: u16 = registers.getBP();
                    const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
                    if (regIsSource) {
                        dest_effective_address = (@as(u20, bp_value) << 4) + registers.getSI() + displacement;
                    } else {
                        source_effective_address = (@as(u20, bp_value) << 4) + registers.getSI() + displacement;
                    }
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    const bp_value: u16 = registers.getBP();
                    const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
                    if (regIsSource) {
                        dest_effective_address = (@as(u20, bp_value) << 4) + registers.getDI() + displacement;
                    } else {
                        source_effective_address = (@as(u20, bp_value) << 4) + registers.getDI() + displacement;
                    }
                },
                .AHSP_SI_SID8_SID16 => {
                    const si_value: u16 = registers.getSI();
                    const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
                    if (regIsSource) {
                        dest_effective_address = (@as(u20, si_value) << 4) + displacement;
                    } else {
                        source_effective_address = (@as(u20, si_value) << 4) + displacement;
                    }
                    
                },
                .CHBP_DI_DID8_DID16 => {
                    const di_value: u16 = registers.getDI();
                    const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
                    if (regIsSource) {
                        dest_effective_address = (@as(u20, di_value) << 4) + displacement;
                    } else {
                        source_effective_address = (@as(u20, di_value) << 4) + displacement;
                    }

                },
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    const bp_value: u16 = registers.getBP();
                    const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
                    if (regIsSource) {
                        dest_effective_address = (@as(u20, bp_value) << 4) + displacement;
                    } else {
                        source_effective_address = (@as(u20, bp_value) << 4) + displacement;
                    }

                },
                .BHDI_BX_BXD8_BXD16 => {
                    const bx_value: u16 = registers.getBX(WValue.word, null).value16;
                    const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
                    if (regIsSource) {
                        dest_effective_address = (@as(u20, bx_value) << 4) + displacement;
                    } else {
                        source_effective_address = (@as(u20, bx_value) << 4) + displacement;
                    }
                },
            }
        },
        .registerModeNoDisplacement => {
            switch (w) {
                .byte => {
                    switch (rm) {
                        .ALAX_BXSI_BXSID8_BXSID16 => {
                            if (regIsSource) dest = Address.al else source = Address.al;
                        },
                        .CLCX_BXDI_BXDID8_BXDID16 => {
                            if (regIsSource) dest = Address.cl else source = Address.cl;
                        },
                        .DLDX_BPSI_BPSID8_BPSID16 => {
                            if (regIsSource) dest = Address.dl else source = Address.dl;
                        },
                        .BLBX_BPDI_BPDID8_BPDID16 => {
                            if (regIsSource) dest = Address.bl else source = Address.bl;
                        },
                        .AHSP_SI_SID8_SID16 => {
                            if (regIsSource) dest = Address.ah else source = Address.ah;
                        },
                        .CHBP_DI_DID8_DID16 => {
                            if (regIsSource) dest = Address.ch else source = Address.ch;
                        },
                        .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                            if (regIsSource) dest = Address.dh else source = Address.dh;
                        },
                        .BHDI_BX_BXD8_BXD16 => {
                            if (regIsSource) dest = Address.bh else source = Address.bh;
                        },
                    }
                },
                .word => {
                    switch (rm) {
                        .ALAX_BXSI_BXSID8_BXSID16 => {
                            if (regIsSource) dest = Address.ax else source = Address.ax;
                        },
                        .CLCX_BXDI_BXDID8_BXDID16 => {
                            if (regIsSource) dest = Address.cx else source = Address.cx;
                        },
                        .DLDX_BPSI_BPSID8_BPSID16 => {
                            if (regIsSource) dest = Address.dx else source = Address.dx;
                        },
                        .BLBX_BPDI_BPDID8_BPDID16 => {
                            if (regIsSource) dest = Address.bx else source = Address.bx;
                        },
                        .AHSP_SI_SID8_SID16 => {
                            if (regIsSource) dest = Address.sp else source = Address.sp;
                        },
                        .CHBP_DI_DID8_DID16 => {
                            if (regIsSource) dest = Address.bp else source = Address.bp;
                        },
                        .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                            if (regIsSource) dest = Address.si else source = Address.si;
                        },
                        .BHDI_BX_BXD8_BXD16 => {
                            if (regIsSource) dest = Address.di else source = Address.di;
                        },
                    }
                },
            }
        },
    }

    var destination_payload: DestinationInfo = undefined;
    if (mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) {
        destination_payload = DestinationInfo{
            .address = dest,
        };
    } else if (mod == ModValue.memoryModeNoDisplacement) {
        destination_payload = DestinationInfo{
            .address_calculation = EffectiveAddressCalculation{
                .base = switch (rm) {
                    .ALAX_BXSI_BXSID8_BXSID16 => Address.bx,
                    .CLCX_BXDI_BXDID8_BXDID16 => Address.bx,
                    .DLDX_BPSI_BPSID8_BPSID16 => Address.bp,
                    .BLBX_BPDI_BPDID8_BPDID16 => Address.bp,
                    .AHSP_SI_SID8_SID16 => Address.si,
                    .CHBP_DI_DID8_DID16 => Address.di,
                    .BHDI_BX_BXD8_BXD16 => Address.bx,
                    else => Address.none,
                },
                .index = switch (rm) {
                    .ALAX_BXSI_BXSID8_BXSID16 => Address.si,
                    .CLCX_BXDI_BXDID8_BXDID16 => Address.di,
                    .DLDX_BPSI_BPSID8_BPSID16 => Address.si,
                    .BLBX_BPDI_BPDID8_BPDID16 => Address.di,
                    .AHSP_SI_SID8_SID16 => Address.none,
                    .CHBP_DI_DID8_DID16 => Address.none,
                    .BHDI_BX_BXD8_BXD16 => Address.none,
                    else => Address.none,
                },
                .displacement = null,
                .effective_address = dest_effective_address,
            }
        };
    } else if (mod == ModValue.memoryMode8BitDisplacement or mod == ModValue.memoryMode16BitDisplacement) {
        destination_payload = DestinationInfo{
            .address_calculation = EffectiveAddressCalculation{
                .base = dest,
                .index = Address.none,
                .displacement = if (mod == ModValue.memoryMode8BitDisplacement) DisplacementFormat.d8 else DisplacementFormat.d16,
                .effective_address = if (mod == ModValue.memoryMode8BitDisplacement) @as(u16, disp_lo.?) else (@as(u16, disp_hi.?) << 4) + disp_lo.?,
            },
        };
    } else if (mod == ModValue.registerModeNoDisplacement) {
        destination_payload = DestinationInfo{
            .address_calculation = EffectiveAddressCalculation{
                .base = dest,
                .index = Address.none,
                .displacement = if (w == WValue.byte) DisplacementFormat.d8 else DisplacementFormat.d16,
                .effective_address = dest_effective_address,
            },
        };
    }

    var source_payload: SourceInfo = undefined;
    if (mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) {
        source_payload = SourceInfo{
            .address_calculation = EffectiveAddressCalculation{
                .base = AddressDirectory.addressFrom(reg, w),
                .index = Address.none, 
                .displacement = null,
                .effective_address = source_effective_address,
            },
        };
    } else if (mod == ModValue.memoryMode8BitDisplacement or mod == ModValue.memoryMode16BitDisplacement) {
        source_payload = SourceInfo{
            .address_calculation = source_address_calculation,
        };
    } else {
        source_payload = SourceInfo{
            .index = source_effective_address,
        };
    }

    return InstructionInfo{
        .destination_info = destination_payload,
        .source_info = source_payload,
    };
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
    destination_info: DestinationInfo,
    source_info: SourceInfo,
};

const EffectiveAddressCalculation = struct {
    base: ?AddressDirectory.Address,
    index: ?AddressDirectory.Address,
    displacement: ?DisplacementFormat,
    effective_address: u20,
};

const DestinationInfoIdentifiers = enum {
    address,
    address_calculation,
    index,
};

const DestinationInfo = union(DestinationInfoIdentifiers) {
    address: AddressDirectory.Address,
    address_calculation: EffectiveAddressCalculation,
    index: u20,
};

const SourceInfoIdentifiers = enum {
    address,
    address_calculation,
    index,
};

const SourceInfo = union(SourceInfoIdentifiers) {
    address: AddressDirectory.Address,
    address_calculation: EffectiveAddressCalculation,
    index: u20,
};

/// Matching binary values against instruction- and register enum's. Returns names of the
/// instructions and registers as strings in an []u8.
fn decodeMovWithMod(
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

                var temp_d = input[0] >> 1;
                temp_d = temp_d << 7;
                temp_d = temp_d >> 7;
                var temp_w = input[0] << 7;
                temp_w = temp_w >> 7;
                var temp_reg = input[1] >> 3;
                temp_reg = temp_reg << 5;
                temp_reg = temp_reg >> 5;

                const d: u1 = @intCast(temp_d);
                const w: u1 = @intCast(temp_w);
                const reg: u3 = @intCast(temp_reg);

                const result = DecodePayload{
                    .mov_with_mod_instruction = MovWithModInstruction{
                        .mnemonic = mnemonic,
                        .d = @enumFromInt(d),
                        .w = @enumFromInt(w),
                        .mod = _mod,
                        .reg = @enumFromInt(reg),
                        .rm = _rm,
                        .disp_lo = input[2],
                        .disp_hi = input[3],
                        .data = null,
                        .w_data = null,
                    },
                };
                return result;
            } else {
                var temp_d = input[0] >> 1;
                temp_d = temp_d << 7;
                temp_d = temp_d >> 7;
                var temp_w = input[0] << 7;
                temp_w = temp_w >> 7;
                var temp_reg = input[1] >> 3;
                temp_reg = temp_reg << 5;
                temp_reg = temp_reg >> 5;

                const d: u1 = @intCast(temp_d);
                const w: u1 = @intCast(temp_w);
                const reg: u3 = @intCast(temp_reg);

                const result = DecodePayload{
                    .mov_with_mod_instruction = MovWithModInstruction{
                        .mnemonic = mnemonic,
                        .d = @enumFromInt(d),
                        .w = @enumFromInt(w),
                        .mod = _mod,
                        .reg = @enumFromInt(reg),
                        .rm = _rm,
                        .disp_lo = null,
                        .disp_hi = null,
                        .data = null,
                        .w_data = null,
                    },
                };
                return result;
            }
        },
        ModValue.memoryMode8BitDisplacement => {
            var temp_d = input[0] >> 1;
            temp_d = temp_d << 7;
            temp_d = temp_d >> 7;
            var temp_w = input[0] << 7;
            temp_w = temp_w >> 7;
            var temp_reg = input[1] >> 3;
            temp_reg = temp_reg << 5;
            temp_reg = temp_reg >> 5;

            const d: u1 = @intCast(temp_d);
            const w: u1 = @intCast(temp_w);
            const reg: u3 = @intCast(temp_reg);

            const result = DecodePayload{
                .mov_with_mod_instruction = MovWithModInstruction{
                    .mnemonic = mnemonic,
                    .d = @enumFromInt(d),
                    .w = @enumFromInt(w),
                    .mod = _mod,
                    .reg = @enumFromInt(reg),
                    .rm = _rm,
                    .disp_lo = input[2],
                    .disp_hi = null,
                    .data = null,
                    .w_data = null,
                },
            };
            return result;
        },
        ModValue.memoryMode16BitDisplacement => {
            var temp_d = input[0] >> 1;
            temp_d = temp_d << 7;
            temp_d = temp_d >> 7;
            var temp_w = input[0] << 7;
            temp_w = temp_w >> 7;
            var temp_reg = input[1] >> 3;
            temp_reg = temp_reg << 5;
            temp_reg = temp_reg >> 5;

            const d: u1 = @intCast(temp_d);
            const w: u1 = @intCast(temp_w);
            const reg: u3 = @intCast(temp_reg);

            const result = DecodePayload{
                .mov_with_mod_instruction = MovWithModInstruction{
                    .mnemonic = mnemonic,
                    .d = @enumFromInt(d),
                    .w = @enumFromInt(w),
                    .mod = _mod,
                    .reg = @enumFromInt(reg),
                    .rm = _rm,
                    .disp_lo = input[2],
                    .disp_hi = input[3],
                    .data = null,
                    .w_data = null,
                },
            };
            return result;
        },
        ModValue.registerModeNoDisplacement => {
            var temp_d = input[0] >> 1;
            temp_d = temp_d << 7;
            temp_d = temp_d >> 7;
            var temp_w = input[0] << 7;
            temp_w = temp_w >> 7;
            var temp_reg = input[1] >> 3;
            temp_reg = temp_reg << 5;
            temp_reg = temp_reg >> 5;

            const d: u1 = @intCast(temp_d);
            const w: u1 = @intCast(temp_w);
            const reg: u3 = @intCast(temp_reg);

            const result = DecodePayload{
                .mov_with_mod_instruction = MovWithModInstruction{
                    .mnemonic = mnemonic,
                    .d = @enumFromInt(d),
                    .w = @enumFromInt(w),
                    .mod = _mod,
                    .reg = @enumFromInt(reg),
                    .rm = _rm,
                    .disp_lo = null,
                    .disp_hi = null,
                    .data = null,
                    .w_data = null,
                },
            };
            return result;
        },
    }
}

fn decodeMovWithoutMod(
    w: WValue,
    input: [6]u8,
) DecodePayload {
    const temp_reg: u8 = input[0] << 5;
    const reg: RegValue = @enumFromInt(temp_reg >> 5);
    switch (w) {
        .byte => {
            const result = DecodePayload{
                .mov_without_mod_instruction = MovWithoutModInstruction{
                    .mnemonic = "mov",
                    .w = w,
                    .reg = reg,
                    .data = input[1],
                    .w_data = null,
                },
            };
            return result;
        },
        .word => {
            const result = DecodePayload{
                .mov_without_mod_instruction = MovWithoutModInstruction{
                    .mnemonic = "mov",
                    .w = w,
                    .reg = reg,
                    .data = input[1],
                    .w_data = input[2],
                },
            };
            return result;
        },
    }
}

/// Identifiers of the Internal Communication Registers as well as
/// the General Registers of the Intel 8086 CPU plus an identifier for
/// a direct address following the instruction as a 16 bit displacement.
const AddressDirectory = struct {
    const Address = enum { cs, ds, es, ss, ip, ah, al, ax, bh, bl, bx, ch, cl, cx, dh, dl, dx, sp, bp, di, si, directaccess, none };
    pub fn addressFrom(reg: RegValue, w: ?WValue) Address {
        const w_value = w orelse WValue.byte;
        switch (reg) {
            .ALAX => {
                if (w_value == WValue.word) return Address.ax else return Address.al;
            },
            .BLBX => {
                if (w_value == WValue.word) return Address.bx else return Address.bl;
            },
            .CLCX => {
                if (w_value == WValue.word) return Address.cx else return Address.cl;
            },
            .DLDX => {
                if (w_value == WValue.word) return Address.dx else return Address.dl;
            },
            .AHSP => {
                if (w_value == WValue.word) return Address.sp else return Address.ah;
            },
            .BHDI => {
                if (w_value == WValue.word) return Address.di else return Address.bh;
            },
            .CHBP => {
                if (w_value == WValue.word) return Address.bp else return Address.ch;
            },
            .DHSI => {
                if (w_value == WValue.word) return Address.si else return Address.dh;
            },
        }
    }
};
const DisplacementFormat = enum { d8, d16 };

/// Errors for the bus interface unit of the 8086 Processor
const BiuError = error{
    InvalidIndex,
};

/// Simulates the bus interface unit of the 8086 Processor, mainly the
/// instruction queue.
const BusInterfaceUnit = struct {
    InstructionQueue: [6]u8 = [1]u8{0} ** 6,

    /// Set a byte of the instruction queue by passing an index (0 - 5) and the
    /// value.
    pub fn setIndex(self: *BusInterfaceUnit, index: u3, value: u8) void {
        if (index > 5 or index < 0) unreachable;
        self.InstructionQueue[index] = value;
    }

    /// Get a byte of the instruction queue by passing an index (0 - 5).
    pub fn getIndex(self: *BusInterfaceUnit, index: u3) u8 {
        if (index < 0 or index > 5) unreachable;
        return self.InstructionQueue[index];
    }
};

const RegisterPayload = union {
    value8: u8,
    value16: u16,
};

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
//
//  76543210 76543210
// -------------------
// |       IP        | IP - INSTRUCTION POINTER - instructions are fetched from here
// -------------------
//
// 16 bit pointer containing the offset (distance in bytes) of the next instruction
// in the current code segment (CS). Saves and restores to / from the Stack.
//
// AF - Auxiliary Carry flag
// CF - Carry flag
// OF - Overflow flag
// SF - Sign flag
// PF - Parity flag
// ZF - Zero flag
//
// Additional flags
//
// DF - Direction flag
// IF - Interrupt-enable flag
// TF - Trap flag
//
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

/// Simulates the Internal Communication and General Registers of the
/// Intel 8086 Processor.
const Register = struct {
    // Internal Communication Registers
    _CS: u16, // Pointer to Code segment base
    _DS: u16, // Pointer to Data segment base
    _ES: u16, // Pointer to Extra segment base
    _SS: u16, // Pointer to Stack segment base
    _IP: u16, // Pointer to the next instruction to execute

    // Status Flags
    _AF: bool, // Auxiliary Carry flag
    _CF: bool, // Carry flag
    _OF: bool, // Overflow flag
    _SF: bool, // Sign flag
    _PF: bool, // Parity flag
    _ZF: bool, // Zero flag

    // Control Flags
    _DF: bool, // Direction flag
    _IF: bool, // Interrupt-enable flag
    _TF: bool, // Trap flag

    // General Registers
    _AX: u16, // Accumulator
    _BX: u16, // Base
    _CX: u16, // Count
    _DX: u16, // Data
    _SP: u16, // Stack Pointer
    _BP: u16, // Base Pointer
    _DI: u16, // Source Index (Offset)
    _SI: u16, // Destination Index (Offset)

    pub fn getReg16FromRegValue(self: *Register, reg: RegValue) RegisterPayload {
        switch (reg) {
            .ALAX => {
                return RegisterPayload{
                    .value16 = self._AX,
                };
            },
            .BLBX => {
                return RegisterPayload{
                    .value16 = self._BX,
                };
            },
            .CLCX => {
                return RegisterPayload{
                    .value16 = self._CX,
                };
            },
            .DLDX => {
                return RegisterPayload{
                    .value16 = self._DX,
                };
            },
            .AHSP => {
                return RegisterPayload{
                    .value16 = self._SP,
                };
            },
            .BHDI => {
                return RegisterPayload{
                    .value16 = self._DI,
                };
            },
            .CHBP => {
                return RegisterPayload{
                    .value16 = self._BP,
                };
            },
            .DHSI => {
                return RegisterPayload{
                    .value16 = self._SI,
                };
            },
        }
    }

    // Internal Communication Register Methods
    pub fn setCS(self: *Register, value: u16) void {
        self._CS = value;
    }
    pub fn getCS(self: *Register) RegisterPayload {
        return RegisterPayload{ .value16 = self._CS };
    }
    pub fn setDS(self: *Register, value: u16) void {
        self._DS = value;
    }
    pub fn getDS(self: *Register) RegisterPayload {
        return RegisterPayload{ .value16 = self._DS };
    }
    pub fn setES(self: *Register, value: u16) void {
        self._ES = value;
    }
    pub fn getES(self: *Register) RegisterPayload {
        return RegisterPayload{ .value16 = self._ES };
    }
    pub fn setSS(self: *Register, value: u16) void {
        self._SS = value;
    }
    pub fn getSS(self: *Register) RegisterPayload {
        return RegisterPayload{ .value16 = self._SS };
    }
    pub fn setIP(self: *Register, value: u16) void {
        self._IP = value;
    }
    pub fn getIP(self: *Register) RegisterPayload {
        return RegisterPayload{ .value16 = self._IP };
    }

    // Flag Methods
    pub fn setAF(self: *Register, state: bool) void {
        self._AF = state;
    }
    pub fn getAF(self: *Register) bool {
        return self._AF;
    }
    pub fn setCF(self: *Register, state: bool) void {
        self._CF = state;
    }
    pub fn getCF(self: *Register) bool {
        return self._CF;
    }
    pub fn setOF(self: *Register, state: bool) void {
        self._OF = state;
    }
    pub fn getOF(self: *Register) bool {
        return self._OF;
    }
    pub fn setSF(self: *Register, state: bool) void {
        self._SF = state;
    }
    pub fn getSF(self: *Register) bool {
        return self._SF;
    }
    pub fn setPF(self: *Register, state: bool) void {
        self._PF = state;
    }
    pub fn getPF(self: *Register) bool {
        return self._PF;
    }
    pub fn setZF(self: *Register, state: bool) void {
        self._ZF = state;
    }
    pub fn getZF(self: *Register) bool {
        return self._ZF;
    }
    pub fn setDF(self: *Register, state: bool) void {
        self._DF = state;
    }
    pub fn getDF(self: *Register) bool {
        return self._DF;
    }
    pub fn setIF(self: *Register, state: bool) void {
        self._IF = state;
    }
    pub fn getIF(self: *Register) bool {
        return self._IF;
    }
    pub fn setTF(self: *Register, state: bool) void {
        self._TF = state;
    }
    pub fn getTF(self: *Register) bool {
        return self._TF;
    }

    // General Register Methods
    pub fn setAH(self: *Register, value: u8) void {
        self._AX = value ++ self._AX[0..8];
    }
    pub fn setAL(self: *Register, value: u8) void {
        self._AX = self._AX[8..] ++ value;
    }
    pub fn setAX(self: *Register, value: u16) void {
        self._AX = value;
    }
    pub fn getAX(self: *Register, w: WValue, hilo: []const u8) RegisterPayload {
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
    pub fn setBH(self: *Register, value: u8) void {
        self._BX = value ++ self._BX[0..8];
    }
    pub fn setBL(self: *Register, value: u8) void {
        self._BX = self._BX[8..] ++ value;
    }
    pub fn setBX(self: *Register, value: u16) void {
        self._BX = value;
    }

    /// Returns value of BH, BL or BX depending on w and hilo. If
    /// w = byte, hilo can be set to "hi" or "lo". If w = word hilo
    /// should be set to "hilo"
    pub fn getBX(self: *Register, w: WValue, hilo: ?[]const u8) RegisterPayload {
        if (w == WValue.byte) {
            if (std.mem.eql(u8, hilo.?, "hi")) {
                return RegisterPayload{ .value8 = @intCast(self._BX >> 8) };
            } else {
                self._BX = self._BX << 8;
                return RegisterPayload{ .value8 = @intCast(self._BX >> 8) };
            }
        } else {
            return RegisterPayload{ .value16 = self._BX };
        }
    }
    pub fn setCH(self: *Register, value: u8) void {
        self._CX = value ++ self._CX[0..8];
    }
    pub fn setCL(self: *Register, value: u8) void {
        self._CX = self._CX[8..] ++ value;
    }
    pub fn setCX(self: *Register, value: u16) void {
        self._CX = value;
    }
    pub fn getCX(self: *Register, w: WValue, hilo: []const u8) RegisterPayload {
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
    pub fn setDH(self: *Register, value: u8) void {
        self._DX = value ++ self._DX[0..8];
    }
    pub fn setDL(self: *Register, value: u8) void {
        self._DX = self._DX[8..] ++ value;
    }
    pub fn setDX(self: *Register, value: u16) void {
        self._DX = value;
    }
    pub fn getDX(self: *Register, w: WValue, hilo: []const u8) RegisterPayload {
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
    pub fn setSP(self: *Register, value: u16) void {
        self._SP = value;
    }
    pub fn getSP(self: *Register) u16 {
        return self._SP;
    }
    pub fn setBP(self: *Register, value: u16) void {
        self._BP = value;
    }
    pub fn getBP(self: *Register) u16 {
        return self._BP;
    }
    pub fn setSI(self: *Register, value: u16) void {
        self._SI = value;
    }
    pub fn getSI(self: *Register) u16 {
        return self._SI;
    }
    pub fn setDI(self: *Register, value: u16) void {
        self._DI = value;
    }
    pub fn getDI(self: *Register) u16 {
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
// Total Memory: 1,048,576 bytes            | physical addresses range from 0x0H to 0xFFFFFH <-- 'H' signifying a physical address
// Segment: up to   65.536 bytes            | logical addresses consist of segment base + offset value
// A, B, C, D, E, F, G, H, I, J             |   -> for any given memory address the segment base value
// und K                                    |      locates the first byte of the containing segment and
//                                          |      the offset is the distance in bytes of the target
//                                          |      location from the beginning of the segment.
//                                          |      segment base and offset are u16

/// Simulates the memory of the 8086 Processor
const Memory = struct {
    _memory: [0xFFFFF]u8 = undefined,

    // byte     0x0 -    0x13 = dedicated
    // byte    0x14 -    0x7F = reserved
    // byte    0x80 - 0xFFFEF = open
    // byte 0xFFFF0 - 0xFFFFB = dedicated
    // byte 0xFFFFC - 0xFFFFF = reserved
    pub fn init(self: *Memory) void {
        self._memory = [1]u8{0} ** 0xFFFFF;
    }
    pub fn defineSegment() void {}
    pub fn moveSegment() void {}
    pub fn removeSegment() void {}
    pub fn setDirectAddress(
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
    pub fn getDirectAddress(self: *Memory, addr: u16, w: WValue) MemoryPayload {
        if (0 <= addr and addr < 0xFFF) {
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
    const print = std.debug.print;
    const log = std.log.scoped(.x86sim);

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
    const open_mode_input_file = std.fs.File.OpenFlags{
        .mode = .read_only,
        .lock = .none,
        .lock_nonblocking = false,
        .allow_ctty = false,
    };
    const open_mode_output_file = std.fs.File.CreateFlags{
        .truncate = true,
        .exclusive = false,
        .lock = .none,
        .lock_nonblocking = false,
    };

    const input_binary_file = std.fs.cwd().openFile(input_file_path, open_mode_input_file) catch |err| {
        switch (err) {
            error.FileNotFound => {
                log.err("{s}: '{s}':{any}", .{ @errorName(err), input_file_path, @errorReturnTrace() });
                std.process.exit(1);
            },
            error.AccessDenied => {
                log.err("{s}: '{s}':{any}", .{ @errorName(err), input_file_path, @errorReturnTrace() });
                std.process.exit(1);
            },
            else => {
                log.err("{s}: Unable to open file '{s}': {any}\n", .{ @errorName(err), input_file_path, @errorReturnTrace() });
                std.process.exit(1);
            },
        }
    };
    defer input_binary_file.close();

    if (@TypeOf(input_binary_file) != std.fs.File) {
        log.err("{s}: File object is not of the correct type.", .{@errorName(SimulatorError.FileError)});
    }

    const output_asm_file_path: []const u8 = "./zig-out/test/disassemble.asm";

    const output_asm_file = std.fs.cwd().createFile(output_asm_file_path, open_mode_output_file) catch |err| {
        switch (err) {
            error.FileNotFound => {
                log.err("{s}: '{s}':{any}", .{
                    @errorName(err),
                    output_asm_file_path,
                    @errorReturnTrace(),
                });
                std.process.exit(1);
            },
            error.AccessDenied => {
                log.err("{s}: '{s}':{any}", .{
                    @errorName(err),
                    output_asm_file_path,
                    @errorReturnTrace(),
                });
                std.process.exit(1);
            },
            else => {
                log.err("{s}: Unable to open file '{s}': {any}\n", .{
                    @errorName(err),
                    output_asm_file_path,
                    @errorReturnTrace(),
                });
                std.process.exit(1);
            },
        }
    };
    defer output_asm_file.close();

    var instruction_buffer: [1024]u8 = undefined;
    var writer = output_asm_file.writer(&instruction_buffer);
    var OutputWriter = &writer.interface;

    //////////////////////////////////////////
    // Initializing the Simulator           //
    //////////////////////////////////////////

    const maxFileSizeBytes = 65535;
    const u8_init_value: u8 = 0b0000_0000;
    const u16_init_value: u16 = 0b0000_0000_0000_0000;

    var registers = Register{
        // Initialize Communication Registers
        ._CS = 0xFFFF,
        ._DS = u16_init_value,
        ._ES = u16_init_value,
        ._SS = u16_init_value,

        // Initialize Instruction Pointer
        ._IP = u16_init_value,

        // Initialize Status Flags
        ._AF = false,
        ._CF = false,
        ._OF = false,
        ._SF = false,
        ._PF = false,
        ._ZF = false,

        // Initialize Control Flags
        ._DF = false,
        ._IF = false,
        ._TF = false,

        // Initialize General Registers
        ._AX = u16_init_value,
        ._BX = u16_init_value,
        ._CX = u16_init_value,
        ._DX = u16_init_value,
        ._SP = u16_init_value,
        ._BP = u16_init_value,
        ._SI = u16_init_value,
        ._DI = u16_init_value,
    };

    var memory = Memory{};
    memory.init();
    log.debug("Test _memory initialization: _memory size = 0x{x}", .{memory._memory.len});

    // TODO: Put loaded binary input file in simulated memory, update CS to point at the base of the segment
    // TODO: Define the stack and data segments and update DS, ES and SS

    var biu = BusInterfaceUnit{
        .InstructionQueue = [1]u8{0} ** 6,
    };

    //////////////////////////////////////////
    // Start of the Simulation Part         //
    //////////////////////////////////////////

    print("\n+++x86+Simulator++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n", .{});
    print("Simulating target: {s}\n", .{input_file_path});

    var activeByte: u16 = 0;

    var stepSize: u3 = 2;
    var InstructionBytes: [6]u8 = undefined;
    const file_contents = try input_binary_file.readToEndAlloc(heap_allocator, maxFileSizeBytes);
    print("Instruction byte count: {d}\n", .{file_contents.len});
    print("+++Start+active+byte+{d}++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n", .{activeByte});

    print("bits 16\n", .{});
    try OutputWriter.writeAll("bits 16\n\n");

    var depleted: bool = false;

    while (!depleted and activeByte < file_contents.len) : (activeByte += stepSize) {
        const queue_size = 6;
        var queue_index: u3 = 0;
        // std.debug.print("---BIU-Instruction-Queue-----------------------------------------------------\n", .{});
        while (queue_index < queue_size) : (queue_index += 1) {
            biu.setIndex(queue_index, if (activeByte + queue_index < file_contents.len) file_contents[activeByte + queue_index] else u8_init_value);
            if (activeByte + queue_index > file_contents.len - 1) break;
            // std.debug.print("{d}: {b:0>8}, {d}\n", .{ queue_index, file_contents[activeByte + queue_index], activeByte + queue_index });
            if (queue_index + 1 == 6) break;
        }

        const instruction: BinaryInstructions = @enumFromInt(biu.getIndex(0));

        var mod: ModValue = undefined;
        var rm: RmValue = undefined;
        var w: WValue = undefined;
        switch (instruction) {
            BinaryInstructions.mov_source_regmem8_reg8,
            BinaryInstructions.mov_source_regmem16_reg16,
            BinaryInstructions.mov_dest_reg8_regmem8,
            BinaryInstructions.mov_dest_reg16_regmem16,
            => {
                // 0x88, 0x89, 0x8A, 0x8B
                mod = @enumFromInt(biu.getIndex(1) >> 6);
                const temp_rm = biu.getIndex(1) << 5;
                rm = @enumFromInt(temp_rm >> 5);

                stepSize = movGetInstructionLength(mod, rm);
            },
            BinaryInstructions.mov_immediate_regmem8,
            BinaryInstructions.mov_immediate_regmem16,
            => {
                // 0x8c, 0x8e
            },
            BinaryInstructions.mov_mem8_acc8,
            BinaryInstructions.mov_mem16_acc16,
            BinaryInstructions.mov_acc8_mem8,
            BinaryInstructions.mov_acc16_mem16,
            => {
                // 0xA0, 0xA1, 0xA2, 0xA3
            },
            BinaryInstructions.mov_immediate_reg_al,
            BinaryInstructions.mov_immediate_reg_bl,
            BinaryInstructions.mov_immediate_reg_cl,
            BinaryInstructions.mov_immediate_reg_dl,
            BinaryInstructions.mov_immediate_reg_ah,
            BinaryInstructions.mov_immediate_reg_bh,
            BinaryInstructions.mov_immediate_reg_ch,
            BinaryInstructions.mov_immediate_reg_dh,
            BinaryInstructions.mov_immediate_reg_ax,
            BinaryInstructions.mov_immediate_reg_cx,
            BinaryInstructions.mov_immediate_reg_dx,
            BinaryInstructions.mov_immediate_reg_bx,
            BinaryInstructions.mov_immediate_reg_sp,
            BinaryInstructions.mov_immediate_reg_bp,
            BinaryInstructions.mov_immediate_reg_si,
            BinaryInstructions.mov_immediate_reg_di,
            => {
                // 0xB0 - 0xBF
                const first_byte = biu.getIndex(0);

                const temp_w: u8 = first_byte << 4;
                w = @enumFromInt(temp_w >> 7);

                stepSize = if (w == WValue.byte) 2 else 3;
            },
            BinaryInstructions.mov_seg_regmem,
            BinaryInstructions.mov_regmem_seg,
            => {
                // 0xC6, 0xC7
            },
            // else => {
            //     log.err("{s}: 0x{x} ({s}) not implemented yet.", .{
            //         @errorName(SimulatorError.InstructionError),
            //         InstructionBytes[0],
            //         @tagName(instruction),
            //     });
            // },
        }

        switch (stepSize) {
            1 => {
                InstructionBytes = [6]u8{
                    biu.getIndex(0),
                    0b0000_0000,
                    0b0000_0000,
                    0b0000_0000,
                    0b0000_0000,
                    0b0000_0000,
                };
            },
            2 => {
                InstructionBytes = [6]u8{
                    biu.getIndex(0),
                    biu.getIndex(1),
                    0b0000_0000,
                    0b0000_0000,
                    0b0000_0000,
                    0b0000_0000,
                };
            },
            3 => {
                InstructionBytes = [6]u8{
                    biu.getIndex(0),
                    biu.getIndex(1),
                    biu.getIndex(2),
                    0b0000_0000,
                    0b0000_0000,
                    0b0000_0000,
                };
            },
            4 => {
                InstructionBytes = [6]u8{
                    biu.getIndex(0),
                    biu.getIndex(1),
                    biu.getIndex(2),
                    biu.getIndex(3),
                    0b0000_0000,
                    0b0000_0000,
                };
            },
            5 => {
                InstructionBytes = [6]u8{
                    biu.getIndex(0),
                    biu.getIndex(1),
                    biu.getIndex(2),
                    biu.getIndex(3),
                    biu.getIndex(4),
                    0b0000_0000,
                };
            },
            6 => {
                InstructionBytes = [6]u8{
                    biu.getIndex(0),
                    biu.getIndex(1),
                    biu.getIndex(2),
                    biu.getIndex(3),
                    biu.getIndex(4),
                    biu.getIndex(5),
                };
            },
            else => {
                log.err("{s}: Instruction size of {d} bytes not valid.", .{ @errorName(SimulatorError.InstructionSizeError), stepSize });
            },
        }

        var payload: DecodePayload = undefined;
        switch (instruction) {
            .mov_source_regmem8_reg8 => {
                payload = decodeMovWithMod(mod, rm, InstructionBytes);
            },
            .mov_source_regmem16_reg16 => {
                payload = decodeMovWithMod(mod, rm, InstructionBytes);
            },
            .mov_dest_reg8_regmem8 => {
                payload = decodeMovWithMod(mod, rm, InstructionBytes);
            },
            .mov_dest_reg16_regmem16 => {
                payload = decodeMovWithMod(mod, rm, InstructionBytes);
            },
            .mov_immediate_reg_al,
            .mov_immediate_reg_ah,
            .mov_immediate_reg_ax,
            .mov_immediate_reg_bl,
            .mov_immediate_reg_bh,
            .mov_immediate_reg_bx,
            .mov_immediate_reg_cl,
            .mov_immediate_reg_ch,
            .mov_immediate_reg_cx,
            .mov_immediate_reg_dl,
            .mov_immediate_reg_dh,
            .mov_immediate_reg_dx,
            .mov_immediate_reg_bp,
            .mov_immediate_reg_sp,
            .mov_immediate_reg_di,
            .mov_immediate_reg_si,
            => {
                payload = decodeMovWithoutMod(w, InstructionBytes);
            },
            else => {
                log.err("{s}: 0x{x} ({s}) not implemented yet.", .{
                    @errorName(SimulatorError.InstructionError),
                    InstructionBytes[0],
                    @tagName(instruction),
                });
            },
        }

        switch (payload) {
            .err => {
                switch (payload.err) {
                    DecodeInstructionError.DecodeError => {
                        log.err("{s}: Instruction 0x{x} could not be decoded.\ncontinue...", .{
                            @errorName(payload.err),
                            InstructionBytes[0],
                        });
                        continue;
                    },
                    DecodeInstructionError.NotYetImplementet => {
                        log.err("{s}: 0x{x} ({s}) not implemented yet.\ncontinue...", .{
                            @errorName(payload.err),
                            InstructionBytes[0],
                            @tagName(instruction),
                        });
                        continue;
                    },
                }
            },
            .mov_with_mod_instruction => {
                const d: DValue = payload.mov_with_mod_instruction.d;
                w = payload.mov_with_mod_instruction.w;
                const reg: RegValue = payload.mov_with_mod_instruction.reg;
                // std.debug.print("Instruction: 0x{x}: Mod: {b}, Reg: {any}, R/M: {any}, DISP-LO: {b:0>8}, DISP-HI: {b:0>8}\n", .{
                //     @intFromEnum(instruction),
                //     @intFromEnum(mod),
                //     reg,
                //     rm,
                //     if (stepSize == 3 or stepSize == 4) payload.mov_instruction.disp_lo.? else instruction_bytes[2],
                //     if (stepSize == 4) payload.mov_instruction.disp_hi.? else instruction_bytes[3],
                // });

                const instruction_info: InstructionInfo = getInstructionSourceAndDest(
                    &registers,
                    d,
                    w,
                    reg,
                    mod,
                    rm,
                    if (mod == ModValue.memoryMode8BitDisplacement or mod == ModValue.memoryMode16BitDisplacement or (mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16)) InstructionBytes[2] else null,
                    if (mod == ModValue.memoryMode16BitDisplacement or (mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16)) InstructionBytes[3] else null,
                );

                const source_payload = instruction_info.source_info;
                const destination_payload = instruction_info.destination_info;

                print("{s} ", .{payload.mov_with_mod_instruction.mnemonic});
                OutputWriter.print("{s} ", .{payload.mov_with_mod_instruction.mnemonic}) catch |err| {
                    log.err(
                        "{s}: Something went wrong trying to write instruction mnemonic {s} to the output file.",
                        .{ @errorName(err), payload.mov_with_mod_instruction.mnemonic },
                    );
                };

                switch (destination_payload) {
                    .address => {
                        print("{t},", .{destination_payload.address});
                        OutputWriter.print(
                            "{t},",
                            .{destination_payload.address},
                        ) catch |err| {
                            log.err(
                                "{s}: Something went wrong trying to write destination {any} the output file.",
                                .{ @errorName(err), destination_payload.address },
                            );
                        };
                    },
                    .address_calculation => {
                        print("[{t} + {t} + {d}],", .{
                            destination_payload.address_calculation.base.?,
                            destination_payload.address_calculation.index.?,
                            destination_payload.address_calculation.displacement.?,
                        });
                        OutputWriter.print("[{t} + {t} + {d}],", .{
                            destination_payload.address_calculation.base.?,
                            destination_payload.address_calculation.index.?,
                            destination_payload.address_calculation.displacement.?,
                        }) catch |err| {
                            log.err(
                                "{s}: Something went wrong trying to write destination effective address calculation {any} to the output file.",
                                .{ @errorName(err), destination_payload.address_calculation },
                            );
                        };
                    },
                    .index => {
                        print("{x},", .{destination_payload.index});
                        OutputWriter.print(
                            "{x},",
                            .{destination_payload.index},
                        ) catch |err| {
                            log.err(
                                "{s}: Something went wrong trying to write destination index {any} to the output file.",
                                .{ @errorName(err), destination_payload.index },
                            );
                        };
                    },
                }

                switch (source_payload) {
                    .address => {
                        print("{t}\n", .{source_payload.address});
                        OutputWriter.print(
                            "{t}\n",
                            .{source_payload.address},
                        ) catch |err| {
                            log.err(
                                "{s}: Something went wrong trying to write source {any} to the output file.",
                                .{ @errorName(err), source_payload.address },
                            );
                        };
                    },
                    .address_calculation => {
                        print("[{t} + {t} + {d}],\n", .{
                            source_payload.address_calculation.base.?,
                            source_payload.address_calculation.index.?,
                            source_payload.address_calculation.displacement.?,
                        });
                        OutputWriter.print("[{t} + {t} + {d}]\n,", .{
                            source_payload.address_calculation.base.?,
                            source_payload.address_calculation.index.?,
                            source_payload.address_calculation.displacement.?,
                        }) catch |err| {
                            log.err(
                                "{s}: Something went wrong trying to write source effective address calculation {any} to the output file.",
                                .{ @errorName(err), source_payload.address_calculation },
                            );
                        };
                    },
                    .index => {
                        print("{x}\n", .{source_payload.index});
                        OutputWriter.print(
                            "{x}\n",
                            .{source_payload.index},
                        ) catch |err| {
                            log.err(
                                "{s}: Something went wrong trying to write source index {any} to the output file.",
                                .{ @errorName(err), source_payload.index },
                            );
                        };
                    },
                }
            },
            .mov_without_mod_instruction => {
                const instruction_info: InstructionInfo = getInstructionDest(
                    payload.mov_without_mod_instruction.w,
                    payload.mov_without_mod_instruction.reg,
                );

                const dest: RegValue = payload.mov_without_mod_instruction.reg;
                print("{s} {t},", .{
                    payload.mov_without_mod_instruction.mnemonic,
                    instruction_info.destination_info.address,
                });
                OutputWriter.print("{s} {t},", .{
                    payload.mov_without_mod_instruction.mnemonic,
                    instruction_info.destination_info.address,
                }) catch |err| {
                    log.err(
                        "{s}: Something went wrong trying to write destination register {any} to the output file.",
                        .{ @errorName(err), @tagName(dest) },
                    );
                };
                var value: u16 = undefined;
                switch (w) {
                    .byte => {
                        value = @as(u16, payload.mov_without_mod_instruction.data);
                    },
                    .word => {
                        value = (@as(u16, payload.mov_without_mod_instruction.w_data.?) << 8) + payload.mov_without_mod_instruction.data;
                    },
                }
                print("{d}\n", .{value});
                OutputWriter.print("{d}\n", .{value}) catch |err| {
                    log.err(
                        "{s}: Something went wrong trying to write immediate value {any} to the output file.",
                        .{ @errorName(err), value },
                    );
                };
            },
        }

        try OutputWriter.flush();

        if (activeByte + stepSize == maxFileSizeBytes or activeByte + stepSize >= file_contents.len) {
            depleted = true;
            std.debug.print("+++Simulation+finished++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n", .{});
        } else {
            if (activeByte + stepSize > 999) {
                // std.debug.print("+++Next+active+byte+{d}++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n", .{activeByte + stepSize});
            } else if (activeByte + stepSize > 99) {
                // std.debug.print("+++Next+active+byte+{d}+++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n", .{activeByte + stepSize});
            } else if (activeByte + stepSize > 9) {
                // std.debug.print("+++Next+active+byte+{d}++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n", .{activeByte + stepSize});
            } else {
                // std.debug.print("+++Next+active+byte+{d}+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n", .{activeByte + stepSize});
            }
        }
    }

    try runAssemblyTest(args_allocator, input_file_path, output_asm_file_path);
}

fn runAssemblyTest(
    allocator: std.mem.Allocator,
    path_to_binary_input: []const u8,
    asm_file_path: []const u8,
) !void {
    const print = std.debug.print;
    // const log = std.log.scoped(.runAssemblyTest);

    print("\n+++Testing+Phase++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n", .{});
    print("Assembler generates .asm file and compares it with the original binary input...\n", .{});

    const cwd_path: []const u8 = try std.process.getCwdAlloc(allocator);
    defer allocator.free(cwd_path);
    const assembled_binary_path: []u8 = try std.fs.path.join(allocator, &[_][]const u8{ cwd_path, "zig-out", "test", "reassemble" });
    defer allocator.free(assembled_binary_path);

    const assemble_args = [_][]const u8{
        "nasm",
        "-f",
        "bin",
        asm_file_path,
        "-o",
        assembled_binary_path,
    };

    var assemble_process = std.process.Child.init(&assemble_args, allocator);
    assemble_process.stdout_behavior = .Pipe;
    assemble_process.stderr_behavior = .Pipe;

    try assemble_process.spawn();
    const assemble_result = try assemble_process.wait();

    if (assemble_process.stderr) |stderr| {
        var buffer: [4096]u8 = undefined;
        var stderr_reader = stderr.reader(&buffer);
        var err_buffer: [10240]u8 = undefined;
        const bytes_read = try stderr_reader.read(&err_buffer);
        const stderr_msg = err_buffer[0..bytes_read];
        // defer allocator.free(&stderr_msg);

        switch (assemble_result) {
            .Exited => |code| {
                if (code == 0) {
                    print("Assembly successfull\n", .{});
                } else {
                    print("Assembly failed with exit code: {d}\nError: {s}\n", .{ code, stderr_msg });
                    return;
                }
            },
            else => {
                print("Assembly process terminated unexpectedly\nError: {s}\n", .{stderr_msg});
                return;
            },
        }
    }

    // defer std.fs.cwd().deleteFile(assembled_binary_path) catch {};
    const compare_result = try compareFiles(
        allocator,
        path_to_binary_input,
        assembled_binary_path,
    );

    if (compare_result) {
        print("SUCCESS: The generated assembly matches the original binary!\n", .{});
    } else {
        print("FAILURE: The generated assembly does NOT match the original binary.\n", .{});
    }

    print("+++Testing+Complete+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n\n", .{});
}

fn compareFiles(
    allocator: std.mem.Allocator,
    path_to_binary_input: []const u8,
    assembled_binary_path: []const u8,
) !bool {
    const print = std.debug.print;
    const input = std.fs.cwd().openFile(path_to_binary_input, .{}) catch |err| {
        print("Error opening input {s}: {}\n", .{ path_to_binary_input, err });
        return false;
    };
    defer input.close();

    const output = std.fs.cwd().openFile(assembled_binary_path, .{}) catch |err| {
        print("Error opening output {s}: {}\n", .{ assembled_binary_path, err });
        return false;
    };
    defer output.close();

    const input_size = try input.getEndPos();
    const output_size = try output.getEndPos();

    if (input_size != output_size) {
        print("File sizes differ: input size {d} vs output size {d} bytes\n", .{ input_size, output_size });
    }

    const max_file_size = 0xFFF;
    const input_content = try input.readToEndAlloc(allocator, max_file_size);
    defer allocator.free(input_content);
    const output_content = try output.readToEndAlloc(allocator, max_file_size);
    defer allocator.free(output_content);

    return std.mem.eql(u8, input_content, output_content);
}

// Since the index of the byte array loaded from file needs
// to move allong at the correct speed, meaning if a
// instruction takes three bytes the cursor also needs to
// move forward three bytes.

// TODO: Add test cases for different instruction sizes

test "TEST listing_0037_single_register_mov" {
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
        .mov_with_mod_instruction = MovWithModInstruction{
            .mnemonic = "mov",
            .d = DValue.source,
            .w = WValue.word,
            .mod = ModValue.registerModeNoDisplacement,
            .reg = RegValue.BLBX,
            .rm = RmValue.CLCX_BXDI_BXDID8_BXDID16,
            .disp_lo = null,
            .disp_hi = null,
            .data = null,
            .w_data = null,
        },
    };
    try std.testing.expectEqual(
        decodeMovWithMod(
            ModValue.registerModeNoDisplacement,
            RmValue.CLCX_BXDI_BXDID8_BXDID16,
            test_input_0x89_mod_register_mode_no_displacement,
        ).mov_with_mod_instruction,
        test_output_payload_0x89_mod_register_mode_no_displacement.mov_with_mod_instruction,
    );
}

test "TEST listing_0038_many_register_mov" {
    // listing_0038_many_register_mov
    // 0x88, 0x89

    // 0x89, Mod: 0b01, R/M: 0b010
    const test_input_0x89_mod_memory_mode_8_bit_displacement: [6]u8 = [_]u8{
        0b1000_1001,
        0b0110_0010,
        0b0101_0101,
        0b0000_0000,
        0b0000_0000,
        0b0000_0000,
    };
    const test_output_payload_0x89_mod_memory_mode_8_bit_displacement = DecodePayload{
        .mov_with_mod_instruction = MovWithModInstruction{
            .mnemonic = "mov",
            .d = @enumFromInt(0b0),
            .w = @enumFromInt(0b1),
            .mod = @enumFromInt(0b01),
            .reg = @enumFromInt(0b100),
            .rm = @enumFromInt(0b010),
            .disp_lo = 0b0101_0101,
            .disp_hi = null,
            .data = null,
            .w_data = null,
        },
    };
    try std.testing.expectEqual(
        decodeMovWithMod(
            ModValue.memoryMode8BitDisplacement,
            RmValue.DLDX_BPSI_BPSID8_BPSID16,
            test_input_0x89_mod_memory_mode_8_bit_displacement,
        ),
        test_output_payload_0x89_mod_memory_mode_8_bit_displacement,
    );

    // 0x89, Mod: 0b10, R/M: 0b001
    const test_input_0x89_mod_memory_mode_16_bit_displacement: [6]u8 = [_]u8{
        0b1000_1001,
        0b1001_0001,
        0b0101_0101,
        0b1010_1010,
        0b0000_0000,
        0b0000_0000,
    };
    const test_output_payload_0x89_mod_memory_mode_16_bit_displacement = DecodePayload{
        .mov_with_mod_instruction = MovWithModInstruction{
            .mnemonic = "mov",
            .d = @enumFromInt(0b0),
            .w = @enumFromInt(0b1),
            .mod = @enumFromInt(0b10),
            .reg = @enumFromInt(0b010),
            .rm = @enumFromInt(0b001),
            .disp_lo = 0b0101_0101,
            .disp_hi = 0b1010_1010,
            .data = null,
            .w_data = null,
        },
    };
    try std.testing.expectEqual(
        decodeMovWithMod(
            ModValue.memoryMode16BitDisplacement,
            RmValue.CLCX_BXDI_BXDID8_BXDID16,
            test_input_0x89_mod_memory_mode_16_bit_displacement,
        ),
        test_output_payload_0x89_mod_memory_mode_16_bit_displacement,
    );
}

test "TEST listing_0039_more_movs" {
    // 0x88 - 0x8B, 0xB0 - 0xBF

    const test_input_0x8A_mod_memory_mode_16_bit_displacement: [6]u8 = [_]u8{
        0b1000_1010, // mov, d=0b1, w=0b0
        0b1000_0000, // mod=0b10, reg=0b000, rm=0b000
        0b1000_0111,
        0b0001_0011,
        0b0000_0000,
        0b0000_0000,
    };
    const test_output_payload_0x8A_mod_memory_mode_16_bit_displacement = DecodePayload{ .mov_with_mod_instruction = MovWithModInstruction{
        .mnemonic = "mov",
        .d = @enumFromInt(0b1),
        .w = @enumFromInt(0b0),
        .mod = @enumFromInt(0b10),
        .reg = @enumFromInt(0b000),
        .rm = @enumFromInt(0b000),
        .disp_lo = 0b1000_0111,
        .disp_hi = 0b0001_0011,
        .data = null,
        .w_data = null,
    } };
    try std.testing.expectEqual(
        decodeMovWithMod(
            ModValue.memoryMode16BitDisplacement,
            RmValue.ALAX_BXSI_BXSID8_BXSID16,
            test_input_0x8A_mod_memory_mode_16_bit_displacement,
        ),
        test_output_payload_0x8A_mod_memory_mode_16_bit_displacement,
    );
}
