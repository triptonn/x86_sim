//! Enter DocString

// TODO: Enter locator.zig DocString

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

/// Returns the destination and source operands of a asm-86 instruction as a
/// InstructionInfo union. If the destination and source cannot be computed
/// a LocatorError is returned specifying what failed. A ExecutionUnit reference,
/// the opcode and the InstructionData union from the decoder are needed as
/// parameters.
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
                => {
                    const Address = RegisterNames;
                    const w = instruction_data.accumulator_op.w;
                    const data_8: ?u8 = instruction_data.accumulator_op.data_8;
                    const data_lo: ?u8 = instruction_data.accumulator_op.data_lo;
                    const data_hi: ?u8 = instruction_data.accumulator_op.data_hi;

                    if (w == Width.byte) {
                        const signed_immed8: i8 = @bitCast(data_8.?);
                        return InstructionInfo{
                            .destination_info = DestinationInfo{
                                .address = Address.al,
                            },
                            .source_info = SourceInfo{
                                .immediate = @intCast(signed_immed8),
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
        .direct_op => {
            const DirectOps = decoder.ScopedInstruction(.DirectOp);
            const direct_ops: DirectOps = @enumFromInt(@intFromEnum(opcode));

            const Address = RegisterNames;
            switch (direct_ops) {

                // zig fmt: off

                .jo_jump_on_overflow,                       // OF=1
                .jno_jump_on_not_overflow,                  // OF=0
                .jb_jnae_jump_on_below_not_above_or_equal,  // CF=1
                .jnb_jae_jump_on_not_below_above_or_equal,  // CF=0
                .je_jz_jump_on_equal_zero,                  // ZF=1
                .jne_jnz_jumb_on_not_equal_not_zero,        // ZF=0
                .jbe_jna_jump_on_below_or_equal_above,      // (CF or ZF)=1
                .jnbe_ja_jump_on_not_below_or_equal_above,  // (CF of ZF)=0
                .js_jump_on_sign,                           // SF=1
                .jns_jump_on_not_sign,                      // SF=0
                .jp_jpe_jump_on_parity_parity_even,         // PF=1
                .jnp_jpo_jump_on_not_parity_parity_odd,     // PF=0
                .jl_jnge_jump_on_less_not_greater_or_equal, // (SF xor OF)=1
                .jnl_jge_jump_on_not_less_greater_or_equal, // (SF xor OF)=0
                .jle_jng_jump_on_less_or_equal_not_greater, // ((SF xor OF) or ZF)=1
                .jnle_jg_jump_on_not_less_or_equal_greater, // ((SF xor OF) or ZF)=0
                .jcxz_jump_on_cx_zero,                      // CX=0
                .loopne_loopnz_loop_while_not_zero_equal,   //
                .loope_loopz_loop_while_zero_equal,
                .loop_loop_cx_times,
                => {
                    const signed_ip_inc_8: i8 = @bitCast(instruction_data.direct_op.ip_inc_8.?);
                    return InstructionInfo{
                        .destination_info = DestinationInfo{
                            .address = Address.none, // for jumps the 'destination' is always IP
                        },
                        .source_info = SourceInfo{
                            .jump_distance = @intCast(signed_ip_inc_8),
                        },
                    };
                },
                .call_direct_intersegment,
                => {
                    const seg_lo: u8 = instruction_data.direct_op.seg_lo.?;
                    const seg_hi: u8 = instruction_data.direct_op.seg_hi.?;
                    const disp_lo: u8 = instruction_data.direct_op.disp_lo.?;
                    const disp_hi: u8 = instruction_data.direct_op.disp_hi.?;
                    const offset: u16 = (@as(u16, disp_hi) << 8) + disp_lo;
                    const segment: u16 = (@as(u16, seg_hi) << 8) + seg_lo;
                    return InstructionInfo{
                        .destination_info = DestinationInfo{
                            .intersegment = (@as(u20, segment) << 4) + offset,
                        },
                        .source_info = SourceInfo{
                            .none = {},
                        },
                    };
                },
                .call_direct_within_segment,
                => {
                    const ip_inc_lo: u8 = instruction_data.direct_op.ip_inc_lo.?;
                    const ip_inc_hi: u8 = instruction_data.direct_op.ip_inc_hi.?;
                    const offset: i16 = @bitCast((@as(u16, ip_inc_hi) << 8) + ip_inc_lo);
                    return InstructionInfo{
                        .destination_info = DestinationInfo{
                            .intrasegment = offset,
                        },
                        .source_info = SourceInfo{
                            .none = {},
                        },
                    };
                },
                .ret_within_seg_adding_immed16_to_sp,
                .ret_intersegment_adding_immed16_to_sp,
                => {
                    const data_lo: u8 = instruction_data.direct_op.data_lo.?;
                    const data_hi: u8 = instruction_data.direct_op.data_hi.?;
                    const immed_16: i16 = @bitCast((@as(u16, data_hi) << 8) + data_lo);
                    return InstructionInfo{
                        .destination_info = DestinationInfo{
                            .none = {},
                        },
                        .source_info = SourceInfo{
                            .immediate = immed_16,
                        },
                    };
                },
                .int_interrupt_type_specified,
                => {
                    const data_8: u8 = instruction_data.direct_op.data_8.?;
                    return InstructionInfo{
                        .destination_info = DestinationInfo{
                            .none = {},
                        },
                        .source_info = SourceInfo{
                            .unsigned_immediate = data_8,
                        },
                    };
                },
                .aam_ASCII_adjust_multiply,
                .aad_ASCII_adjust_divide,
                => {
                    return InstructionInfo{
                        .destination_info = DestinationInfo{
                            .none = {},
                        },
                        .source_info = SourceInfo{
                            .none = {},
                        }
                    };
                },
                .jmp_direct_within_segment => {
                    const ip_inc_lo: u8 = instruction_data.direct_op.ip_inc_lo.?;
                    const ip_inc_hi: u16 = @as(u16, instruction_data.direct_op.ip_inc_hi.?) << 8;
                    const ip_inc_16: i16 = @bitCast(ip_inc_hi + ip_inc_lo);
                    return InstructionInfo{
                        .destination_info = DestinationInfo{
                            .none = {},
                        },
                        .source_info = SourceInfo{
                            .jump_distance = ip_inc_16,
                        },
                    };
                },
                .jmp_direct_intersegment => {
                    const ip_lo: u8 = instruction_data.direct_op.ip_lo.?;
                    const ip_hi: u16 = @as(u16, instruction_data.direct_op.ip_hi.?) << 8;
                    const ip_16: u16 = ip_hi + ip_lo;
                    const cs_lo: u8 = instruction_data.direct_op.cs_lo.?;
                    const cs_hi: u16 = @as(u16, instruction_data.direct_op.cs_hi.?) << 8;
                    const cs_16: u16 = cs_hi + cs_lo;
                    return InstructionInfo{
                        .destination_info = DestinationInfo{
                            .none = {},
                        },
                        .source_info = SourceInfo{
                            .intersegment_direct_jump = [_]u16{ip_16, cs_16},
                        },
                    };
                },
                .jmp_direct_within_segment_short => {
                    const ip_inc_8: i16 = @intCast(instruction_data.direct_op.ip_inc_8.?);
                    return InstructionInfo{
                        .destination_info = DestinationInfo{
                            .none = {},
                        },
                        .source_info = SourceInfo{
                            .jump_distance = ip_inc_8,
                        },
                    };
                },

                // zig fmt: on
            }
        },
        .escape_op => return LocatorError.NotYetImplemented,
        .identifier_add_op => {
            const IdentifierAddOps = decoder.ScopedInstruction(.IdentifierAddOp);
            const identifier_add_ops: IdentifierAddOps = @enumFromInt(@intFromEnum(opcode));

            const w: Width = instruction_data.identifier_add_op.w;
            const mod: MOD = instruction_data.identifier_add_op.mod;
            const rm: RM = instruction_data.identifier_add_op.rm;
            const disp_lo: ?u8 = instruction_data.identifier_add_op.disp_lo;
            const disp_hi: ?u8 = instruction_data.identifier_add_op.disp_hi;
            const data_8: ?u8 = instruction_data.identifier_add_op.data_8;
            const data_lo: ?u8 = instruction_data.identifier_add_op.data_lo;
            const data_hi: ?u8 = instruction_data.identifier_add_op.data_hi;
            const data_sx: ?u8 = instruction_data.identifier_add_op.data_sx;

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
                    .registerModeNoDisplacement => DestinationInfo{
                        .address = registerNameFromRm(w, rm),
                    },
                },
                .source_info = src: switch (identifier_add_ops) {
                    .regmem8_immed8,
                    .regmem16_immed16,
                    => SourceInfo{
                        .unsigned_immediate = switch (w) {
                            Width.byte => @intCast(data_8.?),
                            Width.word => (@as(u16, data_hi.?) << 8) + data_lo.?,
                        },
                    },
                    .signed_regmem8_immed8,
                    => {
                        // Here a u16 value is simply cast to a i16 value (interpreted as signed bytes)
                        const unsigned_immed16_cast: u16 = @intCast(data_8.?);
                        break :src SourceInfo{
                            .immediate = @bitCast(unsigned_immed16_cast),
                        };
                    },
                    .sign_extend_regmem16_immed8,
                    => {
                        const signed_immed8_cast: i8 = @bitCast(data_sx.?);
                        break :src SourceInfo{
                            .immediate = @intCast(signed_immed8_cast),
                        };
                    },
                },
            };
        },
        .identifier_inc_op => {
            const identifier: IncSet = instruction_data.identifier_inc_op.identifier;
            const w: ?Width = instruction_data.identifier_inc_op.w;
            const mod: MOD = instruction_data.identifier_inc_op.mod;
            const rm: RM = instruction_data.identifier_inc_op.rm;
            const disp_lo: ?u8 = instruction_data.identifier_inc_op.disp_lo;
            const disp_hi: ?u8 = instruction_data.identifier_inc_op.disp_hi;
            switch (identifier) {
                IncSet.inc => {
                    return InstructionInfo{
                        .destination_info = DestinationInfo{
                            .address_calculation = BusInterfaceUnit.calculateEffectiveAddress(
                                EU,
                                w.?,
                                mod,
                                rm,
                                disp_lo,
                                disp_hi,
                            ),
                        },
                        .source_info = SourceInfo{
                            .none = {},
                        },
                    };
                },
                IncSet.dec => {
                    return InstructionInfo{
                        .destination_info = DestinationInfo{
                            .address_calculation = BusInterfaceUnit.calculateEffectiveAddress(
                                EU,
                                w.?,
                                mod,
                                rm,
                                disp_lo,
                                disp_hi,
                            ),
                        },
                        .source_info = SourceInfo{
                            .none = {},
                        },
                    };
                },
                IncSet.call_within,
                IncSet.call_intersegment,
                IncSet.jmp_within,
                IncSet.jmp_intersegment,
                => {
                    return InstructionInfo{
                        .destination_info = DestinationInfo{
                            .indirect_target = BusInterfaceUnit.calculateEffectiveAddress(
                                EU,
                                Width.word,
                                mod,
                                rm,
                                disp_lo,
                                disp_hi,
                            ),
                        },
                        .source_info = SourceInfo{
                            .none = {},
                        },
                    };
                },
                IncSet.push => {
                    return InstructionInfo{
                        .destination_info = DestinationInfo{
                            .none = {},
                        },
                        .source_info = SourceInfo{
                            .push_word = BusInterfaceUnit.calculateEffectiveAddress(
                                EU,
                                Width.word,
                                mod,
                                rm,
                                disp_lo,
                                disp_hi,
                            ),
                        },
                    };
                },
            }
        },
        .identifier_rol_op => {
            const Address = RegisterNames;
            const v: Variable = instruction_data.identifier_rol_op.v;
            const w: Width = instruction_data.identifier_rol_op.w;
            const mod: MOD = instruction_data.identifier_rol_op.mod;
            const rm: RM = instruction_data.identifier_rol_op.rm;
            const disp_lo: ?u8 = instruction_data.identifier_rol_op.disp_lo;
            const disp_hi: ?u8 = instruction_data.identifier_rol_op.disp_hi;
            return InstructionInfo{
                .destination_info = DestinationInfo{
                    .address_calculation = BusInterfaceUnit.calculateEffectiveAddress(
                        EU,
                        w,
                        mod,
                        rm,
                        disp_lo,
                        disp_hi,
                    ),
                },
                .source_info = switch (v) {
                    Variable.one => SourceInfo{
                        .immediate = 1,
                    },
                    Variable.in_CL => SourceInfo{
                        .address = Address.cl,
                    },
                },
            };
        },
        .identifier_test_op => {
            const IdentifierTestOps = decoder.ScopedInstruction(.IdentifierTestOp);
            const identifier_test_ops: IdentifierTestOps = @enumFromInt(@intFromEnum(opcode));

            const w: Width = instruction_data.identifier_test_op.w;
            const mod: ?MOD = instruction_data.identifier_test_op.mod;
            const identifier: TestSet = instruction_data.identifier_test_op.identifier;
            const rm: ?RM = instruction_data.identifier_test_op.rm;
            const disp_lo: ?u8 = instruction_data.identifier_test_op.disp_lo;
            const disp_hi: ?u8 = instruction_data.identifier_test_op.disp_hi;

            const data_8: ?u8 = instruction_data.identifier_test_op.data_8;
            const data_lo: ?u8 = instruction_data.identifier_test_op.data_lo;
            const data_hi: ?u8 = instruction_data.identifier_test_op.data_hi;

            return InstructionInfo{
                .destination_info = switch (identifier) {
                    .TEST,
                    .NOT,
                    .NEG,
                    => DestinationInfo{
                        .address_calculation = BusInterfaceUnit.calculateEffectiveAddress(
                            EU,
                            w,
                            mod.?,
                            rm.?,
                            disp_lo,
                            disp_hi,
                        ),
                    },
                    .MUL,
                    .IMUL,
                    .DIV,
                    .IDIV,
                    => DestinationInfo{ .none = {} },
                },
                .source_info = switch (identifier) {
                    .TEST => return SourceInfo{
                        .address_calculation = BusInterfaceUnit.calculateEffectiveAddress(
                            EU,
                            w,
                            mod,
                            rm,
                            disp_lo,
                            disp_hi,
                        ),
                    },
                },
            };
        },
        .immediate_to_memory_op => {
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
                        .address = registerNameFromRm(w, rm),
                    },
                },
                .source_info = SourceInfo{
                    .immediate = switch (w) {
                        .byte => @intCast(data_8.?),
                        .word => @intCast((@as(u16, data_hi.?) << 8) + data_lo.?),
                    },
                },
            };
        },
        .immediate_to_register_op => {
            const reg: REG = instruction_data.immediate_to_register_op.reg;
            const w: Width = instruction_data.immediate_to_register_op.w;
            const data_8: ?u8 = instruction_data.immediate_to_register_op.data_8;
            const data_lo: ?u8 = instruction_data.immediate_to_register_op.data_lo;
            const data_hi: ?u8 = instruction_data.immediate_to_register_op.data_hi;
            return InstructionInfo{
                .destination_info = DestinationInfo{
                    .address = registerNameFromReg(w, reg),
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
            // const Address = RegisterNames;
            const mod: MOD = instruction_data.register_memory_op.mod;
            const rm: RM = instruction_data.register_memory_op.rm;
            const disp_lo: ?u8 = instruction_data.register_memory_op.disp_lo;
            const disp_hi: ?u8 = instruction_data.register_memory_op.disp_hi;

            return InstructionInfo{
                .destination_info = DestinationInfo{
                    .pop_word = BusInterfaceUnit.calculateEffectiveAddress(
                        EU,
                        Width.word,
                        mod,
                        rm,
                        disp_lo,
                        disp_hi,
                    ),
                },
                .source_info = SourceInfo{
                    // .address = Address.sp,
                    .none = {},
                },
            };
        },
        .register_memory_to_from_register_op => {
            const RegisterMemoryToFromRegisterOps = decoder.ScopedInstruction(.RegisterMemoryToFromRegisterOp);
            const register_memory_to_from_register_ops: RegisterMemoryToFromRegisterOps = @enumFromInt(@intFromEnum(opcode));

            const Address = RegisterNames;
            const d: ?Direction = instruction_data.register_memory_to_from_register_op.d;
            const w: ?Width = instruction_data.register_memory_to_from_register_op.w;
            const mod: MOD = instruction_data.register_memory_to_from_register_op.mod;
            const reg: REG = instruction_data.register_memory_to_from_register_op.reg;
            const rm: RM = instruction_data.register_memory_to_from_register_op.rm;
            const disp_lo: ?u8 = instruction_data.register_memory_to_from_register_op.disp_lo;
            const disp_hi: ?u8 = instruction_data.register_memory_to_from_register_op.disp_hi;

            switch (register_memory_to_from_register_ops) {
                .add_regmem8_reg8,
                .add_regmem16_reg16,
                .add_reg8_regmem8,
                .add_reg16_regmem16,
                .or_regmem8_reg8,
                .or_regmem16_reg16,
                .or_reg8_regmem8,
                .or_reg16_regmem16,
                .adc_regmem8_reg8,
                .adc_regmem16_reg16,
                .adc_reg8_regmem8,
                .adc_reg16_regmem16,
                .sbb_regmem8_reg8,
                .sbb_regmem16_reg16,
                .sbb_reg8_regmem8,
                .sbb_reg16_regmem16,
                .and_regmem8_reg8,
                .and_regmem16_reg16,
                .and_reg8_regmem8,
                .and_reg16_regmem16,
                .sub_regmem8_reg8,
                .sub_regmem16_reg16,
                .sub_reg8_regmem8,
                .sub_reg16_regmem16,
                .xor_regmem8_reg8,
                .xor_regmem16_reg16,
                .xor_reg8_regmem8,
                .xor_reg16_regmem16,
                .cmp_regmem8_reg8,
                .cmp_regmem16_reg16,
                .cmp_reg8_regmem8,
                .cmp_reg16_regmem16,
                .mov_regmem8_reg8,
                .mov_regmem16_reg16,
                .mov_reg8_regmem8,
                .mov_reg16_regmem16,
                => {
                    const ea_calc: EffectiveAddressCalculation = BusInterfaceUnit.calculateEffectiveAddress(
                        EU,
                        w.?,
                        mod,
                        rm,
                        disp_lo,
                        disp_hi,
                    );
                    const register: Address = registerNameFromReg(w.?, reg);

                    return InstructionInfo{
                        .destination_info = switch (d.?) {
                            Direction.source => DestinationInfo{
                                .address_calculation = ea_calc,
                            },
                            Direction.destination => DestinationInfo{
                                .address = register,
                            },
                        },
                        .source_info = switch (d.?) {
                            Direction.source => SourceInfo{
                                .address = register,
                            },
                            Direction.destination => SourceInfo{
                                .address_calculation = ea_calc,
                            },
                        },
                    };
                },

                .xchg_reg8_regmem8,
                .xchg_reg16_regmem16,
                => {
                    const ea_calc: EffectiveAddressCalculation = BusInterfaceUnit.calculateEffectiveAddress(
                        EU,
                        w.?,
                        mod,
                        rm,
                        disp_lo,
                        disp_hi,
                    );
                    const register: Address = registerNameFromReg(w.?, reg);
                    return InstructionInfo{
                        .destination_info = DestinationInfo{
                            .address_calculation = ea_calc,
                        },
                        .source_info = SourceInfo{
                            .address = register,
                        },
                    };
                },
                .lea_reg16_mem16,
                .load_ds_regmem16,
                .load_es_regmem16,
                => {
                    const register: Address = registerNameFromReg(
                        Width.word,
                        reg,
                    );

                    return InstructionInfo{
                        .destination_info = DestinationInfo{
                            .address = register,
                        },
                        .source_info = SourceInfo{
                            .address_calculation = BusInterfaceUnit.calculateEffectiveAddress(
                                EU,
                                Width.word,
                                mod,
                                rm,
                                disp_lo,
                                disp_hi,
                            ),
                        },
                    };
                },
                .test_regmem8_reg8,
                .test_regmem16_reg16,
                => return LocatorError.NotYetImplemented,
            }
        },
        .register_op => {
            const RegisterOps = decoder.ScopedInstruction(.RegisterOp);
            const register_ops: RegisterOps = @enumFromInt(@intFromEnum(opcode));

            const Address = RegisterNames;
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
                            .address = registerNameFromReg(Width.word, reg),
                        },
                        .source_info = SourceInfo{
                            .none = {},
                        },
                    };
                },
                .nop_xchg_ax_ax,
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
                            .address = registerNameFromReg(Width.word, reg),
                        },
                    };
                },
            }
        },
        .segment_register_op => {
            const SegmentRegisterOps = decoder.ScopedInstruction(.SegmentRegisterOp);
            const segment_register_ops: SegmentRegisterOps = @enumFromInt(@intFromEnum(opcode));
            const Address = RegisterNames;

            const mod: ?MOD = instruction_data.segment_register_op.mod;
            const sr: SR = instruction_data.segment_register_op.sr;
            const rm: ?RM = instruction_data.segment_register_op.rm;
            const disp_lo: ?u8 = instruction_data.segment_register_op.disp_lo;
            const disp_hi: ?u8 = instruction_data.segment_register_op.disp_hi;

            switch (segment_register_ops) {
                .segment_override_prefix_es,
                .segment_override_prefix_cs,
                .segment_override_prefix_ss,
                .segment_override_prefix_ds,
                => {
                    // TODO: Add missing SegmentRegisterOp cases to getInstructionSourceAndDest()
                    return LocatorError.NotYetImplemented;
                },
                .push_es,
                .pop_es,
                => {
                    return InstructionInfo{
                        .destination_info = DestinationInfo{
                            .address = Address.es,
                        },
                        .source_info = SourceInfo{
                            .none = {},
                        },
                    };
                },
                .push_cs,
                => {
                    return InstructionInfo{
                        .destination_info = DestinationInfo{
                            .address = Address.cs,
                        },
                        .source_info = SourceInfo{
                            .none = {},
                        },
                    };
                },
                .push_ss,
                .pop_ss,
                => {
                    return InstructionInfo{
                        .destination_info = DestinationInfo{
                            .address = Address.ss,
                        },
                        .source_info = SourceInfo{
                            .none = {},
                        },
                    };
                },
                .push_ds,
                .pop_ds,
                => {
                    return InstructionInfo{
                        .destination_info = DestinationInfo{
                            .address = Address.ds,
                        },
                        .source_info = SourceInfo{
                            .none = {},
                        },
                    };
                },
                .mov_segreg_regmem16 => return InstructionInfo{
                    .destination_info = DestinationInfo{
                        .address = switch (sr) {
                            .ES => Address.es,
                            .CS => Address.cs,
                            .SS => Address.ss,
                            .DS => Address.ds,
                        },
                    },
                    .source_info = switch (mod.?) {
                        .memoryModeNoDisplacement,
                        .memoryMode8BitDisplacement,
                        .memoryMode16BitDisplacement,
                        => SourceInfo{
                            .address_calculation = BusInterfaceUnit.calculateEffectiveAddress(
                                EU,
                                Width.word,
                                mod.?,
                                rm.?,
                                disp_lo,
                                disp_hi,
                            ),
                        },
                        .registerModeNoDisplacement => SourceInfo{
                            .address = registerNameFromRm(Width.word, rm.?),
                        },
                    },
                },
                .mov_regmem16_segreg => return InstructionInfo{
                    .destination_info = switch (mod.?) {
                        .memoryModeNoDisplacement,
                        .memoryMode8BitDisplacement,
                        .memoryMode16BitDisplacement,
                        => DestinationInfo{
                            .address_calculation = BusInterfaceUnit.calculateEffectiveAddress(
                                EU,
                                Width.word,
                                mod.?,
                                rm.?,
                                disp_lo,
                                disp_hi,
                            ),
                        },
                        .registerModeNoDisplacement => DestinationInfo{
                            .address = registerNameFromRm(Width.word, rm.?),
                        },
                    },
                    .source_info = SourceInfo{
                        .address = switch (sr) {
                            .ES => Address.es,
                            .CS => Address.cs,
                            .SS => Address.ss,
                            .DS => Address.ds,
                        },
                    },
                },
            }
        },
        .single_byte_op => {
            const SingleByteOps = decoder.ScopedInstruction(.SingleByteOp);
            const single_byte_ops: SingleByteOps = @enumFromInt(@intFromEnum(opcode));

            const Address = RegisterNames;

            switch (single_byte_ops) {
                .in_al_dx,
                => {
                    return InstructionInfo{
                        .destination_info = DestinationInfo{
                            .address = Address.al,
                        },
                        .source_info = SourceInfo{
                            .address = Address.dx,
                        },
                    };
                },
                .in_ax_dx,
                => {
                    return InstructionInfo{
                        .destination_info = DestinationInfo{
                            .address = Address.ax,
                        },
                        .source_info = SourceInfo{
                            .address = Address.dx,
                        },
                    };
                },
                .out_al_dx,
                => {
                    return InstructionInfo{
                        .destination_info = DestinationInfo{
                            .address = Address.dx,
                        },
                        .source_info = SourceInfo{
                            .address = Address.al,
                        },
                    };
                },
                .out_ax_dx,
                => {
                    return InstructionInfo{
                        .destination_info = DestinationInfo{
                            .address = Address.dx,
                        },
                        .source_info = SourceInfo{
                            .address = Address.ax,
                        },
                    };
                },
                .xlat_translate_byte_to_al,
                .lahf,
                .sahf,
                .popf,
                .pushf,
                .aaa_ASCII_adjust_add,
                .daa_decimal_adjust_add,
                .aas_ASCII_adjust_sub,
                .das_decimal_adjust_sub,
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
                else => return LocatorError.NotYetImplemented,
            }
        },
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

// ========================================================================
//
// (C) Copyright 2025, Nicolas Selig, All Rights Reserved.
//
// This software is provided 'as-is', without any express or implied
// warranty. In no event will the authors be held liable for any damages
// arising from the use of this software.
//
// ========================================================================
