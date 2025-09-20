//! Hello

const std = @import("std");

const types = @import("types.zig");
const ModValue = types.instruction_fields.MOD;
const RegValue = types.instruction_fields.REG;
const SrValue = types.instruction_fields.SR;
const RmValue = types.instruction_fields.RM;
const DValue = types.instruction_fields.Direction;
const VValue = types.instruction_fields.Variable;
const WValue = types.instruction_fields.Width;
const ZValue = types.instruction_fields.Zero;
const SValue = types.instruction_fields.Sign;

const errors = @import("errors.zig");
const InstructionDecodeError = errors.InstructionDecodeError;

/// Given the Mod and R/M value of an add register/memory with register to either
/// instruction, this function returns the number of bytes this instruction consists
/// of as a u3 value. Returns 1 if the instruction_name is not known to skip this instruction.
pub fn addGetInstructionLength(
    instruction_name: BinaryInstructions,
    mod: ?ModValue,
    rm: ?RmValue,
) u3 {
    const log = std.log.scoped(.addGetInstructionLength);
    switch (instruction_name) {
        .add_regmem8_reg8,
        .add_regmem16_reg16,
        .add_reg8_regmem8,
        .add_reg16_regmem16,
        => switch (mod.?) {
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
pub fn immediateOpGetInstructionLength(
    instruction_name: BinaryInstructions,
    mod: ModValue,
    rm: RmValue,
) u3 {
    const log = std.log.scoped(.immediateOpGetInstructionLength);
    switch (instruction_name) {
        .regmem8_immed8 => switch (mod) {
            .memoryModeNoDisplacement => if (rm != RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) return 3 else return 5,
            .memoryMode8BitDisplacement => return 4,
            .memoryMode16BitDisplacement => return 5,
            .registerModeNoDisplacement => return 3,
        },
        .regmem16_immed16 => switch (mod) {
            .memoryModeNoDisplacement => if (rm != RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) return 4 else return 6,
            .memoryMode8BitDisplacement => return 5,
            .memoryMode16BitDisplacement => return 6,
            .registerModeNoDisplacement => return 4,
        },
        .signed_regmem8_immed8 => switch (mod) {
            .memoryModeNoDisplacement => if (rm != RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) return 3 else return 5,
            .memoryMode8BitDisplacement => return 4,
            .memoryMode16BitDisplacement => return 5,
            .registerModeNoDisplacement => return 3,
        },
        .sign_extend_regmem16_immed8 => switch (mod) {
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

/// Given the Mod and R/M value of a mov register/memory to/from register
/// instruction, this function returns the number of bytes this instruction
/// consists of as a u3 value. Returns 1 if the instruction_name is not known
/// to skip this instruction.
pub fn movGetInstructionLength(
    instruction_name: BinaryInstructions,
    w: WValue,
    mod: ?ModValue,
    rm: ?RmValue,
) u3 {
    const log = std.log.scoped(.movGetInstructionLength);
    switch (instruction_name) {
        .mov_regmem8_reg8,
        .mov_regmem16_reg16,
        .mov_reg8_regmem8,
        .mov_reg16_regmem16,
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
        .mov_al_immed8,
        .mov_cl_immed8,
        .mov_dl_immed8,
        .mov_bl_immed8,
        .mov_ah_immed8,
        .mov_ch_immed8,
        .mov_dh_immed8,
        .mov_bh_immed8,
        .mov_ax_immed16,
        .mov_cx_immed16,
        .mov_dx_immed16,
        .mov_bx_immed16,
        .mov_sp_immed16,
        .mov_bp_immed16,
        .mov_si_immed16,
        .mov_di_immed16,
        => {
            if (w == WValue.word) return 3 else return 2;
        },
        .mov_regmem16_segreg,
        .mov_segreg_regmem16,
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
        .mov_al_mem8,
        .mov_ax_mem16,
        .mov_mem8_al,
        .mov_mem16_ax,
        => {
            return 3;
        },
        .mov_mem8_immed8,
        .mov_mem16_immed16,
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

/// Categorizing the x86 instruction set into subsets with similar
/// encoding.
pub const InstructionScope = enum {
    AccumulatorOp,
    EscapeOp,
    RegisterMemoryToFromRegisterOp,
    RegisterMemoryOp,
    RegisterOp,
    ImmediateToRegisterOp,
    ImmediateToMemoryOp,
    SegmentRegisterOp,
    IdentifierAddOp,
    IdentifierRolOp,
    IdentifierTestOp,
    IdentifierIncOp,
    DirectOp,
    SingleByteOp,
};

/// Provided an x86 instruction opcode this function returns the
/// InstructionsScope this opcode belongs to.
pub fn instructionScope(opcode: BinaryInstructions) InstructionScope {
    return switch (opcode) {

        /////////////////////////////////////////////////////////////
        // Accumulator opcodes
        /////////////////////////////////////////////////////////////

        BinaryInstructions.add_al_immed8,
        BinaryInstructions.add_ax_immed16,
        BinaryInstructions.or_al_immed8,
        BinaryInstructions.or_ax_immed16,
        BinaryInstructions.adc_al_immed8,
        BinaryInstructions.adc_ax_immed16,
        BinaryInstructions.sbb_al_immed8,
        BinaryInstructions.sbb_ax_immed16,
        BinaryInstructions.and_al_immed8,
        BinaryInstructions.and_ax_immed16,
        BinaryInstructions.sub_al_immed8,
        BinaryInstructions.sub_ax_immed16,
        BinaryInstructions.xor_al_immed8,
        BinaryInstructions.xor_ax_immed16,
        BinaryInstructions.cmp_al_immed8,
        BinaryInstructions.cmp_ax_immed16,
        BinaryInstructions.test_al_immed8,
        BinaryInstructions.test_ax_immed16,
        BinaryInstructions.in_al_immed8,
        BinaryInstructions.in_ax_immed8,
        BinaryInstructions.out_al_immed8,
        BinaryInstructions.out_ax_immed8,
        BinaryInstructions.mov_al_mem8,
        BinaryInstructions.mov_ax_mem16,
        BinaryInstructions.mov_mem8_al,
        BinaryInstructions.mov_mem16_ax,
        => InstructionScope.AccumulatorOp,

        /////////////////////////////////////////////////////////////
        // Escape opcodes
        /////////////////////////////////////////////////////////////

        BinaryInstructions.esc_external_opcode_000_yyy_source,
        BinaryInstructions.esc_external_opcode_001_yyy_source,
        BinaryInstructions.esc_external_opcode_010_yyy_source,
        BinaryInstructions.esc_external_opcode_011_yyy_source,
        BinaryInstructions.esc_external_opcode_100_yyy_source,
        BinaryInstructions.esc_external_opcode_101_yyy_source,
        BinaryInstructions.esc_external_opcode_110_yyy_source,
        BinaryInstructions.esc_external_opcode_111_yyy_source,
        => InstructionScope.EscapeOp,

        /////////////////////////////////////////////////////////////
        // Register/memory to/from register opcodes
        /////////////////////////////////////////////////////////////

        BinaryInstructions.add_regmem8_reg8,
        BinaryInstructions.add_regmem16_reg16,
        BinaryInstructions.add_reg8_regmem8,
        BinaryInstructions.add_reg16_regmem16,
        BinaryInstructions.or_regmem8_reg8,
        BinaryInstructions.or_regmem16_reg16,
        BinaryInstructions.or_reg8_regmem8,
        BinaryInstructions.or_reg16_regmem16,
        BinaryInstructions.adc_regmem8_reg8,
        BinaryInstructions.adc_regmem16_reg16,
        BinaryInstructions.adc_reg8_regmem8,
        BinaryInstructions.adc_reg16_regmem16,
        BinaryInstructions.sbb_regmem8_reg8,
        BinaryInstructions.sbb_regmem16_reg16,
        BinaryInstructions.sbb_reg8_regmem8,
        BinaryInstructions.sbb_reg16_regmem16,
        BinaryInstructions.and_regmem8_reg8,
        BinaryInstructions.and_regmem16_reg16,
        BinaryInstructions.and_reg8_regmem8,
        BinaryInstructions.and_reg16_regmem16,
        BinaryInstructions.sub_regmem8_reg8,
        BinaryInstructions.sub_regmem16_reg16,
        BinaryInstructions.sub_reg8_regmem8,
        BinaryInstructions.sub_reg16_regmem16,
        BinaryInstructions.xor_regmem8_reg8,
        BinaryInstructions.xor_regmem16_reg16,
        BinaryInstructions.xor_reg8_regmem8,
        BinaryInstructions.xor_reg16_regmem16,
        BinaryInstructions.cmp_regmem8_reg8,
        BinaryInstructions.cmp_regmem16_reg16,
        BinaryInstructions.cmp_reg8_regmem8,
        BinaryInstructions.cmp_reg16_regmem16,
        BinaryInstructions.test_regmem8_reg8,
        BinaryInstructions.test_regmem16_reg16,
        BinaryInstructions.xchg_reg8_regmem8,
        BinaryInstructions.xchg_reg16_regmem16,
        BinaryInstructions.mov_regmem8_reg8,
        BinaryInstructions.mov_regmem16_reg16,
        BinaryInstructions.mov_reg8_regmem8,
        BinaryInstructions.mov_reg16_regmem16,
        BinaryInstructions.lea_reg16_mem16,
        BinaryInstructions.load_es_regmem16,
        BinaryInstructions.load_ds_regmem16,
        => InstructionScope.RegisterMemoryToFromRegisterOp,

        /////////////////////////////////////////////////////////////
        // Register/memory opcodes
        /////////////////////////////////////////////////////////////

        BinaryInstructions.pop_regmem16,
        => InstructionScope.RegisterMemoryOp,

        /////////////////////////////////////////////////////////////
        // Register opcodes
        /////////////////////////////////////////////////////////////

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
        BinaryInstructions.nop_xchg_ax_ax,
        BinaryInstructions.xchg_ax_cx,
        BinaryInstructions.xchg_ax_dx,
        BinaryInstructions.xchg_ax_bx,
        BinaryInstructions.xchg_ax_sp,
        BinaryInstructions.xchg_ax_bp,
        BinaryInstructions.xchg_ax_si,
        BinaryInstructions.xchg_ax_di,
        => InstructionScope.RegisterOp,

        /////////////////////////////////////////////////////////////
        // Immediate to register opcodes
        /////////////////////////////////////////////////////////////

        BinaryInstructions.mov_al_immed8,
        BinaryInstructions.mov_cl_immed8,
        BinaryInstructions.mov_dl_immed8,
        BinaryInstructions.mov_bl_immed8,
        BinaryInstructions.mov_ah_immed8,
        BinaryInstructions.mov_ch_immed8,
        BinaryInstructions.mov_dh_immed8,
        BinaryInstructions.mov_bh_immed8,
        BinaryInstructions.mov_ax_immed16,
        BinaryInstructions.mov_cx_immed16,
        BinaryInstructions.mov_dx_immed16,
        BinaryInstructions.mov_bx_immed16,
        BinaryInstructions.mov_sp_immed16,
        BinaryInstructions.mov_bp_immed16,
        BinaryInstructions.mov_si_immed16,
        BinaryInstructions.mov_di_immed16,
        => InstructionScope.ImmediateToRegisterOp,

        /////////////////////////////////////////////////////////////
        // Immediate to memory opcodes
        /////////////////////////////////////////////////////////////

        BinaryInstructions.mov_mem8_immed8,
        BinaryInstructions.mov_mem16_immed16,
        => InstructionScope.ImmediateToMemoryOp,

        /////////////////////////////////////////////////////////////
        // Segment register opcodes
        /////////////////////////////////////////////////////////////

        BinaryInstructions.push_es,
        BinaryInstructions.pop_es,
        BinaryInstructions.push_cs,
        BinaryInstructions.push_ss,
        BinaryInstructions.pop_ss,
        BinaryInstructions.push_ds,
        BinaryInstructions.pop_ds,
        BinaryInstructions.segment_override_prefix_es,
        BinaryInstructions.segment_override_prefix_cs,
        BinaryInstructions.segment_override_prefix_ss,
        BinaryInstructions.segment_override_prefix_ds,
        BinaryInstructions.mov_regmem16_segreg,
        BinaryInstructions.mov_segreg_regmem16,
        => InstructionScope.SegmentRegisterOp,

        /////////////////////////////////////////////////////////////
        // Identifier add opcodes
        /////////////////////////////////////////////////////////////

        BinaryInstructions.regmem8_immed8,
        BinaryInstructions.regmem16_immed16,
        BinaryInstructions.signed_regmem8_immed8,
        BinaryInstructions.sign_extend_regmem16_immed8,
        => InstructionScope.IdentifierAddOp,

        /////////////////////////////////////////////////////////////
        // Identifier rol opcodes
        /////////////////////////////////////////////////////////////

        BinaryInstructions.logical_regmem8,
        BinaryInstructions.logical_regmem8_cl,
        BinaryInstructions.logical_regmem16,
        BinaryInstructions.logical_regmem16_cl,
        => InstructionScope.IdentifierRolOp,

        /////////////////////////////////////////////////////////////
        // Identifier test opcodes
        /////////////////////////////////////////////////////////////

        BinaryInstructions.logical_regmem8_immed8,
        BinaryInstructions.logical_regmem16_immed16,
        => InstructionScope.IdentifierTestOp,

        /////////////////////////////////////////////////////////////
        // Identifier inc opcodes
        /////////////////////////////////////////////////////////////

        BinaryInstructions.regmem8,
        BinaryInstructions.regmem16,
        => InstructionScope.IdentifierIncOp,

        /////////////////////////////////////////////////////////////
        // Direct opcodes
        /////////////////////////////////////////////////////////////

        BinaryInstructions.jo_jump_on_overflow,
        BinaryInstructions.jno_jump_on_not_overflow,
        BinaryInstructions.jb_jnae_jump_on_below_not_above_or_equal,
        BinaryInstructions.jnb_jae_jump_on_not_below_above_or_equal,
        BinaryInstructions.je_jz_jump_on_equal_zero,
        BinaryInstructions.jne_jnz_jumb_on_not_equal_not_zero,
        BinaryInstructions.jbe_jna_jump_on_below_or_equal_above,
        BinaryInstructions.jnbe_ja_jump_on_not_below_or_equal_above,
        BinaryInstructions.js_jump_on_sign,
        BinaryInstructions.jns_jump_on_not_sign,
        BinaryInstructions.jp_jpe_jump_on_parity_parity_even,
        BinaryInstructions.jnp_jpo_jump_on_not_parity_parity_odd,
        BinaryInstructions.jl_jnge_jump_on_less_not_greater_or_equal,
        BinaryInstructions.jnl_jge_jump_on_not_less_greater_or_equal,
        BinaryInstructions.jle_jng_jump_on_less_or_equal_not_greater,
        BinaryInstructions.jnle_jg_jump_on_not_less_or_equal_greater,
        BinaryInstructions.int_interrupt_type_specified,
        BinaryInstructions.aam_ASCII_adjust_multiply,
        BinaryInstructions.aad_ASCII_adjust_divide,
        BinaryInstructions.loopne_loopnz_loop_while_not_zero_equal,
        BinaryInstructions.loope_loopz_loop_while_zero_equal,
        BinaryInstructions.loop_loop_cx_times,
        BinaryInstructions.jcxz_jump_on_cx_zero,
        BinaryInstructions.call_direct_intersegment,
        BinaryInstructions.call_direct_within_segment,
        BinaryInstructions.ret_within_seg_adding_immed16_to_sp,
        BinaryInstructions.ret_intersegment_adding_immed16_to_sp,
        BinaryInstructions.jmp_direct_within_segment,
        BinaryInstructions.jmp_direct_intersegment,
        BinaryInstructions.jmp_direct_within_segment_short,
        => InstructionScope.DirectOp,

        /////////////////////////////////////////////////////////////
        // Single byte opcodes
        /////////////////////////////////////////////////////////////

        BinaryInstructions.daa_decimal_adjust_add,
        BinaryInstructions.das_decimal_adjust_sub,
        BinaryInstructions.aaa_ASCII_adjust_add,
        BinaryInstructions.aas_ASCII_adjust_sub,
        BinaryInstructions.cbw_byte_to_word,
        BinaryInstructions.cwd_word_to_double_word,
        BinaryInstructions.wait,
        BinaryInstructions.pushf,
        BinaryInstructions.popf,
        BinaryInstructions.sahf,
        BinaryInstructions.lahf,
        BinaryInstructions.ret_within_segment,
        BinaryInstructions.ret_intersegment,
        BinaryInstructions.int_interrupt_type_3,
        BinaryInstructions.into_interrupt_on_overflow,
        BinaryInstructions.iret_interrupt_return,
        BinaryInstructions.xlat_translate_byte_to_al,
        BinaryInstructions.in_al_dx,
        BinaryInstructions.in_ax_dx,
        BinaryInstructions.out_al_dx,
        BinaryInstructions.out_ax_dx,
        BinaryInstructions.lock_bus_lock_prefix,
        BinaryInstructions.halt,
        BinaryInstructions.cmc_complement_carry,
        BinaryInstructions.clc_clear_carry,
        BinaryInstructions.stc_set_carry,
        BinaryInstructions.cli_clear_interrupt,
        BinaryInstructions.sti_set_interrupt,
        BinaryInstructions.cld_clear_direction,
        BinaryInstructions.std_set_direction,
        BinaryInstructions.movs_byte,
        BinaryInstructions.movs_word,
        BinaryInstructions.cmps_byte,
        BinaryInstructions.cmps_word,
        BinaryInstructions.stos_byte,
        BinaryInstructions.stos_word,
        BinaryInstructions.lods_byte,
        BinaryInstructions.lods_word,
        BinaryInstructions.scas_byte,
        BinaryInstructions.scas_word,
        BinaryInstructions.repne_repnz_not_equal_zero,
        BinaryInstructions.rep_repe_repz_equal_zero,
        => InstructionScope.SingleByteOp,
    };
}

/// Provided a InstructionScope, this function returns an enum containing
/// all x86 opcodes belonging to this InstructionScope.
pub fn ScopedInstruction(comptime scope: InstructionScope) type {
    const all_instructions = @typeInfo(BinaryInstructions).@"enum";
    var i: usize = 0;
    var instructions: [all_instructions.len]std.builtin.Type.EnumField = undefined;
    for (all_instructions) |instruction| {
        if (instructionScope(instruction) == scope) {
            instructions[i] = instruction;
            i += 1;
        }
    }

    return @Type(
        .{
            .@"enum" = .{
                .is_exhaustive = true,
                .tag_type = null,
                .fields = instructions[0..i],
                .decls = &.{},
            },
        },
    );
}

// zig fmt: off

/// Contains all 8086 ASM-86 opcodes
pub const BinaryInstructions = enum(u8) {
    /// Register 8 bit with register/memory to register/memory 8 bit.
    add_regmem8_reg8                            = 0x00,
    /// Register 16 bit with register/memory to register/memory 16 bit.
    add_regmem16_reg16                          = 0x01,
    /// Register/Memory 8 bit with register to register 8 bit.
    add_reg8_regmem8                            = 0x02,
    /// Register/Memory 16 bit with register to register 16 bit.
    add_reg16_regmem16                          = 0x03,
    /// Add 8 bit immediate value to al.
    add_al_immed8                               = 0x04,
    /// Add 16 bit immediate value to ax.
    add_ax_immed16                              = 0x05,

    // TODO: Implement push/pop segment register es
    push_es                                     = 0x06,
    pop_es                                      = 0x07,

    // TODO: Implement or
    or_regmem8_reg8                             = 0x08,
    or_regmem16_reg16                           = 0x09,
    or_reg8_regmem8                             = 0x0A,
    or_reg16_regmem16                           = 0x0B,

    // TODO: Implement or immediate value to accumulator
    or_al_immed8                                = 0x0C,
    or_ax_immed16                               = 0x0D,

    // TODO: Implement push segment register cs
    push_cs                                     = 0x0E,

    // TODO: Implement adc
    adc_regmem8_reg8                            = 0x10,
    adc_regmem16_reg16                          = 0x11,
    adc_reg8_regmem8                            = 0x12,
    adc_reg16_regmem16                          = 0x13,

    // TODO: Implement adc immediate value to accumulator
    adc_al_immed8                               = 0x14,
    adc_ax_immed16                              = 0x15,

    // TODO: Implement push/pop segment register ss
    push_ss                                     = 0x16,
    pop_ss                                      = 0x17,

    // TODO: Implement sbb
    sbb_regmem8_reg8                            = 0x18,
    sbb_regmem16_reg16                          = 0x19,
    sbb_reg8_regmem8                            = 0x1A,
    sbb_reg16_regmem16                          = 0x1B,

    // TODO: Implement sbb immediate value from accumulator
    sbb_al_immed8                               = 0x1C,
    sbb_ax_immed16                              = 0x1D,

    // TODO: Implement push/pop segment register ss
    push_ds                                     = 0x1E,
    pop_ds                                      = 0x1F,

    // TODO: Implement and
    and_regmem8_reg8                            = 0x20,
    and_regmem16_reg16                          = 0x21,
    and_reg8_regmem8                            = 0x22,
    and_reg16_regmem16                          = 0x23,

    // TODO: Implement and immediate value with accumulator
    and_al_immed8                               = 0x24,
    and_ax_immed16                              = 0x25,

    // TODO: Implement es segment override prefix
    segment_override_prefix_es                  = 0x26,

    // TODO: Implement daa
    daa_decimal_adjust_add                      = 0x27,

    // TODO: Implement sub
    sub_regmem8_reg8                            = 0x28,
    sub_regmem16_reg16                          = 0x29,
    sub_reg8_regmem8                            = 0x2A,
    sub_reg16_regmem16                          = 0x2B,

    // TODO: Implement sub immediate value from accumulator
    sub_al_immed8                               = 0x2C,
    sub_ax_immed16                              = 0x2D,

    // TODO: Implement cs segment override prefix
    segment_override_prefix_cs                  = 0x2E,

    // TODO: Implement das
    das_decimal_adjust_sub                      = 0x2F,

    // TODO: Implement xor
    xor_regmem8_reg8                            = 0x30,
    xor_regmem16_reg16                          = 0x31,
    xor_reg8_regmem8                            = 0x32,
    xor_reg16_regmem16                          = 0x33,

    // TODO: Implement xor immediate value to accumulator
    xor_al_immed8                               = 0x34,
    xor_ax_immed16                              = 0x35,

    // TODO: Implement ss segment override prefix
    segment_override_prefix_ss                  = 0x36,

    // TODO: Implement aaa
    aaa_ASCII_adjust_add                        = 0x37,

    // TODO: Implement cmp
    cmp_regmem8_reg8                            = 0x38,
    cmp_regmem16_reg16                          = 0x39,
    cmp_reg8_regmem8                            = 0x3A,
    cmp_reg16_regmem16                          = 0x3B,

    // TODO: Implement cmp immediate value with accumulator
    cmp_al_immed8                               = 0x3C,
    cmp_ax_immed16                              = 0x3D,

    // TODO: Implement ds segment override prefix
    segment_override_prefix_ds                  = 0x3E,

    // TODO: Implement aas
    aas_ASCII_adjust_sub                        = 0x3F,

    // TODO: Implement inc register
    inc_ax                                      = 0x40,
    inc_cx                                      = 0x41,
    inc_dx                                      = 0x42,
    inc_bx                                      = 0x43,
    inc_sp                                      = 0x44,
    inc_bp                                      = 0x45,
    inc_si                                      = 0x46,
    inc_di                                      = 0x47,

    // TODO: Implement dec register
    dec_ax                                      = 0x48,
    dec_cx                                      = 0x49,
    dec_dx                                      = 0x4A,
    dec_bx                                      = 0x4B,
    dec_sp                                      = 0x4C,
    dec_bp                                      = 0x4D,
    dec_si                                      = 0x4E,
    dec_di                                      = 0x4F,

    // TODO: Push register
    push_ax                                     = 0x50,
    push_cx                                     = 0x51,
    push_dx                                     = 0x52,
    push_bx                                     = 0x53,
    push_sp                                     = 0x54,
    push_bp                                     = 0x55,
    push_si                                     = 0x56,
    push_di                                     = 0x57,

    // TODO: Pop register
    pop_ax                                      = 0x58,
    pop_cx                                      = 0x59,
    pop_dx                                      = 0x5A,
    pop_bx                                      = 0x5B,
    pop_sp                                      = 0x5C,
    pop_bp                                      = 0x5D,
    pop_si                                      = 0x5E,
    pop_di                                      = 0x5F,

    // TODO: Implement jumps
    jo_jump_on_overflow                         = 0x70,
    jno_jump_on_not_overflow                    = 0x71,
    jb_jnae_jump_on_below_not_above_or_equal    = 0x72,
    jnb_jae_jump_on_not_below_above_or_equal    = 0x73,
    je_jz_jump_on_equal_zero                    = 0x74,
    jne_jnz_jumb_on_not_equal_not_zero          = 0x75,
    jbe_jna_jump_on_below_or_equal_above        = 0x76,
    jnbe_ja_jump_on_not_below_or_equal_above    = 0x77,
    js_jump_on_sign                             = 0x78,
    jns_jump_on_not_sign                        = 0x79,
    jp_jpe_jump_on_parity_parity_even           = 0x7A,
    jnp_jpo_jump_on_not_parity_parity_odd       = 0x7B,
    jl_jnge_jump_on_less_not_greater_or_equal   = 0x7C,
    jnl_jge_jump_on_not_less_greater_or_equal   = 0x7D,
    jle_jng_jump_on_less_or_equal_not_greater   = 0x7E,
    jnle_jg_jump_on_not_less_or_equal_greater   = 0x7F,

    /// Immediate 8 bit value <action> to/with/from 8 bit register/memory operation (DATA-8).
    regmem8_immed8                              = 0x80,
    /// Immediate 16 bit value <action> to/with/from 16 bit register/memory operation (DATA-LO, DATA-HI).
    regmem16_immed16                            = 0x81,
    /// Signed immediate value <action> to/with/from 16 bit register/memory operation (DATA-8).
    signed_regmem8_immed8                       = 0x82,
    /// Auto-sign-extend immediate 8 bit value <action> to/with/from 16 bit register/memory operation (DATA-SX).
    sign_extend_regmem16_immed8                 = 0x83,

    // TODO: Implement test
    test_regmem8_reg8                           = 0x84,
    test_regmem16_reg16                         = 0x85,

    // TODO: Implmement xchg
    xchg_reg8_regmem8                           = 0x86,
    xchg_reg16_regmem16                         = 0x87,

    /// 8 bit Register/memory to/from register with Reg defining the source
    /// and R/M defining the destination. If R/M is .DHSI_DIRECTACCESS_BPD8_BPD16
    /// (0b110) a 16 bit displacement follows, so the instruction length is 4 bytes.
    mov_regmem8_reg8                            = 0x88,
    /// 16 bit Register/memory to/from register with Reg defining the source
    /// and R/M defining the destination for the instruction
    mov_regmem16_reg16                          = 0x89,
    /// 8 bit Register/memory to/from register
    mov_reg8_regmem8                            = 0x8A,
    /// 16 bit Register/memory to/from register
    mov_reg16_regmem16                          = 0x8B,
    /// Segment register to register/memory if second byte of format 0x|MOD|0|SR|R/M|
    mov_regmem16_segreg                         = 0x8C,

    // TODO: Implement load ea to register
    lea_reg16_mem16                             = 0x8D,

    /// Register/memory to segment register if second byte of format 0x|MOD|0|SR|R/M|
    mov_segreg_regmem16                         = 0x8E,

    // TODO: Implement Register/memory pop
    pop_regmem16                                = 0x8F,

    // TODO: Implement no op
    nop_xchg_ax_ax                              = 0x90,

    // TODO: Implement xchg
    xchg_ax_cx                                  = 0x91,
    xchg_ax_dx                                  = 0x92,
    xchg_ax_bx                                  = 0x93,
    xchg_ax_sp                                  = 0x94,
    xchg_ax_bp                                  = 0x95,
    xchg_ax_si                                  = 0x96,
    xchg_ax_di                                  = 0x97,

    // TODO: Implement cbw
    cbw_byte_to_word                            = 0x98,

    // TODO: Implement cwd
    cwd_word_to_double_word                     = 0x99,

    /// SP is decremented by two, CS is pushed onto the stack. CS is
    /// replaced by the segment word contained in the instruction. IP is
    /// pushed onto the stack and is replaced by the offset word
    /// contained in the instruction.
    call_direct_intersegment                    = 0x9A,

    // TODO: Implement wait
    wait                                        = 0x9B,

    // TODO: Implement push flags
    pushf                                       = 0x9C,

    // TODO: Implement pop flags
    popf                                        = 0x9D,

    // TODO: Implement store ah into flags sahf
    sahf                                        = 0x9E,

    // TODO: Implement load ah with flags lahf
    lahf                                        = 0x9F,

    /// Memory to accumulator
    mov_al_mem8                                 = 0xA0,
    /// Memory to accumulator
    mov_ax_mem16                                = 0xA1,
    /// Accumulator to memory
    mov_mem8_al                                 = 0xA2,
    /// Accumulator to memory
    mov_mem16_ax                                = 0xA3,

    // TODO: Implement movs
    movs_byte                                   = 0xA4,
    movs_word                                   = 0xA5,

    // TODO: Implement cmps
    cmps_byte                                   = 0xA6,
    cmps_word                                   = 0xA7,

    // TODO: Implement immediate and accumulator
    test_al_immed8                              = 0xA8,
    test_ax_immed16                             = 0xA9,

    // TODO: Implement stos
    stos_byte                                   = 0xAA,
    stos_word                                   = 0xAB,

    // TODO: Implement lods
    lods_byte                                   = 0xAC,
    lods_word                                   = 0xAD,

    // TODO: Implement scas
    scas_byte                                   = 0xAE,
    scas_word                                   = 0xAF,

    /// 8 bit Immediate to register al
    mov_al_immed8                               = 0xB0,
    /// 8 bit Immediate to register cl
    mov_cl_immed8                               = 0xB1,
    /// 8 bit Immediate to register dl
    mov_dl_immed8                               = 0xB2,
    /// 8 bit Immediate to register bl
    mov_bl_immed8                               = 0xB3,
    /// 8 bit Immediate to register ah
    mov_ah_immed8                               = 0xB4,
    /// 8 bit Immediate to register ch
    mov_ch_immed8                               = 0xB5,
    /// 8 bit Immediate to register dh
    mov_dh_immed8                               = 0xB6,
    /// 8 bit Immediate to register bh
    mov_bh_immed8                               = 0xB7,
    /// 8 bit Immediate to register ax
    mov_ax_immed16                              = 0xB8,
    /// 16 bit Immediate to register cx
    mov_cx_immed16                              = 0xB9,
    /// 16 bit Immediate to register dx
    mov_dx_immed16                              = 0xBA,
    /// 16 bit Immediate to register bx
    mov_bx_immed16                              = 0xBB,
    /// 16 bit Immediate to register sp
    mov_sp_immed16                              = 0xBC,
    /// 16 bit Immediate to register bp
    mov_bp_immed16                              = 0xBD,
    /// 16 bit Immediate to register si
    mov_si_immed16                              = 0xBE,
    /// 16 bit Immediate to register di
    mov_di_immed16                              = 0xBF,

    // TODO: Implement ret - return
    ret_within_seg_adding_immed16_to_sp         = 0xC2,
    ret_within_segment                          = 0xC3,

    /// Load pointer to ES
    load_es_regmem16                            = 0xC4,
    /// Load pointer to DS
    load_ds_regmem16                            = 0xC5,

    /// Immediate to register/memory
    mov_mem8_immed8                             = 0xC6,
    /// Immediate to register/memory
    mov_mem16_immed16                           = 0xC7,

    // TODO: Implement ret - return
    ret_intersegment_adding_immed16_to_sp       = 0xCA,
    ret_intersegment                            = 0xCB,

    // TODO: Implement int - interrupt
    int_interrupt_type_3                        = 0xCC,
    int_interrupt_type_specified                = 0xCD,
    into_interrupt_on_overflow                  = 0xCE,
    iret_interrupt_return                       = 0xCF,

    // TODO: Implement rotate
    // TODO: Implement shift
    logical_regmem8                             = 0xD0,
    logical_regmem16                            = 0xD1,
    logical_regmem8_cl                          = 0xD2,
    logical_regmem16_cl                         = 0xD3,

    // TODO: Implement ASCII adjust multiply
    aam_ASCII_adjust_multiply                   = 0xD4,

    // TODO: Implmement ASCII adjust divide
    aad_ASCII_adjust_divide                     = 0xD5,

    // TODO: Implement xlat
    xlat_translate_byte_to_al                   = 0xD7,

    // TODO: Implement esc
    esc_external_opcode_000_yyy_source          = 0xD8,
    esc_external_opcode_001_yyy_source          = 0xD9,
    esc_external_opcode_010_yyy_source          = 0xDA,
    esc_external_opcode_011_yyy_source          = 0xDB,
    esc_external_opcode_100_yyy_source          = 0xDC,
    esc_external_opcode_101_yyy_source          = 0xDD,
    esc_external_opcode_110_yyy_source          = 0xDE,
    esc_external_opcode_111_yyy_source          = 0xDF,

    // TODO: Implement loops
    loopne_loopnz_loop_while_not_zero_equal     = 0xE0,
    loope_loopz_loop_while_zero_equal           = 0xE1,
    loop_loop_cx_times                          = 0xE2,

    // TODO: Implement jump
    jcxz_jump_on_cx_zero                        = 0xE3,

    // TODO: Implement in fixed port
    in_al_immed8                                = 0xE4,
    in_ax_immed8                                = 0xE5,

    // TODO: Implement out fixed port
    out_al_immed8                               = 0xE6,
    out_ax_immed8                               = 0xE7,

    /// SP is decremented by two and IP is pushed onto the stack.
    /// The relative displacement (up to +- 32k) of the target prodedure
    /// from the call instruction is then added to the IP. This form of
    /// call instruction is self-relative and is appropriate for
    /// position-independent (dynamically relocatable) routines in which
    /// the call and its target are in the same segment and are moved together.
    call_direct_within_segment                  = 0xE8,

    // TODO: Implement jmp
    jmp_direct_within_segment                   = 0xE9,
    jmp_direct_intersegment                     = 0xEA,
    jmp_direct_within_segment_short             = 0xEB,

    // TODO: Implement in variable port
    in_al_dx                                    = 0xEC,
    in_ax_dx                                    = 0xED,

    // TODO: Implement out variable port
    out_al_dx                                   = 0xEE,
    out_ax_dx                                   = 0xEF,

    // TODO: Implement lock
    lock_bus_lock_prefix                        = 0xF0,

    // TODO: Implement Repeat
    repne_repnz_not_equal_zero                  = 0xF2,
    rep_repe_repz_equal_zero                    = 0xF3,

    // TODO: Implement halt
    halt                                        = 0xF4,

    // TODO: Implement complement carry
    cmc_complement_carry                        = 0xF5,
    /// Carries an identifier in the second byte to distinguish between:
    /// - TEST  0b000: Logical 'and' on two byte sized operands. Updates flags
    /// but neither operand is changed. If followed by 'jnz' the
    /// jump is taken if there are any 1-bits present in both
    /// operands.
    /// - NOT   0b010: Inverts the bits of the byte sized operand.
    /// - NEG   0b011: Subtracts the byte sized operand from 0 and returns the
    /// result to the destination. Effectively reversing the sign of an integer.
    /// If the operand is 0, its sign is not changed.
    /// - MUL   0b100: Performs an unsigned multiplication of the byte sized
    /// source operand and the accumulator al and the double length result is
    /// returned in ah and al.
    /// - IMUL  0b101: Performes a signed multiplication of the byte sized
    /// source operand the the accumulator al and the double length result is
    /// returned in ah and al.
    /// - DIV   0b110: Performs an unsigned division of the accumulator
    /// (and its extension) by the byte sized source operand. The dividend is
    /// assumed in al and ah, while the single-length quotient is returned in
    /// al and the single-length remainder is returned in ah.
    /// - IDIV  0b111: Performs a sigend division of the accumulator
    /// (and its extension) by the byte sized source operand. The dividend is
    /// assumed in al and ah, while the single-length quotient is returned in
    /// al and the single-length remainder is returned in ah.
    logical_regmem8_immed8                      = 0xF6,
    /// Carries an identifier in the second byte to distinguish between:
    /// - TEST  0b000: Logical 'and' on two word sized operands. Updates flags
    /// but neither operand is changed. If followed by 'jnz' the
    /// jump is taken if there are any 1-bits present in both
    /// operands.
    /// - NOT   0b010: Inverts the bits of the word sized operand.
    /// - NEG   0b011: Subtracts the word sized operand from 0 and returns the
    /// result to the destination. Effectively reversing the sign of an integer.
    /// If the operand is 0, its sign is not changed.
    /// - MUL   0b100: Performs an unsigned multiplication of the word sized
    /// source operand and the accumulator ax and the double length result is
    /// returned in dx and ax.
    /// - IMUL  0b101: Performes a signed multiplication of the word sized
    /// source operand the the accumulator ax and the double length result is
    /// returned in dx and ax.
    /// - DIV   0b110: Performs an unsigned division of the accumulator
    /// (and its extension) by the word sized source operand. The dividend is
    /// assumed in ax and dx, while the single-length quotient is returned in
    /// ax and the single-length remainder is returned in dx.
    /// - IDIV  0b111: Performs a sigend division of the accumulator
    /// (and its extension) by the word sized source operand. The dividend is
    /// assumed in ax and dx, while the single-length quotient is returned in
    /// ax and the single-length remainder is returned in dx.
    logical_regmem16_immed16                    = 0xF7,

    // TODO: Implement clc - clear carry
    clc_clear_carry                             = 0xF8,

    // TODO: Implement stc - set carry
    stc_set_carry                               = 0xF9,

    // TODO: Implement cli - clear interrupt
    cli_clear_interrupt                         = 0xFA,

    // TODO: Implement sti - set interrupt
    sti_set_interrupt                           = 0xFB,

    // TODO: Implement cld - clear direction
    cld_clear_direction                         = 0xFC,

    // TODO: Implement std - set direction
    std_set_direction                           = 0xFD,

    // TODO: Implement Register/memory
    regmem8                                     = 0xFE,
    regmem16                                    = 0xFF,
};

/// Identifier action codes - rol set
pub const RolSet = enum(u3) {
    rol     = 0b000,
    ror     = 0b001,
    rcl     = 0b010,
    rcr     = 0b011,
    sal_shl = 0b100,
    shr     = 0b101,
    sar     = 0b111,
};

/// Identifier action codes - add set
/// When using @tagName() don't forget to make the mnemonics lower case.
pub const AddSet = enum(u3) {
    ADD     = 0b000,
    OR      = 0b001,
    ADC     = 0b010,
    SBB     = 0b011,
    AND     = 0b100,
    SUB     = 0b101,
    XOR     = 0b110,
    CMP     = 0b111,
};

/// Identifier action codes - test set
/// When using @tagName() don't forget to make the mnemonics lower case.
pub const TestSet = enum(u3) {
    TEST    = 0b000,
    NOT     = 0b010,
    NEG     = 0b011,
    MUL     = 0b100,
    IMUL    = 0b101,
    DIV     = 0b110,
    IDIV    = 0b111,
};

/// Identifier action codes - inc set
pub const IncSet = enum(u3) {
    inc                 = 0b000,
    dec                 = 0b001,
    call_within         = 0b010,
    call_intersegment   = 0b011,
    jmp_within          = 0b100,
    jmp_intersegment    = 0b101,
    push                = 0b110,
};

// zig fmt: on

/// Id enum for the Identifier union
const IdentifierId = enum {
    rol_set,
    add_set,
    test_set,
    inc_set,
};

/// Opcode identifier sometimes occuring in the second instruction byte
/// and decoding different sets of data.
const Identifier = union(IdentifierId) {
    rol_set: RolSet,
    add_set: AddSet,
    test_set: TestSet,
    inc_set: IncSet,
};

/// Instruction with mod and reg
pub const RegisterMemoryToFromRegisterOp = struct {
    opcode: BinaryInstructions,
    mnemonic: []const u8,
    mod: ModValue,
    rm: RmValue,
    reg: RegValue,
    d: ?DValue,
    w: ?WValue,
    disp_lo: ?u8,
    disp_hi: ?u8,
};

/// Instruction with mod but no reg or sr
pub const RegisterMemoryOp = struct {
    opcode: BinaryInstructions,
    mnemonic: []const u8,
    mod: ModValue,
    rm: RmValue,
    w: ?WValue,
    disp_lo: ?u8,
    disp_hi: ?u8,
};

/// Instructions without mod but with reg and only containing two bytes
pub const RegisterOp = struct {
    opcode: BinaryInstructions,
    mnemonic: []const u8,
    reg: RegValue,
};

/// Instructions without mod but with reg
pub const ImmediateToRegisterOp = struct {
    opcode: BinaryInstructions,
    mnemonic: []const u8,
    w: WValue,
    reg: RegValue,
    data_8: ?u8,
    data_lo: ?u8,
    data_hi: ?u8,
};

/// Immediate to memory instructions
pub const ImmediateToMemoryOp = struct {
    opcode: BinaryInstructions,
    mnemonic: []const u8,
    w: WValue,
    mod: ModValue,
    rm: RmValue,
    disp_lo: ?u8,
    disp_hi: ?u8,
    data_8: ?u8,
    data_lo: ?u8,
    data_hi: ?u8,
};

/// Instructions with sr involving segment registers
pub const SegmentRegisterOp = struct {
    opcode: BinaryInstructions,
    mnemonic: []const u8,
    mod: ?ModValue,
    sr: SrValue,
    rm: ?RmValue,
    disp_lo: ?u8,
    disp_hi: ?u8,
};

/// Packed instructions with identifier using the add-set
pub const IdentifierAddOp = struct {
    opcode: BinaryInstructions,
    mnemonic: []const u8,
    identifier: AddSet,
    w: WValue,
    s: ?SValue,
    mod: ModValue,
    rm: RmValue,
    disp_lo: ?u8,
    disp_hi: ?u8,
    data_lo: ?u8,
    data_hi: ?u8,
    data_8: ?u8,
    data_sx: ?u8,
};

/// Packed instructions with identifier using rol-set
pub const IdentifierRolOp = struct {
    opcode: BinaryInstructions,
    mnemonic: []const u8,
    identifier: RolSet,
    v: VValue,
    mod: ModValue,
    rm: RmValue,
    disp_lo: ?u8,
    disp_hi: ?u8,
};

/// Packed instructions with identifier using the test-set
pub const IdentifierTestOp = struct {
    opcode: BinaryInstructions,
    mnemonic: []const u8,
    identifier: TestSet,
    w: WValue,
    mod: ModValue,
    rm: RmValue,
    disp_lo: ?u8,
    disp_hi: ?u8,
    data_lo: ?u8,
    data_hi: ?u8,
    data_8: ?u8,
};

/// Packed instructions with identifier using the inc-set
pub const IdentifierIncOp = struct {
    opcode: BinaryInstructions,
    mnemonic: []const u8,
    mod: ModValue,
    identifier: IncSet,
    rm: RmValue,
    w: ?WValue,
    disp_lo: ?u8,
    disp_hi: ?u8,
};

/// Instructions without mod, reg or sr but containing additional instruction bytes
pub const DirectOp = struct {
    opcode: BinaryInstructions,
    mnemonic: []const u8,
    w: ?WValue,
    disp_lo: ?u8,
    disp_hi: ?u8,
    data_8: ?u8,
    data_lo: ?u8,
    data_hi: ?u8,
    ip_lo: ?u8,
    ip_hi: ?u8,
    ip_inc_lo: ?u8,
    ip_inc_hi: ?u8,
    ip_inc_8: ?u8,
    seg_lo: ?u8,
    seg_hi: ?u8,
    cs_lo: ?u8,
    cs_hi: ?u8,
};

/// Accumulator instructions
pub const AccumulatorOp = struct {
    opcode: BinaryInstructions,
    mnemonic: []const u8,
    w: ?WValue,
    data_8: ?u8,
    data_lo: ?u8,
    data_hi: ?u8,
    addr_lo: ?u8,
    addr_hi: ?u8,
};

/// Single byte instructions
pub const SingleByteOp = struct {
    opcode: BinaryInstructions,
    mnemonic: []const u8,
    z: ?ZValue,
    w: ?WValue,
};

/// Escape instructions
pub const EscapeOp = struct {
    opcode: BinaryInstructions,
    mnemonic: []const u8 = "esc",
    mod: ModValue,
    rm: RmValue,
    external_opcode: u8,
    source: u8,
    disp_lo: ?u8,
    disp_hi: ?u8,
};

/// Id enum for the InstructionData union.
const InstructionDataId = enum {
    err,
    accumulator_op,
    escape_op,
    register_memory_to_from_register_op,
    register_memory_op,
    register_op,
    immediate_to_register_op,
    immediate_to_memory_op,
    segment_register_op,
    identifier_add_op,
    identifier_rol_op,
    identifier_test_op,
    identifier_inc_op,
    direct_op,
    single_byte_op,
};

/// Union holding containers for the data of decoded InstructionBytes.
pub const InstructionData = union(InstructionDataId) {
    err: InstructionDecodeError,
    accumulator_op: AccumulatorOp,
    escape_op: EscapeOp,
    register_memory_to_from_register_op: RegisterMemoryToFromRegisterOp,
    register_memory_op: RegisterMemoryOp,
    register_op: RegisterOp,
    immediate_to_register_op: ImmediateToRegisterOp,
    immediate_to_memory_op: ImmediateToMemoryOp,
    segment_register_op: SegmentRegisterOp,
    identifier_add_op: IdentifierAddOp,
    identifier_rol_op: IdentifierRolOp,
    identifier_test_op: IdentifierTestOp,
    identifier_inc_op: IdentifierIncOp,
    direct_op: DirectOp,
    single_byte_op: SingleByteOp,
};

// zig fmt: off

/// Provided a x86 opcode and if available the mod and rm fields of this opcode
/// this function returns the length in bytes of this instruction as an integer value.
pub fn getInstructionLength(
    opcode: BinaryInstructions,
    mod: ?ModValue,
    rm: ?RmValue,
    identifier: ?Identifier,
) u3 {
    return inst_len: switch (opcode) {

        /////////////////////////////////////////////////////////////
        // Accumulator opcodes
        /////////////////////////////////////////////////////////////

        BinaryInstructions.add_al_immed8,
        BinaryInstructions.or_al_immed8,
        BinaryInstructions.adc_al_immed8,
        BinaryInstructions.sbb_al_immed8,
        BinaryInstructions.and_al_immed8,
        BinaryInstructions.sub_al_immed8,
        BinaryInstructions.xor_al_immed8,
        BinaryInstructions.cmp_al_immed8,
        BinaryInstructions.test_al_immed8,
        BinaryInstructions.in_al_dx,
        BinaryInstructions.out_al_dx,
        => 2, // opcode + data_8
        BinaryInstructions.add_ax_immed16,
        BinaryInstructions.or_ax_immed16,
        BinaryInstructions.adc_ax_immed16,
        BinaryInstructions.sbb_ax_immed16,
        BinaryInstructions.and_ax_immed16,
        BinaryInstructions.sub_ax_immed16,
        BinaryInstructions.xor_ax_immed16,
        BinaryInstructions.cmp_ax_immed16,
        BinaryInstructions.test_ax_immed16,
        BinaryInstructions.in_ax_dx,
        BinaryInstructions.out_ax_dx,
        => 3, // opcode + data_lo + data_hi
        BinaryInstructions.mov_al_mem8,
        BinaryInstructions.mov_ax_mem16,
        BinaryInstructions.mov_mem8_al,
        BinaryInstructions.mov_mem16_ax,
        => 3, // opcode + addr_lo + addr_hi

        /////////////////////////////////////////////////////////////
        // Escape opcodes
        /////////////////////////////////////////////////////////////

        BinaryInstructions.esc_external_opcode_000_yyy_source,
        BinaryInstructions.esc_external_opcode_001_yyy_source,
        BinaryInstructions.esc_external_opcode_010_yyy_source,
        BinaryInstructions.esc_external_opcode_011_yyy_source,
        BinaryInstructions.esc_external_opcode_100_yyy_source,
        BinaryInstructions.esc_external_opcode_101_yyy_source,
        BinaryInstructions.esc_external_opcode_110_yyy_source,
        BinaryInstructions.esc_external_opcode_111_yyy_source,
        =>  switch (mod.?) {
            .memoryModeNoDisplacement => break :inst_len if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) 4 else 2,
            .memoryMode8BitDisplacement => break :inst_len 3,
            .memoryMode16BitDisplacement => break :inst_len 4,
            .registerModeNoDisplacement => break :inst_len 2,
        }, // opcode + 2nd byte + (disp_lo) + (disp_hi)

        /////////////////////////////////////////////////////////////
        // Register/memory to/from register opcodes
        /////////////////////////////////////////////////////////////

        BinaryInstructions.add_regmem8_reg8,
        BinaryInstructions.add_regmem16_reg16,
        BinaryInstructions.add_reg8_regmem8,
        BinaryInstructions.add_reg16_regmem16,
        BinaryInstructions.or_regmem8_reg8,
        BinaryInstructions.or_regmem16_reg16,
        BinaryInstructions.or_reg8_regmem8,
        BinaryInstructions.or_reg16_regmem16,
        BinaryInstructions.adc_regmem8_reg8,
        BinaryInstructions.adc_regmem16_reg16,
        BinaryInstructions.adc_reg8_regmem8,
        BinaryInstructions.adc_reg16_regmem16,
        BinaryInstructions.sbb_regmem8_reg8,
        BinaryInstructions.sbb_regmem16_reg16,
        BinaryInstructions.sbb_reg8_regmem8,
        BinaryInstructions.sbb_reg16_regmem16,
        BinaryInstructions.and_regmem8_reg8,
        BinaryInstructions.and_regmem16_reg16,
        BinaryInstructions.and_reg8_regmem8,
        BinaryInstructions.and_reg16_regmem16,
        BinaryInstructions.sub_regmem8_reg8,
        BinaryInstructions.sub_regmem16_reg16,
        BinaryInstructions.sub_reg8_regmem8,
        BinaryInstructions.sub_reg16_regmem16,
        BinaryInstructions.xor_regmem8_reg8,
        BinaryInstructions.xor_regmem16_reg16,
        BinaryInstructions.xor_reg8_regmem8,
        BinaryInstructions.xor_reg16_regmem16,
        BinaryInstructions.cmp_regmem8_reg8,
        BinaryInstructions.cmp_regmem16_reg16,
        BinaryInstructions.cmp_reg8_regmem8,
        BinaryInstructions.cmp_reg16_regmem16,
        BinaryInstructions.test_regmem8_reg8,
        BinaryInstructions.test_regmem16_reg16,
        BinaryInstructions.xchg_reg8_regmem8,
        BinaryInstructions.xchg_reg16_regmem16,
        BinaryInstructions.mov_regmem8_reg8,
        BinaryInstructions.mov_regmem16_reg16,
        BinaryInstructions.mov_reg8_regmem8,
        BinaryInstructions.mov_reg16_regmem16,
        BinaryInstructions.lea_reg16_mem16,
        BinaryInstructions.load_es_regmem16,
        BinaryInstructions.load_ds_regmem16,
        => switch (mod.?) {
            .memoryModeNoDisplacement => break :inst_len if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) 4 else 2,
            .memoryMode8BitDisplacement => break :inst_len 3,
            .memoryMode16BitDisplacement => break :inst_len 4,
            .registerModeNoDisplacement => break :inst_len 2,
        }, // opcode + 2nd byte + (disp_lo) + (disp_hi)

        /////////////////////////////////////////////////////////////
        // Register/memory opcodes
        /////////////////////////////////////////////////////////////

        BinaryInstructions.pop_regmem16 => switch (mod.?) {
            .memoryModeNoDisplacement => break :inst_len if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) 4 else 2,
            .memoryMode8BitDisplacement => break :inst_len 3,
            .memoryMode16BitDisplacement => break :inst_len 4,
            .registerModeNoDisplacement => break :inst_len 2,
        },

        /////////////////////////////////////////////////////////////
        // Register opcodes
        /////////////////////////////////////////////////////////////

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
        BinaryInstructions.nop_xchg_ax_ax,
        BinaryInstructions.xchg_ax_cx,
        BinaryInstructions.xchg_ax_dx,
        BinaryInstructions.xchg_ax_bx,
        BinaryInstructions.xchg_ax_sp,
        BinaryInstructions.xchg_ax_bp,
        BinaryInstructions.xchg_ax_si,
        BinaryInstructions.xchg_ax_di,
        => 1, // opcode

        /////////////////////////////////////////////////////////////
        // Immediate to register opcodes
        /////////////////////////////////////////////////////////////

        BinaryInstructions.mov_al_immed8,
        BinaryInstructions.mov_cl_immed8,
        BinaryInstructions.mov_dl_immed8,
        BinaryInstructions.mov_bl_immed8,
        BinaryInstructions.mov_ah_immed8,
        BinaryInstructions.mov_ch_immed8,
        BinaryInstructions.mov_dh_immed8,
        BinaryInstructions.mov_bh_immed8,
        => 2, // opcode + data_8
        BinaryInstructions.mov_ax_immed16,
        BinaryInstructions.mov_cx_immed16,
        BinaryInstructions.mov_dx_immed16,
        BinaryInstructions.mov_bx_immed16,
        BinaryInstructions.mov_sp_immed16,
        BinaryInstructions.mov_bp_immed16,
        BinaryInstructions.mov_si_immed16,
        BinaryInstructions.mov_di_immed16,
        => 3, // opcode + data_lo + data_hi

        /////////////////////////////////////////////////////////////
        // Immediate to memory opcodes
        /////////////////////////////////////////////////////////////
        
        BinaryInstructions.mov_mem8_immed8 => switch (mod.?) {
            .memoryModeNoDisplacement => break :inst_len if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) 5 else 3,
            .memoryMode8BitDisplacement => break :inst_len 4,
            .memoryMode16BitDisplacement => break :inst_len 5,
            .registerModeNoDisplacement => break :inst_len 3,
        }, // opcode + 2nd byte + (disp_lo) + (disp_hi) + data_8
        BinaryInstructions.mov_mem16_immed16 => switch (mod.?) {
            .memoryModeNoDisplacement => break :inst_len if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) 6 else 4,
            .memoryMode8BitDisplacement => break :inst_len 5,
            .memoryMode16BitDisplacement => break :inst_len 6,
            .registerModeNoDisplacement => break :inst_len 4,
        }, // opcode + 2nd byte + (disp_lo) + (disp_hi) + data_lo + data_hi
    

        /////////////////////////////////////////////////////////////
        // Segment register opcodes
        /////////////////////////////////////////////////////////////

        BinaryInstructions.push_es,
        BinaryInstructions.pop_es,
        BinaryInstructions.push_cs,
        BinaryInstructions.push_ss,
        BinaryInstructions.pop_ss,
        BinaryInstructions.push_ds,
        BinaryInstructions.pop_ds,
        => 1, // opcode
        BinaryInstructions.segment_override_prefix_es,
        BinaryInstructions.segment_override_prefix_cs,
        BinaryInstructions.segment_override_prefix_ss,
        BinaryInstructions.segment_override_prefix_ds,
        => 1, // opcode
        BinaryInstructions.mov_regmem16_segreg,
        BinaryInstructions.mov_segreg_regmem16,
        => switch (mod.?) {
            .memoryModeNoDisplacement => break :inst_len if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) 4 else 2,
            .memoryMode8BitDisplacement => break :inst_len 3,
            .memoryMode16BitDisplacement => break :inst_len 4,
            .registerModeNoDisplacement => break :inst_len 2,
        }, // opcode + 2nd byte + (disp_lo) + (disp_hi)

        /////////////////////////////////////////////////////////////
        // Identifer add opcodes
        /////////////////////////////////////////////////////////////

        BinaryInstructions.regmem8_immed8,
        BinaryInstructions.signed_regmem8_immed8,
        BinaryInstructions.sign_extend_regmem16_immed8,
        => switch (mod.?) {
            .memoryModeNoDisplacement => break :inst_len if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) 5 else 3,
            .memoryMode8BitDisplacement => break :inst_len 4,
            .memoryMode16BitDisplacement => break :inst_len 5,
            .registerModeNoDisplacement => break :inst_len 3,
        }, // opcode + 2nd byte + (disp_lo) + (disp_hi) + data_8 / data_sx
        BinaryInstructions.regmem16_immed16 => switch (mod.?) {
            .memoryModeNoDisplacement => break :inst_len if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) 6 else 4,
            .memoryMode8BitDisplacement => break :inst_len 5,
            .memoryMode16BitDisplacement => break :inst_len 6,
            .registerModeNoDisplacement => break :inst_len 4,
        }, // opcode + 2nd byte + (disp_lo) + (disp_hi) + data_lo + data_hi

        /////////////////////////////////////////////////////////////
        // Identifer rol opcodes
        /////////////////////////////////////////////////////////////

        BinaryInstructions.logical_regmem8,
        BinaryInstructions.logical_regmem8_cl,
        BinaryInstructions.logical_regmem16,
        BinaryInstructions.logical_regmem16_cl,
        => switch (mod.?) {
            .memoryModeNoDisplacement => break :inst_len if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) 4 else 2,
            .memoryMode8BitDisplacement => break :inst_len 3,
            .memoryMode16BitDisplacement => break :inst_len 4,
            .registerModeNoDisplacement => break :inst_len 2,
        }, // opcode + 2nd byte + (disp_lo) + (disp_hi)

        /////////////////////////////////////////////////////////////
        // Identifer test opcodes
        /////////////////////////////////////////////////////////////

        BinaryInstructions.logical_regmem8_immed8 => switch (identifier.?.test_set) {
            TestSet.TEST => switch (mod.?) {
                .memoryModeNoDisplacement => break :inst_len if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) 5 else 3,
                .memoryMode8BitDisplacement => break :inst_len 4,
                .memoryMode16BitDisplacement => break :inst_len 5,
                .registerModeNoDisplacement => break :inst_len 3,
            },
            TestSet.NEG,
            TestSet.NOT,
            TestSet.MUL,
            TestSet.IMUL,
            TestSet.DIV,
            TestSet.IDIV,
            => switch (mod.?) {
                .memoryModeNoDisplacement => break :inst_len if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) 4 else 2,
                .memoryMode8BitDisplacement => break :inst_len 3,
                .memoryMode16BitDisplacement => break :inst_len 4,
                .registerModeNoDisplacement => break :inst_len 2,
            }
        }, // opcode + 2nd byte + (disp_lo) + (disp_hi) + (data_8)
        BinaryInstructions.logical_regmem16_immed16 => switch (identifier.?.test_set) {
            TestSet.TEST => switch (mod.?) {
                .memoryModeNoDisplacement => break :inst_len if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) 6 else 4,
                .memoryMode8BitDisplacement => break :inst_len 5,
                .memoryMode16BitDisplacement => break :inst_len 6,
                .registerModeNoDisplacement => break :inst_len 4,
            },
            TestSet.NEG,
            TestSet.NOT,
            TestSet.MUL,
            TestSet.IMUL,
            TestSet.DIV,
            TestSet.IDIV,
            => switch (mod.?) {
                .memoryModeNoDisplacement => break :inst_len if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) 4 else 2,
                .memoryMode8BitDisplacement => break :inst_len 3,
                .memoryMode16BitDisplacement => break :inst_len 4,
                .registerModeNoDisplacement => break :inst_len 2,
            }
        }, // opcode + 2nd byte + (disp_lo) + (disp_hi) + (data_lo) + (data_hi)

        /////////////////////////////////////////////////////////////
        // Identifer inc opcodes
        /////////////////////////////////////////////////////////////

        BinaryInstructions.regmem8,
        BinaryInstructions.regmem16,
        => switch (mod.?) {
            .memoryModeNoDisplacement => break :inst_len if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) 4 else 2,
            .memoryMode8BitDisplacement => break :inst_len 3,
            .memoryMode16BitDisplacement => break :inst_len 4,
            .registerModeNoDisplacement => break :inst_len 2,
        }, // opcode + 2nd byte + (disp_lo) + (disp_hi)

        /////////////////////////////////////////////////////////////
        // Direct opcodes
        /////////////////////////////////////////////////////////////

        BinaryInstructions.jo_jump_on_overflow,
        BinaryInstructions.jno_jump_on_not_overflow,
        BinaryInstructions.jb_jnae_jump_on_below_not_above_or_equal,
        BinaryInstructions.jnb_jae_jump_on_not_below_above_or_equal,
        BinaryInstructions.je_jz_jump_on_equal_zero,
        BinaryInstructions.jne_jnz_jumb_on_not_equal_not_zero,
        BinaryInstructions.jbe_jna_jump_on_below_or_equal_above,
        BinaryInstructions.jnbe_ja_jump_on_not_below_or_equal_above,
        BinaryInstructions.js_jump_on_sign,
        BinaryInstructions.jns_jump_on_not_sign,
        BinaryInstructions.jp_jpe_jump_on_parity_parity_even,
        BinaryInstructions.jnp_jpo_jump_on_not_parity_parity_odd,
        BinaryInstructions.jl_jnge_jump_on_less_not_greater_or_equal,
        BinaryInstructions.jnl_jge_jump_on_not_less_greater_or_equal,
        BinaryInstructions.jle_jng_jump_on_less_or_equal_not_greater,
        BinaryInstructions.jnle_jg_jump_on_not_less_or_equal_greater,
        BinaryInstructions.loopne_loopnz_loop_while_not_zero_equal,
        BinaryInstructions.loope_loopz_loop_while_zero_equal,
        BinaryInstructions.loop_loop_cx_times,
        BinaryInstructions.jcxz_jump_on_cx_zero,
        BinaryInstructions.jmp_direct_within_segment_short,
        => 2, // opcode + ip_inc_8
        BinaryInstructions.int_interrupt_type_specified,
        => 2, // opcode + data_8
        BinaryInstructions.ret_within_seg_adding_immed16_to_sp,
        BinaryInstructions.ret_intersegment_adding_immed16_to_sp,
        => 3, // opcode + data_lo + data_hi
        BinaryInstructions.aam_ASCII_adjust_multiply,
        BinaryInstructions.aad_ASCII_adjust_divide,
        => 2, // opcode + 2nd byte
        BinaryInstructions.call_direct_intersegment,
        => 5, // opcode + disp_lo + disp_hi + seg_lo + seg_hi
        BinaryInstructions.call_direct_within_segment,
        BinaryInstructions.jmp_direct_within_segment,
        => 3, // opcode + ip_inc_lo + ip_inc_hi
        BinaryInstructions.jmp_direct_intersegment,
        => 5, // opcode + ip_lo + ip_hi + cs_lo + cs_hi
        
        /////////////////////////////////////////////////////////////
        // Single byte opcodes
        /////////////////////////////////////////////////////////////

        BinaryInstructions.daa_decimal_adjust_add,
        BinaryInstructions.das_decimal_adjust_sub,
        BinaryInstructions.aaa_ASCII_adjust_add,
        BinaryInstructions.aas_ASCII_adjust_sub,
        BinaryInstructions.cbw_byte_to_word,
        BinaryInstructions.cwd_word_to_double_word,
        BinaryInstructions.wait,
        BinaryInstructions.pushf,
        BinaryInstructions.popf,
        BinaryInstructions.sahf,
        BinaryInstructions.lahf,
        BinaryInstructions.ret_within_segment,
        BinaryInstructions.ret_intersegment,
        BinaryInstructions.int_interrupt_type_3,
        BinaryInstructions.into_interrupt_on_overflow,
        BinaryInstructions.iret_interrupt_return,
        BinaryInstructions.xlat_translate_byte_to_al,
        BinaryInstructions.lock_bus_lock_prefix,
        BinaryInstructions.halt,
        BinaryInstructions.cmc_complement_carry,
        BinaryInstructions.clc_clear_carry,
        BinaryInstructions.stc_set_carry,
        BinaryInstructions.cli_clear_interrupt,
        BinaryInstructions.sti_set_interrupt,
        BinaryInstructions.cld_clear_direction,
        BinaryInstructions.std_set_direction,
        BinaryInstructions.movs_byte,
        BinaryInstructions.movs_word,
        BinaryInstructions.cmps_byte,
        BinaryInstructions.cmps_word,
        BinaryInstructions.stos_byte,
        BinaryInstructions.stos_word,
        BinaryInstructions.lods_byte,
        BinaryInstructions.lods_word,
        BinaryInstructions.scas_byte,
        BinaryInstructions.scas_word,
        BinaryInstructions.in_al_immed8,
        BinaryInstructions.in_ax_immed8,
        BinaryInstructions.out_al_immed8,
        BinaryInstructions.out_ax_immed8,
        BinaryInstructions.repne_repnz_not_equal_zero,
        BinaryInstructions.rep_repe_repz_equal_zero,
        => 1, // opcode
    };
}

// zig fmt: on

/// Provided a valid opcode and the input bytes as parameters this function
/// returns a InstructionData object containing all extracted instruction data.
pub fn decode(
    opcode: BinaryInstructions,
    input: [6]u8,
) InstructionDecodeError!InstructionData {
    var result: InstructionData = undefined;
    const log = std.log.scoped(.decode);
    defer log.info("{t} returned a {t} object.", .{ opcode, result });

    switch (opcode) {

        /////////////////////////////////////////////////////////////
        // Accumulator opcodes
        /////////////////////////////////////////////////////////////

        // Accumulator instructions
        BinaryInstructions.add_al_immed8,
        BinaryInstructions.add_ax_immed16,
        BinaryInstructions.or_al_immed8,
        BinaryInstructions.or_ax_immed16,
        BinaryInstructions.adc_al_immed8,
        BinaryInstructions.adc_ax_immed16,
        BinaryInstructions.sbb_al_immed8,
        BinaryInstructions.sbb_ax_immed16,
        BinaryInstructions.and_al_immed8,
        BinaryInstructions.and_ax_immed16,
        BinaryInstructions.sub_al_immed8,
        BinaryInstructions.sub_ax_immed16,
        BinaryInstructions.xor_al_immed8,
        BinaryInstructions.xor_ax_immed16,
        BinaryInstructions.cmp_al_immed8,
        BinaryInstructions.cmp_ax_immed16,
        BinaryInstructions.test_al_immed8,
        BinaryInstructions.test_ax_immed16,
        BinaryInstructions.in_al_immed8,
        BinaryInstructions.in_ax_immed8,
        BinaryInstructions.out_al_immed8,
        BinaryInstructions.out_ax_immed8,
        => {
            const w: WValue = @enumFromInt((input[0] << 7) >> 7);

            result = InstructionData{
                .accumulator_op = AccumulatorOp{
                    .opcode = opcode,
                    .mnemonic = switch (opcode) {
                        .add_al_immed8,
                        .add_ax_immed16,
                        => "add",
                        .or_al_immed8,
                        .or_ax_immed16,
                        => "or",
                        .adc_al_immed8,
                        .adc_ax_immed16,
                        => "adc",
                        .sbb_al_immed8,
                        .sbb_ax_immed16,
                        => "sbb",
                        .and_al_immed8,
                        .and_ax_immed16,
                        => "and",
                        .sub_al_immed8,
                        .sub_ax_immed16,
                        => "sub",
                        .xor_al_immed8,
                        .xor_ax_immed16,
                        => "xor",
                        .cmp_al_immed8,
                        .cmp_ax_immed16,
                        => "cmp",
                        .test_al_immed8,
                        .test_ax_immed16,
                        => "test",
                        .in_al_immed8,
                        .in_ax_immed8,
                        => "in",
                        .out_al_immed8,
                        .out_ax_immed8,
                        => "out",
                        else => return InstructionDecodeError.InstructionError,
                    },
                    .w = w,
                    .data_8 = if (w == WValue.byte) input[1] else null,
                    .data_lo = if (w == WValue.word) input[1] else null,
                    .data_hi = if (w == WValue.word) input[2] else null,
                    .addr_lo = null,
                    .addr_hi = null,
                },
            };
            return result;
        },

        // Accumulator instructions - Direct address (offset) addr-lo, addr-hi
        BinaryInstructions.mov_al_mem8,
        BinaryInstructions.mov_ax_mem16,
        BinaryInstructions.mov_mem8_al,
        BinaryInstructions.mov_mem16_ax,
        => {
            const w: WValue = @enumFromInt((input[0] << 7) >> 7);
            result = InstructionData{
                .accumulator_op = AccumulatorOp{
                    .opcode = opcode,
                    .mnemonic = "mov",
                    .w = w,
                    .data_8 = null,
                    .data_lo = null,
                    .data_hi = null,
                    .addr_lo = input[1],
                    .addr_hi = input[2],
                },
            };
            return result;
        },

        /////////////////////////////////////////////////////////////
        // Escape opcodes
        /////////////////////////////////////////////////////////////

        /////////////////////////////////////////////////////////////
        // Register/memory to/from register opcodes
        /////////////////////////////////////////////////////////////

        // Register/Memory to/from Register instructions - with mod and reg
        // min 2, max 4 bytes long with disp_lo and disp_hi
        BinaryInstructions.add_regmem8_reg8,
        BinaryInstructions.add_regmem16_reg16,
        BinaryInstructions.add_reg8_regmem8,
        BinaryInstructions.add_reg16_regmem16,
        BinaryInstructions.or_regmem8_reg8,
        BinaryInstructions.or_regmem16_reg16,
        BinaryInstructions.or_reg8_regmem8,
        BinaryInstructions.or_reg16_regmem16,
        BinaryInstructions.adc_regmem8_reg8,
        BinaryInstructions.adc_regmem16_reg16,
        BinaryInstructions.adc_reg8_regmem8,
        BinaryInstructions.adc_reg16_regmem16,
        BinaryInstructions.sbb_regmem8_reg8,
        BinaryInstructions.sbb_regmem16_reg16,
        BinaryInstructions.sbb_reg8_regmem8,
        BinaryInstructions.sbb_reg16_regmem16,
        BinaryInstructions.and_regmem8_reg8,
        BinaryInstructions.and_regmem16_reg16,
        BinaryInstructions.and_reg8_regmem8,
        BinaryInstructions.and_reg16_regmem16,
        BinaryInstructions.sub_regmem8_reg8,
        BinaryInstructions.sub_regmem16_reg16,
        BinaryInstructions.sub_reg8_regmem8,
        BinaryInstructions.sub_reg16_regmem16,
        BinaryInstructions.xor_regmem8_reg8,
        BinaryInstructions.xor_regmem16_reg16,
        BinaryInstructions.xor_reg8_regmem8,
        BinaryInstructions.xor_reg16_regmem16,
        BinaryInstructions.cmp_regmem8_reg8,
        BinaryInstructions.cmp_regmem16_reg16,
        BinaryInstructions.cmp_reg8_regmem8,
        BinaryInstructions.cmp_reg16_regmem16,
        BinaryInstructions.test_regmem8_reg8,
        BinaryInstructions.test_regmem16_reg16,
        BinaryInstructions.xchg_reg8_regmem8,
        BinaryInstructions.xchg_reg16_regmem16,
        BinaryInstructions.mov_regmem8_reg8,
        BinaryInstructions.mov_regmem16_reg16,
        BinaryInstructions.mov_reg8_regmem8,
        BinaryInstructions.mov_reg16_regmem16,
        BinaryInstructions.lea_reg16_mem16,
        BinaryInstructions.load_es_regmem16,
        BinaryInstructions.load_ds_regmem16,
        => {
            const mod: ModValue = @enumFromInt(input[1] >> 6);
            const rm: RmValue = @enumFromInt((input[1] << 5) >> 5);
            const reg: RegValue = @enumFromInt((input[1] << 2) >> 5);
            const mnemonic: []const u8 = switch (opcode) {
                .add_regmem8_reg8,
                .add_regmem16_reg16,
                .add_reg8_regmem8,
                .add_reg16_regmem16,
                => "add",
                .or_regmem8_reg8,
                .or_regmem16_reg16,
                .or_reg8_regmem8,
                .or_reg16_regmem16,
                => "or",
                .adc_regmem8_reg8,
                .adc_regmem16_reg16,
                .adc_reg8_regmem8,
                .adc_reg16_regmem16,
                => "adc",
                .sbb_regmem8_reg8,
                .sbb_regmem16_reg16,
                .sbb_reg8_regmem8,
                .sbb_reg16_regmem16,
                => "sbb",
                .and_regmem8_reg8,
                .and_regmem16_reg16,
                .and_reg8_regmem8,
                .and_reg16_regmem16,
                => "and",
                .sub_regmem8_reg8,
                .sub_regmem16_reg16,
                .sub_reg8_regmem8,
                .sub_reg16_regmem16,
                => "sub",
                .xor_regmem8_reg8,
                .xor_regmem16_reg16,
                .xor_reg8_regmem8,
                .xor_reg16_regmem16,
                => "xor",
                .cmp_regmem8_reg8,
                .cmp_regmem16_reg16,
                .cmp_reg8_regmem8,
                .cmp_reg16_regmem16,
                => "cmp",
                .test_regmem8_reg8,
                .test_regmem16_reg16,
                => "test",
                .xchg_reg8_regmem8,
                .xchg_reg16_regmem16,
                => "xchg",
                .mov_regmem8_reg8,
                .mov_regmem16_reg16,
                .mov_reg8_regmem8,
                .mov_reg16_regmem16,
                => "mov",
                .lea_reg16_mem16,
                => "lea",
                .load_es_regmem16,
                => "les",
                .load_ds_regmem16,
                => "lds",
                else => {
                    return InstructionDecodeError.InstructionError;
                },
            };
            const d: ?DValue = switch (opcode) {
                .test_regmem8_reg8,
                .test_regmem16_reg16,
                .xchg_reg8_regmem8,
                .xchg_reg16_regmem16,
                .lea_reg16_mem16,
                .load_es_regmem16,
                .load_ds_regmem16,
                => null,
                else => if ((input[0] << 6) >> 7 == 0) DValue.source else DValue.destination,
            };
            const w: ?WValue = switch (opcode) {
                .lea_reg16_mem16,
                .load_es_regmem16,
                .load_ds_regmem16,
                => null,
                else => if ((input[0] << 7) >> 7 == 0) WValue.byte else WValue.word,
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

            result = InstructionData{
                .register_memory_to_from_register_op = RegisterMemoryToFromRegisterOp{
                    .opcode = opcode,
                    .mnemonic = mnemonic,
                    .mod = mod,
                    .rm = rm,
                    .reg = reg,
                    .d = d,
                    .w = w,
                    .disp_lo = disp_lo,
                    .disp_hi = disp_hi,
                },
            };
            return result;
        },

        /////////////////////////////////////////////////////////////
        // Register/memory opcodes
        /////////////////////////////////////////////////////////////

        // Register/memory Op - with w, mod, rm
        // min 2, max 4 bytes long with disp_lo, disp_hi,
        BinaryInstructions.pop_regmem16 => {
            const mod: ModValue = @enumFromInt(input[1] >> 6);
            const rm: RmValue = @enumFromInt((input[1] << 5) >> 5);
            const disp_lo: ?u8 = switch (mod) {
                .memoryModeNoDisplacement => if (rm != RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) input[2] else null,
                .memoryMode8BitDisplacement => input[2],
                .memoryMode16BitDisplacement => input[2],
                .registerModeNoDisplacement => null,
            };
            const disp_hi: ?u8 = switch (mod) {
                .memoryModeNoDisplacement => if (rm != RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) input[3] else null,
                .memoryMode8BitDisplacement => null,
                .memoryMode16BitDisplacement => input[3],
                .registerModeNoDisplacement => null,
            };

            result = InstructionData{
                .register_memory_op = RegisterMemoryOp{
                    .opcode = opcode,
                    .mnemonic = "pop",
                    .mod = mod,
                    .rm = rm,
                    .w = null,
                    .disp_lo = disp_lo,
                    .disp_hi = disp_hi,
                },
            };
            return result;
        },

        /////////////////////////////////////////////////////////////
        // Register opcodes
        /////////////////////////////////////////////////////////////

        BinaryInstructions.inc_ax,
        BinaryInstructions.inc_cx,
        BinaryInstructions.inc_dx,
        BinaryInstructions.inc_bx,
        BinaryInstructions.inc_sp,
        BinaryInstructions.inc_bp,
        BinaryInstructions.inc_si,
        BinaryInstructions.inc_di,
        => {
            const reg: RegValue = @enumFromInt((input[0] << 5) >> 5);

            result = InstructionData{
                .register_op = RegisterOp{
                    .opcode = opcode,
                    .mnemonic = "inc",
                    .reg = reg,
                },
            };
            return result;
        },
        BinaryInstructions.dec_ax,
        BinaryInstructions.dec_cx,
        BinaryInstructions.dec_dx,
        BinaryInstructions.dec_bx,
        BinaryInstructions.dec_sp,
        BinaryInstructions.dec_bp,
        BinaryInstructions.dec_si,
        BinaryInstructions.dec_di,
        => {
            const reg: RegValue = @enumFromInt((input[0] << 5) >> 5);

            result = InstructionData{
                .register_op = RegisterOp{
                    .opcode = opcode,
                    .mnemonic = "dec",
                    .reg = reg,
                },
            };
            return result;
        },
        BinaryInstructions.push_ax,
        BinaryInstructions.push_cx,
        BinaryInstructions.push_dx,
        BinaryInstructions.push_bx,
        BinaryInstructions.push_sp,
        BinaryInstructions.push_bp,
        BinaryInstructions.push_si,
        BinaryInstructions.push_di,
        => {
            const reg: RegValue = @enumFromInt((input[0] << 5) >> 5);

            result = InstructionData{
                .register_op = RegisterOp{
                    .opcode = opcode,
                    .mnemonic = "push",
                    .reg = reg,
                },
            };
            return result;
        },
        BinaryInstructions.pop_ax,
        BinaryInstructions.pop_cx,
        BinaryInstructions.pop_dx,
        BinaryInstructions.pop_bx,
        BinaryInstructions.pop_sp,
        BinaryInstructions.pop_bp,
        BinaryInstructions.pop_si,
        BinaryInstructions.pop_di,
        => {
            const reg: RegValue = @enumFromInt((input[0] << 5) >> 5);

            result = InstructionData{
                .register_op = RegisterOp{
                    .opcode = opcode,
                    .mnemonic = "pop",
                    .reg = reg,
                },
            };
            return result;
        },
        BinaryInstructions.nop_xchg_ax_ax => {
            const reg: RegValue = @enumFromInt((input[0] << 5) >> 5);

            result = InstructionData{
                .register_op = RegisterOp{
                    .opcode = opcode,
                    .mnemonic = "nop",
                    .reg = reg,
                },
            };
            return result;
        },
        BinaryInstructions.xchg_ax_cx,
        BinaryInstructions.xchg_ax_dx,
        BinaryInstructions.xchg_ax_bx,
        BinaryInstructions.xchg_ax_sp,
        BinaryInstructions.xchg_ax_bp,
        BinaryInstructions.xchg_ax_si,
        BinaryInstructions.xchg_ax_di,
        => {
            const reg: RegValue = @enumFromInt((input[0] << 5) >> 5);

            result = InstructionData{
                .register_op = RegisterOp{
                    .opcode = opcode,
                    .mnemonic = "xchg",
                    .reg = reg,
                },
            };
            return result;
        },

        /////////////////////////////////////////////////////////////
        // Immediate to register opcodes
        /////////////////////////////////////////////////////////////

        // Immediate to register mov
        BinaryInstructions.mov_al_immed8,
        BinaryInstructions.mov_cl_immed8,
        BinaryInstructions.mov_dl_immed8,
        BinaryInstructions.mov_bl_immed8,
        BinaryInstructions.mov_ah_immed8,
        BinaryInstructions.mov_ch_immed8,
        BinaryInstructions.mov_dh_immed8,
        BinaryInstructions.mov_bh_immed8,
        BinaryInstructions.mov_ax_immed16,
        BinaryInstructions.mov_cx_immed16,
        BinaryInstructions.mov_dx_immed16,
        BinaryInstructions.mov_bx_immed16,
        BinaryInstructions.mov_sp_immed16,
        BinaryInstructions.mov_bp_immed16,
        BinaryInstructions.mov_si_immed16,
        BinaryInstructions.mov_di_immed16,
        => {
            const w: WValue = @enumFromInt((input[0] << 4) >> 7);
            const reg: RegValue = @enumFromInt((input[0] << 5) >> 5);

            result = InstructionData{
                .immediate_to_register_op = ImmediateToRegisterOp{
                    .opcode = opcode,
                    .mnemonic = "mov",
                    .w = w,
                    .reg = reg,
                    .data_8 = if (@intFromEnum(opcode) <= 0xB7) input[1] else null,
                    .data_lo = if (@intFromEnum(opcode) > 0xB7) input[1] else null,
                    .data_hi = if (@intFromEnum(opcode) > 0xB7) input[2] else null,
                },
            };
            return result;
        },

        /////////////////////////////////////////////////////////////
        // Immediate to memory opcodes
        /////////////////////////////////////////////////////////////

        // Immediate to memory instructions - with mod
        // min 3, max 6 bytes long with disp_lo, disp_hi,
        // data_8 or data_lo and data_hi
        BinaryInstructions.mov_mem8_immed8,
        BinaryInstructions.mov_mem16_immed16,
        => {
            const w: WValue = @enumFromInt((input[0] << 7) >> 7);
            const mod: ModValue = @enumFromInt(input[1] >> 6);
            const rm: RmValue = @enumFromInt((input[1] << 5) >> 5);

            switch (mod) {
                .memoryModeNoDisplacement => {
                    if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) {
                        const disp_lo: u8 = input[2];
                        const disp_hi: u8 = input[3];

                        result = InstructionData{
                            .immediate_to_memory_op = ImmediateToMemoryOp{
                                .opcode = opcode,
                                .mnemonic = "mov",
                                .mod = mod,
                                .rm = rm,
                                .w = w,
                                .disp_lo = disp_lo,
                                .disp_hi = disp_hi,
                                .data_8 = if (w == WValue.byte) input[4] else null,
                                .data_lo = if (w == WValue.word) input[4] else null,
                                .data_hi = if (w == WValue.word) input[5] else null,
                            },
                        };
                        return result;
                    } else {
                        result = InstructionData{
                            .immediate_to_memory_op = ImmediateToMemoryOp{
                                .opcode = opcode,
                                .mnemonic = "mov",
                                .mod = mod,
                                .rm = rm,
                                .w = w,
                                .disp_lo = null,
                                .disp_hi = null,
                                .data_8 = if (w == WValue.byte) input[2] else null,
                                .data_lo = if (w == WValue.word) input[2] else null,
                                .data_hi = if (w == WValue.word) input[3] else null,
                            },
                        };
                        return result;
                    }
                },
                .memoryMode8BitDisplacement => {
                    const disp_lo: u8 = input[2];

                    result = InstructionData{
                        .immediate_to_memory_op = ImmediateToMemoryOp{
                            .opcode = opcode,
                            .mnemonic = "mov",
                            .mod = mod,
                            .rm = rm,
                            .w = w,
                            .disp_lo = disp_lo,
                            .disp_hi = null,
                            .data_8 = if (w == WValue.byte) input[3] else null,
                            .data_lo = if (w == WValue.word) input[3] else null,
                            .data_hi = if (w == WValue.word) input[4] else null,
                        },
                    };
                    return result;
                },
                .memoryMode16BitDisplacement => {
                    const disp_lo: u8 = input[2];
                    const disp_hi: u8 = input[3];

                    result = InstructionData{
                        .immediate_to_memory_op = ImmediateToMemoryOp{
                            .opcode = opcode,
                            .mnemonic = "mov",
                            .mod = mod,
                            .rm = rm,
                            .w = w,
                            .disp_lo = disp_lo,
                            .disp_hi = disp_hi,
                            .data_8 = if (w == WValue.byte) input[4] else null,
                            .data_lo = if (w == WValue.word) input[4] else null,
                            .data_hi = if (w == WValue.word) input[5] else null,
                        },
                    };
                    return result;
                },
                .registerModeNoDisplacement => {
                    result = InstructionData{
                        .immediate_to_memory_op = ImmediateToMemoryOp{
                            .opcode = opcode,
                            .mnemonic = "mov",
                            .w = w,
                            .mod = mod,
                            .rm = rm,
                            .disp_lo = null,
                            .disp_hi = null,
                            .data_8 = if (w == WValue.byte) input[2] else null,
                            .data_lo = if (w == WValue.word) input[2] else null,
                            .data_hi = if (w == WValue.word) input[3] else null,
                        },
                    };
                    return result;
                },
            }
        },

        /////////////////////////////////////////////////////////////
        // Segment register opcodes
        /////////////////////////////////////////////////////////////

        // (Segment) Register ops
        BinaryInstructions.push_es,
        BinaryInstructions.push_cs,
        BinaryInstructions.push_ss,
        BinaryInstructions.push_ds,
        => {
            const sr: SrValue = @enumFromInt((input[0] << 3) >> 6);

            result = InstructionData{
                .segment_register_op = SegmentRegisterOp{
                    .opcode = opcode,
                    .mnemonic = "push",
                    .mod = null,
                    .sr = sr,
                    .rm = null,
                    .disp_lo = null,
                    .disp_hi = null,
                },
            };
            return result;
        },
        BinaryInstructions.pop_es,
        BinaryInstructions.pop_ss,
        BinaryInstructions.pop_ds,
        => {
            const sr: SrValue = @enumFromInt((input[0] << 3) >> 6);

            result = InstructionData{
                .segment_register_op = SegmentRegisterOp{
                    .opcode = opcode,
                    .mnemonic = "pop",
                    .mod = null,
                    .sr = sr,
                    .rm = null,
                    .disp_lo = null,
                    .disp_hi = null,
                },
            };
            return result;
        },

        // Segment register instructions
        BinaryInstructions.mov_regmem16_segreg,
        BinaryInstructions.mov_segreg_regmem16,
        => {
            const mod: ModValue = @enumFromInt(input[1] >> 6);
            const sr: SrValue = @enumFromInt((input[1] << 3) >> 6);
            const rm: RmValue = @enumFromInt((input[1] << 5) >> 5);

            result = InstructionData{
                .segment_register_op = SegmentRegisterOp{
                    .opcode = opcode,
                    .mnemonic = "mov",
                    .mod = mod,
                    .sr = sr,
                    .rm = rm,
                    .disp_lo = switch (mod) {
                        .memoryModeNoDisplacement => if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) input[2] else null,
                        .memoryMode8BitDisplacement => input[2],
                        .memoryMode16BitDisplacement => input[2],
                        .registerModeNoDisplacement => null,
                    },
                    .disp_hi = switch (mod) {
                        .memoryModeNoDisplacement => if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) input[3] else null,
                        .memoryMode8BitDisplacement => null,
                        .memoryMode16BitDisplacement => input[3],
                        .registerModeNoDisplacement => null,
                    },
                },
            };
            return result;
        },

        // no mod no reg no w
        BinaryInstructions.segment_override_prefix_es,
        BinaryInstructions.segment_override_prefix_cs,
        BinaryInstructions.segment_override_prefix_ss,
        BinaryInstructions.segment_override_prefix_ds,
        => {
            const sr: SrValue = @enumFromInt((input[0] << 3) >> 6);

            result = InstructionData{
                .segment_register_op = SegmentRegisterOp{
                    .opcode = opcode,
                    .mnemonic = switch (opcode) {
                        BinaryInstructions.segment_override_prefix_es => "es:",
                        BinaryInstructions.segment_override_prefix_cs => "cs:",
                        BinaryInstructions.segment_override_prefix_ss => "ss:",
                        BinaryInstructions.segment_override_prefix_ds => "ds:",
                        else => return InstructionDecodeError.InstructionError,
                    },
                    .sr = sr,
                    .mod = null,
                    .rm = null,
                    .disp_lo = null,
                    .disp_hi = null,
                },
            };
            return result;
        },

        /////////////////////////////////////////////////////////////
        // Identifier add opcodes
        /////////////////////////////////////////////////////////////

        // Identifier instructions - with mod without reg
        // min 3, max 6 bytes long with disp_lo, disp_hi,
        // data_8 or data_lo and data_hi or data_sx
        // Identifier.add_set
        BinaryInstructions.regmem8_immed8,
        BinaryInstructions.regmem16_immed16,
        BinaryInstructions.signed_regmem8_immed8,
        BinaryInstructions.sign_extend_regmem16_immed8,
        => {
            const s: SValue = @enumFromInt((input[0] << 6) >> 7);
            const w: WValue = @enumFromInt((input[0] << 7) >> 7);
            const mod: ModValue = @enumFromInt(input[1] >> 6);
            const rm: RmValue = @enumFromInt((input[1] << 5) >> 5);
            const identifier: AddSet = @enumFromInt((input[1] << 2) >> 5);
            const mnemonic: []const u8 = switch (identifier) {
                .ADD => "add",
                .OR => "or",
                .ADC => "adc",
                .SBB => "sbb",
                .AND => "and",
                .SUB => "sub",
                .XOR => "xor",
                .CMP => "cmp",
            };

            switch (mod) {
                .memoryModeNoDisplacement => {
                    if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) {
                        const disp_lo: u8 = input[2];
                        const disp_hi: u8 = input[3];
                        const data_lo: ?u8 = switch (opcode) {
                            .regmem16_immed16 => input[4],
                            else => null,
                        };
                        const data_hi: ?u8 = switch (opcode) {
                            .regmem16_immed16 => input[5],
                            else => null,
                        };
                        const data_8: ?u8 = switch (opcode) {
                            .regmem8_immed8,
                            .signed_regmem8_immed8,
                            => input[4],
                            else => null,
                        };
                        const data_sx: ?u8 = switch (opcode) {
                            .sign_extend_regmem16_immed8 => input[4],
                            else => null,
                        };

                        result = InstructionData{
                            .identifier_add_op = IdentifierAddOp{
                                .opcode = opcode,
                                .mnemonic = mnemonic,
                                .identifier = identifier,
                                .mod = mod,
                                .rm = rm,
                                .w = w,
                                .s = s,
                                .disp_lo = disp_lo,
                                .disp_hi = disp_hi,
                                .data_lo = data_lo,
                                .data_hi = data_hi,
                                .data_8 = data_8,
                                .data_sx = data_sx,
                            },
                        };
                        return result;
                    } else {
                        const data_lo: ?u8 = switch (opcode) {
                            .regmem16_immed16 => input[2],
                            else => null,
                        };
                        const data_hi: ?u8 = switch (opcode) {
                            .regmem16_immed16 => input[3],
                            else => null,
                        };
                        const data_8: ?u8 = switch (opcode) {
                            .regmem8_immed8,
                            .signed_regmem8_immed8,
                            => input[2],
                            else => null,
                        };
                        const data_sx: ?u8 = switch (opcode) {
                            .sign_extend_regmem16_immed8 => input[2],
                            else => null,
                        };

                        result = InstructionData{
                            .identifier_add_op = IdentifierAddOp{
                                .opcode = opcode,
                                .mnemonic = mnemonic,
                                .identifier = identifier,
                                .mod = mod,
                                .rm = rm,
                                .w = w,
                                .s = s,
                                .disp_lo = null,
                                .disp_hi = null,
                                .data_lo = data_lo,
                                .data_hi = data_hi,
                                .data_8 = data_8,
                                .data_sx = data_sx,
                            },
                        };
                        return result;
                    }
                },
                .memoryMode8BitDisplacement => {
                    const disp_lo: u8 = input[2];
                    const data_lo: ?u8 = switch (opcode) {
                        .regmem16_immed16 => input[3],
                        else => null,
                    };
                    const data_hi: ?u8 = switch (opcode) {
                        .regmem16_immed16 => input[4],
                        else => null,
                    };
                    const data_8: ?u8 = switch (opcode) {
                        .regmem8_immed8,
                        .signed_regmem8_immed8,
                        => input[3],
                        else => null,
                    };
                    const data_sx: ?u8 = switch (opcode) {
                        .sign_extend_regmem16_immed8 => input[3],
                        else => null,
                    };

                    result = InstructionData{
                        .identifier_add_op = IdentifierAddOp{
                            .opcode = opcode,
                            .mnemonic = mnemonic,
                            .identifier = identifier,
                            .mod = mod,
                            .rm = rm,
                            .w = w,
                            .s = s,
                            .disp_lo = disp_lo,
                            .disp_hi = null,
                            .data_lo = data_lo,
                            .data_hi = data_hi,
                            .data_8 = data_8,
                            .data_sx = data_sx,
                        },
                    };
                    return result;
                },
                .memoryMode16BitDisplacement => {
                    const disp_lo: u8 = input[2];
                    const disp_hi: u8 = input[3];
                    const data_lo: ?u8 = switch (opcode) {
                        .regmem16_immed16 => input[4],
                        else => null,
                    };
                    const data_hi: ?u8 = switch (opcode) {
                        .regmem16_immed16 => input[5],
                        else => null,
                    };
                    const data_8: ?u8 = switch (opcode) {
                        .regmem8_immed8,
                        .signed_regmem8_immed8,
                        => input[4],
                        else => null,
                    };
                    const data_sx: ?u8 = switch (opcode) {
                        .sign_extend_regmem16_immed8 => input[4],
                        else => null,
                    };

                    result = InstructionData{
                        .identifier_add_op = IdentifierAddOp{
                            .opcode = opcode,
                            .mnemonic = mnemonic,
                            .identifier = identifier,
                            .mod = mod,
                            .rm = rm,
                            .w = w,
                            .s = s,
                            .disp_lo = disp_lo,
                            .disp_hi = disp_hi,
                            .data_lo = data_lo,
                            .data_hi = data_hi,
                            .data_8 = data_8,
                            .data_sx = data_sx,
                        },
                    };
                    return result;
                },
                .registerModeNoDisplacement => {
                    const data_lo: ?u8 = switch (opcode) {
                        .regmem16_immed16 => input[2],
                        else => null,
                    };
                    const data_hi: ?u8 = switch (opcode) {
                        .regmem16_immed16 => input[3],
                        else => null,
                    };
                    const data_8: ?u8 = switch (opcode) {
                        .regmem8_immed8,
                        .signed_regmem8_immed8,
                        => input[2],
                        else => null,
                    };
                    const data_sx: ?u8 = switch (opcode) {
                        .sign_extend_regmem16_immed8 => input[2],
                        else => null,
                    };

                    result = InstructionData{
                        .identifier_add_op = IdentifierAddOp{
                            .opcode = opcode,
                            .mnemonic = mnemonic,
                            .identifier = identifier,
                            .mod = mod,
                            .rm = rm,
                            .w = w,
                            .s = s,
                            .disp_lo = null,
                            .disp_hi = null,
                            .data_lo = data_lo,
                            .data_hi = data_hi,
                            .data_8 = data_8,
                            .data_sx = data_sx,
                        },
                    };
                    return result;
                },
            }
        },

        /////////////////////////////////////////////////////////////
        // Identifier rol opcodes
        /////////////////////////////////////////////////////////////

        // Identifier instructions - with mod without reg
        // min 3, max 6 bytes long with disp_lo, disp_hi,
        // data_8 or data_lo and data_hi or data_sx
        // Identifier.rol_set
        BinaryInstructions.logical_regmem8,
        BinaryInstructions.logical_regmem16,
        BinaryInstructions.logical_regmem8_cl,
        BinaryInstructions.logical_regmem16_cl,
        => {
            const v: VValue = @enumFromInt((input[0] << 6) >> 7);
            const mod: ModValue = @enumFromInt(input[1] >> 6);
            const rm: RmValue = @enumFromInt((input[1] << 5) >> 5);
            const identifier: RolSet = @enumFromInt((input[1] << 2) >> 5);
            const mnemonic: []const u8 = @tagName(identifier);

            switch (mod) {
                .memoryModeNoDisplacement => {
                    if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) {
                        const disp_lo: u8 = input[2];
                        const disp_hi: u8 = input[3];

                        result = InstructionData{
                            .identifier_rol_op = IdentifierRolOp{
                                .opcode = opcode,
                                .identifier = identifier,
                                .mnemonic = mnemonic,
                                .v = v,
                                .mod = mod,
                                .rm = rm,
                                .disp_lo = disp_lo,
                                .disp_hi = disp_hi,
                            },
                        };
                        return result;
                    } else {
                        result = InstructionData{
                            .identifier_rol_op = IdentifierRolOp{
                                .opcode = opcode,
                                .identifier = identifier,
                                .mnemonic = mnemonic,
                                .v = v,
                                .mod = mod,
                                .rm = rm,
                                .disp_lo = null,
                                .disp_hi = null,
                            },
                        };
                        return result;
                    }
                },
                .memoryMode8BitDisplacement => {
                    const disp_lo: u8 = input[2];

                    result = InstructionData{
                        .identifier_rol_op = IdentifierRolOp{
                            .opcode = opcode,
                            .identifier = identifier,
                            .mnemonic = mnemonic,
                            .v = v,
                            .mod = mod,
                            .rm = rm,
                            .disp_lo = disp_lo,
                            .disp_hi = null,
                        },
                    };
                    return result;
                },
                .memoryMode16BitDisplacement => {
                    const disp_lo: u8 = input[2];
                    const disp_hi: u8 = input[3];

                    result = InstructionData{
                        .identifier_rol_op = IdentifierRolOp{
                            .opcode = opcode,
                            .identifier = identifier,
                            .mnemonic = mnemonic,
                            .v = v,
                            .mod = mod,
                            .rm = rm,
                            .disp_lo = disp_lo,
                            .disp_hi = disp_hi,
                        },
                    };
                    return result;
                },
                .registerModeNoDisplacement => {
                    result = InstructionData{
                        .identifier_rol_op = IdentifierRolOp{
                            .opcode = opcode,
                            .identifier = identifier,
                            .mnemonic = mnemonic,
                            .v = v,
                            .mod = mod,
                            .rm = rm,
                            .disp_lo = null,
                            .disp_hi = null,
                        },
                    };
                    return result;
                },
            }
        },

        /////////////////////////////////////////////////////////////
        // Identifier test opcodes
        /////////////////////////////////////////////////////////////

        // Identifier instructions - with mod without reg
        // min 3, max 6 bytes long with disp_lo, disp_hi,
        // data_8 or data_lo and data_hi or data_sx
        // Identifier.test_set
        BinaryInstructions.logical_regmem8_immed8,
        BinaryInstructions.logical_regmem16_immed16,
        => {
            const mod: ModValue = @enumFromInt(input[1] >> 6);
            const rm: RmValue = @enumFromInt((input[1] << 5) >> 5);
            const w: WValue = @enumFromInt((input[0] << 7) >> 7);
            const identifier: TestSet = @enumFromInt((input[1] << 2) >> 5);
            const mnemonic: []const u8 = switch (identifier) {
                .TEST => "test",
                .NOT => "not",
                .NEG => "neg",
                .MUL => "mul",
                .IMUL => "imul",
                .DIV => "div",
                .IDIV => "idiv",
            };

            switch (mod) {
                .memoryModeNoDisplacement => {
                    if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) {
                        const disp_lo: u8 = input[2];
                        const disp_hi: u8 = input[3];

                        result = InstructionData{
                            .identifier_test_op = IdentifierTestOp{
                                .opcode = opcode,
                                .mnemonic = mnemonic,
                                .identifier = identifier,
                                .w = w,
                                .mod = mod,
                                .rm = rm,
                                .disp_lo = disp_lo,
                                .disp_hi = disp_hi,
                                .data_8 = if (w == WValue.byte) input[4] else null,
                                .data_lo = if (w == WValue.word) input[4] else null,
                                .data_hi = if (w == WValue.word) input[5] else null,
                            },
                        };
                        return result;
                    } else {
                        result = InstructionData{
                            .identifier_test_op = IdentifierTestOp{
                                .opcode = opcode,
                                .mnemonic = mnemonic,
                                .identifier = identifier,
                                .w = w,
                                .mod = mod,
                                .rm = rm,
                                .disp_lo = null,
                                .disp_hi = null,
                                .data_8 = if (w == WValue.byte) input[2] else null,
                                .data_lo = if (w == WValue.word) input[2] else null,
                                .data_hi = if (w == WValue.word) input[3] else null,
                            },
                        };
                        return result;
                    }
                },
                .memoryMode8BitDisplacement => {
                    const disp_lo: u8 = input[2];

                    result = InstructionData{
                        .identifier_test_op = IdentifierTestOp{
                            .opcode = opcode,
                            .mnemonic = mnemonic,
                            .identifier = identifier,
                            .w = w,
                            .mod = mod,
                            .rm = rm,
                            .disp_lo = disp_lo,
                            .disp_hi = null,
                            .data_8 = if (w == WValue.byte) input[3] else null,
                            .data_lo = if (w == WValue.word) input[3] else null,
                            .data_hi = if (w == WValue.word) input[4] else null,
                        },
                    };
                    return result;
                },
                .memoryMode16BitDisplacement => {
                    const disp_lo: u8 = input[2];
                    const disp_hi: u8 = input[3];

                    return InstructionData{
                        .identifier_test_op = IdentifierTestOp{
                            .opcode = opcode,
                            .mnemonic = mnemonic,
                            .identifier = identifier,
                            .w = w,
                            .mod = mod,
                            .rm = rm,
                            .disp_lo = disp_lo,
                            .disp_hi = disp_hi,
                            .data_8 = if (w == WValue.byte) input[4] else null,
                            .data_lo = if (w == WValue.word) input[4] else null,
                            .data_hi = if (w == WValue.word) input[5] else null,
                        },
                    };
                },
                .registerModeNoDisplacement => {
                    result = InstructionData{
                        .identifier_test_op = IdentifierTestOp{
                            .opcode = opcode,
                            .mnemonic = mnemonic,
                            .identifier = identifier,
                            .w = w,
                            .mod = mod,
                            .rm = rm,
                            .disp_lo = null,
                            .disp_hi = null,
                            .data_8 = if (w == WValue.byte) input[2] else null,
                            .data_lo = if (w == WValue.word) input[2] else null,
                            .data_hi = if (w == WValue.word) input[3] else null,
                        },
                    };
                    return result;
                },
            }
        },

        /////////////////////////////////////////////////////////////
        // Identifier inc opcodes
        /////////////////////////////////////////////////////////////

        // Identifier instructions - with mod without reg
        // min 2, max 4 bytes long with disp_lo, disp_hi,
        // Identifier.inc_set: inc, dec, call, jmp, push
        BinaryInstructions.regmem8,
        BinaryInstructions.regmem16,
        => {
            const mod: ModValue = @enumFromInt(input[0] >> 6);
            const identifier: IncSet = @enumFromInt((input[1] << 2) >> 5);
            const rm: RmValue = @enumFromInt((input[1] << 5) >> 5);
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

            switch (identifier) {
                .inc => {
                    const w: WValue = @enumFromInt((input[0] << 7) >> 7);

                    result = InstructionData{
                        .identifier_inc_op = IdentifierIncOp{
                            .opcode = opcode,
                            .mnemonic = "inc",
                            .w = w,
                            .mod = mod,
                            .identifier = identifier,
                            .rm = rm,
                            .disp_lo = disp_lo,
                            .disp_hi = disp_hi,
                        },
                    };
                    return result;
                },
                .dec => {
                    const w: WValue = @enumFromInt((input[0] << 7) >> 7);

                    result = InstructionData{
                        .identifier_inc_op = IdentifierIncOp{
                            .opcode = opcode,
                            .mnemonic = "dec",
                            .w = w,
                            .mod = mod,
                            .identifier = identifier,
                            .rm = rm,
                            .disp_lo = disp_lo,
                            .disp_hi = disp_hi,
                        },
                    };
                    return result;
                },
                .call_within,
                .call_intersegment,
                => {
                    result = InstructionData{
                        .identifier_inc_op = IdentifierIncOp{
                            .opcode = opcode,
                            .mnemonic = "call",
                            .w = null,
                            .mod = mod,
                            .identifier = identifier,
                            .rm = rm,
                            .disp_lo = disp_lo,
                            .disp_hi = disp_hi,
                        },
                    };
                    return result;
                },
                .jmp_within,
                .jmp_intersegment,
                => {
                    result = InstructionData{
                        .identifier_inc_op = IdentifierIncOp{
                            .opcode = opcode,
                            .mnemonic = "jmp",
                            .w = null,
                            .mod = mod,
                            .identifier = identifier,
                            .rm = rm,
                            .disp_lo = disp_lo,
                            .disp_hi = disp_hi,
                        },
                    };
                    return result;
                },
                .push,
                => {
                    result = InstructionData{
                        .identifier_inc_op = IdentifierIncOp{
                            .opcode = opcode,
                            .mnemonic = "push",
                            .w = null,
                            .mod = mod,
                            .identifier = identifier,
                            .rm = rm,
                            .disp_lo = disp_lo,
                            .disp_hi = disp_hi,
                        },
                    };
                    return result;
                },
            }
        },

        /////////////////////////////////////////////////////////////
        // Direct opcodes
        /////////////////////////////////////////////////////////////

        // Conditional transfers
        BinaryInstructions.jo_jump_on_overflow,
        BinaryInstructions.jno_jump_on_not_overflow,
        BinaryInstructions.jb_jnae_jump_on_below_not_above_or_equal,
        BinaryInstructions.jnb_jae_jump_on_not_below_above_or_equal,
        BinaryInstructions.je_jz_jump_on_equal_zero,
        BinaryInstructions.jne_jnz_jumb_on_not_equal_not_zero,
        BinaryInstructions.jbe_jna_jump_on_below_or_equal_above,
        BinaryInstructions.jnbe_ja_jump_on_not_below_or_equal_above,
        BinaryInstructions.js_jump_on_sign,
        BinaryInstructions.jns_jump_on_not_sign,
        BinaryInstructions.jp_jpe_jump_on_parity_parity_even,
        BinaryInstructions.jnp_jpo_jump_on_not_parity_parity_odd,
        BinaryInstructions.jl_jnge_jump_on_less_not_greater_or_equal,
        BinaryInstructions.jnl_jge_jump_on_not_less_greater_or_equal,
        BinaryInstructions.jle_jng_jump_on_less_or_equal_not_greater,
        BinaryInstructions.jnle_jg_jump_on_not_less_or_equal_greater,

        // TODO: Add exact line number when finished
        // Interrupts (see also below)
        BinaryInstructions.int_interrupt_type_specified,

        BinaryInstructions.aam_ASCII_adjust_multiply,
        BinaryInstructions.aad_ASCII_adjust_divide,

        // Iteration controls
        BinaryInstructions.loopne_loopnz_loop_while_not_zero_equal,
        BinaryInstructions.loope_loopz_loop_while_zero_equal,
        BinaryInstructions.loop_loop_cx_times,
        BinaryInstructions.jcxz_jump_on_cx_zero,

        // TODO: Add exact line number when finished
        // Unconditional transfers (see also below)
        BinaryInstructions.call_direct_intersegment,
        BinaryInstructions.call_direct_within_segment,
        BinaryInstructions.ret_within_seg_adding_immed16_to_sp,
        BinaryInstructions.ret_intersegment_adding_immed16_to_sp,
        BinaryInstructions.jmp_direct_within_segment,
        BinaryInstructions.jmp_direct_intersegment,
        BinaryInstructions.jmp_direct_within_segment_short,
        => {
            const w: WValue = @enumFromInt((input[0] << 7) >> 7);
            const disp_lo: ?u8 = switch (opcode) {
                BinaryInstructions.call_direct_intersegment,
                BinaryInstructions.aam_ASCII_adjust_multiply,
                BinaryInstructions.aad_ASCII_adjust_divide,
                => input[1],
                else => null,
            };
            const disp_hi: ?u8 = switch (opcode) {
                BinaryInstructions.call_direct_intersegment,
                BinaryInstructions.aam_ASCII_adjust_multiply,
                BinaryInstructions.aad_ASCII_adjust_divide,
                => input[2],
                else => null,
            };
            const data_8: ?u8 = switch (opcode) {
                BinaryInstructions.int_interrupt_type_specified => input[1],
                else => null,
            };
            const data_lo: ?u8 = switch (opcode) {
                BinaryInstructions.ret_within_seg_adding_immed16_to_sp,
                BinaryInstructions.ret_intersegment_adding_immed16_to_sp,
                => input[1],
                else => null,
            };
            const data_hi: ?u8 = switch (opcode) {
                BinaryInstructions.ret_within_seg_adding_immed16_to_sp,
                BinaryInstructions.ret_intersegment_adding_immed16_to_sp,
                => input[2],
                else => null,
            };
            const ip_lo: ?u8 = switch (opcode) {
                BinaryInstructions.jmp_direct_intersegment => input[1],
                else => null,
            };
            const ip_hi: ?u8 = switch (opcode) {
                BinaryInstructions.jmp_direct_intersegment => input[2],
                else => null,
            };
            const seg_lo: ?u8 = switch (opcode) {
                BinaryInstructions.call_direct_intersegment => input[3],
                else => null,
            };
            const seg_hi: ?u8 = switch (opcode) {
                BinaryInstructions.call_direct_intersegment => input[4],
                else => null,
            };
            const cs_lo: ?u8 = switch (opcode) {
                BinaryInstructions.jmp_direct_intersegment => input[3],
                else => null,
            };
            const cs_hi: ?u8 = switch (opcode) {
                BinaryInstructions.jmp_direct_intersegment => input[4],
                else => null,
            };
            const ip_inc_lo: ?u8 = switch (opcode) {
                BinaryInstructions.call_direct_within_segment,
                BinaryInstructions.jmp_direct_within_segment,
                => input[1],
                else => null,
            };
            const ip_inc_hi: ?u8 = switch (opcode) {
                BinaryInstructions.call_direct_within_segment,
                BinaryInstructions.jmp_direct_within_segment,
                => input[2],
                else => null,
            };
            const ip_inc_8: ?u8 = switch (opcode) {
                BinaryInstructions.jo_jump_on_overflow,
                BinaryInstructions.jno_jump_on_not_overflow,
                BinaryInstructions.jb_jnae_jump_on_below_not_above_or_equal,
                BinaryInstructions.jnb_jae_jump_on_not_below_above_or_equal,
                BinaryInstructions.je_jz_jump_on_equal_zero,
                BinaryInstructions.jne_jnz_jumb_on_not_equal_not_zero,
                BinaryInstructions.jbe_jna_jump_on_below_or_equal_above,
                BinaryInstructions.jnbe_ja_jump_on_not_below_or_equal_above,
                BinaryInstructions.js_jump_on_sign,
                BinaryInstructions.jns_jump_on_not_sign,
                BinaryInstructions.jp_jpe_jump_on_parity_parity_even,
                BinaryInstructions.jnp_jpo_jump_on_not_parity_parity_odd,
                BinaryInstructions.jl_jnge_jump_on_less_not_greater_or_equal,
                BinaryInstructions.jnl_jge_jump_on_not_less_greater_or_equal,
                BinaryInstructions.jle_jng_jump_on_less_or_equal_not_greater,
                BinaryInstructions.jnle_jg_jump_on_not_less_or_equal_greater,
                BinaryInstructions.loopne_loopnz_loop_while_not_zero_equal,
                BinaryInstructions.loope_loopz_loop_while_zero_equal,
                BinaryInstructions.loop_loop_cx_times,
                BinaryInstructions.jcxz_jump_on_cx_zero,
                BinaryInstructions.jmp_direct_within_segment_short,
                => input[1],
                else => null,
            };

            result = InstructionData{
                .direct_op = DirectOp{
                    .opcode = opcode,
                    .mnemonic = switch (opcode) {
                        BinaryInstructions.jo_jump_on_overflow => "jo",
                        BinaryInstructions.jno_jump_on_not_overflow => "jno",
                        BinaryInstructions.jb_jnae_jump_on_below_not_above_or_equal => "jb_jnae",
                        BinaryInstructions.jnb_jae_jump_on_not_below_above_or_equal => "jnb_jae",
                        BinaryInstructions.je_jz_jump_on_equal_zero => "je_jz",
                        BinaryInstructions.jne_jnz_jumb_on_not_equal_not_zero => "jne_jnz",
                        BinaryInstructions.jbe_jna_jump_on_below_or_equal_above => "jbe_jna",
                        BinaryInstructions.jnbe_ja_jump_on_not_below_or_equal_above => "jnbe_ja",
                        BinaryInstructions.js_jump_on_sign => "js",
                        BinaryInstructions.jns_jump_on_not_sign => "jns",
                        BinaryInstructions.jp_jpe_jump_on_parity_parity_even => "jp_jpe",
                        BinaryInstructions.jnp_jpo_jump_on_not_parity_parity_odd => "jnp_jpo",
                        BinaryInstructions.jl_jnge_jump_on_less_not_greater_or_equal => "jl_jnge",
                        BinaryInstructions.jnl_jge_jump_on_not_less_greater_or_equal => "jnl_jge",
                        BinaryInstructions.jle_jng_jump_on_less_or_equal_not_greater => "jle_jng",
                        BinaryInstructions.jnle_jg_jump_on_not_less_or_equal_greater => "jnle_jg",
                        BinaryInstructions.call_direct_intersegment => "call",
                        BinaryInstructions.ret_within_seg_adding_immed16_to_sp => "ret",
                        BinaryInstructions.ret_intersegment_adding_immed16_to_sp => "ret",
                        BinaryInstructions.int_interrupt_type_specified => "int",
                        BinaryInstructions.aam_ASCII_adjust_multiply => "aam",
                        BinaryInstructions.aad_ASCII_adjust_divide => "aad",
                        BinaryInstructions.loopne_loopnz_loop_while_not_zero_equal => "loopne_loopnz",
                        BinaryInstructions.loope_loopz_loop_while_zero_equal => "loope_loopz",
                        BinaryInstructions.loop_loop_cx_times => "loop",
                        BinaryInstructions.jcxz_jump_on_cx_zero => "jcxz",
                        BinaryInstructions.call_direct_within_segment => "call",

                        BinaryInstructions.jmp_direct_within_segment,
                        BinaryInstructions.jmp_direct_intersegment,
                        BinaryInstructions.jmp_direct_within_segment_short,
                        => "jmp",
                        else => return InstructionDecodeError.InstructionError,
                    },
                    .w = w,
                    .disp_lo = disp_lo,
                    .disp_hi = disp_hi,
                    .data_8 = data_8,
                    .data_lo = data_lo,
                    .data_hi = data_hi,
                    .ip_lo = ip_lo,
                    .ip_hi = ip_hi,
                    .ip_inc_8 = ip_inc_8,
                    .ip_inc_lo = ip_inc_lo,
                    .ip_inc_hi = ip_inc_hi,
                    .seg_lo = seg_lo,
                    .seg_hi = seg_hi,
                    .cs_lo = cs_lo,
                    .cs_hi = cs_hi,
                },
            };
            return result;
        },

        /////////////////////////////////////////////////////////////
        // Single byte opcodes
        /////////////////////////////////////////////////////////////

        // Single byte instructions - no w, no z
        BinaryInstructions.daa_decimal_adjust_add,
        BinaryInstructions.das_decimal_adjust_sub,
        BinaryInstructions.aaa_ASCII_adjust_add,
        BinaryInstructions.aas_ASCII_adjust_sub,
        BinaryInstructions.cbw_byte_to_word,
        BinaryInstructions.cwd_word_to_double_word,
        BinaryInstructions.wait,
        BinaryInstructions.pushf,
        BinaryInstructions.popf,
        BinaryInstructions.sahf,
        BinaryInstructions.lahf,

        // TODO: Add exact line number when finished
        // Unconditional transfers (see also above)
        BinaryInstructions.ret_within_segment,
        BinaryInstructions.ret_intersegment,

        // Interrupts
        BinaryInstructions.int_interrupt_type_3,
        BinaryInstructions.into_interrupt_on_overflow,
        BinaryInstructions.iret_interrupt_return,

        // General transfer
        BinaryInstructions.in_al_dx,
        BinaryInstructions.in_ax_dx,
        BinaryInstructions.out_al_dx,
        BinaryInstructions.out_ax_dx,

        BinaryInstructions.xlat_translate_byte_to_al,
        BinaryInstructions.lock_bus_lock_prefix,
        BinaryInstructions.halt,
        BinaryInstructions.cmc_complement_carry,
        BinaryInstructions.clc_clear_carry,
        BinaryInstructions.stc_set_carry,
        BinaryInstructions.cli_clear_interrupt,
        BinaryInstructions.sti_set_interrupt,
        BinaryInstructions.cld_clear_direction,
        BinaryInstructions.std_set_direction,
        => {
            result = InstructionData{
                .single_byte_op = SingleByteOp{
                    .opcode = opcode,
                    .mnemonic = switch (opcode) {
                        BinaryInstructions.daa_decimal_adjust_add => "daa",
                        BinaryInstructions.das_decimal_adjust_sub => "das",
                        BinaryInstructions.aaa_ASCII_adjust_add => "aaa",
                        BinaryInstructions.aas_ASCII_adjust_sub => "aas",
                        BinaryInstructions.cbw_byte_to_word => "cbw",
                        BinaryInstructions.cwd_word_to_double_word => "cwd",
                        BinaryInstructions.int_interrupt_type_3 => "int",
                        BinaryInstructions.into_interrupt_on_overflow => "into",
                        BinaryInstructions.iret_interrupt_return => "iret",
                        BinaryInstructions.xlat_translate_byte_to_al => "xlat",
                        BinaryInstructions.lock_bus_lock_prefix => "lock",
                        BinaryInstructions.cmc_complement_carry => "cmc",
                        BinaryInstructions.stc_set_carry => "stc",
                        BinaryInstructions.cli_clear_interrupt => "cli",
                        BinaryInstructions.sti_set_interrupt => "sti",
                        BinaryInstructions.cld_clear_direction => "cld",
                        BinaryInstructions.std_set_direction => "std",
                        BinaryInstructions.in_al_dx,
                        BinaryInstructions.in_ax_dx,
                        => "in",
                        BinaryInstructions.out_al_dx,
                        BinaryInstructions.out_ax_dx,
                        => "out",
                        BinaryInstructions.ret_within_segment,
                        BinaryInstructions.ret_intersegment,
                        => "ret",
                        BinaryInstructions.wait,
                        BinaryInstructions.pushf,
                        BinaryInstructions.popf,
                        BinaryInstructions.sahf,
                        BinaryInstructions.lahf,
                        BinaryInstructions.halt,
                        => @tagName(opcode),
                        else => return InstructionDecodeError.InstructionError,
                    },
                    .w = null,
                    .z = null,
                },
            };
            return result;
        },

        // Single byte instructions - w, no z
        // String instructions
        BinaryInstructions.movs_byte,
        BinaryInstructions.movs_word,
        BinaryInstructions.cmps_byte,
        BinaryInstructions.cmps_word,
        BinaryInstructions.stos_byte,
        BinaryInstructions.stos_word,
        BinaryInstructions.lods_byte,
        BinaryInstructions.lods_word,
        BinaryInstructions.scas_byte,
        BinaryInstructions.scas_word,
        => {
            const w: WValue = @enumFromInt((input[0] << 7) >> 7);
            result = InstructionData{
                .single_byte_op = SingleByteOp{
                    .opcode = opcode,
                    .mnemonic = switch (opcode) {
                        .movs_byte,
                        .movs_word,
                        => "movs",
                        .cmps_byte,
                        .cmps_word,
                        => "cmps",
                        .stos_byte,
                        .stos_word,
                        => "stos",
                        .lods_byte,
                        .lods_word,
                        => "lods",
                        .scas_byte,
                        .scas_word,
                        => "scas",
                        else => return InstructionDecodeError.InstructionError,
                    },
                    .w = w,
                    .z = null,
                },
            };
            return result;
        },

        // Single byte instructions - z, no w
        // String instructions
        BinaryInstructions.repne_repnz_not_equal_zero,
        BinaryInstructions.rep_repe_repz_equal_zero,
        => {
            const z: ZValue = @enumFromInt((input[0] << 7) >> 7);
            result = InstructionData{
                .single_byte_op = SingleByteOp{
                    .opcode = opcode,
                    .mnemonic = "rep",
                    .w = null,
                    .z = z,
                },
            };
            return result;
        },

        // Escape instructions
        BinaryInstructions.esc_external_opcode_000_yyy_source,
        BinaryInstructions.esc_external_opcode_001_yyy_source,
        BinaryInstructions.esc_external_opcode_010_yyy_source,
        BinaryInstructions.esc_external_opcode_011_yyy_source,
        BinaryInstructions.esc_external_opcode_100_yyy_source,
        BinaryInstructions.esc_external_opcode_101_yyy_source,
        BinaryInstructions.esc_external_opcode_110_yyy_source,
        BinaryInstructions.esc_external_opcode_111_yyy_source,
        => {
            const external_opcode: u8 = (input[0] << 5) >> 5;
            const mod: ModValue = @enumFromInt(input[1] >> 6);
            const source: u8 = (input[1] << 2) >> 5;
            const rm: RmValue = @enumFromInt((input[1] << 5) >> 5);

            result = InstructionData{
                .escape_op = EscapeOp{
                    .opcode = opcode,
                    .mnemonic = "esc",
                    .external_opcode = external_opcode,
                    .mod = mod,
                    .source = source,
                    .rm = rm,
                    .disp_lo = switch (mod) {
                        .memoryModeNoDisplacement => if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) input[2] else null,
                        .memoryMode8BitDisplacement => input[2],
                        .memoryMode16BitDisplacement => input[2],
                        .registerModeNoDisplacement => null,
                    },
                    .disp_hi = switch (mod) {
                        .memoryModeNoDisplacement => if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) input[3] else null,
                        .memoryMode8BitDisplacement => null,
                        .memoryMode16BitDisplacement => input[3],
                        .registerModeNoDisplacement => null,
                    },
                },
            };
            return result;
        },
    }
}

test "Register/memory to/from register instructions" {
    const expectEqual = std.testing.expectEqual;

    // 0x03 - Register/Memory 16 bit with Register to Register/Memory 16 bit
    // mod: 0b11, reg: 0b001, rm: 0b010
    const input_0x03_register_mode: [6]u8 = [_]u8{
        0b0000_0011,
        0b1100_1010,
        0b0000_0000,
        0b0000_0000,
        0b0000_0000,
        0b0000_0000,
    };
    const output_payload_0x03_register_mode = InstructionData{
        .register_memory_to_from_register_op = RegisterMemoryToFromRegisterOp{
            .opcode = BinaryInstructions.add_reg16_regmem16,
            .mnemonic = "add",
            .mod = ModValue.registerModeNoDisplacement,
            .rm = RmValue.DLDX_BPSI_BPSID8_BPSID16,
            .reg = RegValue.CLCX,
            .d = DValue.destination,
            .w = WValue.word,
            .disp_hi = null,
            .disp_lo = null,
        },
    };
    try expectEqual(
        output_payload_0x03_register_mode,
        try decode(
            BinaryInstructions.add_reg16_regmem16,
            input_0x03_register_mode,
        ),
    );

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
    const test_output_payload_0x89_mod_register_mode_no_displacement = InstructionData{
        .register_memory_to_from_register_op = RegisterMemoryToFromRegisterOp{
            .opcode = BinaryInstructions.mov_regmem16_reg16,
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
    try expectEqual(
        test_output_payload_0x89_mod_register_mode_no_displacement,
        try decode(
            BinaryInstructions.mov_regmem16_reg16,
            test_input_0x89_mod_register_mode_no_displacement,
        ),
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
    const output_payload_0x88_register_mode_no_displacement = InstructionData{
        .register_memory_to_from_register_op = RegisterMemoryToFromRegisterOp{
            .opcode = BinaryInstructions.mov_regmem8_reg8,
            .mnemonic = "mov",
            .d = DValue.source,
            .w = WValue.byte,
            .mod = ModValue.registerModeNoDisplacement,
            .reg = RegValue.CHBP,
            .rm = RmValue.DLDX_BPSI_BPSID8_BPSID16,
            .disp_lo = null,
            .disp_hi = null,
        },
    };
    try expectEqual(
        output_payload_0x88_register_mode_no_displacement,
        try decode(
            BinaryInstructions.mov_regmem8_reg8,
            input_0x88_register_mode_no_displacement,
        ),
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
    const output_payload_0x88_memory_mode_with_displacement = InstructionData{
        .register_memory_to_from_register_op = RegisterMemoryToFromRegisterOp{
            .opcode = BinaryInstructions.mov_regmem8_reg8,
            .mnemonic = "mov",
            .d = DValue.source,
            .w = WValue.byte,
            .mod = ModValue.memoryModeNoDisplacement,
            .reg = RegValue.BLBX,
            .rm = RmValue.DHSI_DIRECTACCESS_BPD8_BPD16,
            .disp_lo = input_0x88_memory_mode_with_displacement[2],
            .disp_hi = input_0x88_memory_mode_with_displacement[3],
        },
    };
    try expectEqual(
        output_payload_0x88_memory_mode_with_displacement,
        try decode(
            BinaryInstructions.mov_regmem8_reg8,
            input_0x88_memory_mode_with_displacement,
        ),
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
    const output_payload_0x89_memory_mode_no_displacement = InstructionData{
        .register_memory_to_from_register_op = RegisterMemoryToFromRegisterOp{
            .opcode = BinaryInstructions.mov_regmem16_reg16,
            .mnemonic = "mov",
            .d = DValue.source,
            .w = WValue.word,
            .mod = ModValue.memoryModeNoDisplacement,
            .reg = RegValue.CHBP,
            .rm = RmValue.AHSP_SI_SID8_SID16,
            .disp_lo = null,
            .disp_hi = null,
        },
    };
    try expectEqual(
        output_payload_0x89_memory_mode_no_displacement,
        try decode(
            BinaryInstructions.mov_regmem16_reg16,
            input_0x89_memory_mode_no_displacement,
        ),
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
    const output_payload_0x89_memory_mode_8_bit_displacement = InstructionData{
        .register_memory_to_from_register_op = RegisterMemoryToFromRegisterOp{
            .opcode = BinaryInstructions.mov_regmem16_reg16,
            .mnemonic = "mov",
            .d = @enumFromInt(0b0),
            .w = @enumFromInt(0b1),
            .mod = @enumFromInt(0b01),
            .reg = @enumFromInt(0b100),
            .rm = @enumFromInt(0b010),
            .disp_lo = 0b0101_0101,
            .disp_hi = null,
        },
    };
    try expectEqual(
        output_payload_0x89_memory_mode_8_bit_displacement,
        try decode(
            BinaryInstructions.mov_regmem16_reg16,
            input_0x89_memory_mode_8_bit_displacement,
        ),
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
    const test_output_payload_0x89_mod_memory_mode_16_bit_displacement = InstructionData{
        .register_memory_to_from_register_op = RegisterMemoryToFromRegisterOp{
            .opcode = BinaryInstructions.mov_regmem16_reg16,
            .mnemonic = "mov",
            .d = @enumFromInt(0b0),
            .w = @enumFromInt(0b1),
            .mod = @enumFromInt(0b10),
            .reg = @enumFromInt(0b010),
            .rm = @enumFromInt(0b001),
            .disp_lo = 0b0101_0101,
            .disp_hi = 0b1010_1010,
        },
    };
    try expectEqual(
        test_output_payload_0x89_mod_memory_mode_16_bit_displacement,
        try decode(
            BinaryInstructions.mov_regmem16_reg16,
            test_input_0x89_mod_memory_mode_16_bit_displacement,
        ),
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
    const output_payload_0x8A_memory_mode_16_bit_displacement = InstructionData{
        .register_memory_to_from_register_op = RegisterMemoryToFromRegisterOp{
            .opcode = BinaryInstructions.mov_reg8_regmem8,
            .mnemonic = "mov",
            .d = @enumFromInt(0b1),
            .w = @enumFromInt(0b0),
            .mod = @enumFromInt(0b10),
            .reg = @enumFromInt(0b000),
            .rm = @enumFromInt(0b000),
            .disp_lo = 0b1000_0111,
            .disp_hi = 0b0001_0011,
        },
    };
    try expectEqual(
        output_payload_0x8A_memory_mode_16_bit_displacement,
        try decode(
            BinaryInstructions.mov_reg8_regmem8,
            input_0x8A_memory_mode_16_bit_displacement,
        ),
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
    const output_payload_0x8B_memory_mode_8_bit_displacement = InstructionData{
        .register_memory_to_from_register_op = RegisterMemoryToFromRegisterOp{
            .opcode = BinaryInstructions.mov_reg16_regmem16,
            .mnemonic = "mov",
            .d = DValue.destination,
            .w = WValue.word,
            .mod = ModValue.memoryMode8BitDisplacement,
            .reg = RegValue.DHSI,
            .rm = RmValue.CLCX_BXDI_BXDID8_BXDID16,
            .disp_lo = input_0x8B_memory_mode_8_bit_displacement[2],
            .disp_hi = null,
        },
    };
    try expectEqual(
        output_payload_0x8B_memory_mode_8_bit_displacement,
        try decode(
            BinaryInstructions.mov_reg16_regmem16,
            input_0x8B_memory_mode_8_bit_displacement,
        ),
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
    const output_payload_0x8B_memory_mode_16_bit_displacement = InstructionData{
        .register_memory_to_from_register_op = RegisterMemoryToFromRegisterOp{
            .opcode = BinaryInstructions.mov_reg16_regmem16,
            .mnemonic = "mov",
            .d = DValue.destination,
            .w = WValue.word,
            .mod = ModValue.memoryMode16BitDisplacement,
            .reg = RegValue.DHSI,
            .rm = RmValue.DHSI_DIRECTACCESS_BPD8_BPD16,
            .disp_lo = input_0x8B_memory_mode_16_bit_displacement[2],
            .disp_hi = input_0x8B_memory_mode_16_bit_displacement[3],
        },
    };
    try expectEqual(
        output_payload_0x8B_memory_mode_16_bit_displacement,
        try decode(
            BinaryInstructions.mov_reg16_regmem16,
            input_0x8B_memory_mode_16_bit_displacement,
        ),
    );
}

test "Identifier instructions - add set" {
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
    const output_payload_0x83_immediate8_to_regmem16 = InstructionData{
        .identifier_add_op = IdentifierAddOp{
            .opcode = BinaryInstructions.sign_extend_regmem16_immed8,
            .mnemonic = "add",
            .identifier = AddSet.ADD,
            .s = SValue.sign_extend,
            .w = WValue.word,
            .mod = ModValue.memoryMode16BitDisplacement,
            .rm = RmValue.DLDX_BPSI_BPSID8_BPSID16,
            .disp_lo = input_0x83_immediate8_to_regmem16[2],
            .disp_hi = input_0x83_immediate8_to_regmem16[3],
            .data_lo = null,
            .data_hi = null,
            .data_8 = null,
            .data_sx = @intCast(input_0x83_immediate8_to_regmem16[4]),
        },
    };
    try expectEqual(
        output_payload_0x83_immediate8_to_regmem16,
        try decode(
            BinaryInstructions.sign_extend_regmem16_immed8,
            input_0x83_immediate8_to_regmem16,
        ),
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
    const output_payload_0x80_immediate8_to_regmem8 = InstructionData{
        .identifier_add_op = IdentifierAddOp{
            .opcode = BinaryInstructions.regmem8_immed8,
            .mnemonic = "add",
            .identifier = AddSet.ADD,
            .w = WValue.byte,
            .s = SValue.no_sign,
            .mod = ModValue.memoryMode16BitDisplacement,
            .rm = RmValue.DLDX_BPSI_BPSID8_BPSID16,
            .disp_lo = input_0x80_immediate8_to_regmem8[2],
            .disp_hi = input_0x80_immediate8_to_regmem8[3],
            .data_lo = null,
            .data_hi = null,
            .data_8 = input_0x80_immediate8_to_regmem8[4],
            .data_sx = null,
        },
    };
    try expectEqual(
        output_payload_0x80_immediate8_to_regmem8,
        try decode(
            BinaryInstructions.regmem8_immed8,
            input_0x80_immediate8_to_regmem8,
        ),
    );

    const input_0x81_immediate16_to_regmem16_memory_mode_no_displacement: [6]u8 = [_]u8{
        0b1000_0001, // S = 0, W = 1
        0b0000_0011, // mod = 00, ADD, rm = 011
        0b1010_1000,
        0b1111_1101,
        0b0000_0000,
        0b0000_0000,
    };
    const output_payload_0x81_immediate16_to_regmem16_memory_mode_no_displacement = InstructionData{
        .identifier_add_op = IdentifierAddOp{
            .opcode = BinaryInstructions.regmem16_immed16,
            .mnemonic = "add",
            .identifier = AddSet.ADD,
            .s = SValue.no_sign,
            .w = WValue.word,
            .mod = ModValue.memoryModeNoDisplacement,
            .rm = RmValue.BLBX_BPDI_BPDID8_BPDID16,
            .disp_lo = null,
            .disp_hi = null,
            .data_lo = input_0x81_immediate16_to_regmem16_memory_mode_no_displacement[2],
            .data_hi = input_0x81_immediate16_to_regmem16_memory_mode_no_displacement[3],
            .data_8 = null,
            .data_sx = null,
        },
    };
    try expectEqual(
        output_payload_0x81_immediate16_to_regmem16_memory_mode_no_displacement,
        try decode(
            BinaryInstructions.regmem16_immed16,
            input_0x81_immediate16_to_regmem16_memory_mode_no_displacement,
        ),
    );

    const input_0x81_immediate16_to_regmem16: [6]u8 = [_]u8{
        0b1000_0001, // S = 0, W = 1
        0b1000_0010, // mod = 10, ADD, rm = 010
        0b0000_0100,
        0b0010_1011,
        0b0000_0001,
        0b0000_0000,
    };
    const output_payload_0x81_immediate16_to_regmem16 = InstructionData{
        .identifier_add_op = IdentifierAddOp{
            .opcode = BinaryInstructions.regmem16_immed16,
            .mnemonic = "add",
            .identifier = AddSet.ADD,
            .s = SValue.no_sign,
            .w = WValue.word,
            .mod = ModValue.memoryMode16BitDisplacement,
            .rm = RmValue.DLDX_BPSI_BPSID8_BPSID16,
            .disp_lo = input_0x81_immediate16_to_regmem16[2],
            .disp_hi = input_0x81_immediate16_to_regmem16[3],
            .data_lo = input_0x81_immediate16_to_regmem16[4],
            .data_hi = input_0x81_immediate16_to_regmem16[5],
            .data_8 = null,
            .data_sx = null,
        },
    };
    try expectEqual(
        output_payload_0x81_immediate16_to_regmem16,
        try decode(
            BinaryInstructions.regmem16_immed16,
            input_0x81_immediate16_to_regmem16,
        ),
    );
}

test "Identifier instructions - inc set" {
    const expectEqual = std.testing.expectEqual;

    // 0xC6, mod: 0b00, sr: 0b00,
    const input_0xC6_memory_mode_no_displacement: [6]u8 = [_]u8{
        0b1100_0110, // 0xC6
        0b0000_0011, // 0x03
        0b0000_0111, // 0x07
        0b0000_0000,
        0b0000_0000,
        0b0000_0000,
    };
    const output_payload_0xC6_memory_mode_no_displacement = InstructionData{
        .immediate_to_memory_op = ImmediateToMemoryOp{
            .opcode = BinaryInstructions.mov_mem8_immed8,
            .mnemonic = "mov",
            .w = WValue.byte,
            .mod = ModValue.memoryModeNoDisplacement,
            .rm = RmValue.BLBX_BPDI_BPDID8_BPDID16,
            .disp_lo = null,
            .disp_hi = null,
            .data_8 = input_0xC6_memory_mode_no_displacement[2],
            .data_lo = null,
            .data_hi = null,
        },
    };
    try expectEqual(
        output_payload_0xC6_memory_mode_no_displacement,
        try decode(
            BinaryInstructions.mov_mem8_immed8,
            input_0xC6_memory_mode_no_displacement,
        ),
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
    const output_payload_0xC7_memory_mode_16_bit_displacement = InstructionData{
        .immediate_to_memory_op = ImmediateToMemoryOp{
            .opcode = BinaryInstructions.mov_mem16_immed16,
            .mnemonic = "mov",
            .w = WValue.word,
            .mod = ModValue.memoryMode16BitDisplacement,
            .rm = RmValue.AHSP_SI_SID8_SID16,
            .disp_lo = input_0xC7_memory_mode_16_bit_displacement[2],
            .disp_hi = input_0xC7_memory_mode_16_bit_displacement[3],
            .data_8 = null,
            .data_lo = input_0xC7_memory_mode_16_bit_displacement[4],
            .data_hi = input_0xC7_memory_mode_16_bit_displacement[5],
        },
    };
    try expectEqual(
        output_payload_0xC7_memory_mode_16_bit_displacement,
        try decode(
            BinaryInstructions.mov_mem16_immed16,
            input_0xC7_memory_mode_16_bit_displacement,
        ),
    );
}

// TODO: Implemment additional test cases
// test "Identifier instructions - rol set" {}
// test "Identifier instructions - test set" {}
// test "Segment register instructions" {}
// test "Register instructions" {}

test "Accumulator instructions" {
    const expectEqual = std.testing.expectEqual;

    // 0xA1, 0xA2, 0xA3, 0xA4
    const input_0xA1_memory_to_accumulator: [6]u8 = [_]u8{
        0b1010_0001, // 0xA2
        0b0101_0101, // 0x55
        0b1010_1010, // 0xAA
        0b0000_0000,
        0b0000_0000,
        0b0000_0000,
    };
    const output_payload_0xA1_memory_to_accumulator = InstructionData{
        .accumulator_op = AccumulatorOp{
            .opcode = BinaryInstructions.mov_ax_mem16,
            .mnemonic = "mov",
            .w = WValue.word,
            .data_8 = null,
            .data_lo = null,
            .data_hi = null,
            .addr_lo = input_0xA1_memory_to_accumulator[1],
            .addr_hi = input_0xA1_memory_to_accumulator[2],
        },
    };
    try expectEqual(
        output_payload_0xA1_memory_to_accumulator,
        try decode(
            BinaryInstructions.mov_ax_mem16,
            input_0xA1_memory_to_accumulator,
        ),
    );
}

test "Immediate to register mov" {
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
    const output_payload_0xB1_byte = InstructionData{
        .immediate_to_register_op = ImmediateToRegisterOp{
            .opcode = BinaryInstructions.mov_cl_immed8,
            .mnemonic = "mov",
            .w = WValue.byte,
            .reg = RegValue.CLCX,
            .data_8 = input_0xB1_byte[1],
            .data_lo = null,
            .data_hi = null,
        },
    };
    try expectEqual(
        output_payload_0xB1_byte,
        try decode(
            BinaryInstructions.mov_cl_immed8,
            input_0xB1_byte,
        ),
    );

    // 0xBB, w: word
    const input_0xBB_word: [6]u8 = [_]u8{
        0b1011_1011,
        0b0010_0100,
        0b0100_1000,
        0b0000_0000,
        0b0000_0000,
        0b0000_0000,
    };
    const output_payload_0xBB_word = InstructionData{
        .immediate_to_register_op = ImmediateToRegisterOp{
            .opcode = BinaryInstructions.mov_bx_immed16,
            .mnemonic = "mov",
            .w = WValue.word,
            .reg = RegValue.BLBX,
            .data_8 = null,
            .data_lo = input_0xBB_word[1],
            .data_hi = input_0xBB_word[2],
        },
    };
    try expectEqual(
        output_payload_0xBB_word,
        try decode(
            BinaryInstructions.mov_bx_immed16,
            input_0xBB_word,
        ),
    );
}

test instructionScope {
    const expectEqual = std.testing.expectEqual;

    try expectEqual(
        InstructionScope.AccumulatorOp,
        instructionScope(BinaryInstructions.in_ax_immed8),
    );
    try expectEqual(
        InstructionScope.DirectOp,
        instructionScope(BinaryInstructions.jcxz_jump_on_cx_zero),
    );
    try expectEqual(
        InstructionScope.EscapeOp,
        instructionScope(BinaryInstructions.esc_external_opcode_010_yyy_source),
    );
    try expectEqual(
        InstructionScope.IdentifierAddOp,
        instructionScope(BinaryInstructions.regmem16_immed16),
    );
    try expectEqual(
        InstructionScope.IdentifierRolOp,
        instructionScope(BinaryInstructions.logical_regmem16),
    );
    try expectEqual(
        InstructionScope.IdentifierTestOp,
        instructionScope(BinaryInstructions.logical_regmem8_immed8),
    );
    try expectEqual(
        InstructionScope.IdentifierIncOp,
        instructionScope(BinaryInstructions.regmem8),
    );
    try expectEqual(
        InstructionScope.ImmediateToMemoryOp,
        instructionScope(BinaryInstructions.mov_mem8_immed8),
    );
    try expectEqual(
        InstructionScope.ImmediateToRegisterOp,
        instructionScope(BinaryInstructions.mov_si_immed16),
    );
    try expectEqual(
        InstructionScope.RegisterMemoryOp,
        instructionScope(BinaryInstructions.pop_regmem16),
    );
    try expectEqual(
        InstructionScope.RegisterMemoryToFromRegisterOp,
        instructionScope(BinaryInstructions.sub_regmem16_reg16),
    );
    try expectEqual(
        InstructionScope.RegisterOp,
        instructionScope(BinaryInstructions.xchg_ax_di),
    );
}

// TODO: Add missing test cases
// test "Immediate arithmatic instructions" {}
// test "Direct address (offset) operations" {}
// test "Single byte instructions" {}
// test "Escape instructions" {}

// TODO: Add test cases for different instruction sizes

// ========================================================================
//
// (C) Copyright 2025, Nicolas Selig, All Rights Reserved.
//
// This software is provided 'as-is', without any express or implied
// warranty. In no event will the authors be held liable for any damages
// arising from the use of this software.
//
// ========================================================================
