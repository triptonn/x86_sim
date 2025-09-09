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

const decoder = @import("modules/decoder.zig");
const BinaryInstructions = decoder.BinaryInstructions;
const DecodePayload = decoder.InstructionPayload;
const ImmediateOpInstruction = decoder.ImmediateOp;
const MovWithModInstruction = decoder.MovWithMod;
const MovWithoutModInstruction = decoder.MovWithoutMod;

const types = @import("types.zig");

const ModValue = types.instruction_field_names.ModValue;
const RegValue = types.instruction_field_names.RegValue;
const RmValue = types.instruction_field_names.RmValue;
const DValue = types.instruction_field_names.DValue;
const WValue = types.instruction_field_names.WValue;
const SValue = types.instruction_field_names.SValue;
const SrValue = types.instruction_field_names.SrValue;

const errors = @import("errors.zig");
const InstructionDecodeError = errors.InstructionDecodeError;
const InstructionExecutionError = errors.InstructionExecutionError;
const SimulatorError = errors.SimulatorError;

/// global log level
const LogLevel: std.log.Level = .debug;
// const LogLevel: std.log.Level = .info;

/// Immediate operation action codes
const ImmediateAction = enum(u3) {
    ADD = 0b000,
    OR = 0b001,
    ADC = 0b010,
    SBB = 0b011,
    AND = 0b100,
    SUB = 0b101,
    XOR = 0b110,
    CMP = 0b111,
};

/// Contains the destination as DestinationInfo and source as SourceInfo
/// objects to rebuild the ASM-86 instruction from.
const InstructionInfo = struct {
    destination_info: DestinationInfo,
    source_info: SourceInfo,
};

const EffectiveAddressCalculation = struct {
    base: ?RegisterDirectory.RegisterName,
    index: ?RegisterDirectory.RegisterName,
    displacement: ?DisplacementFormat,
    displacement_value: ?u16,
    effective_address: ?u20,
};

const DestinationInfoIdentifiers = enum {
    address,
    address_calculation,
    mem_addr,
};

const DestinationInfo = union(DestinationInfoIdentifiers) {
    address: RegisterDirectory.RegisterName,
    address_calculation: EffectiveAddressCalculation,
    mem_addr: u20,
};

const SourceInfoIdentifiers = enum {
    address,
    address_calculation,
    immediate,
    mem_addr,
};

const SourceInfo = union(SourceInfoIdentifiers) {
    address: RegisterDirectory.RegisterName,
    address_calculation: EffectiveAddressCalculation,
    immediate: u16,
    mem_addr: u20,
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

// TODO: DocString

fn calculateEffectiveAddress(
    registers: *Register,
    mod: ModValue,
    rm: RmValue,
    disp_lo: ?u8,
    disp_hi: ?u8,
) EffectiveAddressCalculation {
    const Address = RegisterDirectory.RegisterName;
    var disp_format: DisplacementFormat = undefined;
    var disp_value: u16 = undefined;
    if (mod == ModValue.memoryMode16BitDisplacement) {
        disp_format = DisplacementFormat.d16;
        disp_value = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
    } else if (mod == ModValue.memoryMode8BitDisplacement) {
        disp_format = DisplacementFormat.d8;
        disp_value = @as(u16, disp_lo.?);
    } else {
        disp_format = DisplacementFormat.none;
        disp_value = 0;
    }

    var base_value: u20 = undefined;
    var index_value: u20 = undefined;
    switch (rm) {
        .ALAX_BXSI_BXSID8_BXSID16 => {
            base_value = @as(u20, registers.getBX(WValue.word, null).value16);
            index_value = @as(u20, registers.getSI());
        },
        .DLDX_BPSI_BPSID8_BPSID16 => {
            base_value = @as(u20, registers.getBP());
            index_value = @as(u20, registers.getSI());
        },
        .CLCX_BXDI_BXDID8_BXDID16 => {
            base_value = @as(u20, registers.getBX(WValue.word, null).value16);
            index_value = @as(u20, registers.getDI());
        },
        .BLBX_BPDI_BPDID8_BPDID16 => {
            base_value = @as(u20, registers.getBP());
            index_value = @as(u20, registers.getDI());
        },
        .AHSP_SI_SID8_SID16 => {
            base_value = @as(u20, registers.getSI());
            index_value = 0;
        },
        .CHBP_DI_DID8_DID16 => {
            base_value = @as(u20, registers.getDI());
            index_value = 0;
        },
        .DHSI_DIRECTACCESS_BPD8_BPD16 => {
            base_value = @as(u20, registers.getBP());
            index_value = 0;
        },
        .BHDI_BX_BXD8_BXD16 => {
            base_value = @as(u20, registers.getBX(WValue.word, null).value16);
            index_value = 0;
        },
    }

    return EffectiveAddressCalculation{
        .base = switch (rm) {
            .ALAX_BXSI_BXSID8_BXSID16,
            .CLCX_BXDI_BXDID8_BXDID16,
            => Address.bx,
            .DLDX_BPSI_BPSID8_BPSID16,
            .BLBX_BPDI_BPDID8_BPDID16,
            => Address.bp,
            .AHSP_SI_SID8_SID16 => Address.si,
            .CHBP_DI_DID8_DID16 => Address.di,
            .DHSI_DIRECTACCESS_BPD8_BPD16 => Address.bp,
            .BHDI_BX_BXD8_BXD16 => Address.bx,
        },
        .index = switch (rm) {
            .ALAX_BXSI_BXSID8_BXSID16,
            .DLDX_BPSI_BPSID8_BPSID16,
            => Address.si,
            .CLCX_BXDI_BXDID8_BXDID16,
            .BLBX_BPDI_BPDID8_BPDID16,
            => Address.di,
            .AHSP_SI_SID8_SID16,
            .CHBP_DI_DID8_DID16,
            .DHSI_DIRECTACCESS_BPD8_BPD16,
            .BHDI_BX_BXD8_BXD16,
            => Address.none,
        },
        .displacement = disp_format,
        .displacement_value = disp_value,
        .effective_address = base_value + index_value + disp_value,
    };
}

// TODO: DocString

fn getImmediateOpSourceAndDest(
    registers: *Register,
    payload: DecodePayload,
) InstructionInfo {
    const log = std.log.scoped(.getImmediateOpSourceAndDest);
    const Address = RegisterDirectory.RegisterName;
    var dest_info: DestinationInfo = undefined;
    var immediate_8: u8 = undefined;
    var immediate_16: u16 = undefined;
    var source_info: SourceInfo = undefined;
    var sign_extended_immediate: i16 = undefined;
    var signed_immediate: i16 = undefined;
    const instruction: BinaryInstructions = payload.immediate_op_instruction.opcode;
    const mod: ModValue = payload.immediate_op_instruction.mod;
    const rm: RmValue = payload.immediate_op_instruction.rm;
    const w: WValue = payload.immediate_op_instruction.w;
    switch (mod) {
        .memoryModeNoDisplacement => {
            if (rm != RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) {
                dest_info = DestinationInfo{
                    .address_calculation = calculateEffectiveAddress(
                        registers,
                        mod,
                        rm,
                        null,
                        null,
                    ),
                };
            } else {
                const disp_lo = @as(u16, payload.immediate_op_instruction.disp_lo.?);
                const disp_hi = (@as(u16, payload.immediate_op_instruction.disp_hi.?) << 8);
                dest_info = DestinationInfo{
                    .mem_addr = @as(u20, disp_hi + disp_lo),
                };
            }
        },
        .memoryMode8BitDisplacement => {
            dest_info = DestinationInfo{
                .address_calculation = calculateEffectiveAddress(
                    registers,
                    mod,
                    rm,
                    payload.immediate_op_instruction.data_lo.?,
                    null,
                ),
            };
        },
        .memoryMode16BitDisplacement => {
            dest_info = DestinationInfo{
                .address_calculation = calculateEffectiveAddress(
                    registers,
                    mod,
                    rm,
                    payload.immediate_op_instruction.disp_lo.?,
                    payload.immediate_op_instruction.disp_hi.?,
                ),
            };
        },
        .registerModeNoDisplacement => {
            dest_info = DestinationInfo{
                .address = switch (rm) {
                    .ALAX_BXSI_BXSID8_BXSID16 => if (w == WValue.word) Address.ax else Address.al,
                    .CLCX_BXDI_BXDID8_BXDID16 => if (w == WValue.word) Address.cx else Address.cl,
                    .DLDX_BPSI_BPSID8_BPSID16 => if (w == WValue.word) Address.dx else Address.dl,
                    .BLBX_BPDI_BPDID8_BPDID16 => if (w == WValue.word) Address.bx else Address.bl,
                    .AHSP_SI_SID8_SID16 => if (w == WValue.word) Address.sp else Address.ah,
                    .CHBP_DI_DID8_DID16 => if (w == WValue.word) Address.bp else Address.ch,
                    .DHSI_DIRECTACCESS_BPD8_BPD16 => if (w == WValue.word) Address.si else Address.dh,
                    .BHDI_BX_BXD8_BXD16 => if (w == WValue.word) Address.di else Address.bh,
                },
            };
        },
    }

    switch (instruction) {
        .immediate8_to_regmem8 => {
            immediate_8 = payload.immediate_op_instruction.data_8.?;
            source_info = SourceInfo{
                .immediate = @intCast(immediate_8),
            };
        },
        .immediate16_to_regmem16 => {
            immediate_16 = (@as(u16, payload.immediate_op_instruction.data_hi.?) << 8) + payload.immediate_op_instruction.data_lo.?;
            source_info = SourceInfo{
                .immediate = immediate_16,
            };
        },
        .s_immediate8_to_regmem8 => {
            sign_extended_immediate = @intCast(payload.immediate_op_instruction.signed_data_8.?);
            source_info = SourceInfo{
                .immediate = @bitCast(sign_extended_immediate),
            };
        },
        .immediate8_to_regmem16 => {
            signed_immediate = payload.immediate_op_instruction.data_sx.?;
            source_info = SourceInfo{
                .immediate = @bitCast(signed_immediate),
            };
        },
        else => {
            log.err("Not a valid opcode for this function: {t}", .{instruction});
        },
    }

    return InstructionInfo{
        .destination_info = dest_info,
        .source_info = source_info,
    };
}

fn getImmediateToRegMovDest(w: WValue, reg: RegValue, data: u8, w_data: ?u8) InstructionInfo {
    const Address = RegisterDirectory.RegisterName;
    var dest: Address = undefined;
    var immediate: u16 = undefined;
    if (w_data != null) {
        immediate = (@as(u16, w_data.?) << 8) + data;
    } else {
        immediate = @as(u16, data);
    }
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
        .immediate = immediate,
    };
    return InstructionInfo{
        .destination_info = destination_payload,
        .source_info = source_payload,
    };
}

/// Checks if a displacement value fits inside a 8 bit signed integer
/// or if a 16 bit signed integer is needed. Returns true if a 8 bit integer
/// suffices.
fn shouldUse8BitDisplacement(displacement: i16) bool {
    return displacement >= -128 and displacement <= 127;
}

// zig fmt: off

fn getAddImmediateToAccumulatorDest(
    // registers: *Register,
    w: WValue,
    data: u8,
    w_data: ?u8,
) InstructionInfo {
    const Address = RegisterDirectory.RegisterName;
    var dest: Address = undefined;
    var immediate_8: u8 = undefined;
    var immediate_16: u16 = undefined;
    if (w == WValue.byte) {
        dest = Address.al;
        immediate_8 = data;
        return InstructionInfo{
            .destination_info = DestinationInfo{
                .address = dest,
            },
            .source_info = SourceInfo{
                .immediate = @intCast(immediate_8),
            },
        };
    } else {
        dest = Address.ax;
        immediate_16 = (@as(u16, w_data.?) << 8) + @as(u16, data);
        return InstructionInfo{
            .destination_info = DestinationInfo{
                .address = dest,
            },
            .source_info = SourceInfo{
                .immediate = immediate_16,
            },
        };
    }
}

/// Given the fields decoded from the instruction bytes this function returns
/// the addresses of source and destination. These can be registers or memory
/// addresses. The values are returned as InstructionInfo.
fn getRegMemToFromRegSourceAndDest(
    registers: *Register,
    d: DValue,
    w: WValue,
    reg: RegValue,
    mod: ModValue,
    rm: RmValue,
    disp_lo: ?u8,
    disp_hi: ?u8,
    ) InstructionInfo {

    const Address = RegisterDirectory.RegisterName;
    var dest: Address = undefined;
    var source: Address = undefined;
    var source_mem_addr: u20 = undefined;
    var destination_mem_addr: u20 = undefined;
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
                    const si_value: u16 = registers.getSI();
                    if (regIsSource) {
                        dest_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.si,
                            .displacement = DisplacementFormat.none,
                            .displacement_value = null,
                            .effective_address = (@as(u20, bx_value) << 4) + si_value,
                        };
                    } else if (!regIsSource) {
                        source_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.si,
                            .displacement = DisplacementFormat.none,
                            .displacement_value = null,
                            .effective_address = (@as(u20, bx_value) << 4) + si_value,
                        };
                    }
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    const bx_value: u16 = registers.getBX(WValue.word, null).value16;
                    const di_value: u16 = registers.getDI();
                    if (regIsSource) {
                        dest_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.di,
                            .displacement = DisplacementFormat.none,
                            .displacement_value = null,
                            .effective_address = (@as(u20, bx_value) << 4) + di_value,
                        };
                    } else if (!regIsSource) {
                        source_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.di,
                            .displacement = DisplacementFormat.none,
                            .displacement_value = null,
                            .effective_address = (@as(u20, bx_value) << 4) + di_value,
                        };
                    }
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    const bp_value = registers.getBP();
                    const si_value = registers.getSI();
                    if (regIsSource) {
                        dest_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.si,
                            .displacement = DisplacementFormat.none,
                            .displacement_value = null,
                            .effective_address = (@as(u20, bp_value) << 4) + si_value,

                        };
                    } else {
                        source_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.si,
                            .displacement = DisplacementFormat.none,
                            .displacement_value = null,
                            .effective_address = (@as(u20, bp_value) << 4) + si_value,

                        };
                    }
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    const bp_value = registers.getBP();
                    const di_value: u16 = registers.getDI();
                    if (regIsSource) {
                        dest_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.di,
                            .displacement = DisplacementFormat.none,
                            .displacement_value = null,
                            .effective_address = (@as(u20, bp_value) << 4) + di_value,

                        };
                    } else {
                        source_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.di,
                            .displacement = DisplacementFormat.none,
                            .displacement_value = null,
                            .effective_address = (@as(u20, bp_value) << 4) + di_value,

                        };
                    }
                },
                .AHSP_SI_SID8_SID16 => {
                    if (regIsSource) {
                        dest = Address.si;
                    } else if (!regIsSource) {
                        source = Address.si;
                    }
                },
                .CHBP_DI_DID8_DID16 => {
                    if (regIsSource) {
                        dest = Address.di;
                    } else if (!regIsSource) {
                        source = Address.di;
                    }
                },


                // TODO: What value should i pass along here? I think
                // it is an immediate value. Make sure!
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
                    if (regIsSource) {
                        destination_mem_addr = displacement;
                    } else if (!regIsSource) {
                        source_mem_addr = displacement;
                    }
                },
                .BHDI_BX_BXD8_BXD16 => {
                    if (regIsSource) {
                        dest = Address.bx;
                    } else if (!regIsSource) {
                        source = Address.bx;
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
                        .displacement_value = @as(u16, disp_lo.?),
                        .effective_address = ((@as(u20, bx_value)) << 4) + registers.getSI() + disp_lo.?,
                    };
                    if (regIsSource) {
                        dest_address_calculation = effective_address_calculation; 
                    } else if (!regIsSource) {
                        source_address_calculation = effective_address_calculation;
                    }
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    const bx_value: u16 = registers.getBX(WValue.word, null).value16;
                    const effective_address_calculation: EffectiveAddressCalculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.di,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = @as(u16, disp_lo.?),
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
                        .displacement_value = @as(u16, disp_lo.?),
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
                        .displacement_value = @as(u16, disp_lo.?),
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
                        .displacement_value = @as(u16, disp_lo.?),
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
                        .displacement_value = @as(u16, disp_lo.?),
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
                        .displacement_value = @as(u16, disp_lo.?),
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
                        .displacement_value = @as(u16, disp_lo.?),
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
                    const si_value: u16 = registers.getSI();
                    const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
                    if (regIsSource) {
                        dest_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.si,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bx_value) << 4) + si_value + displacement,

                        };
                    } else {
                        source_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.si,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bx_value) << 4) + si_value + displacement,
                        };
                    }
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    const bx_value: u16 = registers.getBX(WValue.word, null).value16;
                    const di_value: u16 = registers.getDI();
                    const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
                    if (regIsSource) {
                        dest_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.di,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bx_value) << 4) + di_value + displacement,
                        };
                    } else {
                        source_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.di,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bx_value) << 4) + di_value + displacement,
                        };
                    }
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    const bp_value: u16 = registers.getBP();
                    const si_value: u16 = registers.getSI();
                    const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
                    if (regIsSource) {
                        dest_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.si,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bp_value) << 4) + si_value + displacement,
                        };
                    } else {
                        source_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.si,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bp_value) << 4) + si_value + displacement,
                        };
                    }
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    const bp_value: u16 = registers.getBP();
                    const di_value: u16 = registers.getDI();
                    const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
                    if (regIsSource) {
                        dest_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.di,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bp_value) << 4) + di_value + displacement,
                        };
                    } else {
                        source_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.di,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bp_value) << 4) + di_value + displacement,
                        };
                    }
                },
                .AHSP_SI_SID8_SID16 => {
                    const si_value: u16 = registers.getSI();
                    const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
                    if (regIsSource) {
                        dest_address_calculation = EffectiveAddressCalculation{
                            .base = Address.si,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, si_value) << 4) + displacement,
                        };
                    } else {
                        source_address_calculation = EffectiveAddressCalculation{
                            .base = Address.si,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, si_value) << 4) + displacement,
                        };
                    }
                    
                },
                .CHBP_DI_DID8_DID16 => {
                    const di_value: u16 = registers.getDI();
                    const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
                    if (regIsSource) {
                        dest_address_calculation = EffectiveAddressCalculation{
                            .base = Address.di,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, di_value) << 4) + displacement,
                        };
                    } else {
                        source_address_calculation = EffectiveAddressCalculation{
                            .base = Address.di,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, di_value) << 4) + displacement,
                        };
                    }

                },
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    const bp_value: u16 = registers.getBP();
                    const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
                    if (regIsSource) {
                        dest_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bp_value) << 4) + displacement,
                        };
                    } else {
                        source_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bp_value) << 4) + displacement,
                        };
                    }

                },
                .BHDI_BX_BXD8_BXD16 => {
                    const bx_value: u16 = registers.getBX(WValue.word, null).value16;
                    const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
                    if (regIsSource) {
                        dest_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bx_value) << 4) + displacement,
                        };
                    } else {
                        source_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bx_value) << 4) + displacement,
                        };
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
    } else if (mod == ModValue.memoryModeNoDisplacement and rm != RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) {
        if (regIsSource) {
            switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16,
                .CLCX_BXDI_BXDID8_BXDID16,
                .DLDX_BPSI_BPSID8_BPSID16,
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    destination_payload = DestinationInfo{
                        .address_calculation = dest_address_calculation,
                    };
                },
                .AHSP_SI_SID8_SID16,
                .CHBP_DI_DID8_DID16,
                .BHDI_BX_BXD8_BXD16 => {
                    destination_payload = DestinationInfo{
                        .address = dest,
                    };
                },
                else => {
                    std.debug.print("Error: Destination Address Calculation is messed up", .{});
                }
            }
        } else if (!regIsSource) {
            destination_payload = DestinationInfo{
                .address = dest,
            };
        }
    } else if (mod == ModValue.memoryMode8BitDisplacement or mod == ModValue.memoryMode16BitDisplacement) {
        if (regIsSource) {
            destination_payload = DestinationInfo{
                .address_calculation = dest_address_calculation,
            };
        } else if (!regIsSource) {
            destination_payload = DestinationInfo{
                .address = dest,
            };
        }
    } else if (mod == ModValue.registerModeNoDisplacement) {
        destination_payload = DestinationInfo{
            .address = dest,
        };
    }

    var source_payload: SourceInfo = undefined;
    if (mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) {
        source_payload = SourceInfo{
            .mem_addr = source_mem_addr,
        };
    } else if (mod == ModValue.memoryModeNoDisplacement and rm != RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) {
        if (regIsSource) {
            source_payload = SourceInfo{
                .address = source,    
            };
        } else if (!regIsSource) {
            switch (rm) {
                .AHSP_SI_SID8_SID16,
                .CHBP_DI_DID8_DID16,
                .BHDI_BX_BXD8_BXD16 => {
                    source_payload = SourceInfo{
                        .address = source,
                    };
                },
                .ALAX_BXSI_BXSID8_BXSID16,
                .CLCX_BXDI_BXDID8_BXDID16,
                .DLDX_BPSI_BPSID8_BPSID16,
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    source_payload = SourceInfo{
                        .address_calculation = source_address_calculation,
                    };
                },
                else => {
                    std.debug.print("Error: Source Address Calculation is messed up", .{});
                }
            }
        }
    } else if (mod == ModValue.memoryMode8BitDisplacement or mod == ModValue.memoryMode16BitDisplacement) {
        if (regIsSource) {
            source_payload = SourceInfo{
                .address = source,
            };
        } else if (!regIsSource) {
            source_payload = SourceInfo{
                .address_calculation = source_address_calculation,
            };
        }
    } else if (mod == ModValue.registerModeNoDisplacement) {
        source_payload = SourceInfo{
            .address = source,
        };
    }

    return InstructionInfo{
        .destination_info = destination_payload,
        .source_info = source_payload,
    };
}

/// Get source and destination for Reg/Mem to segment register operations.
fn getRegMemToSegMovSourceAndDest(
    registers: *Register,
    mod: ModValue,
    sr: SrValue,
    rm: RmValue,
    disp_lo: ?u8,
    disp_hi: ?u8,
) InstructionInfo {
    const Address = RegisterDirectory.RegisterName;
    var dest: Address = undefined;
    var source: Address = undefined;
    var source_address_calculation: EffectiveAddressCalculation = undefined; 

    var destination_payload: DestinationInfo = undefined;
    var source_payload: SourceInfo = undefined;

    switch(mod) {
        .memoryModeNoDisplacement => {
            switch(rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    const bx_value: u16 = registers.getBX(WValue.word, null).value16;
                    const si_value: u16 = registers.getSI();
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.si,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, bx_value) << 4) + si_value,
                    };
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    const bx_value: u16 = registers.getBX(WValue.word, null).value16;
                    const di_value: u16 = registers.getDI();
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.di,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, bx_value) << 4) + di_value,
                    };
                },
                    .DLDX_BPSI_BPSID8_BPSID16 => {
                        const bp_value: u16 = registers.getBP();
                        const si_value: u16 = registers.getSI();
                        source_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.si,
                            .displacement = DisplacementFormat.none,
                            .displacement_value = null,
                            .effective_address = (@as(u20, bp_value) << 4) + si_value,
                        };
                    },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    const bp_value: u16 = registers.getBP();
                    const di_value: u16 = registers.getDI();
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.di,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, bp_value) << 4) + di_value,
                    };
                },
                .AHSP_SI_SID8_SID16 => {
                    const si_value: u16 = registers.getSI();
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.si,
                        .index = Address.none,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, si_value) << 4),
                    };
                },
                .CHBP_DI_DID8_DID16 => {
                    const di_value: u16 = registers.getDI();
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.di,
                        .index = Address.none,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, di_value) << 4),
                    };
                },
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    const displacement = (@as(u16, disp_hi.?) << 8) + disp_lo.?;
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.none,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, displacement),
                    };
                },
                .BHDI_BX_BXD8_BXD16 => {
                    const bx_value: u16 = registers.getBX(WValue.word, null).value16;
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.none,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, bx_value) << 4),
                    };
                },
            }
        },
        .memoryMode8BitDisplacement => {
            switch(rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    const bx_value = registers.getBX(WValue.word, null).value16;
                    const si_value = registers.getSI();
                    const displacement = @as(u16, disp_lo.?);
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.si,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, bx_value) + si_value + displacement,
                    };
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    const bx_value = registers.getBX(WValue.word, null).value16;
                    const di_value = registers.getDI();
                    const displacement = @as(u16, disp_lo.?);
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.di,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, bx_value) + di_value + displacement,
                    };
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    const bp_value = registers.getBP();
                    const si_value = registers.getSI();
                    const displacement = @as(u16, disp_lo.?);
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.si,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, bp_value) + si_value + displacement,
                    };
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    const bp_value = registers.getBP();
                    const di_value = registers.getDI();
                    const displacement = @as(u16, disp_lo.?);
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.di,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, bp_value) + di_value + displacement,
                    };
                },
                .AHSP_SI_SID8_SID16 => {
                    const si_value = registers.getSI();
                    const displacement = @as(u16, disp_lo.?);
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.si,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, si_value) + displacement,
                    };
                },
                .CHBP_DI_DID8_DID16 => {
                    const di_value = registers.getDI();
                    const displacement = @as(u16, disp_lo.?);
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.di,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, di_value) + displacement,
                    };
                },
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    const bp_value = registers.getBP();
                    const displacement = @as(u16, disp_lo.?);
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, bp_value) + displacement,
                    };
                },
                .BHDI_BX_BXD8_BXD16 => {
                    const bx_value = registers.getBX(WValue.word, null).value16;
                    const displacement = @as(u16, disp_lo.?);
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, bx_value) + displacement,
                    };
                },
            }
        },
        .memoryMode16BitDisplacement => {
            switch(rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    const bx_value = registers.getBX(WValue.word, null).value16;
                    const si_value = registers.getSI();
                    const displacement = @as(u16, disp_hi.?) + disp_lo.?;
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.si,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = (@as(u20, bx_value) << 4) + si_value + displacement,
                    };
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    const bx_value = registers.getBX(WValue.word, null).value16;
                    const di_value = registers.getDI();
                    const displacement = @as(u16, disp_hi.?) + disp_lo.?;
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.di,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = (@as(u20, bx_value) << 4) + di_value + displacement,
                    };
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    const bp_value = registers.getBP();
                    const si_value = registers.getSI();
                    const displacement = @as(u16, disp_hi.?) + disp_lo.?;
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.si,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = (@as(u20, bp_value) << 4) + si_value + displacement,
                    };
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    const bp_value = registers.getBP();
                    const di_value = registers.getDI();
                    const displacement = @as(u16, disp_hi.?) + disp_lo.?;
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.di,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = (@as(u20, bp_value) << 4) + di_value + displacement,
                    };
                },
                .AHSP_SI_SID8_SID16 => {
                    const si_value = registers.getSI();
                    const displacement = @as(u16, disp_hi.?) + disp_lo.?;
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.si,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, si_value) + displacement,
                    };
                },
                .CHBP_DI_DID8_DID16 => {
                    const di_value = registers.getDI();
                    const displacement = @as(u16, disp_hi.?) + disp_lo.?;
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.di,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, di_value) + displacement,
                    };
                },
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    const bp_value = registers.getBP();
                    const displacement = @as(u16, disp_hi.?) + disp_lo.?;
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.none,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, bp_value) + displacement,
                    };
                },
                .BHDI_BX_BXD8_BXD16 => {
                    const bx_value = registers.getBX(WValue.word, null).value16;
                    const displacement = @as(u16, disp_hi.?) + disp_lo.?;
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = (@as(u20, bx_value) << 4) + displacement,
                    };
                },
            }
        },
        .registerModeNoDisplacement => {
            switch(rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    source = Address.ax;
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    source = Address.cx;
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    source = Address.dx;
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    source = Address.bx;
                },
                .AHSP_SI_SID8_SID16 => {
                    source = Address.sp;
                },
                .CHBP_DI_DID8_DID16 => {
                    source = Address.bp;
                },
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    source = Address.si;
                },
                .BHDI_BX_BXD8_BXD16 => {
                    source = Address.di;
                },
            }
        },
    }

    if (mod == ModValue.registerModeNoDisplacement) {
        source_payload = SourceInfo{
            .address = source,
        };
    } else {
        source_payload = SourceInfo{
            .address_calculation = source_address_calculation
        };
    }

    switch(sr) {
        .ES => {
            dest = Address.es;
        },
        .CS => {
            dest = Address.cs;
        },
        .SS => {
            dest = Address.ss;
        },
        .DS => {
            dest = Address.ds;
        },
    }

    destination_payload = DestinationInfo{
        .address = dest,
    };

    return InstructionInfo{
        .destination_info = destination_payload,
        .source_info = source_payload,
    }; 
}

/// Get source and destination for segment register to Reg/Mem operations.
fn getSegToRegMemMovSourceAndDest(
    registers: *Register,
    mod: ModValue,
    sr: SrValue,
    rm: RmValue,
    disp_lo: ?u8,
    disp_hi: ?u8,
) InstructionInfo {
    const Address = RegisterDirectory.RegisterName;
    var dest: Address = undefined;
    var source: Address = undefined;
    var dest_address_calculation: EffectiveAddressCalculation = undefined; 

    var destination_payload: DestinationInfo = undefined;
    var source_payload: SourceInfo = undefined;

    switch(sr) {
        .ES => {
            source = Address.es;
        },
        .CS => {
            source = Address.cs;
        },
        .SS => {
            source = Address.ss;
        },
        .DS => {
            source = Address.ds;
        },
    }

    source_payload = SourceInfo{
        .address = source,
    };

    switch(mod) {
        .memoryModeNoDisplacement => {
            switch(rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    const bx_value: u16 = registers.getBX(WValue.word, null).value16;
                    const si_value: u16 = registers.getSI();
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.si,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, bx_value) << 4) + si_value,
                    };
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    const bx_value: u16 = registers.getBX(WValue.word, null).value16;
                    const di_value: u16 = registers.getDI();
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.di,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, bx_value) << 4) + di_value,
                    };
                },
                    .DLDX_BPSI_BPSID8_BPSID16 => {
                        const bp_value: u16 = registers.getBP();
                        const si_value: u16 = registers.getSI();
                        dest_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.si,
                            .displacement = DisplacementFormat.none,
                            .displacement_value = null,
                            .effective_address = (@as(u20, bp_value) << 4) + si_value,
                        };
                    },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    const bp_value: u16 = registers.getBP();
                    const di_value: u16 = registers.getDI();
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.di,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, bp_value) << 4) + di_value,
                    };
                },
                .AHSP_SI_SID8_SID16 => {
                    const si_value: u16 = registers.getSI();
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.si,
                        .index = Address.none,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, si_value) << 4),
                    };
                },
                .CHBP_DI_DID8_DID16 => {
                    const di_value: u16 = registers.getDI();
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.di,
                        .index = Address.none,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, di_value) << 4),
                    };
                },
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    const displacement = (@as(u16, disp_hi.?) << 8) + disp_lo.?;
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.none,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, displacement),
                    };
                },
                .BHDI_BX_BXD8_BXD16 => {
                    const bx_value: u16 = registers.getBX(WValue.word, null).value16;
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.none,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, bx_value) << 4),
                    };
                },
            }
        },
        .memoryMode8BitDisplacement => {
            switch(rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    const bx_value = registers.getBX(WValue.word, null).value16;
                    const si_value = registers.getSI();
                    const displacement = @as(u16, disp_lo.?);
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.si,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, bx_value) + si_value + displacement,
                    };
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    const bx_value = registers.getBX(WValue.word, null).value16;
                    const di_value = registers.getDI();
                    const displacement = @as(u16, disp_lo.?);
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.di,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, bx_value) + di_value + displacement,
                    };
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    const bp_value = registers.getBP();
                    const si_value = registers.getSI();
                    const displacement = @as(u16, disp_lo.?);
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.si,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, bp_value) + si_value + displacement,
                    };
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    const bp_value = registers.getBP();
                    const di_value = registers.getDI();
                    const displacement = @as(u16, disp_lo.?);
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.di,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, bp_value) + di_value + displacement,
                    };
                },
                .AHSP_SI_SID8_SID16 => {
                    const si_value = registers.getSI();
                    const displacement = @as(u16, disp_lo.?);
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.si,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, si_value) + displacement,
                    };
                },
                .CHBP_DI_DID8_DID16 => {
                    const di_value = registers.getDI();
                    const displacement = @as(u16, disp_lo.?);
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.di,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, di_value) + displacement,
                    };
                },
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    const bp_value = registers.getBP();
                    const displacement = @as(u16, disp_lo.?);
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, bp_value) + displacement,
                    };
                },
                .BHDI_BX_BXD8_BXD16 => {
                    const bx_value = registers.getBX(WValue.word, null).value16;
                    const displacement = @as(u16, disp_lo.?);
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, bx_value) + displacement,
                    };
                },
            }
        },
        .memoryMode16BitDisplacement => {
            switch(rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    const bx_value = registers.getBX(WValue.word, null).value16;
                    const si_value = registers.getSI();
                    const displacement = @as(u16, disp_hi.?) + disp_lo.?;
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.si,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = (@as(u20, bx_value) << 4) + si_value + displacement,
                    };
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    const bx_value = registers.getBX(WValue.word, null).value16;
                    const di_value = registers.getDI();
                    const displacement = @as(u16, disp_hi.?) + disp_lo.?;
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.di,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = (@as(u20, bx_value) << 4) + di_value + displacement,
                    };
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    const bp_value = registers.getBP();
                    const si_value = registers.getSI();
                    const displacement = @as(u16, disp_hi.?) + disp_lo.?;
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.si,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = (@as(u20, bp_value) << 4) + si_value + displacement,
                    };
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    const bp_value = registers.getBP();
                    const di_value = registers.getDI();
                    const displacement = @as(u16, disp_hi.?) + disp_lo.?;
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.di,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = (@as(u20, bp_value) << 4) + di_value + displacement,
                    };
                },
                .AHSP_SI_SID8_SID16 => {
                    const si_value = registers.getSI();
                    const displacement = @as(u16, disp_hi.?) + disp_lo.?;
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.si,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, si_value) + displacement,
                    };
                },
                .CHBP_DI_DID8_DID16 => {
                    const di_value = registers.getDI();
                    const displacement = @as(u16, disp_hi.?) + disp_lo.?;
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.di,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, di_value) + displacement,
                    };
                },
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    const bp_value = registers.getBP();
                    const displacement = @as(u16, disp_hi.?) + disp_lo.?;
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.none,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, bp_value) + displacement,
                    };
                },
                .BHDI_BX_BXD8_BXD16 => {
                    const bx_value = registers.getBX(WValue.word, null).value16;
                    const displacement = @as(u16, disp_hi.?) + disp_lo.?;
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = (@as(u20, bx_value) << 4) + displacement,
                    };
                },
            }
        },
        .registerModeNoDisplacement => {
            switch(rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    dest = Address.ax;
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    dest = Address.cx;
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    dest = Address.dx;
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    dest = Address.bx;
                },
                .AHSP_SI_SID8_SID16 => {
                    dest = Address.sp;
                },
                .CHBP_DI_DID8_DID16 => {
                    dest = Address.bp;
                },
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    dest = Address.si;
                },
                .BHDI_BX_BXD8_BXD16 => {
                    dest = Address.di;
                },
            }
        },
    }

    if (mod == ModValue.registerModeNoDisplacement) {
        destination_payload = DestinationInfo{
            .address = dest,
        };
    } else {
        destination_payload = DestinationInfo{
            .address_calculation = dest_address_calculation
        };
    }

    return InstructionInfo{
        .destination_info = destination_payload,
        .source_info = source_payload,
    }; 
}

fn getMemToAccMovSourceAndDest(w: WValue, addr_lo: ?u8, addr_hi: ?u8) InstructionInfo {
    const Address = RegisterDirectory.RegisterName;
    var destination_payload: DestinationInfo = undefined;
    var source_payload: SourceInfo = undefined;
    switch (w) {
        .byte => {
            const addr = (@as(u16, addr_hi.?) << 8) + addr_lo.?;
            source_payload = SourceInfo{
                .mem_addr = @as(u20, addr),
            };
            destination_payload = DestinationInfo{
                .address = Address.al,
            };
        },
        .word => {
            const addr = (@as(u16, addr_hi.?) << 8) + addr_lo.?;
            source_payload = SourceInfo{
                .mem_addr = @as(u20, addr),
            };
            destination_payload = DestinationInfo{
                .address = Address.ax,
            };
        },
    }
    return InstructionInfo{
        .destination_info = destination_payload,
        .source_info = source_payload,
    };
}

fn getAccToMemMovSourceAndDest(w: WValue, addr_lo: ?u8, addr_hi: ?u8,) InstructionInfo {
    const Address = RegisterDirectory.RegisterName;
    var destination_payload: DestinationInfo = undefined;
    var source_payload: SourceInfo = undefined;
    switch (w) {
        .byte => {
            const addr = (@as(u16, addr_hi.?) << 8) + addr_lo.?;
            destination_payload = DestinationInfo{
                .mem_addr = @as(u20, addr),
            };
            source_payload = SourceInfo{
                .address = Address.al,
            };
        },
        .word => {
            const addr = (@as(u16, addr_hi.?) << 8) + addr_lo.?;
            destination_payload = DestinationInfo{
                .mem_addr = @as(u20, addr),
            };
            source_payload = SourceInfo{
                .address = Address.ax,
            };
        },
    }


    return InstructionInfo{
        .destination_info = destination_payload,
        .source_info = source_payload,
    };
}

// zig fmt: on

fn getImmediateToRegMemMovDest(
    registers: *Register,
    mod: ModValue,
    rm: RmValue,
    w: WValue,
    disp_lo: ?u8,
    disp_hi: ?u8,
    data: u8,
    w_data: ?u8,
) InstructionInfo {
    const Address = RegisterDirectory.RegisterName;
    const source_payload: SourceInfo = SourceInfo{
        .immediate = @intCast(if (w == WValue.word) (@as(u16, w_data.?) << 8) + (@as(u16, data)) else @as(u16, data)),
    };

    var destination_payload: DestinationInfo = undefined;
    switch (mod) {
        .memoryModeNoDisplacement => {
            switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    const bx_value = registers.getBX(WValue.word, null).value16;
                    const si_value = registers.getSI();
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.si,
                            .displacement = DisplacementFormat.none,
                            .displacement_value = null,
                            .effective_address = (@as(u20, bx_value) << 4) + si_value,
                        },
                    };
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    const bx_value = registers.getBX(WValue.word, null).value16;
                    const di_value = registers.getDI();
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.di,
                            .displacement = DisplacementFormat.none,
                            .displacement_value = null,
                            .effective_address = (@as(u20, bx_value) << 4) + di_value,
                        },
                    };
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    const bp_value = registers.getBP();
                    const si_value = registers.getSI();
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.si,
                            .displacement = DisplacementFormat.none,
                            .displacement_value = null,
                            .effective_address = (@as(u20, bp_value) << 4) + si_value,
                        },
                    };
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    const bp_value = registers.getBP();
                    const di_value = registers.getDI();
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.di,
                            .displacement = DisplacementFormat.none,
                            .displacement_value = null,
                            .effective_address = (@as(u20, bp_value) << 4) + di_value,
                        },
                    };
                },
                .AHSP_SI_SID8_SID16 => {
                    const si_value = registers.getSI();
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.si,
                            .index = Address.none,
                            .displacement = DisplacementFormat.none,
                            .displacement_value = null,
                            .effective_address = (@as(u20, si_value) << 4),
                        },
                    };
                },
                .CHBP_DI_DID8_DID16 => {
                    const di_value = registers.getDI();
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.di,
                            .index = Address.none,
                            .displacement = DisplacementFormat.none,
                            .displacement_value = null,
                            .effective_address = (@as(u20, di_value) << 4),
                        },
                    };
                },
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    const displacement = (@as(u16, disp_hi.?) << 8) + disp_lo.?;
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.none,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = @as(u20, displacement),
                        },
                    };
                },
                .BHDI_BX_BXD8_BXD16 => {
                    const bx_value = registers.getBX(WValue.word, null).value16;
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.none,
                            .displacement = DisplacementFormat.none,
                            .displacement_value = null,
                            .effective_address = (@as(u20, bx_value) << 4),
                        },
                    };
                },
            }
        },
        .memoryMode8BitDisplacement => {
            switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    const bx_value = registers.getBX(WValue.word, null).value16;
                    const si_value = registers.getSI();
                    const displacement = @as(u16, disp_lo.?);
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.si,
                            .displacement = DisplacementFormat.d8,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bx_value) << 4) + si_value + displacement,
                        },
                    };
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    const bx_value = registers.getBX(WValue.word, null).value16;
                    const di_value = registers.getDI();
                    const displacement = @as(u16, disp_lo.?);
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.di,
                            .displacement = DisplacementFormat.d8,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bx_value) << 4) + di_value + displacement,
                        },
                    };
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    const bp_value = registers.getBP();
                    const si_value = registers.getSI();
                    const displacement = @as(u16, disp_lo.?);
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.si,
                            .displacement = DisplacementFormat.d8,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bp_value) << 4) + si_value + displacement,
                        },
                    };
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    const bp_value = registers.getBP();
                    const di_value = registers.getDI();
                    const displacement = @as(u16, disp_lo.?);
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.di,
                            .displacement = DisplacementFormat.d8,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bp_value) << 4) + di_value + displacement,
                        },
                    };
                },
                .AHSP_SI_SID8_SID16 => {
                    const si_value = registers.getSI();
                    const displacement = @as(u16, disp_lo.?);
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.si,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d8,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, si_value) << 4) + displacement,
                        },
                    };
                },
                .CHBP_DI_DID8_DID16 => {
                    const di_value = registers.getDI();
                    const displacement = @as(u16, disp_lo.?);
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.di,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d8,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, di_value) << 4) + displacement,
                        },
                    };
                },
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    const bp_value = registers.getBP();
                    const displacement = @as(u16, disp_lo.?);
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d8,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bp_value) << 4) + displacement,
                        },
                    };
                },
                .BHDI_BX_BXD8_BXD16 => {
                    const bx_value = registers.getBX(WValue.word, null).value16;
                    const displacement = @as(u16, disp_lo.?);
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d8,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bx_value) << 4) + displacement,
                        },
                    };
                },
            }
        },
        .memoryMode16BitDisplacement => {
            switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    const bx_value = registers.getBX(WValue.word, null).value16;
                    const si_value = registers.getSI();
                    const displacement = (@as(u16, disp_hi.?) << 8) + disp_lo.?;
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.si,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bx_value) << 4) + si_value + displacement,
                        },
                    };
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    const bx_value = registers.getBX(WValue.word, null).value16;
                    const di_value = registers.getDI();
                    const displacement = (@as(u16, disp_hi.?) << 8) + disp_lo.?;
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.di,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bx_value) << 4) + di_value + displacement,
                        },
                    };
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    const bp_value = registers.getBP();
                    const si_value = registers.getSI();
                    const displacement = (@as(u16, disp_hi.?) << 8) + disp_lo.?;
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.si,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bp_value) << 4) + si_value + displacement,
                        },
                    };
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    const bp_value = registers.getBP();
                    const di_value = registers.getDI();
                    const displacement = (@as(u16, disp_hi.?) << 8) + disp_lo.?;
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.di,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bp_value) << 4) + di_value + displacement,
                        },
                    };
                },
                .AHSP_SI_SID8_SID16 => {
                    const si_value = registers.getSI();
                    const displacement = (@as(u16, disp_hi.?) << 8) + disp_lo.?;
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.si,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, si_value) << 4) + displacement,
                        },
                    };
                },
                .CHBP_DI_DID8_DID16 => {
                    const di_value = registers.getDI();
                    const displacement = (@as(u16, disp_hi.?) << 8) + disp_lo.?;
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.di,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, di_value) << 4) + displacement,
                        },
                    };
                },
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    const bp_value = registers.getBP();
                    const displacement = (@as(u16, disp_hi.?) << 8) + disp_lo.?;
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bp_value) << 4) + displacement,
                        },
                    };
                },
                .BHDI_BX_BXD8_BXD16 => {
                    const bx_value = registers.getBX(WValue.word, null).value16;
                    const displacement = (@as(u16, disp_hi.?) << 8) + disp_lo.?;
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bx_value) << 4) + displacement,
                        },
                    };
                },
            }
        },
        .registerModeNoDisplacement => {
            switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    destination_payload = DestinationInfo{
                        .address = if (w == WValue.word) Address.ax else Address.al,
                    };
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    destination_payload = DestinationInfo{
                        .address = if (w == WValue.word) Address.cx else Address.cl,
                    };
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    destination_payload = DestinationInfo{
                        .address = if (w == WValue.word) Address.dx else Address.dl,
                    };
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    destination_payload = DestinationInfo{
                        .address = if (w == WValue.word) Address.bx else Address.bl,
                    };
                },
                .AHSP_SI_SID8_SID16 => {
                    destination_payload = DestinationInfo{
                        .address = if (w == WValue.word) Address.sp else Address.ah,
                    };
                },
                .CHBP_DI_DID8_DID16 => {
                    destination_payload = DestinationInfo{
                        .address = if (w == WValue.word) Address.bp else Address.ch,
                    };
                },
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    destination_payload = DestinationInfo{
                        .address = if (w == WValue.word) Address.si else Address.dh,
                    };
                },
                .BHDI_BX_BXD8_BXD16 => {
                    destination_payload = DestinationInfo{
                        .address = if (w == WValue.word) Address.di else Address.bh,
                    };
                },
            }
        },
    }

    return InstructionInfo{
        .destination_info = destination_payload,
        .source_info = source_payload,
    };
}

// zig fmt: off
/// Given the Mod and R/M value of an add register/memory with register to either
/// instruction, this function returns the number of bytes this instruction consists
/// of as a u3 value. Returns 1 if the instruction_name is not known to skip this instruction.
fn addGetInstructionLength(
    instruction_name: BinaryInstructions,
    mod: ?ModValue,
    rm: ?RmValue,
) u3 {
    const log = std.log.scoped(.addGetInstructionLength);
    switch (instruction_name) {
        .add_reg8_source_regmem8_dest,
        .add_reg16_source_regmem16_dest,
        .add_regmem8_source_reg8_dest,
        .add_regmem16_source_reg16_dest => switch (mod.?) {
            .memoryModeNoDisplacement => if (rm.? != RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) return 2 else return 4,
            .memoryMode8BitDisplacement => return 3,
            .memoryMode16BitDisplacement => return 4,
            .registerModeNoDisplacement => return 2,
        },
        else => {
            log.debug("Instruction not yet implemented. Skipping...", .{});
            return 1;
        },
    }
}

/// Given the InstructionBinaries value, SValue and WValue of a immediate value operation
/// this function returns the number of bytes it consists of as a u3 value. Returns 1 if
/// the instruction_name is not known to skip this instruction.
fn immediateOpGetInstructionLength(
    instruction_name: BinaryInstructions,
    mod: ModValue,
    rm: RmValue,
) u3 {
    const log = std.log.scoped(.immediateOpGetInstructionLength);
    switch (instruction_name) {
        .immediate8_to_regmem8 => switch (mod) {
            .memoryModeNoDisplacement => if (rm != RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) return 3 else return 5,
            .memoryMode8BitDisplacement => return 4,
            .memoryMode16BitDisplacement => return 5,
            .registerModeNoDisplacement => return 3,
        },
        .immediate16_to_regmem16 => switch (mod) {
            .memoryModeNoDisplacement => if (rm != RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) return 4 else return 6,
            .memoryMode8BitDisplacement => return 5,
            .memoryMode16BitDisplacement => return 6,
            .registerModeNoDisplacement => return 4,
        },
        .s_immediate8_to_regmem8 => switch (mod) {
            .memoryModeNoDisplacement => if (rm != RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) return 3 else return 5,
            .memoryMode8BitDisplacement => return 4,
            .memoryMode16BitDisplacement => return 5,
            .registerModeNoDisplacement => return 3,
        },
        .immediate8_to_regmem16 => switch (mod) {
            .memoryModeNoDisplacement => if (rm != RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) return 3 else return 5,
            .memoryMode8BitDisplacement => return 4,
            .memoryMode16BitDisplacement => return 5,
            .registerModeNoDisplacement => return 3,
        },
        else => {
            log.debug("Instruction not yet implemented. Skipping...", .{});
            return 1;
        },
    }
}

// zig fmt: on

/// Given the Mod and R/M value of a mov register/memory to/from register
/// instruction, this function returns the number of bytes this instruction
/// consists of as a u3 value. Returns 1 if the instruction_name is not known
/// to skip this instruction.
fn movGetInstructionLength(
    instruction_name: BinaryInstructions,
    w: WValue,
    mod: ?ModValue,
    rm: ?RmValue,
) u3 {
    const log = std.log.scoped(.movGetInstructionLength);
    switch (instruction_name) {
        .mov_source_regmem8_reg8,
        .mov_source_regmem16_reg16,
        .mov_dest_reg8_regmem8,
        .mov_dest_reg16_regmem16,
        => {
            const _mod = mod.?;
            const _rm = rm.?;
            switch (_mod) {
                .memoryModeNoDisplacement => {
                    if (_rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) return 4 else return 2;
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
        },
        .mov_immediate_reg_al,
        .mov_immediate_reg_cl,
        .mov_immediate_reg_dl,
        .mov_immediate_reg_bl,
        .mov_immediate_reg_ah,
        .mov_immediate_reg_ch,
        .mov_immediate_reg_dh,
        .mov_immediate_reg_bh,
        .mov_immediate_reg_ax,
        .mov_immediate_reg_cx,
        .mov_immediate_reg_dx,
        .mov_immediate_reg_bx,
        .mov_immediate_reg_sp,
        .mov_immediate_reg_bp,
        .mov_immediate_reg_si,
        .mov_immediate_reg_di,
        => {
            if (w == WValue.word) return 3 else return 2;
        },
        .mov_seg_regmem,
        .mov_regmem_seg,
        => {
            const _mod = mod.?;
            const _rm = rm.?;
            switch (_mod) {
                .memoryModeNoDisplacement => {
                    if (_rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) return 4 else return 2;
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
        },
        .mov_mem8_acc8,
        .mov_mem16_acc16,
        .mov_acc8_mem8,
        .mov_acc16_mem16,
        => {
            return 3;
        },
        .mov_immediate_to_regmem8,
        .mov_immediate_to_regmem16,
        => {
            const _mod = mod.?;
            const _rm = rm.?;
            switch (_mod) {
                .memoryModeNoDisplacement => {
                    if (_rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16 and w == WValue.word) {
                        return 6;
                    } else if (_rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) {
                        return 5;
                    } else if (_rm != RmValue.DHSI_DIRECTACCESS_BPD8_BPD16 and w == WValue.word) {
                        return 4;
                    } else {
                        return 3;
                    }
                },
                .memoryMode16BitDisplacement => {
                    if (w == WValue.word) return 6 else return 5;
                },
                .memoryMode8BitDisplacement => {
                    if (w == WValue.word) return 5 else return 4;
                },
                .registerModeNoDisplacement => {
                    if (w == WValue.word) return 4 else return 3;
                },
            }
        },
        else => {
            log.debug("Instruction not yet implemented. Skipping...", .{});
            return 1;
        },
    }
}

// TODO: Create DocString for this function
/// DocString
fn decodeImmediateOp(
    s: SValue,
    w: WValue,
    input: [6]u8,
) InstructionDecodeError!DecodePayload {
    const log = std.log.scoped(.decodeImmediateOp);
    const instruction: BinaryInstructions = @enumFromInt(input[0]);
    const mod: ModValue = @enumFromInt(input[1] >> 6);
    const rm: RmValue = @enumFromInt((input[1] << 5) >> 5);
    const action_code: ImmediateAction = @enumFromInt((input[1] << 2) >> 5);
    const mnemonic: []const u8 = switch (action_code) {
        .ADD => "add",
        .OR => "or",
        .ADC => "adc",
        .SBB => "sbb",
        .AND => "and",
        .SUB => "sub",
        .XOR => "xor",
        .CMP => "cmp",
    };
    const disp_lo: ?u8 = switch (mod) {
        .memoryModeNoDisplacement => if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) input[2] else null,
        .memoryMode8BitDisplacement => input[2],
        .memoryMode16BitDisplacement => input[2],
        .registerModeNoDisplacement => null,
    };
    const disp_hi: ?u8 = switch (mod) {
        .memoryModeNoDisplacement => if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) input[3] else null,
        .memoryMode8BitDisplacement => null,
        .memoryMode16BitDisplacement => input[3],
        .registerModeNoDisplacement => null,
    };
    var data_lo: ?u8 = undefined;
    if ((mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) or mod == ModValue.memoryMode16BitDisplacement) {
        data_lo = input[4];
    } else if (mod == ModValue.memoryMode8BitDisplacement) {
        data_lo = input[3];
    } else {
        data_lo = input[2];
    }
    var data_hi: ?u8 = undefined;
    if ((mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) or mod == ModValue.memoryMode16BitDisplacement) {
        data_hi = input[5];
    } else if (mod == ModValue.memoryMode8BitDisplacement) {
        data_hi = input[4];
    } else {
        data_hi = input[3];
    }
    var data_8: ?u8 = undefined;
    if ((mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) or mod == ModValue.memoryMode16BitDisplacement) {
        data_8 = input[4];
    } else if (mod == ModValue.memoryMode8BitDisplacement) {
        data_8 = input[3];
    } else {
        data_8 = input[2];
    }
    var signed_data_8: ?i8 = undefined;
    if ((mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) or mod == ModValue.memoryMode16BitDisplacement) {
        signed_data_8 = @bitCast(input[4]);
    } else if (mod == ModValue.memoryMode8BitDisplacement) {
        signed_data_8 = @bitCast(input[3]);
    } else {
        signed_data_8 = @bitCast(input[2]);
    }
    var data_sx: ?i16 = undefined;
    if ((mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) or mod == ModValue.memoryMode16BitDisplacement) {
        data_sx = @intCast(input[4]);
    } else if (mod == ModValue.memoryMode8BitDisplacement) {
        data_sx = @intCast(input[3]);
    } else {
        data_sx = @intCast(input[2]);
    }
    switch (instruction) {
        .immediate8_to_regmem8 => {
            return DecodePayload{
                .immediate_op_instruction = ImmediateOpInstruction{
                    .opcode = BinaryInstructions.immediate8_to_regmem8,
                    .mnemonic = mnemonic,
                    .s = s,
                    .w = w,
                    .mod = mod,
                    .rm = rm,
                    .disp_lo = disp_lo,
                    .disp_hi = disp_hi,
                    .data_lo = null,
                    .data_hi = null,
                    .data_8 = data_8,
                    .signed_data_8 = null,
                    .data_sx = null,
                },
            };
        },
        .immediate16_to_regmem16 => {
            return DecodePayload{
                .immediate_op_instruction = ImmediateOpInstruction{
                    .opcode = BinaryInstructions.immediate16_to_regmem16,
                    .mnemonic = mnemonic,
                    .s = s,
                    .w = w,
                    .mod = mod,
                    .rm = rm,
                    .disp_lo = disp_lo,
                    .disp_hi = disp_hi,
                    .data_lo = data_lo,
                    .data_hi = if (s == SValue.no_sign and w == WValue.word) data_hi else null,
                    .data_8 = null,
                    .signed_data_8 = null,
                    .data_sx = null,
                },
            };
        },
        .s_immediate8_to_regmem8 => {
            return DecodePayload{
                .immediate_op_instruction = ImmediateOpInstruction{
                    .opcode = BinaryInstructions.s_immediate8_to_regmem8,
                    .mnemonic = mnemonic,
                    .s = s,
                    .w = w,
                    .mod = mod,
                    .rm = rm,
                    .disp_lo = disp_lo,
                    .disp_hi = disp_hi,
                    .data_lo = null,
                    .data_hi = null,
                    .data_8 = null,
                    .signed_data_8 = signed_data_8,
                    .data_sx = null,
                },
            };
        },
        .immediate8_to_regmem16 => {
            return DecodePayload{
                .immediate_op_instruction = ImmediateOpInstruction{
                    .opcode = BinaryInstructions.immediate8_to_regmem16,
                    .mnemonic = mnemonic,
                    .s = s,
                    .w = w,
                    .mod = mod,
                    .rm = rm,
                    .disp_lo = disp_lo,
                    .disp_hi = disp_hi,
                    .data_lo = null,
                    .data_hi = null,
                    .data_8 = null,
                    .signed_data_8 = null,
                    .data_sx = data_sx,
                },
            };
        },
        else => {
            log.debug("Instruction not yet implemented.", .{});
            return InstructionDecodeError.NotYetImplemented;
        },
    }
}

/// Matching binary values against instruction- and register enum's. Returns a DecodePayload union
/// with instruction specific decoded conten.
fn decodeMovWithMod(
    mod: ModValue,
    rm: RmValue,
    input: [6]u8,
) DecodePayload {
    const log = std.log.scoped(.decodeMovWithMod);
    const mnemonic = "mov";
    const _rm = rm;
    const _mod = mod;

    const instruction: BinaryInstructions = @enumFromInt(input[0]);

    switch (instruction) {
        .mov_seg_regmem,
        .mov_regmem_seg,
        => {
            switch (_mod) {
                ModValue.memoryModeNoDisplacement => {
                    const temp_w = input[0] << 7;
                    const w: u1 = @intCast(temp_w >> 7);

                    var temp_sr = input[1] << 3;
                    temp_sr = temp_sr >> 6;
                    const sr: u2 = @intCast(temp_sr);

                    const result = DecodePayload{
                        .mov_with_mod_instruction = MovWithModInstruction{
                            .opcode = instruction,
                            .mnemonic = mnemonic,
                            .d = null,
                            .w = @enumFromInt(w),
                            .mod = _mod,
                            .reg = null,
                            .sr = @enumFromInt(sr),
                            .rm = _rm,
                            .disp_lo = if (_rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) input[2] else null,
                            .disp_hi = if (_rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) input[3] else null,
                            .data = if (_rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) input[4] else input[2],
                            .w_data = if (_rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16 and w == @intFromEnum(WValue.word)) input[5] else if (w == @intFromEnum(WValue.word)) input[3] else null,
                        },
                    };
                    return result;
                },
                ModValue.memoryMode8BitDisplacement => {
                    const temp_w = input[0] << 7;
                    const w: u1 = @intCast(temp_w >> 7);

                    var temp_sr = input[1] << 3;
                    temp_sr = temp_sr >> 6;
                    const sr: u2 = @intCast(temp_sr);

                    const result = DecodePayload{
                        .mov_with_mod_instruction = MovWithModInstruction{
                            .opcode = instruction,
                            .mnemonic = mnemonic,
                            .d = null,
                            .w = @enumFromInt(w),
                            .mod = _mod,
                            .reg = null,
                            .sr = @enumFromInt(sr),
                            .rm = _rm,
                            .disp_lo = input[2],
                            .disp_hi = null,
                            .data = input[3],
                            .w_data = if (w == @intFromEnum(WValue.word)) input[4] else null,
                        },
                    };
                    return result;
                },
                ModValue.memoryMode16BitDisplacement => {
                    const temp_w = input[0] << 7;
                    const w: u1 = @intCast(temp_w >> 7);

                    var temp_sr = input[1] << 3;
                    temp_sr = temp_sr >> 6;
                    const sr: u2 = @intCast(temp_sr);

                    const result = DecodePayload{
                        .mov_with_mod_instruction = MovWithModInstruction{
                            .opcode = instruction,
                            .mnemonic = mnemonic,
                            .d = null,
                            .w = @enumFromInt(w),
                            .mod = _mod,
                            .reg = null,
                            .sr = @enumFromInt(sr),
                            .rm = _rm,
                            .disp_lo = input[2],
                            .disp_hi = input[3],
                            .data = input[4],
                            .w_data = if (w == @intFromEnum(WValue.word)) input[5] else null,
                        },
                    };
                    return result;
                },
                ModValue.registerModeNoDisplacement => {
                    const temp_w = input[0] << 7;
                    const w: u1 = @intCast(temp_w >> 7);

                    var temp_sr = input[1] << 3;
                    temp_sr = temp_sr >> 6;
                    const sr: u2 = @intCast(temp_sr);

                    const result = DecodePayload{
                        .mov_with_mod_instruction = MovWithModInstruction{
                            .opcode = instruction,
                            .mnemonic = mnemonic,
                            .d = null,
                            .w = @enumFromInt(w),
                            .mod = _mod,
                            .reg = null,
                            .sr = @enumFromInt(sr),
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
        },
        .mov_source_regmem8_reg8,
        .mov_source_regmem16_reg16,
        .mov_dest_reg8_regmem8,
        .mov_dest_reg16_regmem16,
        => {
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
                                .opcode = instruction,
                                .mnemonic = mnemonic,
                                .d = @enumFromInt(d),
                                .w = @enumFromInt(w),
                                .mod = _mod,
                                .reg = @enumFromInt(reg),
                                .sr = null,
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
                                .opcode = instruction,
                                .mnemonic = mnemonic,
                                .d = @enumFromInt(d),
                                .w = @enumFromInt(w),
                                .mod = _mod,
                                .reg = @enumFromInt(reg),
                                .sr = null,
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
                            .opcode = instruction,
                            .mnemonic = mnemonic,
                            .d = @enumFromInt(d),
                            .w = @enumFromInt(w),
                            .mod = _mod,
                            .reg = @enumFromInt(reg),
                            .sr = null,
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
                            .opcode = instruction,
                            .mnemonic = mnemonic,
                            .d = @enumFromInt(d),
                            .w = @enumFromInt(w),
                            .mod = _mod,
                            .reg = @enumFromInt(reg),
                            .sr = null,
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
                            .opcode = instruction,
                            .mnemonic = mnemonic,
                            .d = @enumFromInt(d),
                            .w = @enumFromInt(w),
                            .mod = _mod,
                            .reg = @enumFromInt(reg),
                            .sr = null,
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
        },
        .mov_immediate_to_regmem8,
        .mov_immediate_to_regmem16,
        => {
            const w: WValue = @enumFromInt((input[0] << 7) >> 7);
            switch (mod) {
                .memoryModeNoDisplacement => {
                    const result = DecodePayload{
                        .mov_with_mod_instruction = MovWithModInstruction{
                            .opcode = instruction,
                            .mnemonic = "mov",
                            .d = null,
                            .w = w,
                            .mod = mod,
                            .reg = null,
                            .sr = null,
                            .rm = rm,
                            .disp_lo = if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) input[2] else null,
                            .disp_hi = if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) input[3] else null,
                            .data = if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) input[4] else input[2],
                            .w_data = if (w == WValue.word) input[5] else null,
                        },
                    };
                    return result;
                },
                .memoryMode8BitDisplacement => {
                    const result = DecodePayload{
                        .mov_with_mod_instruction = MovWithModInstruction{
                            .opcode = instruction,
                            .mnemonic = "mov",
                            .d = null,
                            .w = w,
                            .mod = mod,
                            .reg = null,
                            .sr = null,
                            .rm = rm,
                            .disp_lo = input[2],
                            .disp_hi = null,
                            .data = input[3],
                            .w_data = if (w == WValue.word) input[4] else null,
                        },
                    };
                    return result;
                },
                .memoryMode16BitDisplacement => {
                    const result = DecodePayload{
                        .mov_with_mod_instruction = MovWithModInstruction{
                            .opcode = instruction,
                            .mnemonic = "mov",
                            .d = null,
                            .w = w,
                            .mod = mod,
                            .reg = null,
                            .sr = null,
                            .rm = rm,
                            .disp_lo = input[2],
                            .disp_hi = input[3],
                            .data = input[4],
                            .w_data = if (w == WValue.word) input[5] else null,
                        },
                    };
                    return result;
                },
                .registerModeNoDisplacement => {
                    const result = DecodePayload{
                        .mov_with_mod_instruction = MovWithModInstruction{
                            .opcode = instruction,
                            .mnemonic = "mov",
                            .d = null,
                            .w = w,
                            .mod = mod,
                            .reg = null,
                            .sr = null,
                            .rm = rm,
                            .disp_lo = null,
                            .disp_hi = null,
                            .data = input[2],
                            .w_data = if (w == WValue.word) input[3] else null,
                        },
                    };
                    return result;
                },
            }
        },
        else => {
            const result = DecodePayload{
                .err = InstructionDecodeError.NotYetImplemented,
            };
            log.err("Error: Decode mov with mod field not possible. Instruction not yet implemented.", .{});
            return result;
        },
    }
}

/// Matchin binary values against instruction- and register enum's. Returns a DecodePayload union
/// with instruction specific decoded content.
fn decodeMovWithoutMod(
    w: WValue,
    input: [6]u8,
) DecodePayload {
    const log = std.log.scoped(.decodeMovWithoutMod);

    const temp_reg: u8 = input[0] << 5;
    const reg: RegValue = @enumFromInt(temp_reg >> 5);

    const instruction: BinaryInstructions = @enumFromInt(input[0]);

    switch (instruction) {
        .mov_immediate_reg_al,
        .mov_immediate_reg_cl,
        .mov_immediate_reg_dl,
        .mov_immediate_reg_bl,
        .mov_immediate_reg_ah,
        .mov_immediate_reg_ch,
        .mov_immediate_reg_dh,
        .mov_immediate_reg_bh,
        .mov_immediate_reg_ax,
        .mov_immediate_reg_cx,
        .mov_immediate_reg_dx,
        .mov_immediate_reg_bx,
        .mov_immediate_reg_sp,
        .mov_immediate_reg_bp,
        .mov_immediate_reg_si,
        .mov_immediate_reg_di,
        => {
            switch (w) {
                .byte => {
                    const result = DecodePayload{
                        .mov_without_mod_instruction = MovWithoutModInstruction{
                            .opcode = instruction,
                            .mnemonic = "mov",
                            .w = w,
                            .reg = reg,
                            .data = input[1],
                            .w_data = null,
                            .addr_lo = null,
                            .addr_hi = null,
                        },
                    };
                    return result;
                },
                .word => {
                    const result = DecodePayload{
                        .mov_without_mod_instruction = MovWithoutModInstruction{
                            .opcode = instruction,
                            .mnemonic = "mov",
                            .w = w,
                            .reg = reg,
                            .data = input[1],
                            .w_data = input[2],
                            .addr_lo = null,
                            .addr_hi = null,
                        },
                    };
                    return result;
                },
            }
        },
        .mov_mem8_acc8,
        .mov_mem16_acc16,
        .mov_acc8_mem8,
        .mov_acc16_mem16,
        => {
            const result = DecodePayload{
                .mov_without_mod_instruction = MovWithoutModInstruction{
                    .opcode = instruction,
                    .mnemonic = "mov",
                    .w = w,
                    .reg = null,
                    .data = null,
                    .w_data = null,
                    .addr_lo = input[1],
                    .addr_hi = input[2],
                },
            };
            return result;
        },
        else => {
            const result = DecodePayload{
                .err = InstructionDecodeError.NotYetImplemented,
            };
            log.err("Error: Decode mov without mod field not possible. Instruction not yet implemented.", .{});
            return result;
        },
    }
}

/// Identifiers of the Internal Communication Registers as well as
/// the General Registers of the Intel 8086 CPU plus an identifier for
/// a direct address following the instruction as a 16 bit displacement.
const RegisterDirectory = struct {
    const RegisterName = enum { cs, ds, es, ss, ip, ah, al, ax, bh, bl, bx, ch, cl, cx, dh, dl, dx, sp, bp, di, si, directaccess, none };
    pub fn addressFrom(reg: RegValue, w: ?WValue) RegisterName {
        const w_value = w orelse WValue.byte;
        switch (reg) {
            .ALAX => {
                if (w_value == WValue.word) return RegisterName.ax else return RegisterName.al;
            },
            .BLBX => {
                if (w_value == WValue.word) return RegisterName.bx else return RegisterName.bl;
            },
            .CLCX => {
                if (w_value == WValue.word) return RegisterName.cx else return RegisterName.cl;
            },
            .DLDX => {
                if (w_value == WValue.word) return RegisterName.dx else return RegisterName.dl;
            },
            .AHSP => {
                if (w_value == WValue.word) return RegisterName.sp else return RegisterName.ah;
            },
            .BHDI => {
                if (w_value == WValue.word) return RegisterName.di else return RegisterName.bh;
            },
            .CHBP => {
                if (w_value == WValue.word) return RegisterName.bp else return RegisterName.ch;
            },
            .DHSI => {
                if (w_value == WValue.word) return RegisterName.si else return RegisterName.dh;
            },
        }
    }
};
const DisplacementFormat = enum { d8, d16, none };

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

    /// Read 8 or 16 bit of memory starting at the 16 bit memory address
    /// passed as a parameter.
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

// TODO: Insert Doc string
/// Placeholder
fn executeInstruction(
    instruction_payload: DecodePayload,
    // register_ptr: *Register,
    // memory_ptr: *Memory,
) InstructionExecutionError!void {
    const log = std.log.scoped(.executeInstruction);
    switch (instruction_payload) {
        .err => {},
        .add_instruction => {
            log.info("Not doing anything here for a while.", .{});
        },
        .immediate_op_instruction => {
            log.info("Not doing anything here for a while.", .{});
        },
        .mov_with_mod_instruction => {
            switch (instruction_payload.mov_with_mod_instruction.opcode) {
                .mov_source_regmem8_reg8 => {
                    // const instruction = instruction_payload.mov_with_mod_instruction;
                    // switch (instruction.mod) {
                    //     .memoryModeNoDisplacement => {
                    //         if (instruction.rm != RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) {} else {}
                    //     },
                    // }
                },
                .mov_source_regmem16_reg16 => {},
                .mov_dest_reg8_regmem8 => {},
                .mov_dest_reg16_regmem16 => {},
                else => {
                    log.debug("Instruction not yet implemented", .{});
                },
            }
        },
        .mov_without_mod_instruction => {
            switch (instruction_payload.mov_without_mod_instruction.opcode) {
                .mov_immediate_reg_al => {},
                .mov_immediate_reg_cl => {},
                .mov_immediate_reg_dl => {},
                .mov_immediate_reg_bl => {},
                else => {
                    log.debug("Instruction not yet implemented", .{});
                },
            }
        },
    }
}

pub const std_options: std.Options = .{
    .log_level = LogLevel,
    .logFn = projectLog,
};

pub fn projectLog(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const scope_prefix = "(" ++ switch (scope) {
        .x86sim,
        .decodeMovWithMod,
        .decodeMovWithoutMod,
        .makeAssembly,
        .runAssemblyTest,
        .compareFiles,
        std.log.default_log_scope,
        => @tagName(scope),
        .printer => "Print: ",
        else => if (@intFromEnum(level) <= @intFromEnum(std.log.Level.err)) @tagName(scope) else return,
    } ++ "): ";

    const prefix = "[" ++ comptime level.asText() ++ "]" ++ scope_prefix;

    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    const stderr = std.fs.File.stderr().deprecatedWriter();
    nosuspend stderr.print(prefix ++ format ++ "\n", args) catch return;
}

pub fn main() !void {
    const print = std.log.scoped(.printer);

    print.debug("Printer test...", .{});

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

    try std.fs.Dir.makePath(std.fs.cwd(), "./zig-out/test");

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

    // TODO: Initialize cpu clock

    ////////////////////////////////////////////////////////////////////////////
    // Simulation //
    ////////////////////////////////////////////////////////////////////////////

    log.info("\n+++x86+Simulator++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++", .{});
    log.info("Simulating target: {s}", .{input_file_path});

    var activeByte: u16 = 0;

    var stepSize: u3 = 2;
    var InstructionBytes: [6]u8 = undefined;
    const file_contents = try input_binary_file.readToEndAlloc(heap_allocator, maxFileSizeBytes);

    // TODO: Define Segments in memory

    // TODO: Copy instruction file to memory

    // TODO: set segment registers

    // TODO: set flags

    log.debug("Instruction byte count: {d}", .{file_contents.len});
    log.info("+++Start+active+byte+{d}++++++++++++++++++++++++++++++++++++++++++++++++++++++++++", .{activeByte});

    log.info("bits 16\n", .{});
    try OutputWriter.writeAll("bits 16\n\n");

    var depleted: bool = false;

    while (!depleted and activeByte < file_contents.len) : (activeByte += stepSize) {

        ////////////////////////////////////////////////////////////////////////
        // Instruction decoding //
        ////////////////////////////////////////////////////////////////////////

        const queue_size = 6;
        var queue_index: u3 = 0;
        log.debug("---BIU-Instruction-Queue-----------------------------------------------------", .{});
        while (queue_index < queue_size) : (queue_index += 1) {
            biu.setIndex(queue_index, if (activeByte + queue_index < file_contents.len) file_contents[activeByte + queue_index] else u8_init_value);
            if (activeByte + queue_index > file_contents.len - 1) break;
            log.debug("{d}: {b:0>8}, active byte {d}, instruction 0x{x:0>2}", .{
                queue_index,
                file_contents[activeByte + queue_index],
                activeByte + queue_index,
                file_contents[activeByte + queue_index],
            });
            if (queue_index + 1 == 6) break;
        }

        const instruction_binary: u8 = biu.getIndex(0);
        const instruction_name: BinaryInstructions = @enumFromInt(instruction_binary);
        log.debug("Read instruction: 0x{x:0>2}, {t}", .{ instruction_binary, instruction_name });
        const instruction: BinaryInstructions = @enumFromInt(instruction_binary);

        var s: SValue = undefined;
        var w: WValue = undefined;
        var mod: ModValue = undefined;
        var rm: RmValue = undefined;
        switch (instruction) {
            BinaryInstructions.add_reg8_source_regmem8_dest,
            BinaryInstructions.add_reg16_source_regmem16_dest,
            BinaryInstructions.add_regmem8_source_reg8_dest,
            BinaryInstructions.add_regmem16_source_reg16_dest,
            => {
                // 0x00, 0x01, 0x02, 0x03
                mod = @enumFromInt(biu.getIndex(1) >> 6);
                rm = @enumFromInt((biu.getIndex(1) << 5) >> 5);

                stepSize = addGetInstructionLength(instruction_name, mod, rm);
            },
            BinaryInstructions.add_immediate_8_bit_to_acc,
            BinaryInstructions.add_immediate_16_bit_to_acc,
            => {
                log.err("Instruction '{t}' not yet implemented.", .{instruction});
            },
            BinaryInstructions.immediate8_to_regmem8,
            BinaryInstructions.immediate16_to_regmem16,
            BinaryInstructions.s_immediate8_to_regmem8,
            BinaryInstructions.immediate8_to_regmem16,
            => {
                // 0x80, 0x81, 0x82, 0x83
                mod = @enumFromInt(biu.getIndex(1) >> 6);
                rm = @enumFromInt((biu.getIndex(1) << 5) >> 5);

                stepSize = immediateOpGetInstructionLength(instruction_name, mod, rm);
            },
            BinaryInstructions.mov_source_regmem8_reg8,
            BinaryInstructions.mov_source_regmem16_reg16,
            BinaryInstructions.mov_dest_reg8_regmem8,
            BinaryInstructions.mov_dest_reg16_regmem16,
            => {
                // 0x88, 0x89, 0x8A, 0x8B
                w = @enumFromInt((biu.getIndex(0) << 7) >> 7);
                mod = @enumFromInt(biu.getIndex(1) >> 6);
                rm = @enumFromInt((biu.getIndex(1) << 5) >> 5);

                stepSize = movGetInstructionLength(instruction_name, w, mod, rm);
            },
            BinaryInstructions.mov_seg_regmem,
            BinaryInstructions.mov_regmem_seg,
            => {
                // 0x8c, 0x8e
                mod = @enumFromInt(biu.getIndex(1) >> 6);
                rm = @enumFromInt((biu.getIndex(1) << 5) >> 5);

                stepSize = movGetInstructionLength(instruction_name, w, mod, rm);
            },
            BinaryInstructions.mov_mem8_acc8,
            BinaryInstructions.mov_mem16_acc16,
            BinaryInstructions.mov_acc8_mem8,
            BinaryInstructions.mov_acc16_mem16,
            => {
                // 0xA0, 0xA1, 0xA2, 0xA3
                w = @enumFromInt((biu.getIndex(0) << 7) >> 7);
                stepSize = movGetInstructionLength(instruction_name, w, null, null);
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
                w = @enumFromInt((biu.getIndex(0) << 4) >> 7);
                stepSize = if (w == WValue.word) 3 else 2;
            },
            BinaryInstructions.mov_immediate_to_regmem8,
            BinaryInstructions.mov_immediate_to_regmem16,
            => {
                // 0xC6, 0xC7
                const second_byte = biu.getIndex(1);
                w = @enumFromInt((biu.getIndex(0) << 7) >> 7);
                mod = @enumFromInt(second_byte >> 6);
                rm = @enumFromInt((second_byte << 5) >> 5);
                stepSize = movGetInstructionLength(instruction_name, w, mod, rm);
            },
            // else => {
            //     log.debug("This instruction is not yet implemented. Skipping...", .{});
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

        log.debug("InstructionBytes(length: {d}):", .{stepSize});
        var steps: u3 = 1;
        var instruction_step_number = activeByte;
        for (InstructionBytes) |instruction_byte| {
            if (steps == 1) {
                log.debug("{b:0>8}, active byte {d}, instruction 0x{x:0>2}", .{
                    instruction_byte,
                    activeByte,
                    instruction_byte,
                });
            } else if (steps <= stepSize) {
                log.debug("{b:0>8}, active byte {d}, instruction 0x{x:0>2}", .{
                    instruction_byte,
                    instruction_step_number,
                    instruction_byte,
                });
            } else {
                log.debug("{b:0>8}, empty byte", .{instruction_byte});
            }
            instruction_step_number += 1;
            steps += 1;
        }

        var payload: DecodePayload = undefined;
        switch (instruction) {
            .add_reg8_source_regmem8_dest,
            .add_reg16_source_regmem16_dest,
            .add_regmem8_source_reg8_dest,
            .add_regmem16_source_reg16_dest,
            .add_immediate_8_bit_to_acc,
            .add_immediate_16_bit_to_acc,
            => {
                payload = decoder.decodeAdd(mod, rm, InstructionBytes) catch |err| {
                    log.err("{s}: DecodePayload could not be receivied. Continueing...", .{@errorName(err)});
                    continue;
                };
            },
            .immediate8_to_regmem8,
            .immediate16_to_regmem16,
            .s_immediate8_to_regmem8,
            .immediate8_to_regmem16,
            => {
                s = @enumFromInt(((biu.getIndex(0) >> 1) << 7) >> 7);
                w = @enumFromInt((biu.getIndex(0) << 7) >> 7);

                payload = decodeImmediateOp(s, w, InstructionBytes) catch |err| {
                    log.err("{s}: DecodePayload could not be received. Continuing...", .{@errorName(err)});
                    continue;
                };
            },
            .mov_source_regmem8_reg8,
            .mov_source_regmem16_reg16,
            .mov_dest_reg8_regmem8,
            .mov_dest_reg16_regmem16,
            .mov_immediate_to_regmem8,
            .mov_immediate_to_regmem16,
            .mov_seg_regmem,
            .mov_regmem_seg,
            => {
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
            .mov_acc8_mem8,
            .mov_acc16_mem16,
            .mov_mem8_acc8,
            .mov_mem16_acc16,
            => {
                payload = decodeMovWithoutMod(w, InstructionBytes);
            },
            // else => {
            //     log.debug("Instruction not yet implemented. Skipping...", .{});
            // },
        }

        ////////////////////////////////////////////////////////////////////////
        // Instruction execution //
        ////////////////////////////////////////////////////////////////////////

        executeInstruction(
            payload,
            // &registers,
            // &memory,
        ) catch |err| {
            switch (err) {
                InstructionExecutionError.InvalidInstruction => {
                    log.err("{s}: Instruction 0x{x:0>2} could not be executed.\ncontinue...", .{
                        @errorName(payload.err),
                        InstructionBytes[0],
                    });
                },
            }
        };

        ////////////////////////////////////////////////////////////////////////
        // Testing //
        ////////////////////////////////////////////////////////////////////////

        disassemble(
            &registers,
            OutputWriter,
            // InstructionBytes,
            payload,
        ) catch |err| {
            switch (err) {
                InstructionDecodeError.DecodeError => {
                    log.err("{s}: Instruction 0x{x:0>2} could not be decoded.\ncontinue...", .{
                        @errorName(payload.err),
                        InstructionBytes[0],
                    });
                },
                InstructionDecodeError.InstructionError => {
                    log.err("{s}: Instruction 0x{x:0>2} could not be decoded.\ncontinue...", .{
                        @errorName(payload.err),
                        InstructionBytes[0],
                    });
                },
                InstructionDecodeError.NotYetImplemented => {
                    log.err("{s}: 0x{x:0>2} ({s}) not implemented yet.\ncontinue...", .{
                        @errorName(payload.err),
                        InstructionBytes[0],
                        @tagName(instruction),
                    });
                },
                InstructionDecodeError.WriteFailed => {
                    log.err("{s}: Failed to write instruction 0x{x:0>2} ({s}) to .asm file.\ncontinue...", .{
                        @errorName(payload.err),
                        InstructionBytes[0],
                        @tagName(instruction),
                    });
                },
            }
        };

        try OutputWriter.flush();

        if (activeByte + stepSize >= maxFileSizeBytes or activeByte + stepSize >= file_contents.len) {
            depleted = true;
            log.info("+++Simulation+finished++++++++++++++++++++++++++++++++++++++++++++++++++++++++++", .{});
        } else {
            if (activeByte + stepSize > 999) {
                log.debug("+++Next+active+byte+{d}++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n", .{activeByte + stepSize});
            } else if (activeByte + stepSize > 99) {
                log.debug("+++Next+active+byte+{d}+++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n", .{activeByte + stepSize});
            } else if (activeByte + stepSize > 9) {
                log.debug("+++Next+active+byte+{d}++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n", .{activeByte + stepSize});
            } else {
                log.debug("+++Next+active+byte+{d}+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n", .{activeByte + stepSize});
            }
        }
    }

    try runAssemblyTest(args_allocator, input_file_path, output_asm_file_path);
}

fn printEffectiveAddressCalculationDest(
    OutputWriter: *std.io.Writer,
    address_calculation: EffectiveAddressCalculation,
) void {
    const log = std.log.scoped(.printEffectiveAddressCalculationDest);
    const Address = RegisterDirectory.RegisterName;
    if (address_calculation.index == Address.none) {
        if (address_calculation.displacement == DisplacementFormat.none) {
            log.info("[{t}], ", .{
                address_calculation.base.?,
            });
            OutputWriter.print("[{t}], ", .{
                address_calculation.base.?,
            }) catch |err| {
                log.err(
                    "{s}: Something went wrong trying to write destination effective address calculation {any} to the output file.",
                    .{ @errorName(err), address_calculation },
                );
            };
        } else if (address_calculation.displacement != DisplacementFormat.none and address_calculation.displacement_value.? == 0) {
            log.info("[{t}], ", .{
                address_calculation.base.?,
            });
            OutputWriter.print("[{t}], ", .{
                address_calculation.base.?,
            }) catch |err| {
                log.err(
                    "{s}: Something went wrong trying to write destination effective address calculation {any} to the output file.",
                    .{ @errorName(err), .address_calculation },
                );
            };
        } else if (address_calculation.displacement != DisplacementFormat.none) {
            const disp_u16: u16 = @intCast(address_calculation.displacement_value.?);
            const disp_signed: i16 = if (address_calculation.displacement == DisplacementFormat.d8) blk: {
                const u8val: u8 = @intCast(disp_u16 & 0xFF);
                const s8: i8 = @bitCast(u8val);
                break :blk @as(i16, s8);
            } else blk: {
                const s16: i16 = @bitCast(disp_u16);
                break :blk s16;
            };
            if (disp_signed < 0) {
                log.info("[{t} - {d}], ", .{
                    address_calculation.base.?,
                    -disp_signed,
                });
                OutputWriter.print("[{t} - {d}], ", .{
                    address_calculation.base.?,
                    -disp_signed,
                }) catch |err| {
                    log.err(
                        "{s}: Something went wrong trying to write destination effective address calculation {any} to the output file.",
                        .{ @errorName(err), address_calculation },
                    );
                };
            } else {
                log.info("[{t} + {d}], ", .{
                    address_calculation.base.?,
                    disp_signed,
                });
                OutputWriter.print("[{t} + {d}], ", .{
                    address_calculation.base.?,
                    disp_signed,
                }) catch |err| {
                    log.err(
                        "{s}: Something went wrong trying to write destination effective address calculation {any} to the output file.",
                        .{ @errorName(err), address_calculation },
                    );
                };
            }
        }
    } else if (address_calculation.index != Address.none) {
        if (address_calculation.displacement == DisplacementFormat.none) {
            log.info("[{t} + {t}], ", .{
                address_calculation.base.?,
                address_calculation.index.?,
            });
            OutputWriter.print("[{t} + {t}], ", .{
                address_calculation.base.?,
                address_calculation.index.?,
            }) catch |err| {
                log.err(
                    "{s}: Something went wrong trying to write destination effective address calculation {any} to the output file.",
                    .{ @errorName(err), address_calculation },
                );
            };
        } else if (address_calculation.displacement != DisplacementFormat.none) {
            const disp_u16: u16 = @intCast(address_calculation.displacement_value.?);
            const disp_signed: i16 = if (address_calculation.displacement == DisplacementFormat.d8) blk: {
                const u8val: u8 = @intCast(disp_u16 & 0xFF);
                const s8: i8 = @bitCast(u8val);
                break :blk @as(i16, s8);
            } else blk: {
                const s16: i16 = @bitCast(disp_u16);
                break :blk s16;
            };
            if (disp_signed < 0) {
                log.info("[{t} + {t} - {d}], ", .{
                    address_calculation.base.?,
                    address_calculation.index.?,
                    -disp_signed,
                });
                OutputWriter.print("[{t} + {t} - {d}], ", .{
                    address_calculation.base.?,
                    address_calculation.index.?,
                    -disp_signed,
                }) catch |err| {
                    log.err(
                        "{s}: Something went wrong trying to write destination effective address calculation {any} to the output file.",
                        .{ @errorName(err), address_calculation },
                    );
                };
            } else {
                log.info("[{t} + {t} + {d}], ", .{
                    address_calculation.base.?,
                    address_calculation.index.?,
                    disp_signed,
                });
                OutputWriter.print("[{t} + {t} + {d}], ", .{
                    address_calculation.base.?,
                    address_calculation.index.?,
                    disp_signed,
                }) catch |err| {
                    log.err(
                        "{s}: Something went wrong trying to write destination effective address calculation {any} to the output file.",
                        .{ @errorName(err), address_calculation },
                    );
                };
            }
        }
    }
}

fn printEffectiveAddressCalculationSource(
    OutputWriter: *std.io.Writer,
    address_calculation: EffectiveAddressCalculation,
) void {
    const log = std.log.scoped(.printEffectiveAddressCalculationSource);
    const Address = RegisterDirectory.RegisterName;
    if (address_calculation.index == Address.none) {
        if (address_calculation.displacement == DisplacementFormat.none) {
            log.info("[{t}]", .{
                address_calculation.base.?,
            });
            OutputWriter.print("[{t}]\n", .{
                address_calculation.base.?,
            }) catch |err| {
                log.err(
                    "{s}: Something went wrong trying to write source effective address calculation {any} to the output file.",
                    .{ @errorName(err), address_calculation },
                );
            };
        } else if (address_calculation.displacement != DisplacementFormat.none and address_calculation.displacement_value.? == 0) {
            log.info("[{t}]", .{
                address_calculation.base.?,
            });
            OutputWriter.print("[{t}]\n", .{
                address_calculation.base.?,
            }) catch |err| {
                log.err(
                    "{s}: Something went wrong trying to write source effective address calculation {any} to the output file.",
                    .{ @errorName(err), address_calculation },
                );
            };
        } else if (address_calculation.displacement != DisplacementFormat.none) {
            const disp_u16: u16 = @intCast(address_calculation.displacement_value.?);
            const disp_signed: i16 = if (address_calculation.displacement == DisplacementFormat.d8) blk: {
                const u8val: u8 = @intCast(disp_u16 & 0xFF);
                const s8: i8 = @bitCast(u8val);
                break :blk @as(i16, s8);
            } else blk: {
                const s16: i16 = @bitCast(disp_u16);
                break :blk s16;
            };
            if (disp_signed < 0) {
                log.info("[{t} - {d}]", .{
                    address_calculation.base.?,
                    -disp_signed,
                });
                OutputWriter.print("[{t} - {d}]\n", .{
                    address_calculation.base.?,
                    -disp_signed,
                }) catch |err| {
                    log.err(
                        "{s}: Something went wrong trying to write source effective address calculation {any} to the output file.",
                        .{ @errorName(err), address_calculation },
                    );
                };
            } else if (disp_signed == 0) {
                log.info("[{t}]", .{
                    address_calculation.base.?,
                });
                OutputWriter.print("[{t}]\n", .{
                    address_calculation.base.?,
                }) catch |err| {
                    log.err(
                        "{s}: Something went wrong trying to write source effective address calculation {any} to the output file.",
                        .{ @errorName(err), address_calculation },
                    );
                };
            } else {
                log.info("[{t} + {d}]", .{
                    address_calculation.base.?,
                    disp_signed,
                });
                OutputWriter.print("[{t} + {d}]\n", .{
                    address_calculation.base.?,
                    disp_signed,
                }) catch |err| {
                    log.err(
                        "{s}: Something went wrong trying to write source effective address calculation {any} to the output file.",
                        .{ @errorName(err), address_calculation },
                    );
                };
            }
        }
    } else if (address_calculation.index != Address.none) {
        if (address_calculation.displacement == DisplacementFormat.none) {
            log.info("[{t} + {t}]", .{
                address_calculation.base.?,
                address_calculation.index.?,
            });
            OutputWriter.print("[{t} + {t}]\n", .{
                address_calculation.base.?,
                address_calculation.index.?,
            }) catch |err| {
                log.err(
                    "{s}: Something went wrong trying to write source effective address calculation {any} to the output file.",
                    .{ @errorName(err), address_calculation },
                );
            };
        } else if (address_calculation.displacement != DisplacementFormat.none) {
            const disp_u16: u16 = @intCast(address_calculation.displacement_value.?);
            const disp_signed: i16 = if (address_calculation.displacement == DisplacementFormat.d8) blk: {
                const u8val: u8 = @intCast(disp_u16 & 0xFF);
                const s8: i8 = @bitCast(u8val);
                break :blk @as(i16, s8);
            } else blk: {
                const s16: i16 = @bitCast(disp_u16);
                break :blk s16;
            };
            if (disp_signed < 0) {
                log.info("[{t} + {t} - {d}]", .{
                    address_calculation.base.?,
                    address_calculation.index.?,
                    -disp_signed,
                });
                OutputWriter.print("[{t} + {t} - {d}]\n", .{
                    address_calculation.base.?,
                    address_calculation.index.?,
                    -disp_signed,
                }) catch |err| {
                    log.err(
                        "{s}: Something went wrong trying to write source effective address calculation {any} to the output file.",
                        .{ @errorName(err), address_calculation },
                    );
                };
            } else {
                log.info("[{t} + {t} + {d}]", .{
                    address_calculation.base.?,
                    address_calculation.index.?,
                    disp_signed,
                });
                OutputWriter.print("[{t} + {t} + {d}]\n", .{
                    address_calculation.base.?,
                    address_calculation.index.?,
                    disp_signed,
                }) catch |err| {
                    log.err(
                        "{s}: Something went wrong trying to write source effective address calculation {any} to the output file.",
                        .{ @errorName(err), address_calculation },
                    );
                };
            }
        }
    }
}

/// Writes decoded asm-86 instructions to a test file.
fn disassemble(
    registers: *Register,
    OutputWriter: *std.io.Writer,
    // InstructionBytes: [6]u8,
    payload: DecodePayload,
) InstructionDecodeError!void {
    const log = std.log.scoped(.disassemble);

    switch (payload) {
        .err => {
            return payload.err;
        },
        .add_instruction => {
            log.info("{s} ", .{payload.add_instruction.mnemonic});
            OutputWriter.print("{s} ", .{payload.add_instruction.mnemonic}) catch |err| {
                return err;
            };

            var instruction_info: InstructionInfo = undefined;

            // TODO: in case of add_immediate_8/16_to_acc there is no d, reg, mod, rm or displacement
            switch (payload.add_instruction.opcode) {
                .add_reg8_source_regmem8_dest,
                .add_reg16_source_regmem16_dest,
                .add_regmem8_source_reg8_dest,
                .add_regmem16_source_reg16_dest,
                => {
                    instruction_info = getRegMemToFromRegSourceAndDest(
                        registers,
                        payload.add_instruction.d.?,
                        payload.add_instruction.w,
                        payload.add_instruction.reg.?,
                        payload.add_instruction.mod.?,
                        payload.add_instruction.rm.?,
                        payload.add_instruction.disp_lo,
                        payload.add_instruction.disp_hi,
                    );
                },
                .add_immediate_8_bit_to_acc,
                .add_immediate_16_bit_to_acc,
                => {
                    instruction_info = getAddImmediateToAccumulatorDest(
                        // registers,
                        payload.add_instruction.w,
                        payload.add_instruction.data.?,
                        payload.add_instruction.w_data,
                    );
                },
                else => {
                    log.err("Opening add_instruction payload, but no valid add opcode inside.", .{});
                },
            }

            const destination: DestinationInfo = instruction_info.destination_info;
            var destinationIsEffectiveAddressCalculation: bool = undefined;
            switch (destination) {
                .address => {
                    destinationIsEffectiveAddressCalculation = false;
                    log.info("{t}, ", .{destination.address});
                    OutputWriter.print(
                        "{t}, ",
                        .{destination.address},
                    ) catch |err| {
                        log.err(
                            "{s}: Something went wrong trying to write destination {t} the output file.",
                            .{ @errorName(err), destination.address },
                        );
                    };
                },
                .address_calculation => {
                    destinationIsEffectiveAddressCalculation = true;
                    printEffectiveAddressCalculationDest(OutputWriter, destination.address_calculation);
                },
                .mem_addr => {
                    destinationIsEffectiveAddressCalculation = false;
                    log.info("[{d}],", .{destination.mem_addr});
                    OutputWriter.print("[{d}], ", .{
                        destination.mem_addr,
                    }) catch |err| {
                        log.err(
                            "{s}: Something went wrong trying to write to memory address [{d}] to the output file.",
                            .{ @errorName(err), destination.mem_addr },
                        );
                    };
                },
            }

            const source: SourceInfo = instruction_info.source_info;
            switch (source) {
                .address => {
                    log.info("{t}", .{source.address});
                    OutputWriter.print(
                        "{t}\n",
                        .{source.address},
                    ) catch |err| {
                        log.err(
                            "{s}: Something went wrong trying to write source {any} to the output file.",
                            .{ @errorName(err), source.address },
                        );
                    };
                },
                .address_calculation => {
                    printEffectiveAddressCalculationSource(OutputWriter, source.address_calculation);
                },
                .immediate => {
                    log.err("ERROR: Immediate value source for add not yet implemented", .{});
                },
                .mem_addr => {
                    log.info("[{d}]", .{source.mem_addr});
                    OutputWriter.print(
                        "[{d}]\n",
                        .{source.mem_addr},
                    ) catch |err| {
                        log.err(
                            "{s}: Something went wrong trying to write source index {any} to the output file.",
                            .{ @errorName(err), source.mem_addr },
                        );
                    };
                },
            }
        },
        .immediate_op_instruction => {
            log.info("{s} ", .{payload.immediate_op_instruction.mnemonic});
            OutputWriter.print("{s} ", .{payload.immediate_op_instruction.mnemonic}) catch |err| {
                return err;
            };

            const instruction_info: InstructionInfo = getImmediateOpSourceAndDest(registers, payload);
            const destination: DestinationInfo = instruction_info.destination_info;
            switch (destination) {
                .address => {
                    log.info("{t},", .{destination.address});
                    OutputWriter.print("{t}, ", .{destination.address}) catch |err| {
                        return err;
                    };
                },
                .address_calculation => {
                    printEffectiveAddressCalculationDest(OutputWriter, destination.address_calculation);
                },
                .mem_addr => {
                    log.info("[{d}],", .{destination.mem_addr});
                    OutputWriter.print("[{d}], ", .{destination.mem_addr}) catch |err| {
                        return err;
                    };
                },
            }
            const source: SourceInfo = instruction_info.source_info;
            // const instruction: BinaryInstructions = @enumFromInt(InstructionBytes[0]);
            switch (source) {
                .address => {
                    log.info("{t}", .{destination.address});
                    OutputWriter.print("{t}\n", .{destination.address}) catch |err| {
                        return err;
                    };
                },
                .address_calculation => {
                    printEffectiveAddressCalculationSource(OutputWriter, source.address_calculation);
                },
                .immediate => {
                    log.info("{d}", .{source.immediate});
                    OutputWriter.print("{d}\n", .{source.immediate}) catch |err| {
                        return err;
                    };
                },
                .mem_addr => {
                    log.info("[{d}]", .{source.mem_addr});
                    OutputWriter.print("[{d}]\n", .{source.mem_addr}) catch |err| {
                        return err;
                    };
                },
            }
        },
        .mov_with_mod_instruction => {
            log.info("{s} ", .{payload.mov_with_mod_instruction.mnemonic});
            OutputWriter.print("{s} ", .{payload.mov_with_mod_instruction.mnemonic}) catch |err| {
                return err;
            };

            const mod = payload.mov_with_mod_instruction.mod;
            const rm = payload.mov_with_mod_instruction.rm;
            const instruction: BinaryInstructions = payload.mov_with_mod_instruction.opcode;
            var instruction_info: InstructionInfo = undefined;
            switch (instruction) {
                .mov_source_regmem8_reg8,
                .mov_source_regmem16_reg16,
                .mov_dest_reg8_regmem8,
                .mov_dest_reg16_regmem16,
                => {
                    const d: DValue = payload.mov_with_mod_instruction.d.?;
                    const reg: RegValue = payload.mov_with_mod_instruction.reg.?;
                    instruction_info = getRegMemToFromRegSourceAndDest(
                        registers,
                        d,
                        payload.mov_with_mod_instruction.w.?,
                        reg,
                        mod,
                        rm,
                        // if (mod == ModValue.memoryMode8BitDisplacement or mod == ModValue.memoryMode16BitDisplacement or (mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16)) InstructionBytes[2] else null,
                        if (mod == ModValue.memoryMode8BitDisplacement or mod == ModValue.memoryMode16BitDisplacement or (mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16)) payload.mov_with_mod_instruction.disp_lo.? else null,
                        // if (mod == ModValue.memoryMode16BitDisplacement or (mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16)) InstructionBytes[3] else null,
                        if (mod == ModValue.memoryMode16BitDisplacement or (mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16)) payload.mov_with_mod_instruction.disp_hi.? else null,
                    );
                },
                .mov_seg_regmem => {
                    const sr: SrValue = payload.mov_with_mod_instruction.sr.?;
                    instruction_info = getSegToRegMemMovSourceAndDest(
                        registers,
                        mod,
                        sr,
                        rm,
                        if (mod == ModValue.memoryMode8BitDisplacement or mod == ModValue.memoryMode16BitDisplacement or (mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16)) payload.mov_with_mod_instruction.disp_lo.? else null,
                        if (mod == ModValue.memoryMode16BitDisplacement or (mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16)) payload.mov_with_mod_instruction.disp_hi.? else null,
                    );
                },
                .mov_regmem_seg => {
                    const sr: SrValue = payload.mov_with_mod_instruction.sr.?;
                    instruction_info = getRegMemToSegMovSourceAndDest(
                        registers,
                        mod,
                        sr,
                        rm,
                        if (mod == ModValue.memoryMode8BitDisplacement or mod == ModValue.memoryMode16BitDisplacement or (mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16)) payload.mov_with_mod_instruction.disp_lo.? else null,
                        if (mod == ModValue.memoryMode16BitDisplacement or (mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16)) payload.mov_with_mod_instruction.disp_hi.? else null,
                    );
                },
                .mov_immediate_to_regmem8,
                .mov_immediate_to_regmem16,
                => {
                    const w = payload.mov_with_mod_instruction.w.?;
                    instruction_info = getImmediateToRegMemMovDest(
                        registers,
                        mod,
                        rm,
                        w,
                        if ((mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) or mod == ModValue.memoryMode8BitDisplacement or mod == ModValue.memoryMode16BitDisplacement) payload.mov_with_mod_instruction.disp_lo.? else null,
                        if ((mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) or mod == ModValue.memoryMode16BitDisplacement) payload.mov_with_mod_instruction.disp_hi.? else null,
                        payload.mov_with_mod_instruction.data.?,
                        if (w == WValue.word) payload.mov_with_mod_instruction.w_data.? else null,
                    );
                },
                else => {
                    log.err("Error: Instruction 0x{x} not implemented yet", .{instruction});
                },
            }

            const destination = instruction_info.destination_info;
            switch (destination) {
                .address => {
                    log.info("{t}, ", .{destination.address});
                    OutputWriter.print(
                        "{t}, ",
                        .{destination.address},
                    ) catch |err| {
                        log.err(
                            "{s}: Something went wrong trying to write destination {t} the output file.",
                            .{ @errorName(err), destination.address },
                        );
                    };
                },
                .address_calculation => {
                    const Address = RegisterDirectory.RegisterName;
                    if (destination.address_calculation.index == Address.none) {
                        if (destination.address_calculation.displacement == DisplacementFormat.none) {
                            log.info("[{t}], ", .{
                                destination.address_calculation.base.?,
                            });
                            OutputWriter.print("[{t}], ", .{
                                destination.address_calculation.base.?,
                            }) catch |err| {
                                log.err(
                                    "{s}: Something went wrong trying to write destination effective address calculation {any} to the output file.",
                                    .{ @errorName(err), destination.address_calculation },
                                );
                            };
                        } else if (destination.address_calculation.displacement != DisplacementFormat.none and destination.address_calculation.displacement_value.? == 0) {
                            log.info("[{t}], ", .{
                                destination.address_calculation.base.?,
                            });
                            OutputWriter.print("[{t}], ", .{
                                destination.address_calculation.base.?,
                            }) catch |err| {
                                log.err(
                                    "{s}: Something went wrong trying to write destination effective address calculation {any} to the output file.",
                                    .{ @errorName(err), destination.address_calculation },
                                );
                            };
                        } else if (destination.address_calculation.displacement != DisplacementFormat.none) {
                            const disp_u16: u16 = @intCast(destination.address_calculation.displacement_value.?);
                            const disp_signed: i16 = if (destination.address_calculation.displacement == DisplacementFormat.d8) blk: {
                                const u8val: u8 = @intCast(disp_u16 & 0xFF);
                                const s8: i8 = @bitCast(u8val);
                                break :blk @as(i16, s8);
                            } else blk: {
                                const s16: i16 = @bitCast(disp_u16);
                                break :blk s16;
                            };
                            if (disp_signed < 0) {
                                log.info("[{t} - {d}], ", .{
                                    destination.address_calculation.base.?,
                                    -disp_signed,
                                });
                                OutputWriter.print("[{t} - {d}], ", .{
                                    destination.address_calculation.base.?,
                                    -disp_signed,
                                }) catch |err| {
                                    log.err(
                                        "{s}: Something went wrong trying to write destination effective address calculation {any} to the output file.",
                                        .{ @errorName(err), destination.address_calculation },
                                    );
                                };
                            } else {
                                log.info("[{t} + {d}], ", .{
                                    destination.address_calculation.base.?,
                                    disp_signed,
                                });
                                OutputWriter.print("[{t} + {d}], ", .{
                                    destination.address_calculation.base.?,
                                    disp_signed,
                                }) catch |err| {
                                    log.err(
                                        "{s}: Something went wrong trying to write destination effective address calculation {any} to the output file.",
                                        .{ @errorName(err), destination.address_calculation },
                                    );
                                };
                            }
                        }
                    } else if (destination.address_calculation.index != Address.none) {
                        if (destination.address_calculation.displacement == DisplacementFormat.none) {
                            log.info("[{t} + {t}], ", .{
                                destination.address_calculation.base.?,
                                destination.address_calculation.index.?,
                            });
                            OutputWriter.print("[{t} + {t}], ", .{
                                destination.address_calculation.base.?,
                                destination.address_calculation.index.?,
                            }) catch |err| {
                                log.err(
                                    "{s}: Something went wrong trying to write destination effective address calculation {any} to the output file.",
                                    .{ @errorName(err), destination.address_calculation },
                                );
                            };
                        } else if (destination.address_calculation.displacement != DisplacementFormat.none) {
                            const disp_u16: u16 = @intCast(destination.address_calculation.displacement_value.?);
                            const disp_signed: i16 = if (destination.address_calculation.displacement == DisplacementFormat.d8) blk: {
                                const u8val: u8 = @intCast(disp_u16 & 0xFF);
                                const s8: i8 = @bitCast(u8val);
                                break :blk @as(i16, s8);
                            } else blk: {
                                const s16: i16 = @bitCast(disp_u16);
                                break :blk s16;
                            };
                            if (disp_signed < 0) {
                                log.info("[{t} + {t} - {d}], ", .{
                                    destination.address_calculation.base.?,
                                    destination.address_calculation.index.?,
                                    -disp_signed,
                                });
                                OutputWriter.print("[{t} + {t} - {d}], ", .{
                                    destination.address_calculation.base.?,
                                    destination.address_calculation.index.?,
                                    -disp_signed,
                                }) catch |err| {
                                    log.err(
                                        "{s}: Something went wrong trying to write destination effective address calculation {any} to the output file.",
                                        .{ @errorName(err), destination.address_calculation },
                                    );
                                };
                            } else {
                                log.info("[{t} + {t} + {d}], ", .{
                                    destination.address_calculation.base.?,
                                    destination.address_calculation.index.?,
                                    disp_signed,
                                });
                                OutputWriter.print("[{t} + {t} + {d}], ", .{
                                    destination.address_calculation.base.?,
                                    destination.address_calculation.index.?,
                                    disp_signed,
                                }) catch |err| {
                                    log.err(
                                        "{s}: Something went wrong trying to write destination effective address calculation {any} to the output file.",
                                        .{ @errorName(err), destination.address_calculation },
                                    );
                                };
                            }
                        }
                    }
                },
                .mem_addr => {
                    log.info("[{d}],", .{destination.mem_addr});
                    OutputWriter.print("[{d}], ", .{
                        destination.mem_addr,
                    }) catch |err| {
                        log.err(
                            "{s}: Something went wrong trying to write to memory address [{d}] to the output file.",
                            .{ @errorName(err), destination.mem_addr },
                        );
                    };
                },
            }

            const source: SourceInfo = instruction_info.source_info;
            switch (source) {
                .address => {
                    log.info("{t}", .{source.address});
                    OutputWriter.print(
                        "{t}\n",
                        .{source.address},
                    ) catch |err| {
                        log.err(
                            "{s}: Something went wrong trying to write source {any} to the output file.",
                            .{ @errorName(err), source.address },
                        );
                    };
                },
                .address_calculation => {
                    const Address = RegisterDirectory.RegisterName;
                    if (source.address_calculation.index == Address.none) {
                        if (source.address_calculation.displacement == DisplacementFormat.none) {
                            log.info("[{t}]", .{
                                source.address_calculation.base.?,
                            });
                            OutputWriter.print("[{t}]\n", .{
                                source.address_calculation.base.?,
                            }) catch |err| {
                                log.err(
                                    "{s}: Something went wrong trying to write source effective address calculation {any} to the output file.",
                                    .{ @errorName(err), source.address_calculation },
                                );
                            };
                        } else if (source.address_calculation.displacement != DisplacementFormat.none and source.address_calculation.displacement_value.? == 0) {
                            log.info("[{t}]", .{
                                source.address_calculation.base.?,
                            });
                            OutputWriter.print("[{t}]\n", .{
                                source.address_calculation.base.?,
                            }) catch |err| {
                                log.err(
                                    "{s}: Something went wrong trying to write source effective address calculation {any} to the output file.",
                                    .{ @errorName(err), source.address_calculation },
                                );
                            };
                        } else if (source.address_calculation.displacement != DisplacementFormat.none) {
                            const disp_u16: u16 = @intCast(source.address_calculation.displacement_value.?);
                            const disp_signed: i16 = if (source.address_calculation.displacement == DisplacementFormat.d8) blk: {
                                const u8val: u8 = @intCast(disp_u16 & 0xFF);
                                const s8: i8 = @bitCast(u8val);
                                break :blk @as(i16, s8);
                            } else blk: {
                                const s16: i16 = @bitCast(disp_u16);
                                break :blk s16;
                            };
                            if (disp_signed < 0) {
                                log.info("[{t} - {d}]", .{
                                    source.address_calculation.base.?,
                                    -disp_signed,
                                });
                                OutputWriter.print("[{t} - {d}]\n", .{
                                    source.address_calculation.base.?,
                                    -disp_signed,
                                }) catch |err| {
                                    log.err(
                                        "{s}: Something went wrong trying to write source effective address calculation {any} to the output file.",
                                        .{ @errorName(err), source.address_calculation },
                                    );
                                };
                            } else {
                                log.info("[{t} + {d}]", .{
                                    source.address_calculation.base.?,
                                    disp_signed,
                                });
                                OutputWriter.print("[{t} + {d}]\n", .{
                                    source.address_calculation.base.?,
                                    disp_signed,
                                }) catch |err| {
                                    log.err(
                                        "{s}: Something went wrong trying to write source effective address calculation {any} to the output file.",
                                        .{ @errorName(err), source.address_calculation },
                                    );
                                };
                            }
                        }
                    } else if (source.address_calculation.index != Address.none) {
                        if (source.address_calculation.displacement == DisplacementFormat.none) {
                            log.info("[{t} + {t}]", .{
                                source.address_calculation.base.?,
                                source.address_calculation.index.?,
                            });
                            OutputWriter.print("[{t} + {t}]\n", .{
                                source.address_calculation.base.?,
                                source.address_calculation.index.?,
                            }) catch |err| {
                                log.err(
                                    "{s}: Something went wrong trying to write source effective address calculation {any} to the output file.",
                                    .{ @errorName(err), source.address_calculation },
                                );
                            };
                        } else if (source.address_calculation.displacement != DisplacementFormat.none) {
                            const disp_u16: u16 = @intCast(source.address_calculation.displacement_value.?);
                            const disp_signed: i16 = if (source.address_calculation.displacement == DisplacementFormat.d8) blk: {
                                const u8val: u8 = @intCast(disp_u16 & 0xFF);
                                const s8: i8 = @bitCast(u8val);
                                break :blk @as(i16, s8);
                            } else blk: {
                                const s16: i16 = @bitCast(disp_u16);
                                break :blk s16;
                            };
                            if (disp_signed < 0) {
                                log.info("[{t} + {t} - {d}]", .{
                                    source.address_calculation.base.?,
                                    source.address_calculation.index.?,
                                    -disp_signed,
                                });
                                OutputWriter.print("[{t} + {t} - {d}]\n", .{
                                    source.address_calculation.base.?,
                                    source.address_calculation.index.?,
                                    -disp_signed,
                                }) catch |err| {
                                    log.err(
                                        "{s}: Something went wrong trying to write source effective address calculation {any} to the output file.",
                                        .{ @errorName(err), source.address_calculation },
                                    );
                                };
                            } else {
                                log.info("[{t} + {t} + {d}]", .{
                                    source.address_calculation.base.?,
                                    source.address_calculation.index.?,
                                    disp_signed,
                                });
                                OutputWriter.print("[{t} + {t} + {d}]\n", .{
                                    source.address_calculation.base.?,
                                    source.address_calculation.index.?,
                                    disp_signed,
                                }) catch |err| {
                                    log.err(
                                        "{s}: Something went wrong trying to write source effective address calculation {any} to the output file.",
                                        .{ @errorName(err), source.address_calculation },
                                    );
                                };
                            }
                        }
                    }
                },
                .immediate => {
                    if (instruction == BinaryInstructions.mov_immediate_to_regmem8) {
                        log.info("byte {d}", .{source.immediate});
                        OutputWriter.print(
                            "byte {d}\n",
                            .{source.immediate},
                        ) catch |err| {
                            log.err(
                                "{s}: Something went wrong trying to write source index {any} to the output file.",
                                .{ @errorName(err), source.immediate },
                            );
                        };
                    } else if (instruction == BinaryInstructions.mov_immediate_to_regmem16) {
                        log.info("word {d}", .{source.immediate});
                        OutputWriter.print(
                            "word {d}\n",
                            .{source.immediate},
                        ) catch |err| {
                            log.err(
                                "{s}: Something went wrong trying to write source index {any} to the output file.",
                                .{ @errorName(err), source.immediate },
                            );
                        };
                    } else {
                        log.info("{d}", .{source.immediate});
                        OutputWriter.print(
                            "{d}\n",
                            .{source.immediate},
                        ) catch |err| {
                            log.err(
                                "{s}: Something went wrong trying to write source index {any} to the output file.",
                                .{ @errorName(err), source.immediate },
                            );
                        };
                    }
                },
                .mem_addr => {
                    log.info("[{d}]", .{source.mem_addr});
                    OutputWriter.print(
                        "[{d}]\n",
                        .{source.mem_addr},
                    ) catch |err| {
                        log.err(
                            "{s}: Something went wrong trying to write source index {any} to the output file.",
                            .{ @errorName(err), source.mem_addr },
                        );
                    };
                },
            }
        },
        .mov_without_mod_instruction => {
            log.info("{s} ", .{payload.mov_without_mod_instruction.mnemonic});
            OutputWriter.print("{s} ", .{payload.mov_without_mod_instruction.mnemonic}) catch |err| {
                return err;
            };

            const instruction: BinaryInstructions = payload.mov_without_mod_instruction.opcode;
            var instruction_info: InstructionInfo = undefined;
            switch (instruction) {
                .mov_immediate_reg_al,
                .mov_immediate_reg_cl,
                .mov_immediate_reg_dl,
                .mov_immediate_reg_bl,
                .mov_immediate_reg_ah,
                .mov_immediate_reg_ch,
                .mov_immediate_reg_dh,
                .mov_immediate_reg_bh,
                .mov_immediate_reg_ax,
                .mov_immediate_reg_cx,
                .mov_immediate_reg_dx,
                .mov_immediate_reg_bx,
                .mov_immediate_reg_bp,
                .mov_immediate_reg_sp,
                .mov_immediate_reg_si,
                .mov_immediate_reg_di,
                => {
                    instruction_info = getImmediateToRegMovDest(
                        payload.mov_without_mod_instruction.w,
                        payload.mov_without_mod_instruction.reg.?,
                        payload.mov_without_mod_instruction.data.?,
                        if (payload.mov_without_mod_instruction.w == WValue.word) payload.mov_without_mod_instruction.w_data.? else null,
                    );
                },
                .mov_mem8_acc8,
                .mov_mem16_acc16,
                => {
                    instruction_info = getMemToAccMovSourceAndDest(
                        payload.mov_without_mod_instruction.w,
                        payload.mov_without_mod_instruction.addr_lo,
                        payload.mov_without_mod_instruction.addr_hi,
                    );
                },
                .mov_acc8_mem8,
                .mov_acc16_mem16,
                => {
                    instruction_info = getAccToMemMovSourceAndDest(
                        payload.mov_without_mod_instruction.w,
                        payload.mov_without_mod_instruction.addr_lo,
                        payload.mov_without_mod_instruction.addr_hi,
                    );
                },
                else => {
                    log.err("Error: Instruction 0x{x} not implemented yet", .{instruction});
                },
            }

            const destination = instruction_info.destination_info;
            switch (destination) {
                .address => {
                    log.info("{t},", .{destination.address});
                    OutputWriter.print("{t}, ", .{
                        destination.address,
                    }) catch |err| {
                        log.err(
                            "{s}: Something went wrong trying to write destination register {t} to the output file.",
                            .{ @errorName(err), destination.address },
                        );
                    };
                },
                .mem_addr => {
                    log.info("[{d}],", .{destination.mem_addr});
                    OutputWriter.print("[{d}], ", .{
                        destination.mem_addr,
                    }) catch |err| {
                        log.err(
                            "{s}: Something went wrong trying to write to memory address [{d}] to the output file.",
                            .{ @errorName(err), destination.mem_addr },
                        );
                    };
                },
                else => {
                    log.err("Error: Not a valid destination address.", .{});
                },
            }

            const source = instruction_info.source_info;
            switch (source) {
                .address => {
                    log.info("{t}", .{source.address});
                    OutputWriter.print("{t}\n", .{
                        source.address,
                    }) catch |err| {
                        log.err(
                            "{s}: Something went wrong trying to write destination register {t} to the output file.",
                            .{ @errorName(err), source.address },
                        );
                    };
                },
                .mem_addr => {
                    log.info("[{d}],", .{source.mem_addr});
                    OutputWriter.print("[{d}]\n", .{
                        source.mem_addr,
                    }) catch |err| {
                        log.err(
                            "{s}: Something went wrong trying to write to memory address [{d}] to the output file.",
                            .{ @errorName(err), source.mem_addr },
                        );
                    };
                },
                .immediate => {
                    const immediate_value: u16 = source.immediate;
                    const signed_immediate: i16 = @bitCast(immediate_value);
                    log.info("{d}", .{signed_immediate});
                    OutputWriter.print("{d}\n", .{signed_immediate}) catch |err| {
                        log.err(
                            "{s}: Something went wrong trying to write immediate value {any} to the output file.",
                            .{ @errorName(err), signed_immediate },
                        );
                    };
                },
                else => {
                    log.err("Error: Not a valid destination address.", .{});
                },
            }
        },
    }
}

fn runAssemblyTest(
    allocator: std.mem.Allocator,
    path_to_binary_input: []const u8,
    asm_file_path: []const u8,
) !void {
    const log = std.log.scoped(.runAssemblyTest);

    log.info("\n+++Testing+Phase++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++", .{});
    log.info("Assembler generates .asm file and compares it with the original binary input...", .{});

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
                    log.info("Assembly successfull.", .{});
                } else {
                    log.err("Assembly failed with exit code: {d}\nError: {s}", .{ code, stderr_msg });
                    return;
                }
            },
            else => {
                log.err("Assembly process terminated unexpectedly\nError: {s}", .{stderr_msg});
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
        log.info("SUCCESS: The generated assembly matches the original binary!", .{});
    } else {
        log.info("FAILURE: The generated assembly does NOT match the original binary.", .{});
    }

    log.info("+++Testing+Complete+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n", .{});
}

fn compareFiles(
    allocator: std.mem.Allocator,
    path_to_binary_input: []const u8,
    assembled_binary_path: []const u8,
) !bool {
    const log = std.log.scoped(.compareFiles);
    const input = std.fs.cwd().openFile(path_to_binary_input, .{}) catch |err| {
        log.err("Error opening input {s}: {s}", .{ path_to_binary_input, @errorName(err) });
        return false;
    };
    defer input.close();

    const output = std.fs.cwd().openFile(assembled_binary_path, .{}) catch |err| {
        log.err("Error opening output {s}: {s}\n", .{ assembled_binary_path, @errorName(err) });
        return false;
    };
    defer output.close();

    const input_size = try input.getEndPos();
    const output_size = try output.getEndPos();

    if (input_size != output_size) {
        log.info("File sizes differ: input size {d} vs output size {d} bytes.", .{ input_size, output_size });
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

test decodeImmediateOp {
    const expectEqual = std.testing.expectEqual;

    // 0x83 - immediate8_to_regmem16, mod: 0b10, ADD: 000, rm: 0b010
    // add word [bp + si + 4], 29
    const input_0x83_immediate8_to_regmem16: [6]u8 = [_]u8{
        0b1000_0011,
        0b1000_0010,
        0b0000_0100,
        0b0011_1101,
        0b0000_1100,
        0b0000_0000,
    };
    const output_payload_0x83_immediate8_to_regmem16 = DecodePayload{
        .immediate_op_instruction = ImmediateOpInstruction{
            .opcode = BinaryInstructions.immediate8_to_regmem16,
            .mnemonic = "add",
            .s = SValue.sign_extend,
            .w = WValue.word,
            .mod = ModValue.memoryMode16BitDisplacement,
            .rm = RmValue.DLDX_BPSI_BPSID8_BPSID16,
            .disp_lo = input_0x83_immediate8_to_regmem16[2],
            .disp_hi = input_0x83_immediate8_to_regmem16[3],
            .data_lo = null,
            .data_hi = null,
            .data_8 = null,
            .signed_data_8 = null,
            .data_sx = @intCast(input_0x83_immediate8_to_regmem16[4]),
        },
    };
    try expectEqual(
        decodeImmediateOp(
            SValue.sign_extend,
            WValue.word,
            input_0x83_immediate8_to_regmem16,
        ),
        output_payload_0x83_immediate8_to_regmem16,
    );

    // 0x80 - immediate8_to_regmem8, mod: 0b10, reg: 0b000, rm: 0b010
    // add byte [bp + si + 4], 29
    const input_0x80_immediate8_to_regmem8: [6]u8 = [_]u8{
        0b1000_0000,
        0b1000_0010,
        0b0000_0100,
        0b0011_1101,
        0b1100_1000,
        0b0000_0000,
    };
    const output_payload_0x80_immediate8_to_regmem8 = DecodePayload{
        .immediate_op_instruction = ImmediateOpInstruction{
            .opcode = BinaryInstructions.immediate8_to_regmem8,
            .mnemonic = "add",
            .s = SValue.no_sign,
            .w = WValue.byte,
            .mod = ModValue.memoryMode16BitDisplacement,
            .rm = RmValue.DLDX_BPSI_BPSID8_BPSID16,
            .disp_lo = input_0x80_immediate8_to_regmem8[2],
            .disp_hi = input_0x80_immediate8_to_regmem8[3],
            .data_lo = null,
            .data_hi = null,
            .data_8 = input_0x80_immediate8_to_regmem8[4],
            .signed_data_8 = null,
            .data_sx = null,
        },
    };
    try expectEqual(
        decodeImmediateOp(
            SValue.no_sign,
            WValue.byte,
            input_0x80_immediate8_to_regmem8,
        ),
        output_payload_0x80_immediate8_to_regmem8,
    );

    const input_0x81_immediate16_to_regmem16_memory_mode_no_displacement: [6]u8 = [_]u8{
        0b1000_0001, // S = 0, W = 1
        0b0000_0011, // mod = 00, ADD, rm = 011
        0b1010_1000,
        0b1111_1101,
        0b0000_0000,
        0b0000_0000,
    };
    const output_payload_0x81_immediate16_to_regmem16_memory_mode_no_displacement = DecodePayload{
        .immediate_op_instruction = ImmediateOpInstruction{
            .opcode = BinaryInstructions.immediate16_to_regmem16,
            .mnemonic = "add",
            .s = SValue.no_sign,
            .w = WValue.word,
            .mod = ModValue.memoryModeNoDisplacement,
            .rm = RmValue.BLBX_BPDI_BPDID8_BPDID16,
            .disp_lo = null,
            .disp_hi = null,
            .data_lo = input_0x81_immediate16_to_regmem16_memory_mode_no_displacement[2],
            .data_hi = input_0x81_immediate16_to_regmem16_memory_mode_no_displacement[3],
            .data_8 = null,
            .signed_data_8 = null,
            .data_sx = null,
        },
    };
    try expectEqual(
        decodeImmediateOp(
            SValue.no_sign,
            WValue.word,
            input_0x81_immediate16_to_regmem16_memory_mode_no_displacement,
        ),
        output_payload_0x81_immediate16_to_regmem16_memory_mode_no_displacement,
    );

    const input_0x81_immediate16_to_regmem16: [6]u8 = [_]u8{
        0b1000_0001, // S = 0, W = 1
        0b1000_0010, // mod = 10, ADD, rm = 010
        0b0000_0100,
        0b0010_1011,
        0b0000_0001,
        0b0000_0000,
    };
    const output_payload_0x81_immediate16_to_regmem16 = DecodePayload{
        .immediate_op_instruction = ImmediateOpInstruction{
            .opcode = BinaryInstructions.immediate16_to_regmem16,
            .mnemonic = "add",
            .s = SValue.no_sign,
            .w = WValue.word,
            .mod = ModValue.memoryMode16BitDisplacement,
            .rm = RmValue.DLDX_BPSI_BPSID8_BPSID16,
            .disp_lo = input_0x81_immediate16_to_regmem16[2],
            .disp_hi = input_0x81_immediate16_to_regmem16[3],
            .data_lo = input_0x81_immediate16_to_regmem16[4],
            .data_hi = null,
            .data_8 = null,
            .signed_data_8 = null,
            .data_sx = null,
        },
    };
    try expectEqual(
        decodeImmediateOp(
            SValue.no_sign,
            WValue.word,
            input_0x81_immediate16_to_regmem16,
        ),
        output_payload_0x81_immediate16_to_regmem16,
    );
}

test decodeMovWithMod {
    const expectEqual = std.testing.expectEqual;

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
            .opcode = BinaryInstructions.mov_source_regmem16_reg16,
            .mnemonic = "mov",
            .d = DValue.source,
            .w = WValue.word,
            .mod = ModValue.registerModeNoDisplacement,
            .reg = RegValue.BLBX,
            .sr = null,
            .rm = RmValue.CLCX_BXDI_BXDID8_BXDID16,
            .disp_lo = null,
            .disp_hi = null,
            .data = null,
            .w_data = null,
        },
    };
    try expectEqual(
        decodeMovWithMod(
            ModValue.registerModeNoDisplacement,
            RmValue.CLCX_BXDI_BXDID8_BXDID16,
            test_input_0x89_mod_register_mode_no_displacement,
        ).mov_with_mod_instruction,
        test_output_payload_0x89_mod_register_mode_no_displacement.mov_with_mod_instruction,
    );

    // listing_0038_many_register_mov
    // 0x88, 0x89

    // 0x88, Mod: 0b11, R/M: 0b010
    const input_0x88_register_mode_no_displacement: [6]u8 = [_]u8{
        0b1000_1000,
        0b1110_1010,
        0b0000_0000,
        0b0000_0000,
        0b0000_0000,
        0b0000_0000,
    };
    const output_payload_0x88_register_mode_no_displacement = DecodePayload{
        .mov_with_mod_instruction = MovWithModInstruction{
            .opcode = BinaryInstructions.mov_source_regmem8_reg8,
            .mnemonic = "mov",
            .d = DValue.source,
            .w = WValue.byte,
            .mod = ModValue.registerModeNoDisplacement,
            .reg = RegValue.CHBP,
            .sr = null,
            .rm = RmValue.DLDX_BPSI_BPSID8_BPSID16,
            .disp_lo = null,
            .disp_hi = null,
            .data = null,
            .w_data = null,
        },
    };
    try expectEqual(
        decodeMovWithMod(
            ModValue.registerModeNoDisplacement,
            RmValue.DLDX_BPSI_BPSID8_BPSID16,
            input_0x88_register_mode_no_displacement,
        ),
        output_payload_0x88_register_mode_no_displacement,
    );

    // 0x88, Mod: 0b00, R/M: 0b110
    const input_0x88_memory_mode_with_displacement: [6]u8 = [_]u8{
        0b1000_1000,
        0b0001_1110,
        0b0101_0101,
        0b1010_1010,
        0b0000_0000,
        0b0000_0000,
    };
    const output_payload_0x88_memory_mode_with_displacement = DecodePayload{
        .mov_with_mod_instruction = MovWithModInstruction{
            .opcode = BinaryInstructions.mov_source_regmem8_reg8,
            .mnemonic = "mov",
            .d = DValue.source,
            .w = WValue.byte,
            .mod = ModValue.memoryModeNoDisplacement,
            .reg = RegValue.BLBX,
            .sr = null,
            .rm = RmValue.DHSI_DIRECTACCESS_BPD8_BPD16,
            .disp_lo = input_0x88_memory_mode_with_displacement[2],
            .disp_hi = input_0x88_memory_mode_with_displacement[3],
            .data = null,
            .w_data = null,
        },
    };
    try expectEqual(
        decodeMovWithMod(
            ModValue.memoryModeNoDisplacement,
            RmValue.DHSI_DIRECTACCESS_BPD8_BPD16,
            input_0x88_memory_mode_with_displacement,
        ),
        output_payload_0x88_memory_mode_with_displacement,
    );

    // 0x89, Mod: 0b00, R/M: 0b100
    const input_0x89_memory_mode_no_displacement: [6]u8 = [_]u8{
        0b1000_1001,
        0b0010_1100,
        0b0000_0000,
        0b0000_0000,
        0b0000_0000,
        0b0000_0000,
    };
    const output_payload_0x89_memory_mode_no_displacement = DecodePayload{
        .mov_with_mod_instruction = MovWithModInstruction{
            .opcode = BinaryInstructions.mov_source_regmem16_reg16,
            .mnemonic = "mov",
            .d = DValue.source,
            .w = WValue.word,
            .mod = ModValue.memoryModeNoDisplacement,
            .reg = RegValue.CHBP,
            .sr = null,
            .rm = RmValue.AHSP_SI_SID8_SID16,
            .disp_lo = null,
            .disp_hi = null,
            .data = null,
            .w_data = null,
        },
    };
    try expectEqual(
        decodeMovWithMod(
            ModValue.memoryModeNoDisplacement,
            RmValue.AHSP_SI_SID8_SID16,
            input_0x89_memory_mode_no_displacement,
        ),
        output_payload_0x89_memory_mode_no_displacement,
    );

    // 0x89, Mod: 0b01, R/M: 0b010
    const input_0x89_memory_mode_8_bit_displacement: [6]u8 = [_]u8{
        0b1000_1001,
        0b0110_0010,
        0b0101_0101,
        0b0000_0000,
        0b0000_0000,
        0b0000_0000,
    };
    const output_payload_0x89_memory_mode_8_bit_displacement = DecodePayload{
        .mov_with_mod_instruction = MovWithModInstruction{
            .opcode = BinaryInstructions.mov_source_regmem16_reg16,
            .mnemonic = "mov",
            .d = @enumFromInt(0b0),
            .w = @enumFromInt(0b1),
            .mod = @enumFromInt(0b01),
            .reg = @enumFromInt(0b100),
            .sr = null,
            .rm = @enumFromInt(0b010),
            .disp_lo = 0b0101_0101,
            .disp_hi = null,
            .data = null,
            .w_data = null,
        },
    };
    try expectEqual(
        decodeMovWithMod(
            ModValue.memoryMode8BitDisplacement,
            RmValue.DLDX_BPSI_BPSID8_BPSID16,
            input_0x89_memory_mode_8_bit_displacement,
        ),
        output_payload_0x89_memory_mode_8_bit_displacement,
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
            .opcode = BinaryInstructions.mov_source_regmem16_reg16,
            .mnemonic = "mov",
            .d = @enumFromInt(0b0),
            .w = @enumFromInt(0b1),
            .mod = @enumFromInt(0b10),
            .reg = @enumFromInt(0b010),
            .sr = null,
            .rm = @enumFromInt(0b001),
            .disp_lo = 0b0101_0101,
            .disp_hi = 0b1010_1010,
            .data = null,
            .w_data = null,
        },
    };
    try expectEqual(
        decodeMovWithMod(
            ModValue.memoryMode16BitDisplacement,
            RmValue.CLCX_BXDI_BXDID8_BXDID16,
            test_input_0x89_mod_memory_mode_16_bit_displacement,
        ),
        test_output_payload_0x89_mod_memory_mode_16_bit_displacement,
    );

    // 0x88 - 0x8B, 0xB0 - 0xBF

    // 0x8A, mod: 0b10, rm: 0b000
    const input_0x8A_memory_mode_16_bit_displacement: [6]u8 = [_]u8{
        0b1000_1010, // mov, d=0b1, w=0b0
        0b1000_0000, // mod=0b10, reg=0b000, rm=0b000
        0b1000_0111,
        0b0001_0011,
        0b0000_0000,
        0b0000_0000,
    };
    const output_payload_0x8A_memory_mode_16_bit_displacement = DecodePayload{
        .mov_with_mod_instruction = MovWithModInstruction{
            .opcode = BinaryInstructions.mov_dest_reg8_regmem8,
            .mnemonic = "mov",
            .d = @enumFromInt(0b1),
            .w = @enumFromInt(0b0),
            .mod = @enumFromInt(0b10),
            .reg = @enumFromInt(0b000),
            .sr = null,
            .rm = @enumFromInt(0b000),
            .disp_lo = 0b1000_0111,
            .disp_hi = 0b0001_0011,
            .data = null,
            .w_data = null,
        },
    };
    try expectEqual(
        decodeMovWithMod(
            ModValue.memoryMode16BitDisplacement,
            RmValue.ALAX_BXSI_BXSID8_BXSID16,
            input_0x8A_memory_mode_16_bit_displacement,
        ),
        output_payload_0x8A_memory_mode_16_bit_displacement,
    );

    // 0x8B, mod: 0b01, rm: 0b001
    const input_0x8B_memory_mode_8_bit_displacement: [6]u8 = [_]u8{
        0b1000_1011,
        0b0111_0001,
        0b0101_0101,
        0b0000_0000,
        0b0000_0000,
        0b0000_0000,
    };
    const output_payload_0x8B_memory_mode_8_bit_displacement = DecodePayload{
        .mov_with_mod_instruction = MovWithModInstruction{
            .opcode = BinaryInstructions.mov_dest_reg16_regmem16,
            .mnemonic = "mov",
            .d = DValue.destination,
            .w = WValue.word,
            .mod = ModValue.memoryMode8BitDisplacement,
            .reg = RegValue.DHSI,
            .sr = null,
            .rm = RmValue.CLCX_BXDI_BXDID8_BXDID16,
            .disp_lo = input_0x8B_memory_mode_8_bit_displacement[2],
            .disp_hi = null,
            .data = null,
            .w_data = null,
        },
    };
    try expectEqual(
        decodeMovWithMod(
            ModValue.memoryMode8BitDisplacement,
            RmValue.CLCX_BXDI_BXDID8_BXDID16,
            input_0x8B_memory_mode_8_bit_displacement,
        ),
        output_payload_0x8B_memory_mode_8_bit_displacement,
    );

    // 0x8B, mod: 0b10, rm: 0b110
    const input_0x8B_memory_mode_16_bit_displacement: [6]u8 = [_]u8{
        0b1000_1011,
        0b1011_0110,
        0b0101_0101,
        0b1010_1010,
        0b0000_0000,
        0b0000_0000,
    };
    const output_payload_0x8B_memory_mode_16_bit_displacement = DecodePayload{
        .mov_with_mod_instruction = MovWithModInstruction{
            .opcode = BinaryInstructions.mov_dest_reg16_regmem16,
            .mnemonic = "mov",
            .d = DValue.destination,
            .w = WValue.word,
            .mod = ModValue.memoryMode16BitDisplacement,
            .reg = RegValue.DHSI,
            .sr = null,
            .rm = RmValue.DHSI_DIRECTACCESS_BPD8_BPD16,
            .disp_lo = input_0x8B_memory_mode_16_bit_displacement[2],
            .disp_hi = input_0x8B_memory_mode_16_bit_displacement[3],
            .data = null,
            .w_data = null,
        },
    };
    try expectEqual(
        decodeMovWithMod(
            ModValue.memoryMode16BitDisplacement,
            RmValue.DHSI_DIRECTACCESS_BPD8_BPD16,
            input_0x8B_memory_mode_16_bit_displacement,
        ),
        output_payload_0x8B_memory_mode_16_bit_displacement,
    );

    // 0xC6, mod: 0b00, sr: 0b00,
    const input_0xC6_memory_mode_no_displacement: [6]u8 = [_]u8{
        0b1100_0110, // 0xC6
        0b0000_0011, // 0x03
        0b0000_0111, // 0x07
        0b0000_0000,
        0b0000_0000,
        0b0000_0000,
    };
    const output_payload_0xC6_memory_mode_no_displacement = DecodePayload{
        .mov_with_mod_instruction = MovWithModInstruction{
            .opcode = BinaryInstructions.mov_immediate_to_regmem8,
            .mnemonic = "mov",
            .d = null,
            .w = WValue.byte,
            .mod = ModValue.memoryModeNoDisplacement,
            .reg = null,
            .sr = null,
            .rm = RmValue.BLBX_BPDI_BPDID8_BPDID16,
            .disp_lo = null,
            .disp_hi = null,
            .data = input_0xC6_memory_mode_no_displacement[2],
            .w_data = null,
        },
    };
    try expectEqual(
        decodeMovWithMod(
            ModValue.memoryModeNoDisplacement,
            RmValue.BLBX_BPDI_BPDID8_BPDID16,
            input_0xC6_memory_mode_no_displacement,
        ),
        output_payload_0xC6_memory_mode_no_displacement,
    );

    // 0xC7, mod: 0b10, sr: 0b10,
    const input_0xC7_memory_mode_16_bit_displacement: [6]u8 = [_]u8{
        0b1100_0111, // 0xC7
        0b1001_0100, // 0x94
        0b0100_0010, // 0x42
        0b0001_0001, // 0x11
        0b0010_1100, // 0x2C
        0b0010_0100, // 0x24
    };
    const output_payload_0xC7_memory_mode_16_bit_displacement = DecodePayload{
        .mov_with_mod_instruction = MovWithModInstruction{
            .opcode = BinaryInstructions.mov_immediate_to_regmem16,
            .mnemonic = "mov",
            .d = null,
            .w = WValue.word,
            .mod = ModValue.memoryMode16BitDisplacement,
            .reg = null,
            .sr = null,
            .rm = RmValue.AHSP_SI_SID8_SID16,
            .disp_lo = input_0xC7_memory_mode_16_bit_displacement[2],
            .disp_hi = input_0xC7_memory_mode_16_bit_displacement[3],
            .data = input_0xC7_memory_mode_16_bit_displacement[4],
            .w_data = input_0xC7_memory_mode_16_bit_displacement[5],
        },
    };
    try expectEqual(
        decodeMovWithMod(
            ModValue.memoryMode16BitDisplacement,
            RmValue.AHSP_SI_SID8_SID16,
            input_0xC7_memory_mode_16_bit_displacement,
        ),
        output_payload_0xC7_memory_mode_16_bit_displacement,
    );
}

test decodeMovWithoutMod {
    const expectEqual = std.testing.expectEqual;

    // 0xB1, w: byte
    const input_0xB1_byte: [6]u8 = [_]u8{
        0b1011_0001,
        0b1000_1000,
        0b0000_0000,
        0b0000_0000,
        0b0000_0000,
        0b0000_0000,
    };
    const output_payload_0xB1_byte = DecodePayload{
        .mov_without_mod_instruction = MovWithoutModInstruction{
            .opcode = BinaryInstructions.mov_immediate_reg_cl,
            .mnemonic = "mov",
            .w = WValue.byte,
            .reg = RegValue.CLCX,
            .data = input_0xB1_byte[1],
            .w_data = null,
            .addr_lo = null,
            .addr_hi = null,
        },
    };
    try expectEqual(
        decodeMovWithoutMod(
            WValue.byte,
            input_0xB1_byte,
        ),
        output_payload_0xB1_byte,
    );

    // 0xBB, w: word
    const input_0xBB_word: [6]u8 = [_]u8{
        0b1011_1011,
        0b0000_0000,
        0b0010_0100,
        0b0100_1000,
        0b0000_0000,
        0b0000_0000,
    };
    const output_payload_0xBB_word = DecodePayload{
        .mov_without_mod_instruction = MovWithoutModInstruction{
            .opcode = BinaryInstructions.mov_immediate_reg_bx,
            .mnemonic = "mov",
            .w = WValue.word,
            .reg = RegValue.BLBX,
            .data = input_0xBB_word[1],
            .w_data = input_0xBB_word[2],
            .addr_lo = null,
            .addr_hi = null,
        },
    };
    try expectEqual(
        decodeMovWithoutMod(
            WValue.word,
            input_0xBB_word,
        ),
        output_payload_0xBB_word,
    );

    // 0xA1, 0xA2, 0xA3, 0xA4
    const input_0xA1_memory_to_accumulator: [6]u8 = [_]u8{
        0b1010_0001, // 0xA2
        0b0101_0101, // 0x55
        0b1010_1010, // 0xAA
        0b0000_0000,
        0b0000_0000,
        0b0000_0000,
    };
    const output_payload_0xA1_memory_to_accumulator = DecodePayload{
        .mov_without_mod_instruction = MovWithoutModInstruction{
            .opcode = BinaryInstructions.mov_mem16_acc16,
            .mnemonic = "mov",
            .w = WValue.word,
            .reg = null,
            .data = null,
            .w_data = null,
            .addr_lo = input_0xA1_memory_to_accumulator[1],
            .addr_hi = input_0xA1_memory_to_accumulator[2],
        },
    };
    try expectEqual(
        decodeMovWithoutMod(
            WValue.word,
            input_0xA1_memory_to_accumulator,
        ),
        output_payload_0xA1_memory_to_accumulator,
    );
}
