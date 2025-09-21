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
const Variable = types.instruction_fields.Variable;

const EffectiveAddressCalculation = types.data_types.EffectiveAddressCalculation;
const InstructionInfo = types.data_types.InstructionInfo;
const DestinationInfo = types.data_types.DestinationInfo;
const SourceInfo = types.data_types.SourceInfo;
const DisplacementFormat = types.data_types.DisplacementFormat;

const hw = @import("hardware.zig");
const ExecutionUnit = hw.ExecutionUnit;
const BusInterfaceUnit = hw.BusInterfaceUnit;

const decoder = @import("decoder.zig");
const BinaryInstructions = decoder.BinaryInstructions;
const InstructionScope = decoder.InstructionScope;
const InstructionData = decoder.InstructionData;
const AddSet = decoder.AddSet;
const RolSet = decoder.RolSet;
const TestSet = decoder.TestSet;
const IncSet = decoder.IncSet;
const AccumulatorOp = decoder.AccumulatorOp;
const EscapeOp = decoder.EscapeOp;
const RegisterMemoryToFromRegisterOp = decoder.RegisterMemoryToFromRegisterOp;
const RegisterMemoryOp = decoder.RegisterMemoryOp;
const RegisterOp = decoder.RegisterOp;
const ImmediateToRegisterOp = decoder.ImmediateToRegisterOp;
const ImmediateToMemoryOp = decoder.ImmediateToMemoryOp;
const SegmentRegisterOp = decoder.SegmentRegisterOp;
const IdentifierAddOp = decoder.IdentifierAddOp;
const IdentifierRolOp = decoder.IdentifierRolOp;
const IdentifierTestOp = decoder.IdentifierTestOp;
const IdentifierIncOp = decoder.IdentifierIncOp;
const DirectOp = decoder.DirectOp;
const SingleByteOp = decoder.SingleByteOp;

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

pub fn getInstructionSourceAndDest(
    EU: *ExecutionUnit,
    opcode: BinaryInstructions,
    instruction_data: InstructionData,
) LocatorError!InstructionInfo {
    switch (instruction_data) {
        .err => return LocatorError.AccumulatorSourceAndDest,
        .accumulator_op => {
            const AccumulatorOps = decoder.ScopedInstruction(.AccumulatorOp);
            const accumulator_ops: AccumulatorOps = @enumFromInt(@intFromEnum(opcode));

            switch (accumulator_ops) {
                .add_al_immed8,
                .add_ax_immed16,
                .or_al_immed8,
                .or_ax_immed16,
                .adc_al_immed8,
                .adc_ax_immed16,
                .sbb_al_immed8,
                .sbb_ax_immed16,
                .and_al_immed8,
                .and_ax_immed16,
                .sub_al_immed8,
                .sub_ax_immed16,
                .xor_al_immed8,
                .xor_ax_immed16,
                .cmp_al_immed8,
                .cmp_ax_immed16,
                .test_al_immed8,
                .test_ax_immed16,
                .in_al_immed8,
                .in_ax_immed8,
                .out_al_immed8,
                .out_ax_immed8,
                => {
                    const Address = RegisterNames;
                    const w = instruction_data.accumulator_op.w;
                    const data_8: ?u8 = instruction_data.accumulator_op.data_8;
                    const data_lo: ?u8 = instruction_data.accumulator_op.data_lo;
                    const data_hi: ?u8 = instruction_data.accumulator_op.data_hi;

                    if (w == Width.byte) {
                        return InstructionInfo{
                            .destination_info = DestinationInfo{
                                .address = Address.al,
                            },
                            .source_info = SourceInfo{
                                .immediate = @intCast(data_8.?),
                            },
                        };
                    } else {
                        return InstructionInfo{
                            .destination_info = DestinationInfo{
                                .address = Address.ax,
                            },
                            .source_info = SourceInfo{
                                .immediate = @bitCast((@as(u16, data_hi.?) << 8) + @as(u16, data_lo.?)),
                            },
                        };
                    }
                },
                .mov_al_mem8,
                .mov_ax_mem16,
                => {
                    const Address = RegisterNames;
                    const addr_lo = instruction_data.accumulator_op.addr_lo;
                    const addr_hi = instruction_data.accumulator_op.addr_hi;
                    const w = instruction_data.accumulator_op.w;
                    return InstructionInfo{
                        .destination_info = DestinationInfo{
                            .address = if (w == Width.word) Address.ax else Address.al,
                        },
                        .source_info = SourceInfo{
                            .mem_addr = if (w == Width.word) (@as(u16, addr_hi.?) << 8) + addr_lo.? else (@as(u16, addr_hi.?) << 8) + addr_lo.?,
                        },
                    };
                },
                .mov_mem8_al,
                .mov_mem16_ax,
                => {
                    const Address = RegisterNames;
                    const addr_lo = instruction_data.accumulator_op.addr_lo;
                    const addr_hi = instruction_data.accumulator_op.addr_hi;
                    const w = instruction_data.accumulator_op.w;
                    return InstructionInfo{
                        .destination_info = DestinationInfo{
                            .mem_addr = if (w == Width.word) (@as(u16, addr_hi.?) << 8) + addr_lo.? else (@as(u16, addr_hi.?) << 8) + addr_lo.?,
                        },
                        .source_info = SourceInfo{
                            .address = if (w == Width.word) Address.ax else Address.al,
                        },
                    };
                },
            }
        },
        .direct_op,
        .escape_op,
        .identifier_add_op,
        .identifier_inc_op,
        .identifier_rol_op,
        .identifier_test_op,
        => return LocatorError.NotYetImplemented,
        .immediate_to_memory_op => {
            const Address = RegisterNames;
            const w: Width = instruction_data.immediate_to_memory_op.w;
            const mod: MOD = instruction_data.immediate_to_memory_op.mod;
            const rm: RM = instruction_data.immediate_to_memory_op.rm;
            const disp_lo: ?u8 = instruction_data.immediate_to_memory_op.disp_lo;
            const disp_hi: ?u8 = instruction_data.immediate_to_memory_op.disp_hi;
            const data_8: ?u8 = instruction_data.immediate_to_memory_op.data_8;
            const data_lo: ?u8 = instruction_data.immediate_to_memory_op.data_lo;
            const data_hi: ?u8 = instruction_data.immediate_to_memory_op.data_hi;
            return InstructionInfo{
                .destination_info = switch (mod) {
                    .memoryModeNoDisplacement,
                    .memoryMode8BitDisplacement,
                    .memoryMode16BitDisplacement,
                    => DestinationInfo{
                        .address_calculation = BusInterfaceUnit.calculateEffectiveAddress(
                            EU,
                            w,
                            mod,
                            rm,
                            disp_lo,
                            disp_hi,
                        ),
                    },
                    .registerModeNoDisplacement,
                    => DestinationInfo{
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
                    },
                },
                .source_info = SourceInfo{
                    .immediate = switch (w) {
                        .byte => @intCast(data_8.?),
                        .word => @intCast(@as(u16, data_hi.? << 8) + data_lo.?),
                    },
                },
            };
        },
        .immediate_to_register_op => {
            const Address = RegisterNames;
            const reg: REG = instruction_data.immediate_to_register_op.reg;
            const w: Width = instruction_data.immediate_to_register_op.w;
            const data_8: ?u8 = instruction_data.immediate_to_register_op.data_8;
            const data_lo: ?u8 = instruction_data.immediate_to_register_op.data_lo;
            const data_hi: ?u8 = instruction_data.immediate_to_register_op.data_hi;
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
                        Width.word => @bitCast((@as(u16, data_hi.?) << 8) + @as(u16, data_lo.?)),
                    },
                },
            };
        },
        .register_memory_op => {
            const Address = RegisterNames;
            const mod: MOD = instruction_data.register_memory_op.mod;
            const rm: RM = instruction_data.register_memory_op.rm;
            const disp_lo: ?u8 = instruction_data.register_memory_op.disp_lo;
            const disp_hi: ?u8 = instruction_data.register_memory_op.disp_hi;

            return InstructionInfo{
                .destination_info = DestinationInfo{
                    .address_calculation = BusInterfaceUnit.calculateEffectiveAddress(
                        EU,
                        Width.word,
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
        },
        .register_memory_to_from_register_op => {
            const Address = RegisterNames;
            const d: Direction = instruction_data.register_memory_to_from_register_op.d;
            const w: Width = instruction_data.register_memory_to_from_register_op.w;
            const mod: MOD = instruction_data.register_memory_to_from_register_op.mod;
            const reg: REG = instruction_data.register_memory_to_from_register_op.reg;
            const rm: RM = instruction_data.register_memory_to_from_register_op.rm;
            const disp_lo: ?u8 = instruction_data.register_memory_to_from_register_op.disp_lo;
            const disp_hi: ?u8 = instruction_data.register_memory_to_from_register_op.disp_hi;

            const ea_calc: EffectiveAddressCalculation = BusInterfaceUnit.calculateEffectiveAddress(
                EU,
                w,
                mod,
                rm,
                disp_lo,
                disp_hi,
            );
            const addr: Address = switch (reg) {
                .ALAX => if (w == Width.word) Address.ax else Address.al,
                .CLCX => if (w == Width.word) Address.cx else Address.cl,
                .DLDX => if (w == Width.word) Address.dx else Address.dl,
                .BLBX => if (w == Width.word) Address.bx else Address.bl,
                .AHSP => if (w == Width.word) Address.sp else Address.ah,
                .CHBP => if (w == Width.word) Address.bp else Address.ch,
                .DHSI => if (w == Width.word) Address.si else Address.dh,
                .BHDI => if (w == Width.word) Address.di else Address.bh,
            };

            return InstructionInfo{
                .destination_info = switch (d) {
                    Direction.source => DestinationInfo{
                        .address_calculation = ea_calc,
                    },
                    Direction.destination => DestinationInfo{
                        .address = addr,
                    },
                },
                .source_info = switch (d) {
                    Direction.source => SourceInfo{
                        .address = addr,
                    },
                    Direction.destination => SourceInfo{
                        .address_calculation = ea_calc,
                    },
                },
            };
        },
        .register_op => {
            const Address = RegisterNames;
            const RegisterOps = decoder.ScopedInstruction(.RegisterOp);
            const register_ops: RegisterOps = @enumFromInt(@intFromEnum(opcode));

            const reg: REG = instruction_data.register_op.reg;

            switch (register_ops) {
                .inc_ax,
                .inc_cx,
                .inc_dx,
                .inc_bx,
                .inc_sp,
                .inc_bp,
                .inc_si,
                .inc_di,
                .dec_ax,
                .dec_cx,
                .dec_dx,
                .dec_bx,
                .dec_sp,
                .dec_bp,
                .dec_si,
                .dec_di,
                .push_ax,
                .push_cx,
                .push_dx,
                .push_bx,
                .push_sp,
                .push_bp,
                .push_si,
                .push_di,
                .pop_ax,
                .pop_cx,
                .pop_dx,
                .pop_bx,
                .pop_sp,
                .pop_bp,
                .pop_si,
                .pop_di,
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
                .nop_xchg_ax_ax,
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
                .xchg_ax_cx,
                .xchg_ax_dx,
                .xchg_ax_bx,
                .xchg_ax_sp,
                .xchg_ax_bp,
                .xchg_ax_si,
                .xchg_ax_di,
                => {
                    return InstructionInfo{
                        .destination_info = DestinationInfo{
                            .address = Address.ax,
                        },
                        .source_info = SourceInfo{
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
                    };
                },
            }
        },
        .segment_register_op,
        .single_byte_op,
        => return LocatorError.NotYetImplemented,
    }
}

// pub fn getImmediateToMemoryOpSourceAndDest(
//     EU: *ExecutionUnit,
//     instruction_data: InstructionData,
// ) LocatorError!InstructionInfo {
//     // const log = std.log.scoped(.getImmediateToMemoryOpSourceAndDest);
//     const Address = RegisterNames;

//     const opcode: BinaryInstructions = instruction_data.immediate_to_memory_op.opcode;
//     const w: Width = instruction_data.immediate_to_memory_op.w;
//     const mod: MOD = instruction_data.immediate_to_memory_op.mod;
//     const rm: RM = instruction_data.immediate_to_memory_op.rm;
//     const disp_lo: ?u8 = instruction_data.immediate_to_memory_op.disp_lo;
//     const disp_hi: ?u8 = instruction_data.immediate_to_memory_op.disp_hi;
//     const data_8: ?u8 = instruction_data.immediate_to_memory_op.data_8;
//     const data_lo: ?u8 = instruction_data.immediate_to_memory_op.data_lo;
//     const data_hi: ?u8 = instruction_data.immediate_to_memory_op.data_hi;

//     return InstructionInfo{
//         .destination_info = destination_switch: switch (mod) {
//             .memoryModeNoDisplacement,
//             .memoryMode8BitDisplacement,
//             .memoryMode16BitDisplacement,
//             => DestinationInfo{
//                 .address_calculation = BusInterfaceUnit.calculateEffectiveAddress(
//                     EU,
//                     w,
//                     mod,
//                     rm,
//                     disp_lo,
//                     disp_hi,
//                 ),
//             },
//             .registerModeNoDisplacement => {
//                 break :destination_switch DestinationInfo{
//                     .address = switch (rm) {
//                         .ALAX_BXSI_BXSID8_BXSID16 => Address.ax,
//                         .CLCX_BXDI_BXDID8_BXDID16 => Address.cx,
//                         .DLDX_BPSI_BPSID8_BPSID16 => Address.dx,
//                         .BLBX_BPDI_BPDID8_BPDID16 => Address.bx,
//                         .AHSP_SI_SID8_SID16 => Address.sp,
//                         .CHBP_DI_DID8_DID16 => Address.bp,
//                         .DHSI_DIRECTACCESS_BPD8_BPD16 => Address.si,
//                         .BHDI_BX_BXD8_BXD16 => Address.di,
//                     },
//                 };
//             },
//         },
//         .source_info = SourceInfo{ .immediate = switch (opcode) {
//             BinaryInstructions.mov_mem8_immed8 => @as(i16, data_8.?),
//             BinaryInstructions.mov_mem16_immed16 => @bitCast((@as(u16, data_hi.?) << 8) + @as(u16, data_lo.?)),
//             else => return LocatorError.InvalidOpcode,
//         } },
//     };
// }

pub fn getIdentifierAddOpSourceAndDest(
    EU: *ExecutionUnit,
    opcode: BinaryInstructions,
    instruction_data: InstructionData,
) LocatorError!InstructionInfo {
    const Address = RegisterNames;

    // const identifier: AddSet = identifier_add_op.identifier;
    const w: Width = instruction_data.identifier_add_op.w;
    // const s: Sign = instruction_data.identifier_add_op.s;
    const mod: MOD = instruction_data.identifier_add_op.mod;
    const rm: RM = instruction_data.identifier_add_op.rm;
    const disp_lo: ?u8 = instruction_data.identifier_add_op.disp_lo;
    const disp_hi: ?u8 = instruction_data.identifier_add_op.disp_hi;

    const data_8: ?u8 = instruction_data.identifier_add_op.data_8;
    const data_lo: ?u8 = instruction_data.identifier_add_op.data_lo;
    const data_hi: ?u8 = instruction_data.identifier_add_op.data_hi;
    const data_sx: ?u8 = instruction_data.identifier_add_op.data_sx;

    return InstructionInfo{
        .destination_info = dest: switch (mod) {
            .memoryModeNoDisplacement => if (rm == RM.DHSI_DIRECTACCESS_BPD8_BPD16) {
                break :dest DestinationInfo{
                    .mem_addr = (@as(u20, disp_hi.?) << 8) + @as(u20, disp_lo.?),
                };
            } else {
                break :dest DestinationInfo{
                    .address_calculation = BusInterfaceUnit.calculateEffectiveAddress(EU, w, mod, rm, disp_lo, disp_hi),
                };
            },
            .memoryMode8BitDisplacement,
            .memoryMode16BitDisplacement,
            => DestinationInfo{
                .address_calculation = BusInterfaceUnit.calculateEffectiveAddress(EU, w, mod, rm, disp_lo, disp_hi),
            },
            .registerModeNoDisplacement => DestinationInfo{ .address = switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => if (w == Width.word) Address.ax else Address.al,
                .CLCX_BXDI_BXDID8_BXDID16 => if (w == Width.word) Address.cx else Address.cl,
                .DLDX_BPSI_BPSID8_BPSID16 => if (w == Width.word) Address.dx else Address.dl,
                .BLBX_BPDI_BPDID8_BPDID16 => if (w == Width.word) Address.bx else Address.bl,
                .AHSP_SI_SID8_SID16 => if (w == Width.word) Address.sp else Address.ah,
                .CHBP_DI_DID8_DID16 => if (w == Width.word) Address.bp else Address.ch,
                .DHSI_DIRECTACCESS_BPD8_BPD16 => if (w == Width.word) Address.si else Address.dh,
                .BHDI_BX_BXD8_BXD16 => if (w == Width.word) Address.di else Address.bh,
            } },
        },
        .source_info = SourceInfo{
            .immediate = immed: switch (opcode) {
                .regmem8_immed8 => @intCast(data_8.?),
                .regmem16_immed16 => @bitCast((@as(u16, data_hi.?) << 8) + data_lo.?),
                .signed_regmem8_immed8 => {
                    const signed_immed8: i8 = @bitCast(data_8.?);
                    break :immed @intCast(signed_immed8);
                },
                .sign_extend_regmem16_immed8 => {
                    const signed_immed8: i8 = @bitCast(data_sx.?);
                    break :immed @bitCast(@as(i16, signed_immed8));
                },
                else => {
                    return LocatorError.NotYetImplemented;
                },
            },
        },
    };
}

pub fn getIdentifierRolOpSourceAndDest(
    EU: *ExecutionUnit,
    opcode: BinaryInstructions,
    instruction_data: InstructionData,
) LocatorError!InstructionInfo {
    const Address = RegisterNames;

    // const identifier: RolSet = instruction_data.identifier_rol_op.identifier;
    const v: Variable = instruction_data.identifier_rol_op.v;
    const mod: MOD = instruction_data.identifier_rol_op.mod;
    const rm: RM = instruction_data.identifier_rol_op.rm;

    const disp_lo: ?u8 = instruction_data.identifier_rol_op.disp_lo;
    const disp_hi: ?u8 = instruction_data.identifier_rol_op.disp_hi;

    return InstructionInfo{
        .destination_info = switch (mod) {
            .memoryModeNoDisplacement => if (rm == RM.DHSI_DIRECTACCESS_BPD8_BPD16) DestinationInfo{
                .mem_addr = @as(u20, (@as(u16, disp_hi.?) << 8) + disp_lo.?),
            } else DestinationInfo{
                .address_calculation = BusInterfaceUnit.calculateEffectiveAddress(
                    EU,
                    switch (opcode) {
                        .logical_regmem8,
                        .logical_regmem8_cl,
                        => Width.byte,
                        .logical_regmem16,
                        .logical_regmem16_cl,
                        => Width.word,
                        else => return LocatorError.NotYetImplemented,
                    },
                    mod,
                    rm,
                    disp_lo,
                    disp_hi,
                ),
            },
            .memoryMode8BitDisplacement,
            .memoryMode16BitDisplacement,
            => DestinationInfo{
                .address_calculation = BusInterfaceUnit.calculateEffectiveAddress(
                    EU,
                    switch (opcode) {
                        .logical_regmem8,
                        .logical_regmem8_cl,
                        => Width.byte,
                        .logical_regmem16,
                        .logical_regmem16_cl,
                        => Width.word,
                        else => return LocatorError.NotYetImplemented,
                    },
                    mod,
                    rm,
                    disp_lo,
                    disp_hi,
                ),
            },
            .registerModeNoDisplacement => DestinationInfo{ .address = switch (opcode) {
                .logical_regmem8,
                .logical_regmem8_cl,
                => switch (rm) {
                    .ALAX_BXSI_BXSID8_BXSID16 => Address.al,
                    .CLCX_BXDI_BXDID8_BXDID16 => Address.cl,
                    .DLDX_BPSI_BPSID8_BPSID16 => Address.dl,
                    .BLBX_BPDI_BPDID8_BPDID16 => Address.bl,
                    .AHSP_SI_SID8_SID16 => Address.ah,
                    .CHBP_DI_DID8_DID16 => Address.ch,
                    .DHSI_DIRECTACCESS_BPD8_BPD16 => Address.dh,
                    .BHDI_BX_BXD8_BXD16 => Address.bh,
                },
                .logical_regmem16,
                .logical_regmem16_cl,
                => switch (rm) {
                    .ALAX_BXSI_BXSID8_BXSID16 => Address.ax,
                    .CLCX_BXDI_BXDID8_BXDID16 => Address.cx,
                    .DLDX_BPSI_BPSID8_BPSID16 => Address.dx,
                    .BLBX_BPDI_BPDID8_BPDID16 => Address.bx,
                    .AHSP_SI_SID8_SID16 => Address.sp,
                    .CHBP_DI_DID8_DID16 => Address.bp,
                    .DHSI_DIRECTACCESS_BPD8_BPD16 => Address.si,
                    .BHDI_BX_BXD8_BXD16 => Address.di,
                },
                else => return LocatorError.NotYetImplemented,
            } },
        },
        .source_info = switch (v) {
            .one => SourceInfo{
                .immediate = 1,
            },
            .in_CL => SourceInfo{
                .address = Address.cl,
            },
        },
    };
}

pub fn getIdentifierTestOpSourceAndDest(
    EU: *ExecutionUnit,
    opcode: BinaryInstructions,
    instruction_data: InstructionData,
) LocatorError!InstructionInfo {
    const mod: ?MOD = instruction_data.identifier_test_op.mod;
    const identifier: TestSet = instruction_data.identifier_test_op.identifier;
    const rm: ?RM = instruction_data.identifier_test_op.rm;
    const disp_lo: ?u8 = instruction_data.identifier_test_op.disp_lo;
    const disp_hi: ?u8 = instruction_data.identifier_test_op.disp_hi;

    const data_8: ?u8 = instruction_data.identifier_test_op.data_8;
    const data_lo: ?u8 = instruction_data.identifier_test_op.data_lo;
    const data_hi: ?u8 = instruction_data.identifier_test_op.data_hi;

    return InstructionInfo{
        .destination_info = dest: switch (identifier) {
            .TEST,
            .NOT,
            .NEG,
            => switch (opcode) {
                .regmem8_immed8 => break :dest DestinationInfo{
                    .address_calculation = BusInterfaceUnit.calculateEffectiveAddress(
                        EU,
                        Width.byte,
                        mod.?,
                        rm.?,
                        disp_lo,
                        disp_hi,
                    ),
                },
                .regmem16_immed16 => break :dest DestinationInfo{
                    .address_calculation = BusInterfaceUnit.calculateEffectiveAddress(
                        EU,
                        Width.word,
                        mod.?,
                        rm.?,
                        disp_lo,
                        disp_hi,
                    ),
                },
                else => return LocatorError.NotYetImplemented,
            },
            .MUL,
            .IMUL,
            .DIV,
            .IDIV,
            => DestinationInfo{
                .none = {},
            },
        },
        .source_info = src: switch (identifier) {
            .NOT,
            .NEG,
            => SourceInfo{
                .none = {},
            },
            .TEST,
            .MUL,
            .IMUL,
            .DIV,
            .IDIV,
            => switch (opcode) {
                .regmem8_immed8 => break :src SourceInfo{
                    .immediate = @as(i16, data_8.?),
                },
                .regmem16_immed16 => break :src SourceInfo{
                    .immediate = @bitCast((@as(u16, data_hi.?) << 8) + data_lo.?),
                },
                else => return LocatorError.NotYetImplemented,
            },
        },
    };
}

// pub fn getImmediateToRegDest(
//     w: Width,
//     reg: REG,
//     data_8: ?u8,
//     data_lo: ?u8,
//     data_hi: ?u8,
// ) InstructionInfo {
//     const Address = RegisterNames;
//     return InstructionInfo{
//         .destination_info = DestinationInfo{
//             .address = switch (reg) {
//                 .ALAX => if (w == Width.byte) Address.al else Address.ax,
//                 .CLCX => if (w == Width.byte) Address.cl else Address.cx,
//                 .DLDX => if (w == Width.byte) Address.dl else Address.dx,
//                 .BLBX => if (w == Width.byte) Address.bl else Address.bx,
//                 .AHSP => if (w == Width.byte) Address.ah else Address.sp,
//                 .CHBP => if (w == Width.byte) Address.ch else Address.bp,
//                 .DHSI => if (w == Width.byte) Address.dh else Address.si,
//                 .BHDI => if (w == Width.byte) Address.bh else Address.di,
//             },
//         },
//         .source_info = SourceInfo{
//             .immediate = switch (w) {
//                 Width.byte => @intCast(data_8.?),
//                 Width.word => @bitCast((@as(u16, data_hi.?) << 8) + @as(u16, data_lo.?)),
//             },
//         },
//     };
// }

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

// pub fn getImmediateToAccumulatorDest(
//     w: Width,
//     data_8: ?u8,
//     data_lo: ?u8,
//     data_hi: ?u8,
// ) InstructionInfo {
//     const Address = RegisterNames;
//     var dest: Address = undefined;
//     if (w == Width.byte) {
//         dest = Address.al;
//         return InstructionInfo{
//             .destination_info = DestinationInfo{
//                 .address = dest,
//             },
//             .source_info = SourceInfo{
//                 .immediate = @intCast(data_8.?),
//             },
//         };
//     } else {
//         dest = Address.ax;
//         return InstructionInfo{
//             .destination_info = DestinationInfo{
//                 .address = dest,
//             },
//             .source_info = SourceInfo{
//                 .immediate = @bitCast((@as(u16, data_hi.?) << 8) + @as(u16, data_lo.?)),
//             },
//         };
//     }
// }

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
// pub fn getRegMemToFromRegSourceAndDest(
//     EU: *ExecutionUnit,
//     d: Direction,
//     w: Width,
//     reg: REG,
//     mod: MOD,
//     rm: RM,
//     disp_lo: ?u8,
//     disp_hi: ?u8,
// ) InstructionInfo {
//     const Address = RegisterNames;

//     const regIsSource: bool = if (d == Direction.source) true else false;
//     const instruction_info: InstructionInfo = switch (regIsSource) {
//         true => InstructionInfo{
//             .destination_info = switch (mod) {
//                 .memoryModeNoDisplacement => if (rm == RM.DHSI_DIRECTACCESS_BPD8_BPD16) DestinationInfo{
//                     .mem_addr = @intCast((@as(u16, disp_hi.?) << 8) + disp_lo.?),
//                     // .address_calculation = BusInterfaceUnit.calculateEffectiveAddress(
//                     //     EU,
//                     //     w,
//                     //     mod,
//                     //     rm,
//                     //     disp_lo,
//                     //     disp_hi,
//                     // ),
//                 } else DestinationInfo{
//                     .address_calculation = BusInterfaceUnit.calculateEffectiveAddress(
//                         EU,
//                         w,
//                         mod,
//                         rm,
//                         disp_lo,
//                         disp_hi,
//                     ),
//                 },
//                 .memoryMode8BitDisplacement,
//                 .memoryMode16BitDisplacement,
//                 => DestinationInfo{
//                     .address_calculation = BusInterfaceUnit.calculateEffectiveAddress(
//                         EU,
//                         w,
//                         mod,
//                         rm,
//                         disp_lo,
//                         disp_hi,
//                     ),
//                 },
//                 .registerModeNoDisplacement => DestinationInfo{
//                     .address = registerNameFromRm(w, rm),
//                 },
//             },
//             .source_info = SourceInfo{
//                 .address = switch (reg) {
//                     REG.ALAX => if (w == Width.word) Address.ax else Address.al,
//                     REG.CLCX => if (w == Width.word) Address.cx else Address.cl,
//                     REG.DLDX => if (w == Width.word) Address.dx else Address.dl,
//                     REG.BLBX => if (w == Width.word) Address.bx else Address.bl,
//                     REG.AHSP => if (w == Width.word) Address.sp else Address.ah,
//                     REG.CHBP => if (w == Width.word) Address.bp else Address.ch,
//                     REG.DHSI => if (w == Width.word) Address.si else Address.dh,
//                     REG.BHDI => if (w == Width.word) Address.di else Address.bh,
//                 },
//             },
//         },
//         false => InstructionInfo{
//             .destination_info = DestinationInfo{
//                 .address = registerNameFromReg(w, reg),
//             },
//             .source_info = switch (mod) {
//                 .memoryModeNoDisplacement => if (rm == RM.DHSI_DIRECTACCESS_BPD8_BPD16) SourceInfo{
//                     .mem_addr = (@as(u20, disp_hi.?) << 8) + @as(u20, disp_lo.?),
//                 } else SourceInfo{
//                     .address_calculation = BusInterfaceUnit.calculateEffectiveAddress(EU, w, mod, rm, disp_lo, disp_hi),
//                 },
//                 .memoryMode8BitDisplacement,
//                 .memoryMode16BitDisplacement,
//                 => SourceInfo{
//                     .address_calculation = BusInterfaceUnit.calculateEffectiveAddress(
//                         EU,
//                         w,
//                         mod,
//                         rm,
//                         disp_lo,
//                         disp_hi,
//                     ),
//                 },
//                 .registerModeNoDisplacement => SourceInfo{
//                     .address = registerNameFromRm(Width.word, rm),
//                 },
//             },
//         },
//     };
//     return instruction_info;
// }

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
        .memoryModeNoDisplacement,
        .memoryMode8BitDisplacement,
        .memoryMode16BitDisplacement,
        => {
            source_address_calculation = BusInterfaceUnit.calculateEffectiveAddress(
                execution_unit,
                Width.word,
                mod,
                rm,
                disp_lo,
                disp_hi,
            );
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
        .memoryModeNoDisplacement,
        .memoryMode8BitDisplacement,
        .memoryMode16BitDisplacement,
        => {
            dest_address_calculation = BusInterfaceUnit.calculateEffectiveAddress(
                execution_unit,
                Width.word,
                mod,
                rm,
                disp_lo,
                disp_hi,
            );
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

// pub fn getRegisterMemoryOpSourceAndDest(
//     EU: *ExecutionUnit,
//     // opcode: BinaryInstructions,
//     mod: MOD,
//     rm: RM,
//     disp_lo: ?u8,
//     disp_hi: ?u8,
// ) InstructionInfo {
//     // const log = std.log.scoped(.getRegisterMemoryOpSourceAndDest);
//     const Address = RegisterNames;
//     return InstructionInfo{
//         .destination_info = DestinationInfo{
//             .address_calculation = BusInterfaceUnit.calculateEffectiveAddress(
//                 EU,
//                 Width.word,
//                 mod,
//                 rm,
//                 disp_lo,
//                 disp_hi,
//             ),
//         },
//         .source_info = SourceInfo{
//             .address = Address.sp,
//         },
//     };
// }

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

// pub fn getRegisterOpSourceAndDest(
//     opcode: BinaryInstructions,
//     reg: REG,
// ) InstructionInfo {
//     const log = std.log.scoped(.getRegisterOpSourceAndDest);
//     const Address = RegisterNames;

//     switch (opcode) {
//         BinaryInstructions.inc_ax,
//         BinaryInstructions.inc_cx,
//         BinaryInstructions.inc_dx,
//         BinaryInstructions.inc_bx,
//         BinaryInstructions.inc_sp,
//         BinaryInstructions.inc_bp,
//         BinaryInstructions.inc_si,
//         BinaryInstructions.inc_di,
//         BinaryInstructions.dec_ax,
//         BinaryInstructions.dec_cx,
//         BinaryInstructions.dec_dx,
//         BinaryInstructions.dec_bx,
//         BinaryInstructions.dec_sp,
//         BinaryInstructions.dec_bp,
//         BinaryInstructions.dec_si,
//         BinaryInstructions.dec_di,
//         => {
//             return InstructionInfo{
//                 .destination_info = DestinationInfo{
//                     .address = switch (reg) {
//                         .ALAX => Address.ax,
//                         .CLCX => Address.cx,
//                         .DLDX => Address.dx,
//                         .BLBX => Address.bx,
//                         .AHSP => Address.sp,
//                         .CHBP => Address.bp,
//                         .DHSI => Address.si,
//                         .BHDI => Address.di,
//                     },
//                 },
//                 .source_info = SourceInfo{
//                     .none = {},
//                 },
//             };
//         },
//         BinaryInstructions.push_ax,
//         BinaryInstructions.push_cx,
//         BinaryInstructions.push_dx,
//         BinaryInstructions.push_bx,
//         BinaryInstructions.push_sp,
//         BinaryInstructions.push_bp,
//         BinaryInstructions.push_si,
//         BinaryInstructions.push_di,
//         BinaryInstructions.pop_ax,
//         BinaryInstructions.pop_cx,
//         BinaryInstructions.pop_dx,
//         BinaryInstructions.pop_bx,
//         BinaryInstructions.pop_sp,
//         BinaryInstructions.pop_bp,
//         BinaryInstructions.pop_si,
//         BinaryInstructions.pop_di,
//         => {
//             return InstructionInfo{
//                 .destination_info = DestinationInfo{
//                     .address = switch (reg) {
//                         .ALAX => Address.ax,
//                         .CLCX => Address.cx,
//                         .DLDX => Address.dx,
//                         .BLBX => Address.bx,
//                         .AHSP => Address.sp,
//                         .CHBP => Address.bp,
//                         .DHSI => Address.si,
//                         .BHDI => Address.di,
//                     },
//                 },
//                 .source_info = SourceInfo{
//                     .none = {},
//                 },
//             };
//         },
//         BinaryInstructions.nop_xchg_ax_ax,
//         => {
//             return InstructionInfo{
//                 .destination_info = DestinationInfo{
//                     .none = {},
//                 },
//                 .source_info = SourceInfo{
//                     .none = {},
//                 },
//             };
//         },
//         BinaryInstructions.xchg_ax_cx,
//         BinaryInstructions.xchg_ax_dx,
//         BinaryInstructions.xchg_ax_bx,
//         BinaryInstructions.xchg_ax_sp,
//         BinaryInstructions.xchg_ax_bp,
//         BinaryInstructions.xchg_ax_si,
//         BinaryInstructions.xchg_ax_di,
//         => {
//             return InstructionInfo{
//                 .destination_info = DestinationInfo{
//                     .address = Address.ax,
//                 },
//                 .source_info = SourceInfo{
//                     .address = switch (reg) {
//                         .ALAX => Address.ax, // Should never happen!
//                         .CLCX => Address.cx,
//                         .DLDX => Address.dx,
//                         .BLBX => Address.bx,
//                         .AHSP => Address.sp,
//                         .CHBP => Address.bp,
//                         .DHSI => Address.si,
//                         .BHDI => Address.di,
//                     },
//                 },
//             };
//         },
//         else => {
//             log.err("ERROR: {t} should not end up here.", .{opcode});
//             return InstructionInfo{
//                 .destination_info = DestinationInfo{
//                     .none = {},
//                 },
//                 .source_info = SourceInfo{
//                     .none = {},
//                 },
//             };
//         },
//     }
// }

// pub fn getImmediateToRegMemMovDest(
//     execution_unit: *ExecutionUnit,
//     mod: MOD,
//     rm: RM,
//     w: Width,
//     disp_lo: ?u8,
//     disp_hi: ?u8,
//     data: u8,
//     w_data: ?u8,
// ) InstructionInfo {
//     const Address = RegisterNames;
//     const source_payload: SourceInfo = SourceInfo{
//         .immediate = @bitCast(if (w == Width.word) (@as(u16, w_data.?) << 8) + data else @as(u16, data)),
//     };
//     var destination_payload: DestinationInfo = undefined;
//     switch (mod) {
//         .memoryModeNoDisplacement,
//         .memoryMode8BitDisplacement,
//         .memoryMode16BitDisplacement,
//         => {
//             destination_payload = DestinationInfo{
//                 .address_calculation = BusInterfaceUnit.calculateEffectiveAddress(
//                     execution_unit,
//                     w,
//                     mod,
//                     rm,
//                     disp_lo,
//                     disp_hi,
//                 ),
//             };
//         },
//         .registerModeNoDisplacement => {
//             switch (rm) {
//                 .ALAX_BXSI_BXSID8_BXSID16 => {
//                     destination_payload = DestinationInfo{
//                         .address = if (w == Width.word) Address.ax else Address.al,
//                     };
//                 },
//                 .CLCX_BXDI_BXDID8_BXDID16 => {
//                     destination_payload = DestinationInfo{
//                         .address = if (w == Width.word) Address.cx else Address.cl,
//                     };
//                 },
//                 .DLDX_BPSI_BPSID8_BPSID16 => {
//                     destination_payload = DestinationInfo{
//                         .address = if (w == Width.word) Address.dx else Address.dl,
//                     };
//                 },
//                 .BLBX_BPDI_BPDID8_BPDID16 => {
//                     destination_payload = DestinationInfo{
//                         .address = if (w == Width.word) Address.bx else Address.bl,
//                     };
//                 },
//                 .AHSP_SI_SID8_SID16 => {
//                     destination_payload = DestinationInfo{
//                         .address = if (w == Width.word) Address.sp else Address.ah,
//                     };
//                 },
//                 .CHBP_DI_DID8_DID16 => {
//                     destination_payload = DestinationInfo{
//                         .address = if (w == Width.word) Address.bp else Address.ch,
//                     };
//                 },
//                 .DHSI_DIRECTACCESS_BPD8_BPD16 => {
//                     destination_payload = DestinationInfo{
//                         .address = if (w == Width.word) Address.si else Address.dh,
//                     };
//                 },
//                 .BHDI_BX_BXD8_BXD16 => {
//                     destination_payload = DestinationInfo{
//                         .address = if (w == Width.word) Address.di else Address.bh,
//                     };
//                 },
//             }
//         },
//     }

//     return InstructionInfo{
//         .destination_info = destination_payload,
//         .source_info = source_payload,
//     };
// }
