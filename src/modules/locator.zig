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

const errors = @import("errors.zig");
const LocatorError = errors.LocatorError;

const types = @import("types.zig");
const MOD = types.instruction_fields.MOD;
const REG = types.instruction_fields.REG;
const SR = types.instruction_fields.SR;
const RM = types.instruction_fields.RM;
const Direction = types.instruction_fields.Direction;
const Width = types.instruction_fields.Width;
const Sign = types.instruction_fields.Sign;

const EffectiveAddressCalculation = types.data_types.EffectiveAddressCalculation;
const InstructionInfo = types.data_types.InstructionInfo;
const DestinationInfo = types.data_type.DestinationInfo;
const SourceInfo = types.data_types.SourceInfo;
const DisplacementFormat = types.data_types.DisplacementFormat;

const hw = @import("hardware.zig");
const ExecutionUnit = hw.ExecutionUnit;
const BusInterfaceUnit = hw.BusInterfaceUnit;

const decoder = @import("decoder.zig");
const BinaryInstructions = decoder.BinaryInstructions;
const InstructionData = decoder.InstructionData;

/// Identifiers of the Internal Communication execution_unit as well as
/// the General execution_unit of the Intel 8086 CPU plus an identifier for
/// a direct address following the instruction as a 16 bit displacement.
pub const RegisterNames = enum {
    cs,
    ds,
    es,
    ss,
    ip,
    ah,
    al,
    ax,
    bh,
    bl,
    bx,
    ch,
    cl,
    cx,
    dh,
    dl,
    dx,
    sp,
    bp,
    di,
    si,
    directaccess,
    none,
};

pub fn registerNameFrom(reg: REG, w: ?Width) RegisterNames {
    const width = w orelse Width.byte;
    switch (reg) {
        .ALAX => {
            if (width == Width.word) return RegisterNames.ax else return RegisterNames.al;
        },
        .BLBX => {
            if (width == Width.word) return RegisterNames.bx else return RegisterNames.bl;
        },
        .CLCX => {
            if (width == Width.word) return RegisterNames.cx else return RegisterNames.cl;
        },
        .DLDX => {
            if (width == Width.word) return RegisterNames.dx else return RegisterNames.dl;
        },
        .AHSP => {
            if (width == Width.word) return RegisterNames.sp else return RegisterNames.ah;
        },
        .BHDI => {
            if (width == Width.word) return RegisterNames.di else return RegisterNames.bh;
        },
        .CHBP => {
            if (width == Width.word) return RegisterNames.bp else return RegisterNames.ch;
        },
        .DHSI => {
            if (width == Width.word) return RegisterNames.si else return RegisterNames.dh;
        },
    }
}

// TODO: DocString

pub fn getImmediateToMemoryOpSourceAndDest(
    EU: *ExecutionUnit,
    instruction_data: InstructionData,
) LocatorError!InstructionInfo {
    // const log = std.log.scoped(.getImmediateToMemoryOpSourceAndDest);
    const Address = RegisterNames;

    const opcode: BinaryInstructions = instruction_data.immediate_to_memory_op.opcode;
    const mod: MOD = instruction_data.immediate_to_memory_op.mod;
    const rm: RM = instruction_data.immediate_to_memory_op.rm;
    const disp_lo: ?u8 = instruction_data.immediate_to_memory_op.disp_lo;
    const disp_hi: ?u8 = instruction_data.immediate_to_memory_op.disp_hi;
    const data_8: ?u8 = instruction_data.immediate_to_memory_op.data_8;
    const data_lo: ?u8 = instruction_data.immediate_to_memory_op.data_lo;
    const data_hi: ?u8 = instruction_data.immediate_to_memory_op.data_hi;

    return InstructionInfo{
        .destination_info = destination_switch: switch (mod) {
            .memoryModeNoDisplacement => if (rm == RM.DHSI_DIRECTACCESS_BPD8_BPD16) {
                break :destination_switch DestinationInfo{
                    .address_calculation = BusInterfaceUnit.calculateEffectiveAddress(EU, mod, rm, disp_lo, disp_hi),
                };
            } else {
                break :destination_switch DestinationInfo{
                    .address = switch (rm) {
                        .ALAX_BXSI_BXSID8_BXSID16 => Address.ax,
                        .CLCX_BXDI_BXDID8_BXDID16 => Address.cx,
                        .DLDX_BPSI_BPSID8_BPSID16 => Address.dx,
                        .BLBX_BPDI_BPDID8_BPDID16 => Address.bx,
                        .AHSP_SI_SID8_SID16 => Address.sp,
                        .CHBP_DI_DID8_DID16 => Address.bp,
                        .DHSI_DIRECTACCESS_BPD8_BPD16 => Address.si,
                        .BHDI_BX_BXD8_BXD16 => Address.di,
                    },
                };
            },
            .memoryMode8BitDisplacement,
            .memoryMode16BitDisplacement,
            => DestinationInfo{
                .address_calculation = BusInterfaceUnit.calculateEffectiveAddress(
                    EU,
                    mod,
                    rm,
                    disp_lo,
                    disp_hi,
                ),
            },
            .registerModeNoDisplacement => {
                break :destination_switch DestinationInfo{
                    .address = switch (rm) {
                        .ALAX_BXSI_BXSID8_BXSID16 => Address.ax,
                        .CLCX_BXDI_BXDID8_BXDID16 => Address.cx,
                        .DLDX_BPSI_BPSID8_BPSID16 => Address.dx,
                        .BLBX_BPDI_BPDID8_BPDID16 => Address.bx,
                        .AHSP_SI_SID8_SID16 => Address.sp,
                        .CHBP_DI_DID8_DID16 => Address.bp,
                        .DHSI_DIRECTACCESS_BPD8_BPD16 => Address.si,
                        .BHDI_BX_BXD8_BXD16 => Address.di,
                    },
                };
            },
        },
        .source_info = SourceInfo{ .immediate = switch (opcode) {
            BinaryInstructions.mov_mem8_immed8 => @as(u16, data_8.?),
            BinaryInstructions.mov_mem16_immed16 => (@as(u16, data_hi.?) << 8) + @as(u16, data_lo.?),
            else => return LocatorError.InvalidOpcode,
        } },
    };
}

// pub fn getIdentifierAddOppSourceAndDest() InstructionInfo {
//     // ??? is this even relevant?
//     // TODO: Figure out how to properly sign the immediate value either here or where the InstructionInfo
//     // is worked on.
//     switch (instruction) {
//         .regmem8_immed8 => {
//             immediate_8 = instruction_data.immediate_to_memory_op.data_8.?;
//             source_info = SourceInfo{
//                 .immediate = @intCast(immediate_8),
//             };
//         },
//         .regmem16_immed16 => {
//             immediate_16 = (@as(u16, instruction_data.immediate_to_memory_op.data_hi.?) << 8) + instruction_data.immediate_to_memory_op.data_lo.?;
//             source_info = SourceInfo{
//                 .immediate = immediate_16,
//             };
//         },
//         .signed_regmem8_immed8 => {
//             sign_extended_immediate = @intCast(instruction_data.immediate_to_memory_op.signed_data_8.?);
//             source_info = SourceInfo{
//                 .immediate = @bitCast(sign_extended_immediate),
//             };
//         },
//         .sign_extend_regmem16_immed8 => {
//             signed_immediate = instruction_data.immediate_to_memory_op.data_sx.?;
//             source_info = SourceInfo{
//                 .immediate = @bitCast(signed_immediate),
//             };
//         },
//         else => {
//             log.err("Not a valid opcode for this function: {t}", .{instruction});
//         },
//     }
//     return InstructionInfo{
//         .destination_info = DestinationInfo{
//             // TODO: Put destination in here
//         },
//         .source_info = SourceInfo{
//             .immediate = switch (opcode) {
//                 .regmem8_immed8 => ,
//                 .regmem16_immed16 => ,
//                 .signed_regmem8_immed8 => ,
//                 .sign_extend_regmem16_immed8 => ,
//                 else => ,
//             }
//         },
//     };
// }

pub fn getImmediateToRegDest(
    w: Width,
    reg: REG,
    data_8: ?u8,
    data_lo: ?u8,
    data_hi: ?u8,
) InstructionInfo {
    const Address = RegisterNames;
    return InstructionInfo{
        .destination_info = DestinationInfo{
            .address = switch (reg) {
                .ALAX => if (w == Width.byte) Address.al else Address.ax,
                .CLCX => if (w == Width.byte) Address.cl else Address.cx,
                .DLDX => if (w == Width.byte) Address.dl else Address.dx,
                .BLBX => if (w == Width.byte) Address.bl else Address.bx,
                .AHSP => if (w == Width.byte) Address.ah else Address.sp,
                .CHBP => if (w == Width.byte) Address.ch else Address.bp,
                .DHSI => if (w == Width.byte) Address.dh else Address.si,
                .BHDI => if (w == Width.byte) Address.bh else Address.di,
            },
        },
        .source_info = SourceInfo{
            .immediate = switch (w) {
                Width.byte => @intCast(data_8.?),
                Width.word => (@as(u16, data_hi.?) << 8) + @as(u16, data_lo.?),
            },
        },
    };
}

pub fn getImmediateToRegMovDest(w: Width, reg: REG, data: u8, w_data: ?u8) InstructionInfo {
    const Address = RegisterNames;
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

pub fn getImmediateToAccumulatorDest(
    w: Width,
    data_8: ?u8,
    data_lo: ?u8,
    data_hi: ?u8,
) InstructionInfo {
    const Address = RegisterNames;
    var dest: Address = undefined;
    var immediate_8: u8 = undefined;
    var immediate_16: u16 = undefined;
    if (w == Width.byte) {
        dest = Address.al;
        immediate_8 = data_8.?;
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
        immediate_16 = (@as(u16, data_hi.?) << 8) + @as(u16, data_lo.?);
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

pub fn registerNameFromRm(w: Width, rm: RM) RegisterNames {
    return switch (rm) {
        .ALAX_BXSI_BXSID8_BXSID16 => if (w == Width.word) RegisterNames.ax else RegisterNames.al,
        .CLCX_BXDI_BXDID8_BXDID16 => if (w == Width.word) RegisterNames.cx else RegisterNames.cl,
        .DLDX_BPSI_BPSID8_BPSID16 => if (w == Width.word) RegisterNames.dx else RegisterNames.dl,
        .BLBX_BPDI_BPDID8_BPDID16 => if (w == Width.word) RegisterNames.bx else RegisterNames.bl,
        .AHSP_SI_SID8_SID16 => if (w == Width.word) RegisterNames.sp else RegisterNames.ah,
        .CHBP_DI_DID8_DID16 => if (w == Width.word) RegisterNames.bp else RegisterNames.ch,
        .DHSI_DIRECTACCESS_BPD8_BPD16 => if (w == Width.word) RegisterNames.si else RegisterNames.dh,
        .BHDI_BX_BXD8_BXD16 => if (w == Width.word) RegisterNames.di else RegisterNames.bh,
    };
}

// Return a RegisterName value by providing WValue and RegValue.
pub fn registerNameFromReg(w: Width, reg: REG) RegisterNames {
    return switch (reg) {
        .ALAX => if (w == Width.word) RegisterNames.ax else RegisterNames.al,
        .CLCX => if (w == Width.word) RegisterNames.cx else RegisterNames.cl,
        .DLDX => if (w == Width.word) RegisterNames.dx else RegisterNames.dl,
        .BLBX => if (w == Width.word) RegisterNames.bx else RegisterNames.bl,
        .AHSP => if (w == Width.word) RegisterNames.sp else RegisterNames.ah,
        .CHBP => if (w == Width.word) RegisterNames.bp else RegisterNames.ch,
        .DHSI => if (w == Width.word) RegisterNames.si else RegisterNames.dh,
        .BHDI => if (w == Width.word) RegisterNames.di else RegisterNames.bh,
    };
}

/// Given the fields decoded from the instruction bytes this function returns
/// the addresses of source and destination. These can be execution_unit or memory
/// addresses. The values are returned as InstructionInfo.
pub fn getRegMemToFromRegSourceAndDest(
    EU: *ExecutionUnit,
    d: Direction,
    w: Width,
    reg: REG,
    mod: MOD,
    rm: RM,
    disp_lo: ?u8,
    disp_hi: ?u8,
) InstructionInfo {
    const Address = RegisterNames;

    // var dest: Address = undefined;
    // var source: Address = undefined;
    // var source_mem_addr: u20 = undefined;
    // var destination_mem_addr: u20 = undefined;
    // var dest_address_calculation: EffectiveAddressCalculation = undefined;
    // var source_address_calculation: EffectiveAddressCalculation = undefined;

    const regIsSource: bool = if (d == Direction.source) true else false;
    const instruction_info: InstructionInfo = switch (regIsSource) {
        true => InstructionInfo{
            .destination_info = switch (mod) {
                .memoryModeNoDisplacement => if (rm == RM.DHSI_DIRECTACCESS_BPD8_BPD16) DestinationInfo{
                    .mem_addr = (@as(u20, disp_hi.?) << 4) + @as(u20, disp_lo.?),
                } else DestinationInfo{
                    .address_calculation = BusInterfaceUnit.calculateEffectiveAddress(EU, mod, rm, disp_lo, disp_hi),
                },
                .memoryMode8BitDisplacement,
                .memoryMode16BitDisplacement,
                => DestinationInfo{
                    .address_calculation = BusInterfaceUnit.calculateEffectiveAddress(
                        EU,
                        mod,
                        rm,
                        disp_lo,
                        disp_hi,
                    ),
                },
                .registerModeNoDisplacement => DestinationInfo{
                    .address = registerNameFromRm(Width.word, rm),
                },
            },
            .source_info = SourceInfo{
                .address = switch (reg) {
                    REG.ALAX => if (w == Width.word) Address.ax else Address.al,
                    REG.CLCX => if (w == Width.word) Address.cx else Address.cl,
                    REG.DLDX => if (w == Width.word) Address.dx else Address.dl,
                    REG.BLBX => if (w == Width.word) Address.bx else Address.bl,
                    REG.AHSP => if (w == Width.word) Address.sp else Address.ah,
                    REG.CHBP => if (w == Width.word) Address.bp else Address.ch,
                    REG.DHSI => if (w == Width.word) Address.si else Address.dh,
                    REG.BHDI => if (w == Width.word) Address.di else Address.bh,
                },
            },
        },
        false => InstructionInfo{
            .destination_info = DestinationInfo{
                .address = registerNameFromReg(w, reg),
            },
            .source_info = switch (mod) {
                .memoryModeNoDisplacement => if (rm == RM.DHSI_DIRECTACCESS_BPD8_BPD16) SourceInfo{
                    .mem_addr = (@as(u20, disp_hi.?) << 4) + @as(u20, disp_lo.?),
                } else SourceInfo{
                    .address_calculation = BusInterfaceUnit.calculateEffectiveAddress(EU, mod, rm, disp_lo, disp_hi),
                },
                .memoryMode8BitDisplacement,
                .memoryMode16BitDisplacement,
                => SourceInfo{
                    .address_calculation = BusInterfaceUnit.calculateEffectiveAddress(
                        EU,
                        mod,
                        rm,
                        disp_lo,
                        disp_hi,
                    ),
                },
                .registerModeNoDisplacement => SourceInfo{
                    .address = registerNameFromRm(Width.word, rm),
                },
            },
        },
    };
    return instruction_info;

    // // Checking what the REG field encodes
    // switch (w) {
    //     .byte => {
    //         switch (reg) {
    //             .ALAX => {
    //                 if (regIsSource) source = Address.al else dest = Address.al;
    //             },
    //             .CLCX => {
    //                 if (regIsSource) source = Address.cl else dest = Address.cl;
    //             },
    //             .DLDX => {
    //                 if (regIsSource) source = Address.dl else dest = Address.dl;
    //             },
    //             .BLBX => {
    //                 if (regIsSource) source = Address.bl else dest = Address.bl;
    //             },
    //             .AHSP => {
    //                 if (regIsSource) source = Address.ah else dest = Address.ah;
    //             },
    //             .CHBP => {
    //                 if (regIsSource) source = Address.ch else dest = Address.ch;
    //             },
    //             .DHSI => {
    //                 if (regIsSource) source = Address.dh else dest = Address.dh;
    //             },
    //             .BHDI => {
    //                 if (regIsSource) source = Address.bh else dest = Address.bh;
    //             },
    //         }
    //     },
    //     .word => {
    //         switch (reg) {
    //             .ALAX => {
    //                 if (regIsSource) source = Address.ax else dest = Address.ax;
    //             },
    //             .CLCX => {
    //                 if (regIsSource) source = Address.cx else dest = Address.cx;
    //             },
    //             .DLDX => {
    //                 if (regIsSource) source = Address.dx else dest = Address.dx;
    //             },
    //             .BLBX => {
    //                 if (regIsSource) source = Address.bx else dest = Address.bx;
    //             },
    //             .AHSP => {
    //                 if (regIsSource) source = Address.sp else dest = Address.sp;
    //             },
    //             .CHBP => {
    //                 if (regIsSource) source = Address.bp else dest = Address.bp;
    //             },
    //             .DHSI => {
    //                 if (regIsSource) source = Address.si else dest = Address.si;
    //             },
    //             .BHDI => {
    //                 if (regIsSource) source = Address.di else dest = Address.di;
    //             },
    //         }
    //     },
    // }

    // // Checking what the R/M field encodes
    // switch (mod) {
    //     .memoryModeNoDisplacement => {
    //         switch (rm) {
    //             .ALAX_BXSI_BXSID8_BXSID16 => {
    //                 const bx_value: u16 = EU.getBX(WValue.word, null).value16;
    //                 const si_value: u16 = EU.getSI();
    //                 if (regIsSource) {
    //                     dest_address_calculation = EffectiveAddressCalculation{
    //                         .base = Address.bx,
    //                         .index = Address.si,
    //                         .displacement = DisplacementFormat.none,
    //                         .displacement_value = null,
    //                         .effective_address = (@as(u20, bx_value) << 4) + si_value,
    //                     };
    //                 } else {
    //                     source_address_calculation = EffectiveAddressCalculation{
    //                         .base = Address.bx,
    //                         .index = Address.si,
    //                         .displacement = DisplacementFormat.none,
    //                         .displacement_value = null,
    //                         .effective_address = (@as(u20, bx_value) << 4) + si_value,
    //                     };
    //                 }
    //             },
    //             .CLCX_BXDI_BXDID8_BXDID16 => {
    //                 const bx_value: u16 = EU.getBX(WValue.word, null).value16;
    //                 const di_value: u16 = EU.getDI();
    //                 if (regIsSource) {
    //                     dest_address_calculation = EffectiveAddressCalculation{
    //                         .base = Address.bx,
    //                         .index = Address.di,
    //                         .displacement = DisplacementFormat.none,
    //                         .displacement_value = null,
    //                         .effective_address = (@as(u20, bx_value) << 4) + di_value,
    //                     };
    //                 } else {
    //                     source_address_calculation = EffectiveAddressCalculation{
    //                         .base = Address.bx,
    //                         .index = Address.di,
    //                         .displacement = DisplacementFormat.none,
    //                         .displacement_value = null,
    //                         .effective_address = (@as(u20, bx_value) << 4) + di_value,
    //                     };
    //                 }
    //             },
    //             .DLDX_BPSI_BPSID8_BPSID16 => {
    //                 const bp_value = EU.getBP();
    //                 const si_value = EU.getSI();
    //                 if (regIsSource) {
    //                     dest_address_calculation = EffectiveAddressCalculation{
    //                         .base = Address.bp,
    //                         .index = Address.si,
    //                         .displacement = DisplacementFormat.none,
    //                         .displacement_value = null,
    //                         .effective_address = (@as(u20, bp_value) << 4) + si_value,
    //                     };
    //                 } else {
    //                     source_address_calculation = EffectiveAddressCalculation{
    //                         .base = Address.bp,
    //                         .index = Address.si,
    //                         .displacement = DisplacementFormat.none,
    //                         .displacement_value = null,
    //                         .effective_address = (@as(u20, bp_value) << 4) + si_value,
    //                     };
    //                 }
    //             },
    //             .BLBX_BPDI_BPDID8_BPDID16 => {
    //                 const bp_value = EU.getBP();
    //                 const di_value: u16 = EU.getDI();
    //                 if (regIsSource) {
    //                     dest_address_calculation = EffectiveAddressCalculation{
    //                         .base = Address.bp,
    //                         .index = Address.di,
    //                         .displacement = DisplacementFormat.none,
    //                         .displacement_value = null,
    //                         .effective_address = (@as(u20, bp_value) << 4) + di_value,
    //                     };
    //                 } else {
    //                     source_address_calculation = EffectiveAddressCalculation{
    //                         .base = Address.bp,
    //                         .index = Address.di,
    //                         .displacement = DisplacementFormat.none,
    //                         .displacement_value = null,
    //                         .effective_address = (@as(u20, bp_value) << 4) + di_value,
    //                     };
    //                 }
    //             },
    //             .AHSP_SI_SID8_SID16 => {
    //                 if (regIsSource) {
    //                     dest = Address.si;
    //                 } else {
    //                     source = Address.si;
    //                 }
    //             },
    //             .CHBP_DI_DID8_DID16 => {
    //                 if (regIsSource) {
    //                     dest = Address.di;
    //                 } else {
    //                     source = Address.di;
    //                 }
    //             },

    //             // TODO: What value should i pass along here? I think
    //             // it is an immediate value. Make sure!
    //             .DHSI_DIRECTACCESS_BPD8_BPD16 => {
    //                 const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
    //                 if (regIsSource) {
    //                     destination_mem_addr = displacement;
    //                 } else if (!regIsSource) {
    //                     source_mem_addr = displacement;
    //                 }
    //             },
    //             .BHDI_BX_BXD8_BXD16 => {
    //                 if (regIsSource) {
    //                     dest = Address.bx;
    //                 } else if (!regIsSource) {
    //                     source = Address.bx;
    //                 }
    //             },
    //         }
    //     },
    //     .memoryMode8BitDisplacement => {
    //         switch (rm) {
    //             .ALAX_BXSI_BXSID8_BXSID16 => {
    //                 const bx_value: u16 = EU.getBX(WValue.word, null).value16;
    //                 const effective_address_calculation: EffectiveAddressCalculation = EffectiveAddressCalculation{
    //                     .base = Address.bx,
    //                     .index = Address.si,
    //                     .displacement = DisplacementFormat.d8,
    //                     .displacement_value = @as(u16, disp_lo.?),
    //                     .effective_address = ((@as(u20, bx_value)) << 4) + EU.getSI() + disp_lo.?,
    //                 };
    //                 if (regIsSource) {
    //                     dest_address_calculation = effective_address_calculation;
    //                 } else if (!regIsSource) {
    //                     source_address_calculation = effective_address_calculation;
    //                 }
    //             },
    //             .CLCX_BXDI_BXDID8_BXDID16 => {
    //                 const bx_value: u16 = EU.getBX(WValue.word, null).value16;
    //                 const effective_address_calculation: EffectiveAddressCalculation = EffectiveAddressCalculation{
    //                     .base = Address.bx,
    //                     .index = Address.di,
    //                     .displacement = DisplacementFormat.d8,
    //                     .displacement_value = @as(u16, disp_lo.?),
    //                     .effective_address = ((@as(u20, bx_value)) << 4) + EU.getDI() + disp_lo.?,
    //                 };
    //                 if (regIsSource) {
    //                     dest_address_calculation = effective_address_calculation;
    //                 } else {
    //                     source_address_calculation = effective_address_calculation;
    //                 }
    //             },
    //             .DLDX_BPSI_BPSID8_BPSID16 => {
    //                 const bp_value: u16 = EU.getBP();
    //                 const effective_address_calculation: EffectiveAddressCalculation = EffectiveAddressCalculation{
    //                     .base = Address.bp,
    //                     .index = Address.si,
    //                     .displacement = DisplacementFormat.d8,
    //                     .displacement_value = @as(u16, disp_lo.?),
    //                     .effective_address = ((@as(u20, bp_value) << 4) + EU.getSI() + disp_lo.?),
    //                 };
    //                 if (regIsSource) {
    //                     dest_address_calculation = effective_address_calculation;
    //                 } else {
    //                     source_address_calculation = effective_address_calculation;
    //                 }
    //             },
    //             .BLBX_BPDI_BPDID8_BPDID16 => {
    //                 const bp_value: u16 = EU.getBP();
    //                 const effective_address_calculation: EffectiveAddressCalculation = EffectiveAddressCalculation{
    //                     .base = Address.bp,
    //                     .index = Address.di,
    //                     .displacement = DisplacementFormat.d8,
    //                     .displacement_value = @as(u16, disp_lo.?),
    //                     .effective_address = ((@as(u20, bp_value) << 4) + EU.getDI() + disp_lo.?),
    //                 };
    //                 if (regIsSource) {
    //                     dest_address_calculation = effective_address_calculation;
    //                 } else {
    //                     source_address_calculation = effective_address_calculation;
    //                 }
    //             },
    //             .AHSP_SI_SID8_SID16 => {
    //                 const si_value: u16 = EU.getSI();
    //                 const effective_address_calculation: EffectiveAddressCalculation = EffectiveAddressCalculation{
    //                     .base = Address.si,
    //                     .index = Address.none,
    //                     .displacement = DisplacementFormat.d8,
    //                     .displacement_value = @as(u16, disp_lo.?),
    //                     .effective_address = ((@as(u20, si_value)) << 4) + disp_lo.?,
    //                 };
    //                 if (regIsSource) {
    //                     dest_address_calculation = effective_address_calculation;
    //                 } else {
    //                     source_address_calculation = effective_address_calculation;
    //                 }
    //             },
    //             .CHBP_DI_DID8_DID16 => {
    //                 const di_value: u16 = EU.getDI();
    //                 const effective_address_calculation: EffectiveAddressCalculation = EffectiveAddressCalculation{
    //                     .base = Address.di,
    //                     .index = Address.none,
    //                     .displacement = DisplacementFormat.d8,
    //                     .displacement_value = @as(u16, disp_lo.?),
    //                     .effective_address = ((@as(u20, di_value)) << 4) + disp_lo.?,
    //                 };
    //                 if (regIsSource) {
    //                     dest_address_calculation = effective_address_calculation;
    //                 } else {
    //                     source_address_calculation = effective_address_calculation;
    //                 }
    //             },
    //             .DHSI_DIRECTACCESS_BPD8_BPD16 => {
    //                 const bp_value: u16 = EU.getBP();
    //                 const effective_address_calculation: EffectiveAddressCalculation = EffectiveAddressCalculation{
    //                     .base = Address.bp,
    //                     .index = Address.none,
    //                     .displacement = DisplacementFormat.d8,
    //                     .displacement_value = @as(u16, disp_lo.?),
    //                     .effective_address = ((@as(u20, bp_value) << 4) + disp_lo.?),
    //                 };
    //                 if (regIsSource) {
    //                     dest_address_calculation = effective_address_calculation;
    //                 } else {
    //                     source_address_calculation = effective_address_calculation;
    //                 }
    //             },
    //             .BHDI_BX_BXD8_BXD16 => {
    //                 const bx_value: u16 = EU.getBX(WValue.word, null).value16;
    //                 const effective_address_calculation: EffectiveAddressCalculation = EffectiveAddressCalculation{
    //                     .base = Address.bx,
    //                     .index = Address.none,
    //                     .displacement = DisplacementFormat.d8,
    //                     .displacement_value = @as(u16, disp_lo.?),
    //                     .effective_address = ((@as(u20, bx_value) << 4) + disp_lo.?),
    //                 };
    //                 if (regIsSource) {
    //                     dest_address_calculation = effective_address_calculation;
    //                 } else {
    //                     source_address_calculation = effective_address_calculation;
    //                 }
    //             },
    //         }
    //     },
    //     .memoryMode16BitDisplacement => {
    //         switch (rm) {
    //             .ALAX_BXSI_BXSID8_BXSID16 => {
    //                 const bx_value: u16 = EU.getBX(WValue.word, null).value16;
    //                 const si_value: u16 = EU.getSI();
    //                 const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
    //                 if (regIsSource) {
    //                     dest_address_calculation = EffectiveAddressCalculation{
    //                         .base = Address.bx,
    //                         .index = Address.si,
    //                         .displacement = DisplacementFormat.d16,
    //                         .displacement_value = displacement,
    //                         .effective_address = (@as(u20, bx_value) << 4) + si_value + displacement,
    //                     };
    //                 } else {
    //                     source_address_calculation = EffectiveAddressCalculation{
    //                         .base = Address.bx,
    //                         .index = Address.si,
    //                         .displacement = DisplacementFormat.d16,
    //                         .displacement_value = displacement,
    //                         .effective_address = (@as(u20, bx_value) << 4) + si_value + displacement,
    //                     };
    //                 }
    //             },
    //             .CLCX_BXDI_BXDID8_BXDID16 => {
    //                 const bx_value: u16 = EU.getBX(WValue.word, null).value16;
    //                 const di_value: u16 = EU.getDI();
    //                 const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
    //                 if (regIsSource) {
    //                     dest_address_calculation = EffectiveAddressCalculation{
    //                         .base = Address.bx,
    //                         .index = Address.di,
    //                         .displacement = DisplacementFormat.d16,
    //                         .displacement_value = displacement,
    //                         .effective_address = (@as(u20, bx_value) << 4) + di_value + displacement,
    //                     };
    //                 } else {
    //                     source_address_calculation = EffectiveAddressCalculation{
    //                         .base = Address.bx,
    //                         .index = Address.di,
    //                         .displacement = DisplacementFormat.d16,
    //                         .displacement_value = displacement,
    //                         .effective_address = (@as(u20, bx_value) << 4) + di_value + displacement,
    //                     };
    //                 }
    //             },
    //             .DLDX_BPSI_BPSID8_BPSID16 => {
    //                 const bp_value: u16 = EU.getBP();
    //                 const si_value: u16 = EU.getSI();
    //                 const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
    //                 if (regIsSource) {
    //                     dest_address_calculation = EffectiveAddressCalculation{
    //                         .base = Address.bp,
    //                         .index = Address.si,
    //                         .displacement = DisplacementFormat.d16,
    //                         .displacement_value = displacement,
    //                         .effective_address = (@as(u20, bp_value) << 4) + si_value + displacement,
    //                     };
    //                 } else {
    //                     source_address_calculation = EffectiveAddressCalculation{
    //                         .base = Address.bp,
    //                         .index = Address.si,
    //                         .displacement = DisplacementFormat.d16,
    //                         .displacement_value = displacement,
    //                         .effective_address = (@as(u20, bp_value) << 4) + si_value + displacement,
    //                     };
    //                 }
    //             },
    //             .BLBX_BPDI_BPDID8_BPDID16 => {
    //                 const bp_value: u16 = EU.getBP();
    //                 const di_value: u16 = EU.getDI();
    //                 const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
    //                 if (regIsSource) {
    //                     dest_address_calculation = EffectiveAddressCalculation{
    //                         .base = Address.bp,
    //                         .index = Address.di,
    //                         .displacement = DisplacementFormat.d16,
    //                         .displacement_value = displacement,
    //                         .effective_address = (@as(u20, bp_value) << 4) + di_value + displacement,
    //                     };
    //                 } else {
    //                     source_address_calculation = EffectiveAddressCalculation{
    //                         .base = Address.bp,
    //                         .index = Address.di,
    //                         .displacement = DisplacementFormat.d16,
    //                         .displacement_value = displacement,
    //                         .effective_address = (@as(u20, bp_value) << 4) + di_value + displacement,
    //                     };
    //                 }
    //             },
    //             .AHSP_SI_SID8_SID16 => {
    //                 const si_value: u16 = EU.getSI();
    //                 const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
    //                 if (regIsSource) {
    //                     dest_address_calculation = EffectiveAddressCalculation{
    //                         .base = Address.si,
    //                         .index = Address.none,
    //                         .displacement = DisplacementFormat.d16,
    //                         .displacement_value = displacement,
    //                         .effective_address = (@as(u20, si_value) << 4) + displacement,
    //                     };
    //                 } else {
    //                     source_address_calculation = EffectiveAddressCalculation{
    //                         .base = Address.si,
    //                         .index = Address.none,
    //                         .displacement = DisplacementFormat.d16,
    //                         .displacement_value = displacement,
    //                         .effective_address = (@as(u20, si_value) << 4) + displacement,
    //                     };
    //                 }
    //             },
    //             .CHBP_DI_DID8_DID16 => {
    //                 const di_value: u16 = EU.getDI();
    //                 const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
    //                 if (regIsSource) {
    //                     dest_address_calculation = EffectiveAddressCalculation{
    //                         .base = Address.di,
    //                         .index = Address.none,
    //                         .displacement = DisplacementFormat.d16,
    //                         .displacement_value = displacement,
    //                         .effective_address = (@as(u20, di_value) << 4) + displacement,
    //                     };
    //                 } else {
    //                     source_address_calculation = EffectiveAddressCalculation{
    //                         .base = Address.di,
    //                         .index = Address.none,
    //                         .displacement = DisplacementFormat.d16,
    //                         .displacement_value = displacement,
    //                         .effective_address = (@as(u20, di_value) << 4) + displacement,
    //                     };
    //                 }
    //             },
    //             .DHSI_DIRECTACCESS_BPD8_BPD16 => {
    //                 const bp_value: u16 = EU.getBP();
    //                 const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
    //                 if (regIsSource) {
    //                     dest_address_calculation = EffectiveAddressCalculation{
    //                         .base = Address.bp,
    //                         .index = Address.none,
    //                         .displacement = DisplacementFormat.d16,
    //                         .displacement_value = displacement,
    //                         .effective_address = (@as(u20, bp_value) << 4) + displacement,
    //                     };
    //                 } else {
    //                     source_address_calculation = EffectiveAddressCalculation{
    //                         .base = Address.bp,
    //                         .index = Address.none,
    //                         .displacement = DisplacementFormat.d16,
    //                         .displacement_value = displacement,
    //                         .effective_address = (@as(u20, bp_value) << 4) + displacement,
    //                     };
    //                 }
    //             },
    //             .BHDI_BX_BXD8_BXD16 => {
    //                 const bx_value: u16 = EU.getBX(WValue.word, null).value16;
    //                 const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
    //                 if (regIsSource) {
    //                     dest_address_calculation = EffectiveAddressCalculation{
    //                         .base = Address.bx,
    //                         .index = Address.none,
    //                         .displacement = DisplacementFormat.d16,
    //                         .displacement_value = displacement,
    //                         .effective_address = (@as(u20, bx_value) << 4) + displacement,
    //                     };
    //                 } else {
    //                     source_address_calculation = EffectiveAddressCalculation{
    //                         .base = Address.bx,
    //                         .index = Address.none,
    //                         .displacement = DisplacementFormat.d16,
    //                         .displacement_value = displacement,
    //                         .effective_address = (@as(u20, bx_value) << 4) + displacement,
    //                     };
    //                 }
    //             },
    //         }
    //     },
    //     .registerModeNoDisplacement => {
    //         switch (w) {
    //             .byte => {
    //                 switch (rm) {
    //                     .ALAX_BXSI_BXSID8_BXSID16 => {
    //                         if (regIsSource) dest = Address.al else source = Address.al;
    //                     },
    //                     .CLCX_BXDI_BXDID8_BXDID16 => {
    //                         if (regIsSource) dest = Address.cl else source = Address.cl;
    //                     },
    //                     .DLDX_BPSI_BPSID8_BPSID16 => {
    //                         if (regIsSource) dest = Address.dl else source = Address.dl;
    //                     },
    //                     .BLBX_BPDI_BPDID8_BPDID16 => {
    //                         if (regIsSource) dest = Address.bl else source = Address.bl;
    //                     },
    //                     .AHSP_SI_SID8_SID16 => {
    //                         if (regIsSource) dest = Address.ah else source = Address.ah;
    //                     },
    //                     .CHBP_DI_DID8_DID16 => {
    //                         if (regIsSource) dest = Address.ch else source = Address.ch;
    //                     },
    //                     .DHSI_DIRECTACCESS_BPD8_BPD16 => {
    //                         if (regIsSource) dest = Address.dh else source = Address.dh;
    //                     },
    //                     .BHDI_BX_BXD8_BXD16 => {
    //                         if (regIsSource) dest = Address.bh else source = Address.bh;
    //                     },
    //                 }
    //             },
    //             .word => {
    //                 switch (rm) {
    //                     .ALAX_BXSI_BXSID8_BXSID16 => {
    //                         if (regIsSource) dest = Address.ax else source = Address.ax;
    //                     },
    //                     .CLCX_BXDI_BXDID8_BXDID16 => {
    //                         if (regIsSource) dest = Address.cx else source = Address.cx;
    //                     },
    //                     .DLDX_BPSI_BPSID8_BPSID16 => {
    //                         if (regIsSource) dest = Address.dx else source = Address.dx;
    //                     },
    //                     .BLBX_BPDI_BPDID8_BPDID16 => {
    //                         if (regIsSource) dest = Address.bx else source = Address.bx;
    //                     },
    //                     .AHSP_SI_SID8_SID16 => {
    //                         if (regIsSource) dest = Address.sp else source = Address.sp;
    //                     },
    //                     .CHBP_DI_DID8_DID16 => {
    //                         if (regIsSource) dest = Address.bp else source = Address.bp;
    //                     },
    //                     .DHSI_DIRECTACCESS_BPD8_BPD16 => {
    //                         if (regIsSource) dest = Address.si else source = Address.si;
    //                     },
    //                     .BHDI_BX_BXD8_BXD16 => {
    //                         if (regIsSource) dest = Address.di else source = Address.di;
    //                     },
    //                 }
    //             },
    //         }
    //     },
    // }

    // var destination_payload: DestinationInfo = undefined;
    // if (mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) {
    //     destination_payload = DestinationInfo{
    //         .address = dest, // ??? Shouldn't this be .address_calculation?
    //     };
    // } else if (mod == ModValue.memoryModeNoDisplacement and rm != RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) {
    //     if (regIsSource) {
    //         switch (rm) {
    //             .ALAX_BXSI_BXSID8_BXSID16, .CLCX_BXDI_BXDID8_BXDID16, .DLDX_BPSI_BPSID8_BPSID16, .BLBX_BPDI_BPDID8_BPDID16 => {
    //                 destination_payload = DestinationInfo{
    //                     .address_calculation = dest_address_calculation,
    //                 };
    //             },
    //             .AHSP_SI_SID8_SID16, .CHBP_DI_DID8_DID16, .BHDI_BX_BXD8_BXD16 => {
    //                 destination_payload = DestinationInfo{
    //                     .address = dest,
    //                 };
    //             },
    //             else => {
    //                 std.debug.print("Error: Destination Address Calculation is messed up", .{});
    //             },
    //         }
    //     } else if (!regIsSource) {
    //         destination_payload = DestinationInfo{
    //             .address = dest,
    //         };
    //     }
    // } else if (mod == ModValue.memoryMode8BitDisplacement or mod == ModValue.memoryMode16BitDisplacement) {
    //     if (regIsSource) {
    //         destination_payload = DestinationInfo{
    //             .address_calculation = dest_address_calculation,
    //         };
    //     } else if (!regIsSource) {
    //         destination_payload = DestinationInfo{
    //             .address = dest,
    //         };
    //     }
    // } else if (mod == ModValue.registerModeNoDisplacement) {
    //     destination_payload = DestinationInfo{
    //         .address = dest,
    //     };
    // }

    // var source_payload: SourceInfo = undefined;
    // if (mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) {
    //     source_payload = SourceInfo{
    //         .mem_addr = source_mem_addr,
    //     };
    // } else if (mod == ModValue.memoryModeNoDisplacement and rm != RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) {
    //     if (regIsSource) {
    //         source_payload = SourceInfo{
    //             .address = source,
    //         };
    //     } else if (!regIsSource) {
    //         switch (rm) {
    //             .AHSP_SI_SID8_SID16, .CHBP_DI_DID8_DID16, .BHDI_BX_BXD8_BXD16 => {
    //                 source_payload = SourceInfo{
    //                     .address = source,
    //                 };
    //             },
    //             .ALAX_BXSI_BXSID8_BXSID16, .CLCX_BXDI_BXDID8_BXDID16, .DLDX_BPSI_BPSID8_BPSID16, .BLBX_BPDI_BPDID8_BPDID16 => {
    //                 source_payload = SourceInfo{
    //                     .address_calculation = source_address_calculation,
    //                 };
    //             },
    //             else => {
    //                 std.debug.print("Error: Source Address Calculation is messed up", .{});
    //             },
    //         }
    //     }
    // } else if (mod == ModValue.memoryMode8BitDisplacement or mod == ModValue.memoryMode16BitDisplacement) {
    //     if (regIsSource) {
    //         source_payload = SourceInfo{
    //             .address = source,
    //         };
    //     } else if (!regIsSource) {
    //         source_payload = SourceInfo{
    //             .address_calculation = source_address_calculation,
    //         };
    //     }
    // } else if (mod == ModValue.registerModeNoDisplacement) {
    //     source_payload = SourceInfo{
    //         .address = source,
    //     };
    // }

    // return InstructionInfo{
    //     .destination_info = destination_payload,
    //     .source_info = source_payload,
    // };
}

/// Get source and destination for Reg/Mem to segment register operations.
pub fn getRegMemToSegMovSourceAndDest(
    execution_unit: *ExecutionUnit,
    mod: MOD,
    sr: SR,
    rm: RM,
    disp_lo: ?u8,
    disp_hi: ?u8,
) InstructionInfo {
    const Address = RegisterNames;
    var dest: Address = undefined;
    var source: Address = undefined;
    var source_address_calculation: EffectiveAddressCalculation = undefined;

    var destination_payload: DestinationInfo = undefined;
    var source_payload: SourceInfo = undefined;

    switch (mod) {
        .memoryModeNoDisplacement => {
            switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    const bx_value: u16 = execution_unit.getBX(Width.word, null).value16;
                    const si_value: u16 = execution_unit.getSI();
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.si,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, bx_value) << 4) + si_value,
                    };
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    const bx_value: u16 = execution_unit.getBX(Width.word, null).value16;
                    const di_value: u16 = execution_unit.getDI();
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.di,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, bx_value) << 4) + di_value,
                    };
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    const bp_value: u16 = execution_unit.getBP();
                    const si_value: u16 = execution_unit.getSI();
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.si,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, bp_value) << 4) + si_value,
                    };
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    const bp_value: u16 = execution_unit.getBP();
                    const di_value: u16 = execution_unit.getDI();
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.di,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, bp_value) << 4) + di_value,
                    };
                },
                .AHSP_SI_SID8_SID16 => {
                    const si_value: u16 = execution_unit.getSI();
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.si,
                        .index = Address.none,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, si_value) << 4),
                    };
                },
                .CHBP_DI_DID8_DID16 => {
                    const di_value: u16 = execution_unit.getDI();
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
                    const bx_value: u16 = execution_unit.getBX(Width.word, null).value16;
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
            switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    const bx_value = execution_unit.getBX(Width.word, null).value16;
                    const si_value = execution_unit.getSI();
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
                    const bx_value = execution_unit.getBX(Width.word, null).value16;
                    const di_value = execution_unit.getDI();
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
                    const bp_value = execution_unit.getBP();
                    const si_value = execution_unit.getSI();
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
                    const bp_value = execution_unit.getBP();
                    const di_value = execution_unit.getDI();
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
                    const si_value = execution_unit.getSI();
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
                    const di_value = execution_unit.getDI();
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
                    const bp_value = execution_unit.getBP();
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
                    const bx_value = execution_unit.getBX(Width.word, null).value16;
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
            switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    const bx_value = execution_unit.getBX(Width.word, null).value16;
                    const si_value = execution_unit.getSI();
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
                    const bx_value = execution_unit.getBX(Width.word, null).value16;
                    const di_value = execution_unit.getDI();
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
                    const bp_value = execution_unit.getBP();
                    const si_value = execution_unit.getSI();
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
                    const bp_value = execution_unit.getBP();
                    const di_value = execution_unit.getDI();
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
                    const si_value = execution_unit.getSI();
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
                    const di_value = execution_unit.getDI();
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
                    const bp_value = execution_unit.getBP();
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
                    const bx_value = execution_unit.getBX(Width.word, null).value16;
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
            switch (rm) {
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

    if (mod == MOD.registerModeNoDisplacement) {
        source_payload = SourceInfo{
            .address = source,
        };
    } else {
        source_payload = SourceInfo{ .address_calculation = source_address_calculation };
    }

    switch (sr) {
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
pub fn getSegToRegMemMovSourceAndDest(
    execution_unit: *ExecutionUnit,
    mod: MOD,
    sr: SR,
    rm: RM,
    disp_lo: ?u8,
    disp_hi: ?u8,
) InstructionInfo {
    const Address = RegisterNames;
    var dest: Address = undefined;
    var source: Address = undefined;
    var dest_address_calculation: EffectiveAddressCalculation = undefined;

    var destination_payload: DestinationInfo = undefined;
    var source_payload: SourceInfo = undefined;

    switch (sr) {
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

    switch (mod) {
        .memoryModeNoDisplacement => {
            switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    const bx_value: u16 = execution_unit.getBX(Width.word, null).value16;
                    const si_value: u16 = execution_unit.getSI();
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.si,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, bx_value) << 4) + si_value,
                    };
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    const bx_value: u16 = execution_unit.getBX(Width.word, null).value16;
                    const di_value: u16 = execution_unit.getDI();
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.di,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, bx_value) << 4) + di_value,
                    };
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    const bp_value: u16 = execution_unit.getBP();
                    const si_value: u16 = execution_unit.getSI();
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.si,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, bp_value) << 4) + si_value,
                    };
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    const bp_value: u16 = execution_unit.getBP();
                    const di_value: u16 = execution_unit.getDI();
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.di,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, bp_value) << 4) + di_value,
                    };
                },
                .AHSP_SI_SID8_SID16 => {
                    const si_value: u16 = execution_unit.getSI();
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.si,
                        .index = Address.none,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, si_value) << 4),
                    };
                },
                .CHBP_DI_DID8_DID16 => {
                    const di_value: u16 = execution_unit.getDI();
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
                    const bx_value: u16 = execution_unit.getBX(Width.word, null).value16;
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
            switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    const bx_value = execution_unit.getBX(Width.word, null).value16;
                    const si_value = execution_unit.getSI();
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
                    const bx_value = execution_unit.getBX(Width.word, null).value16;
                    const di_value = execution_unit.getDI();
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
                    const bp_value = execution_unit.getBP();
                    const si_value = execution_unit.getSI();
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
                    const bp_value = execution_unit.getBP();
                    const di_value = execution_unit.getDI();
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
                    const si_value = execution_unit.getSI();
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
                    const di_value = execution_unit.getDI();
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
                    const bp_value = execution_unit.getBP();
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
                    const bx_value = execution_unit.getBX(Width.word, null).value16;
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
            switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    const bx_value = execution_unit.getBX(Width.word, null).value16;
                    const si_value = execution_unit.getSI();
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
                    const bx_value = execution_unit.getBX(Width.word, null).value16;
                    const di_value = execution_unit.getDI();
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
                    const bp_value = execution_unit.getBP();
                    const si_value = execution_unit.getSI();
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
                    const bp_value = execution_unit.getBP();
                    const di_value = execution_unit.getDI();
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
                    const si_value = execution_unit.getSI();
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
                    const di_value = execution_unit.getDI();
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
                    const bp_value = execution_unit.getBP();
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
                    const bx_value = execution_unit.getBX(Width.word, null).value16;
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
            switch (rm) {
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

    if (mod == MOD.registerModeNoDisplacement) {
        destination_payload = DestinationInfo{
            .address = dest,
        };
    } else {
        destination_payload = DestinationInfo{ .address_calculation = dest_address_calculation };
    }

    return InstructionInfo{
        .destination_info = destination_payload,
        .source_info = source_payload,
    };
}

pub fn getRegisterMemoryOpSourceAndDest(
    EU: *ExecutionUnit,
    // opcode: BinaryInstructions,
    mod: MOD,
    rm: RM,
    disp_lo: ?u8,
    disp_hi: ?u8,
) InstructionInfo {
    // const log = std.log.scoped(.getRegisterMemoryOpSourceAndDest);
    const Address = RegisterNames;
    return InstructionInfo{
        .destination_info = DestinationInfo{
            .address_calculation = BusInterfaceUnit.calculateEffectiveAddress(
                EU,
                mod,
                rm,
                disp_lo,
                disp_hi,
            ),
        },
        .source_info = SourceInfo{
            .address = Address.sp,
        },
    };
}

pub fn getMemToAccSourceAndDest(
    w: Width,
    addr_lo: ?u8,
    addr_hi: ?u8,
) InstructionInfo {
    const Address = RegisterNames;
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

pub fn getAccToMemSourceAndDest(
    w: Width,
    addr_lo: ?u8,
    addr_hi: ?u8,
) InstructionInfo {
    const Address = RegisterNames;
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

pub fn getRegisterOpSourceAndDest(
    opcode: BinaryInstructions,
    reg: REG,
) InstructionInfo {
    const log = std.log.scoped(.getRegisterOpSourceAndDest);
    const Address = RegisterNames;

    switch (opcode) {
        BinaryInstructions.inc_ax,
        BinaryInstructions.inc_cx,
        BinaryInstructions.inc_dx,
        BinaryInstructions.inc_bx,
        BinaryInstructions.inc_sp,
        BinaryInstructions.inc_bp,
        BinaryInstructions.inc_si,
        BinaryInstructions.inc_di,
        BinaryInstructions.dec_ax,
        BinaryInstructions.dec_cx,
        BinaryInstructions.dec_dx,
        BinaryInstructions.dec_bx,
        BinaryInstructions.dec_sp,
        BinaryInstructions.dec_bp,
        BinaryInstructions.dec_si,
        BinaryInstructions.dec_di,
        => {
            return InstructionInfo{
                .destination_info = DestinationInfo{
                    .address = switch (reg) {
                        .ALAX => Address.ax,
                        .CLCX => Address.cx,
                        .DLDX => Address.dx,
                        .BLBX => Address.bx,
                        .AHSP => Address.sp,
                        .CHBP => Address.bp,
                        .DHSI => Address.si,
                        .BHDI => Address.di,
                    },
                },
                .source_info = SourceInfo{
                    .none = {},
                },
            };
        },
        BinaryInstructions.push_ax,
        BinaryInstructions.push_cx,
        BinaryInstructions.push_dx,
        BinaryInstructions.push_bx,
        BinaryInstructions.push_sp,
        BinaryInstructions.push_bp,
        BinaryInstructions.push_si,
        BinaryInstructions.push_di,
        BinaryInstructions.pop_ax,
        BinaryInstructions.pop_cx,
        BinaryInstructions.pop_dx,
        BinaryInstructions.pop_bx,
        BinaryInstructions.pop_sp,
        BinaryInstructions.pop_bp,
        BinaryInstructions.pop_si,
        BinaryInstructions.pop_di,
        => {
            return InstructionInfo{
                .destination_info = DestinationInfo{
                    .address = switch (reg) {
                        .ALAX => Address.ax,
                        .CLCX => Address.cx,
                        .DLDX => Address.dx,
                        .BLBX => Address.bx,
                        .AHSP => Address.sp,
                        .CHBP => Address.bp,
                        .DHSI => Address.si,
                        .BHDI => Address.di,
                    },
                },
                .source_info = SourceInfo{
                    .none = {},
                },
            };
        },
        BinaryInstructions.nop_xchg_ax_ax,
        => {
            return InstructionInfo{
                .destination_info = DestinationInfo{
                    .none = {},
                },
                .source_info = SourceInfo{
                    .none = {},
                },
            };
        },
        BinaryInstructions.xchg_ax_cx,
        BinaryInstructions.xchg_ax_dx,
        BinaryInstructions.xchg_ax_bx,
        BinaryInstructions.xchg_ax_sp,
        BinaryInstructions.xchg_ax_bp,
        BinaryInstructions.xchg_ax_si,
        BinaryInstructions.xchg_ax_di,
        => {
            return InstructionInfo{
                .destination_info = DestinationInfo{
                    .address = Address.ax,
                },
                .source_info = SourceInfo{
                    .address = switch (reg) {
                        .ALAX => Address.ax, // Should never happen!
                        .CLCX => Address.cx,
                        .DLDX => Address.dx,
                        .BLBX => Address.bx,
                        .AHSP => Address.sp,
                        .CHBP => Address.bp,
                        .DHSI => Address.si,
                        .BHDI => Address.di,
                    },
                },
            };
        },
        else => {
            log.err("ERROR: {t} should not end up here.", .{opcode});
            return InstructionInfo{
                .destination_info = DestinationInfo{
                    .none = {},
                },
                .source_info = SourceInfo{
                    .none = {},
                },
            };
        },
    }
}

pub fn getImmediateToRegMemMovDest(
    execution_unit: *ExecutionUnit,
    mod: MOD,
    rm: RM,
    w: Width,
    disp_lo: ?u8,
    disp_hi: ?u8,
    data: u8,
    w_data: ?u8,
) InstructionInfo {
    const Address = RegisterNames;
    const source_payload: SourceInfo = SourceInfo{
        .immediate = @intCast(if (w == Width.word) (@as(u16, w_data.?) << 8) + (@as(u16, data)) else @as(u16, data)),
    };

    var destination_payload: DestinationInfo = undefined;
    switch (mod) {
        .memoryModeNoDisplacement => {
            switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    const bx_value = execution_unit.getBX(Width.word, null).value16;
                    const si_value = execution_unit.getSI();
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
                    const bx_value = execution_unit.getBX(Width.word, null).value16;
                    const di_value = execution_unit.getDI();
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
                    const bp_value = execution_unit.getBP();
                    const si_value = execution_unit.getSI();
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
                    const bp_value = execution_unit.getBP();
                    const di_value = execution_unit.getDI();
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
                    const si_value = execution_unit.getSI();
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
                    const di_value = execution_unit.getDI();
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
                    const bx_value = execution_unit.getBX(Width.word, null).value16;
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
                    const bx_value = execution_unit.getBX(Width.word, null).value16;
                    const si_value = execution_unit.getSI();
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
                    const bx_value = execution_unit.getBX(Width.word, null).value16;
                    const di_value = execution_unit.getDI();
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
                    const bp_value = execution_unit.getBP();
                    const si_value = execution_unit.getSI();
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
                    const bp_value = execution_unit.getBP();
                    const di_value = execution_unit.getDI();
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
                    const si_value = execution_unit.getSI();
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
                    const di_value = execution_unit.getDI();
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
                    const bp_value = execution_unit.getBP();
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
                    const bx_value = execution_unit.getBX(Width.word, null).value16;
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
                    const bx_value = execution_unit.getBX(Width.word, null).value16;
                    const si_value = execution_unit.getSI();
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
                    const bx_value = execution_unit.getBX(Width.word, null).value16;
                    const di_value = execution_unit.getDI();
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
                    const bp_value = execution_unit.getBP();
                    const si_value = execution_unit.getSI();
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
                    const bp_value = execution_unit.getBP();
                    const di_value = execution_unit.getDI();
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
                    const si_value = execution_unit.getSI();
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
                    const di_value = execution_unit.getDI();
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
                    const bp_value = execution_unit.getBP();
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
                    const bx_value = execution_unit.getBX(Width.word, null).value16;
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
                        .address = if (w == Width.word) Address.ax else Address.al,
                    };
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    destination_payload = DestinationInfo{
                        .address = if (w == Width.word) Address.cx else Address.cl,
                    };
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    destination_payload = DestinationInfo{
                        .address = if (w == Width.word) Address.dx else Address.dl,
                    };
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    destination_payload = DestinationInfo{
                        .address = if (w == Width.word) Address.bx else Address.bl,
                    };
                },
                .AHSP_SI_SID8_SID16 => {
                    destination_payload = DestinationInfo{
                        .address = if (w == Width.word) Address.sp else Address.ah,
                    };
                },
                .CHBP_DI_DID8_DID16 => {
                    destination_payload = DestinationInfo{
                        .address = if (w == Width.word) Address.bp else Address.ch,
                    };
                },
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    destination_payload = DestinationInfo{
                        .address = if (w == Width.word) Address.si else Address.dh,
                    };
                },
                .BHDI_BX_BXD8_BXD16 => {
                    destination_payload = DestinationInfo{
                        .address = if (w == Width.word) Address.di else Address.bh,
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
