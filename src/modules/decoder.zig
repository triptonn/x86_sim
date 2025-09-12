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

const types = @import("../types.zig");
const ModValue = types.instruction_field_names.ModValue;
const RegValue = types.instruction_field_names.RegValue;
const RmValue = types.instruction_field_names.RmValue;
const DValue = types.instruction_field_names.DValue;
const VValue = types.instruction_field_names.VValue;
const WValue = types.instruction_field_names.WValue;
const ZValue = types.instruction_field_names.ZValue;
const SValue = types.instruction_field_names.SValue;
const SrValue = types.instruction_field_names.SrValue;

const errors = @import("../errors.zig");
const InstructionDecodeError = errors.InstructionDecodeError;

// zig fmt: off

// TODO: DocString for BinaryInstructions
pub const BinaryInstructions = enum(u8) {
    /// Register 8 bit with register/memory to register/memory 8 bit
    add_regmem8_reg8                            = 0x00,
    /// Register 16 bit with register/memory to register/memory 16 bit
    add_regmem16_reg16                          = 0x01,
    /// Register/Memory 8 bit with register to register 8 bit
    add_reg8_regmem8                            = 0x02,
    /// Register/Memory 16 bit with register to register 16 bit
    add_reg16_regmem16                          = 0x03,
    /// Add 8 bit immediate value to al
    add_al_immed8                               = 0x04,
    /// Add 16 bit immediate value to ax
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

    // TODO: Implement call
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
    logical_regmem16                        = 0xD1,
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

    // TODO: Implement call
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

    // TODO: Implement test
    logical_regmem8_immed8                      = 0xF6,

    // TODO: Implement invert
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
const RolSet = enum(u3) {
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
const AddSet = enum(u3) {
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
const TestSet = enum(u3) {
    TEST    = 0b000,
    NOT     = 0b010,
    NEG     = 0b011,
    MUL     = 0b100,
    IMUL    = 0b101,
    DIV     = 0b110,
    IDIV    = 0b111,
};

/// Identifier action codes - inc set
const IncSet = enum(u3) {
    inc                 = 0b000,
    dec                 = 0b001,
    call_within         = 0b010,
    call_intersegment   = 0b011,
    jmp_within          = 0b100,
    jmp_intersegment    = 0b101,
    push                = 0b110,
};

// zig fmt: off

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
const RegisterMemoryToFromRegisterOp = struct {
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
const RegisterMemoryOp = struct {
    opcode: BinaryInstructions,
    mnemonic: []const u8,
    mod: ModValue,
    rm: RmValue,
    w: ?WValue,
    disp_lo: ?u8,
    disp_hi: ?u8,
};

/// Instructions without mod but with reg and only containing two bytes
const RegisterOp = struct {
    opcode: BinaryInstructions,
    mnemonic: []const u8,
    reg: RegValue,
};

/// Instructions without mod but with reg
const ImmediateToRegisterOp = struct {
    opcode: BinaryInstructions,
    mnemonic: []const u8,
    w: WValue,
    reg: RegValue,
    data_lo: ?u8,
    data_hi: ?u8,
    data_8: ?u8,
};

// Immediate to memory instructions
const ImmediateOp = struct {
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
const SegmentRegisterOp = struct {
    opcode: BinaryInstructions,
    mnemonic: []const u8,
    mod: ?ModValue,
    sr: SrValue,
    rm: ?RmValue,
    disp_lo: ?u8,
    disp_hi: ?u8,
};

/// Packed instructions with identifier using the add-set
const IdentifierAddOp = struct {
    opcode: BinaryInstructions,
    mnemonic: []const u8,
    identifier: Identifier.add_set,
    w: WValue,
    s: ?SValue,
    disp_lo: ?u8,
    disp_hi: ?u8,
    data_lo: ?u8,
    data_hi: ?u8,
    data_8: ?u8,
    data_sx: ?u16,
};

/// Packed instructions with identifier using rol-set
const IdentifierRolOp = struct {
    opcode: BinaryInstructions,
    mnemonic: []const u8,
    identifier: Identifier.rol_set,
    v: VValue,
    mod: ModValue,
    rm: RmValue,
    disp_lo: ?u8,
    disp_hi: ?u8,
};

/// Packed instructions with identifier using the test-set
const IdentifierTestOp = struct {
    opcode: BinaryInstructions,
    mnemonic: []const u8,
    identifier: Identifier.test_set,
    w: WValue,
    disp_lo: ?u8,
    disp_hi: ?u8,
    data_lo: ?u8,
    data_hi: ?u8,
    data_8: ?u8,
};

/// Packed instructions with identifier using the inc-set
const IdentifierIncOp = struct {
    opcode: BinaryInstructions,
    mnemonic: []const u8,
    mod: ModValue,
    identifier: Identifier.inc_set,
    rm: RmValue,
    w: ?WValue,
    disp_lo: ?u8,
    disp_hi: ?u8,
};

/// Instructions without mod, reg or sr but containing additional instruction bytes
const DirectOp = struct {
    opcode: BinaryInstructions,
    mnemonic: []const u8,
    w: ?WValue,
    disp_lo: ?u8,
    disp_hi: ?u8,
    data_8: ?u8,
    data_lo: ?u8,
    data_hi: ?u8,
    addr_lo: ?u8,
    addr_hi: ?u8,
    ip_lo: ?u8,
    ip_hi: ?u8,
    ip_inc_lo: ?u8,
    ip_inc_hi: ?u8,
    ip_inc_8: ?u8,
    seg_lo: ?u8,
    seg_hi: ?u8,
};

/// Accumulator instructions
const AccumulatorOp = struct {
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
const SingleByteOp = struct {
    opcode: BinaryInstructions,
    mnemonic: []const u8,
    z: ?ZValue,
    w: ?WValue,
};

/// Escape instructions
const EscapeOp = struct {
    opcode: BinaryInstructions,
    mnemonic: []const u8 = "esc",
    mod: ModValue,
    rm: RmValue,
    external_opcode: u3,
    source: u3,
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
    immediate_op,
    segment_register_op,
    identifier_add_op,
    identifier_rol_op,
    identifier_test_op,
    identifier_inc_op,
    direct_op,
    single_byte_op,
};

/// Union holding containers for the data of decoded InstructionBytes.
const InstructionData = union(InstructionDataId) {
    err: InstructionDecodeError,
    accumulator_op: AccumulatorOp,
    escape_op: EscapeOp,
    register_memory_to_from_register_op: RegisterMemoryToFromRegisterOp,
    register_memory_op: RegisterMemoryOp,
    register_op: RegisterOp,
    immediate_to_register_op: ImmediateToRegisterOp,
    immediate_op: ImmediateOp,
    segment_register_op: SegmentRegisterOp,
    identifier_add_op: IdentifierAddOp,
    identifier_rol_op: IdentifierRolOp,
    identifier_test_op: IdentifierTestOp,
    identifier_inc_op: IdentifierIncOp,
    direct_op: DirectOp,
    single_byte_op: SingleByteOp,
};

/// Provided a valid opcode and the input bytes as parameters this function
/// returns a InstructionData object containing all extracted instruction data.
pub fn decode(
    opcode: BinaryInstructions,
    input: [6]u8,
) InstructionDecodeError!InstructionData {
    const log = std.log.scoped(.decode);
    log.debug("Beginning with decoding of binary input...", .{});

    // Categorize instruction structure
    switch (opcode) {
        // Register/Memory to/from Register instructions - with mod and reg
        // min 2, max 4 bytes long with disp_lo and disp_hi
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
        .test_regmem8_reg8,
        .test_regmem16_reg16,
        .xchg_reg8_regmem8,
        .xchg_reg16_regmem16,
        .mov_regmem8_reg8,
        .mov_regmem16_reg16,
        .mov_reg8_regmem8,
        .mov_reg16_regmem16,
        .lea_reg16_mem16,
        .load_es_regmem16,
        .load_ds_regmem16,
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
                .memoryModeNoDisplacement => if (rm != RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) input[2] else null,
                .memoryMode8BitDisplacement => input[2],
                .memoryMode16BitDisplacement => input[2],
                .registerModeNoDisplacement => null,
            };
            const disp_hi: ?u8 = switch (mod) {
                .memoryModeNoDisplacement => if (rm != RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) input[2] else null,
                .memoryMode8BitDisplacement => null,
                .memoryMode16BitDisplacement => input[3],
                .registerModeNoDisplacement => null,
            };

            return InstructionData{
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
        },

        // Identifier instructions - with mod without reg
        // min 3, max 6 bytes long with disp_lo, disp_hi,
        // data_8 or data_lo and data_hi or data_sx
        // Identifier.add_set
        .regmem8_immed8,
        .regmem16_immed16,
        .signed_regmem8_immed8,
        .sign_extend_regmem16_immed8,
        => {
            const s: SValue =  @enumFromInt((input[0] << 6) >> 7);
            const w: WValue = @enumFromInt((input[0] << 7) >> 7);
            const mod: ModValue = @enumFromInt(input[1] >> 6);
            const rm: RmValue = @enumFromInt((input[1] << 5) >> 5);
            const identifier: Identifier.add_set = @enumFromInt((input[1] << 2) >> 5);
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
                            else => return InstructionDecodeError.InstructionError,
                        };
                        const data_hi: ?u8 = switch (opcode) {
                            .regmem16_immed16 => input[5],
                            else => return InstructionDecodeError.InstructionError,
                        };
                        const data_8: ?u8 = switch (opcode) {
                            .regmem8_immed8,
                            .signed_regmem8_immed8,
                            => input[4],
                        };
                        const data_sx: ?u8 = switch (opcode) {
                            .sign_extend_regmem16_immed8 => input[4],
                        };
                        return InstructionData{
                            .identifier_op = IdentifierAddOp{
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
                    } else {
                        const data_lo: ?u8 = switch (opcode) {
                            .regmem16_immed16 => input[2],
                            else => return InstructionDecodeError.InstructionError,
                        };
                        const data_hi: ?u8 = switch (opcode) {
                            .regmem16_immed16 => input[3],
                            else => return InstructionDecodeError.InstructionError,
                        };
                        const data_8: ?u8 = switch (opcode) {
                            .regmem8_immed8,
                            .signed_regmem8_immed8,
                            => input[2],
                        };
                        const data_sx: ?u8 = switch (opcode) {
                            .sign_extend_regmem16_immed8 => input[2],
                        };
                        return InstructionData{
                            .identifier_op = IdentifierAddOp{
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
                    }
                },
                .memoryMode8BitDisplacement => {
                    const disp_lo: u8 = input[2];
                    const data_lo: ?u8 = switch (opcode) {
                        .regmem16_immed16 => input[3],
                        else => return InstructionDecodeError.InstructionError,
                    };
                    const data_hi: ?u8 = switch (opcode) {
                        .regmem16_immed16 => input[4],
                        else => return InstructionDecodeError.InstructionError,
                    };
                    const data_8: ?u8 = switch (opcode) {
                        .regmem8_immed8,
                        .signed_regmem8_immed8,
                        => input[3],
                    };
                    const data_sx: ?u8 = switch (opcode) {
                        .sign_extend_regmem16_immed8 => input[3],
                    };
                    return InstructionData{
                        .identifier_op = IdentifierAddOp{
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
                },
                .memoryMode16BitDisplacement => {
                    const disp_lo: u8 = input[2];
                    const disp_hi: u8 = input[3];
                    const data_lo: ?u8 = switch (opcode) {
                        .regmem16_immed16 => input[4],
                        else => return InstructionDecodeError.InstructionError,
                    };
                    const data_hi: ?u8 = switch (opcode) {
                        .regmem16_immed16 => input[5],
                        else => return InstructionDecodeError.InstructionError,
                    };
                    const data_8: ?u8 = switch (opcode) {
                        .regmem8_immed8,
                        .signed_regmem8_immed8,
                        => input[4],
                    };
                    const data_sx: ?u8 = switch (opcode) {
                        .sign_extend_regmem16_immed8 => input[4],
                    };
                    return InstructionData{
                        .identifier_op = IdentifierAddOp{
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
                },
                .registerModeNoDisplacement => {
                    const data_lo: ?u8 = switch (opcode) {
                        .regmem16_immed16 => input[2],
                        else => return InstructionDecodeError.InstructionError,
                    };
                    const data_hi: ?u8 = switch (opcode) {
                        .regmem16_immed16 => input[3],
                        else => return InstructionDecodeError.InstructionError,
                    };
                    const data_8: ?u8 = switch (opcode) {
                        .regmem8_immed8,
                        .signed_regmem8_immed8,
                        => input[2],
                    };
                    const data_sx: ?u8 = switch (opcode) {
                        .sign_extend_regmem16_immed8 => input[2],
                    };
                    return InstructionData{
                        .identifier_op = IdentifierAddOp{
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
                },
            }
        },


        // Identifier instructions - with mod without reg
        // min 3, max 6 bytes long with disp_lo, disp_hi,
        // data_8 or data_lo and data_hi or data_sx
        .pop_regmem16 => {
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
            return InstructionData{
                .identifier_inc_op = IdentifierIncOp{
                    .opcode = opcode,
                    .mnemonic = "pop",
                    .mod = mod,
                    .identifier = @enumFromInt(0b000),
                    .rm = rm,
                    .w = null,
                    .disp_lo = disp_lo,
                    .disp_hi = disp_hi,
                },
            };
        },

        // Identifier instructions - with mod without reg
        // min 3, max 6 bytes long with disp_lo, disp_hi,
        // data_8 or data_lo and data_hi or data_sx
        .mov_mem8_immed8,
        .mov_mem16_immed16,
        => {
            const w: WValue = @enumFromInt((input[1] << 7) >> 7);
            const mod: ModValue = @enumFromInt(input[1] >> 6);
            const rm: RmValue = @enumFromInt((input[1] << 5) >> 5);
            switch (mod) {
                .memoryModeNoDisplacement => {
                    if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) {
                        const disp_lo: u8 = input[2];
                        const disp_hi: u8 = input[3];
                        return InstructionData{
                            .immediate_op = ImmediateOp{
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
                    } else {
                        return InstructionData{
                            .immediate_op = ImmediateOp{
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
                    }
                },
                .memoryMode8BitDisplacement => {
                    const disp_lo: u8 = input[2];
                    return InstructionData{
                        .immediate_op = ImmediateOp{
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
                },
                .memoryMode16BitDisplacement => {
                    const disp_lo: u8 = input[2];
                    const disp_hi: u8 = input[3];
                    return InstructionData{
                        .immediate_op = ImmediateOp{
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
                },
                .registerModeNoDisplacement => {
                    return InstructionData{
                        .immediate_op = ImmediateOp{
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
                },
            }
        },

        // Identifier instructions - with mod without reg
        // min 3, max 6 bytes long with disp_lo, disp_hi,
        // data_8 or data_lo and data_hi or data_sx
        // Identifier.rol_set
        .logical_regmem8,
        .logical_regmem16,
        .logical_regmem8_cl,
        .logical_regmem16_cl,
        => {
            const v: VValue = @enumFromInt((input[0] << 6) >> 7);
            const mod: ModValue = @enumFromInt(input[1] >> 6);
            const rm: RmValue = @enumFromInt((input[1] << 5) >> 5);
            const identifier: Identifier.rol_set = @enumFromInt((input[1] << 2) >> 5);
            const mnemonic: []const u8 = @tagName(identifier);
            switch (mod) {
                .memoryModeNoDisplacement => {
                    if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) {
                        const disp_lo: u8 = input[2];
                        const disp_hi: u8 = input[3];
                        return InstructionData{
                            .identifier_op = IdentifierRolOp{
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
                    } else {
                        return InstructionData{
                            .identifier_op = IdentifierRolOp{
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
                    }
                },
                .memoryMode8BitDisplacement => {
                    const disp_lo: u8 = input[2];
                    return InstructionData{
                        .identifier_op = IdentifierRolOp{
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
                },
                .memoryMode16BitDisplacement => {
                    const disp_lo: u8 = input[2];
                    const disp_hi: u8 = input[3];
                    return InstructionData{
                        .identifier_op = IdentifierRolOp{
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
                },
                .registerModeNoDisplacement => {
                    return InstructionData{
                        .identifier_op = IdentifierRolOp{
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
                },
            }
        },

        // Identifier instructions - with mod without reg
        // min 3, max 6 bytes long with disp_lo, disp_hi,
        // data_8 or data_lo and data_hi or data_sx
        // Identifier.test_set
        .logical_regmem8_immed8,
        .logical_regmem16_immed16,
        => {
            const mod: ModValue = @enumFromInt(input[1] >> 6);
            const rm: RmValue = @enumFromInt((input[1] << 5) >> 5);
            const w: WValue = @enumFromInt((input[0] << 7) >> 7);
            const identifier: Identifier.test_set = @enumFromInt((input[1] << 2) >> 5);
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
                        return InstructionData{
                            .identifier_op = IdentifierTestOp{
                                .opcode = opcode,
                                .mnemonic = mnemonic,
                                .identifier = identifier,
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
                    } else {
                        return InstructionData{
                            .identifier_op = IdentifierTestOp{
                                .opcode = opcode,
                                .mnemonic = mnemonic,
                                .identifier = identifier,
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
                    }
                },
                .memoryMode8BitDisplacement => {
                    const disp_lo: u8 = input[2];
                    return InstructionData{
                        .identifier_op = IdentifierTestOp{
                            .opcode = opcode,
                            .mnemonic = mnemonic,
                            .identifier = identifier,
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
                },
                .memoryMode16BitDisplacement => {
                    const disp_lo: u8 = input[2];
                    const disp_hi: u8 = input[3];
                    return InstructionData{
                        .identifier_op = IdentifierTestOp{
                            .opcode = opcode,
                            .mnemonic = mnemonic,
                            .identifier = identifier,
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
                },
                .registerModeNoDisplacement => {
                    return InstructionData{
                        .identifier_op = IdentifierTestOp{
                            .opcode = opcode,
                            .mnemonic = mnemonic,
                            .identifier = identifier,
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
                },
            }
        },

        // Identifier instructions - with mod without reg
        // min 2, max 4 bytes long with disp_lo, disp_hi,
        // Identifier.inc_set
        .regmem8,
        .regmem16,
        => {
            const mod: ModValue = @enumFromInt(input[0] >> 6);
            const identifier: Identifier.inc_set = @enumFromInt((input[1] << 2) >> 5);
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
                    return InstructionData{
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
                },
                .dec => {
                    const w: WValue = @enumFromInt((input[0] << 7) >> 7);
                    return InstructionData{
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
                },
                .call_within,
                .call_intersegment,
                .jmp_within,
                .jmp_intersegment,
                .push,
                => {
                    return InstructionData{
                        .instruction_inc_op = IdentifierIncOp{
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
                },
            }
        },

        // (Segment) Register ops
        .push_es,
        .push_cs,
        .push_ss,
        .push_ds,
        => {
            const sr: SrValue = @enumFromInt((input[0] << 3) >> 6);
            return InstructionData{
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
        },
        .pop_es,
        .pop_ss,
        .pop_ds,
        => {
            const sr: SrValue = @enumFromInt((input[0] << 3) >> 6);
            return InstructionData{
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
        },
        .inc_ax,
        .inc_cx,
        .inc_dx,
        .inc_bx,
        .inc_sp,
        .inc_bp,
        .inc_si,
        .inc_di,
        => {
            const reg: RegValue = @enumFromInt((input[0] << 5) >> 5);
            return InstructionData{
                .register_op = RegisterOp{
                    .opcode = opcode,
                    .mnemonic = "inc",
                    .reg = reg,
                },
            };
        },
        .dec_ax,
        .dec_cx,
        .dec_dx,
        .dec_bx,
        .dec_sp,
        .dec_bp,
        .dec_si,
        .dec_di,
        => {
            const reg: RegValue = @enumFromInt((input[0] << 5) >> 5);
            return InstructionData{
                .register_op = RegisterOp{
                    .opcode = opcode,
                    .mnemonic = "dec",
                    .reg = reg,
                },
            };
        },
        .push_ax,
        .push_cx,
        .push_dx,
        .push_bx,
        .push_sp,
        .push_bp,
        .push_si,
        .push_di,
        => {
            const reg: RegValue = @enumFromInt((input[0] << 5) >> 5);
            return InstructionData{
                .register_op = RegisterOp{
                    .opcode = opcode,
                    .mnemonic = "push",
                    .reg = reg,
                },
            };
        },
        .pop_ax,
        .pop_cx,
        .pop_dx,
        .pop_bx,
        .pop_sp,
        .pop_bp,
        .pop_si,
        .pop_di,
        => {
            const reg: RegValue = @enumFromInt((input[0] << 5) >> 5);
            return InstructionData{
                .register_op = RegisterOp{
                    .opcode = opcode,
                    .mnemonic = "pop",
                    .reg = reg,
                },
            };
        },
        .nop_xchg_ax_ax => {
            const reg: RegValue = @enumFromInt((input[0] << 5) >> 5);
            return InstructionData{
                .register_op = RegisterOp{
                    .opcode = opcode,
                    .mnemonic = "nop",
                    .reg = reg,
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
            const reg: RegValue = @enumFromInt((input[0] << 5) >> 5);
            return InstructionData{
                .register_op = RegisterOp{
                    .opcode = opcode,
                    .mnemonic = "xchg",
                    .reg = reg,
                },
            };
        },

        // Immediate to register mov
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
            const w: WValue = @enumFromInt((input[0] << 4) >> 7);
            const reg: RegValue = @enumFromInt((input[0] << 5) >> 5);
            return InstructionData{
                .immediate_to_register_op = ImmediateToRegisterOp{
                    .opcode = opcode,
                    .mnemonic = "mov",
                    .w = w,
                    .reg = reg,
                    .data_8 = if (@intFromEnum(opcode) <= 0xBE) input[1] else null,
                    .data_lo = if (@intFromEnum(opcode) > 0xBE) input[1] else null,
                    .data_hi = if (@intFromEnum(opcode) > 0xBE) input[2] else null,
                },
            };
        },

        // Segment register instructions
        .mov_regmem16_segreg,
        .mov_segreg_regmem16,
        => {
            const mod: ModValue = @enumFromInt(input[1] >> 6);
            const sr: SrValue = @enumFromInt((input[1] << 3) >> 6);
            const rm: RmValue = @enumFromInt((input[1] << 5) >> 5);
            return InstructionData{
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
        },

        // no mod no reg with w
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
        .in_al_dx,
        .in_ax_dx,
        .out_al_dx,
        .out_ax_dx,
        => {
            const w: WValue = @enumFromInt((input[0] << 7) >> 7);
            return InstructionData{
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
                        .in_al_dx,
                        .in_ax_dx,
                        => "in",
                        .out_al_dx,
                        .out_ax_dx,
                        => "out",
                    },
                    .w = w,
                    .data_8 = if (w == WValue.byte) input[1] else null,
                    .data_lo = if (w == WValue.word) input[1] else null,
                    .data_hi = if (w == WValue.word) input[2] else null,
                    .addr_lo = null,
                    .addr_hi = null,
                },
            };
        },

        // Direct address (offset) addr-lo, addr-hi
        .mov_al_mem8,
        .mov_ax_mem16,
        .mov_mem8_al,
        .mov_mem16_ax,
        => {
            const w: WValue = @enumFromInt((input[0] << 7) >> 7);
            return InstructionData{
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
        },

        // no mod no reg no w
        .segment_override_prefix_es,
        .segment_override_prefix_cs,
        .segment_override_prefix_ss,
        .segment_override_prefix_ds,
        .jo_jump_on_overflow,
        .jno_jump_on_not_overflow,
        .jb_jnae_jump_on_below_not_above_or_equal,
        .jnb_jae_jump_on_not_below_above_or_equal,
        .je_jz_jump_on_equal_zero,
        .jne_jnz_jumb_on_not_equal_not_zero,
        .jbe_jna_jump_on_below_or_equal_above,
        .jnbe_ja_jump_on_not_below_or_equal_above,
        .js_jump_on_sign,
        .jns_jump_on_not_sign,
        .jp_jpe_jump_on_parity_parity_even,
        .jnp_jpo_jump_on_not_parity_parity_odd,
        .jl_jnge_jump_on_less_not_greater_or_equal,
        .jnl_jge_jump_on_not_less_greater_or_equal,
        .jle_jng_jump_on_less_or_equal_not_greater,
        .jnle_jg_jump_on_not_less_or_equal_greater,
        .call_direct_intersegment,
        .ret_within_seg_adding_immed16_to_sp,
        .ret_intersegment_adding_immed16_to_sp,
        .int_interrupt_type_specified,
        .aam_ASCII_adjust_multiply,
        .aad_ASCII_adjust_divide,
        .loopne_loopnz_loop_while_not_zero_equal,
        .loope_loopz_loop_while_zero_equal,
        .loop_loop_cx_times,
        .jcxz_jump_on_cx_zero,
        .call_direct_within_segment,
        .jmp_direct_within_segment,
        .jmp_direct_intersegment,
        .jmp_direct_within_segment_short,
        => {
            // TODO: Whatever this is...
        },

        // Single byte instructions - no w, no z
        .daa_decimal_adjust_add,
        .das_decimal_adjust_sub,
        .aaa_ASCII_adjust_add,
        .aas_ASCII_adjust_sub,
        .cbw_byte_to_word,
        .cwd_word_to_double_word,
        .wait,
        .pushf,
        .popf,
        .sahf,
        .lahf,
        .ret_within_segment,
        .ret_intersegment,
        .int_interrupt_type_3,
        .into_interrupt_on_overflow,
        .iret_interrupt_return,
        .xlat_translate_byte_to_al,
        .lock_bus_lock_prefix,
        .halt,
        .cmc_complement_carry,
        .clc_clear_carry,
        .stc_set_carry,
        .cli_clear_interrupt,
        .sti_set_interrupt,
        .cld_clear_direction,
        .std_set_direction,
        => {
            return InstructionData{
                .single_byte_op = SingleByteOp{
                    .opcode = opcode,
                    .mnemonic = switch (opcode) {
                        .daa_decimal_adjust_add => "daa",
                        .das_decimal_adjust_sub => "das",
                        .aaa_ASCII_adjust_add => "aaa",
                        .aas_ASCII_adjust_sub => "aas",
                        .cbw_byte_to_word => "cbw",
                        .cwd_word_to_double_word => "cwd",
                        .int_interrupt_type_3 => "int",
                        .into_interrupt_on_overflow => "into",
                        .iret_interrupt_return => "iret",
                        .xlat_translate_byte_to_al => "xlat",
                        .lock_bus_lock_prefix => "lock",
                        .cmc_complement_carry => "cmc",
                        .stc_set_carry => "stc",
                        .cli_clear_interrupt => "cli",
                        .sti_set_interrupt => "sti",
                        .cld_clear_direction => "cld",
                        .std_set_direction => "std",

                        .ret_within_segment,
                        .ret_intersegment,
                        => "ret",

                        .wait,
                        .pushf,
                        .popf,
                        .sahf,
                        .lahf,
                        .halt,
                        => @tagName(opcode),
                    },
                    .w = null,
                    .z = null,
                },
            };
        },

        // Single byte instructions - w, no z
        .movs_byte,
        .movs_word,
        .cmps_byte,
        .cmps_word,
        .stos_byte,
        .stos_word,
        .lods_byte,
        .lods_word,
        .scas_byte,
        .scas_word,
        .in_al_immed8,
        .in_ax_immed8,
        .out_al_immed8,
        .out_ax_immed8,
        => {
            const w: WValue = @enumFromInt((input[0] << 7) >> 7);
            return InstructionData{
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
                        .in_al_immed8,
                        .in_ax_immed8,
                        => "in",
                        .out_al_immed8,
                        .out_ax_immed8,
                        => "out",
                    },
                    .w = w,
                    .z = null,
                },
            };
        },

        // Single byte instructions - z, no w
        .repne_repnz_not_equal_zero,
        .rep_repe_repz_equal_zero,
        => {
            const z: ZValue = @enumFromInt((input[0] << 7) >> 7);
            return InstructionData{
                .single_byte_op = SingleByteOp{
                    .opcode = opcode,
                    .mnemonic = "rep",
                    .w = null,
                    .z = z,
                },
            };
        },

        // Escape instructions
        .esc_external_opcode_000_yyy_source,
        .esc_external_opcode_001_yyy_source,
        .esc_external_opcode_010_yyy_source,
        .esc_external_opcode_011_yyy_source,
        .esc_external_opcode_100_yyy_source,
        .esc_external_opcode_101_yyy_source,
        .esc_external_opcode_110_yyy_source,
        .esc_external_opcode_111_yyy_source,
        => {
            const external_opcode: u3 = (input[0] << 5) >> 5;
            const mod: ModValue = @enumFromInt(input[1] >> 6);
            const source: u3 = (input[1] << 2) >> 5;
            const rm: RmValue = @enumFromInt((input[1] << 5) >> 5);

            return InstructionData{
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
        },

    }
}

////////////////////////////////////////////////////////////////////////////////
// DEPRECATED BELOW
////////////////////////////////////////////////////////////////////////////////

/// Add instructions - DEPRECATED
/// - Register/memory with register to either: 0x00 - 0x03
/// - Immediate to accumulator: 0x04, 0x05
pub const Add = struct {
    opcode: BinaryInstructions,
    mnemonic: []const u8,
    d: ?DValue,
    w: WValue,
    mod: ?ModValue,
    reg: ?RegValue,
    rm: ?RmValue,
    disp_lo: ?u8,
    disp_hi: ?u8,
    data: ?u8,
    w_data: ?u8,
};

/// Immediate operation instructions
/// - Immediate byte value to register/memory 0x80
/// - Immediate word value to register/memory 0x81
/// - Sign-extended byte value to register/memory (data-8) 0x82
/// - Immediate byte value to 16 bit register (data-sx) 0x83
// pub const ImmediateOp = struct {
//     opcode: BinaryInstructions,
//     mnemonic: []const u8,
//     s: SValue,
//     w: WValue,
//     mod: ModValue,
//     rm: RmValue,
//     disp_lo: ?u8,
//     disp_hi: ?u8,
//     data_lo: ?u8,
//     data_hi: ?u8,
//     data_8: ?u8,
//     signed_data_8: ?i8,
//     data_sx: ?i16,
// };

/// MovInstruction with mod field
/// - register/memory to/from register: 0x88, 0x89, 0x8A, 0x8B
/// - segment register to/from register/memory: 0x8C, 0x8E
pub const MovWithMod = struct {
    opcode: BinaryInstructions,
    mnemonic: []const u8,
    d: ?DValue,
    w: ?WValue,
    mod: ModValue,
    reg: ?RegValue,
    sr: ?SrValue,
    rm: RmValue,
    disp_lo: ?u8,
    disp_hi: ?u8,
    data: ?u8,
    w_data: ?u8,
};

/// MovInstruction w/o mod field
/// - Immediate to register: 0xB0 - 0xBF
/// - memory to/from accumulator: 0xA0, 0xA1, 0xA2, 0xA3
pub const MovWithoutMod = struct {
    opcode: BinaryInstructions,
    mnemonic: []const u8,
    w: WValue,
    reg: ?RegValue,
    data: ?u8,
    w_data: ?u8,
    addr_lo: ?u8,
    addr_hi: ?u8,
};

/// Enum holding the identifier's for the different DecodePayload fields.
const InstructionPayloadIdentifier = enum {
    err,
    add_instruction,
    immediate_op_instruction,
    mov_with_mod_instruction,
    mov_without_mod_instruction,
};

/// Payload carrying the instruction specific, decoded field values
/// (of the instruction plus all data belonging to the instruction as
/// byte data)inside a struct. If an error occured during instruction
/// decoding its value is returned in this Payload.
pub const InstructionPayload = union(InstructionPayloadIdentifier) {
    err: InstructionDecodeError,
    add_instruction: Add,
    immediate_op_instruction: ImmediateOp,
    mov_with_mod_instruction: MovWithMod,
    mov_without_mod_instruction: MovWithoutMod,
};

/// Decode add instruction providing the values of the Mod and R/M fields
/// of the instruction. Returns a DecodePayload union object containing either
/// a DecodePayload.addInstruction value or an error.
pub fn decodeAdd(
    mod: ModValue,
    rm: RmValue,
    input: [6]u8,
) InstructionDecodeError!InstructionPayload {
    const log = std.log.scoped(.decodeAdd);

    const instruction: BinaryInstructions = @enumFromInt((input[0]));
    const mnemonic = "add";
    const disp_lo: ?u8 = switch (mod) {
        .memoryModeNoDisplacement => if (rm != RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) input[2] else null,
        .memoryMode8BitDisplacement => input[2],
        .memoryMode16BitDisplacement => input[2],
        .registerModeNoDisplacement => null,
    };
    const disp_hi: ?u8 = switch (mod) {
        .memoryModeNoDisplacement => if (rm != RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) input[2] else null,
        .memoryMode8BitDisplacement => null,
        .memoryMode16BitDisplacement => input[2],
        .registerModeNoDisplacement => null,
    };

    const d: DValue = @enumFromInt((input[0] << 6) >> 7);
    const w: WValue = @enumFromInt((input[0] << 7) >> 7);

    switch (instruction) {
        .add_regmem8_reg8,
        .add_regmem16_reg16,
        .add_reg8_regmem8,
        .add_reg16_regmem16,
        => {
            const reg: RegValue = @enumFromInt((input[1] << 2) >> 5);
            return InstructionPayload{
                .add_instruction = Add{
                    .opcode = instruction,
                    .mnemonic = mnemonic,
                    .d = d,
                    .w = w,
                    .mod = mod,
                    .reg = reg,
                    .rm = rm,
                    .disp_lo = disp_lo,
                    .disp_hi = disp_hi,
                    .data = null,
                    .w_data = null,
                },
            };
        },
        .add_al_immed8 => {
            const data: u8 = input[1];

            return InstructionPayload{
                .add_instruction = Add{
                    .opcode = instruction,
                    .mnemonic = "add",
                    .d = null,
                    .w = w,
                    .mod = null,
                    .reg = null,
                    .rm = null,
                    .disp_lo = null,
                    .disp_hi = null,
                    .data = data,
                    .w_data = null,
                },
            };
        },
        .add_ax_immed16 => {
            const data: u8 = input[1];
            const w_data: u8 = input[2];

            return InstructionPayload{
                .add_instruction = Add{
                    .opcode = instruction,
                    .mnemonic = "add",
                    .d = null,
                    .w = w,
                    .mod = null,
                    .reg = null,
                    .rm = null,
                    .disp_lo = null,
                    .disp_hi = null,
                    .data = data,
                    .w_data = w_data,
                },
            };
        },
        else => {
            log.err("Instruction '{t}' not yet implemented.", .{instruction});
            return InstructionDecodeError.NotYetImplemented;
        },
    }
}

/// IdentifierOp action codes
const IdentifierOld = enum(u3) {
    ADD = 0b000,
    OR = 0b001,
    ADC = 0b010,
    SBB = 0b011,
    AND = 0b100,
    SUB = 0b101,
    XOR = 0b110,
    CMP = 0b111,
};

// TODO: Create DocString for this function
/// DocString
pub fn decodeImmediateOp(
    s: SValue,
    w: WValue,
    input: [6]u8,
) InstructionDecodeError!InstructionPayload {
    const log = std.log.scoped(.decodeImmediateOp);
    const instruction: BinaryInstructions = @enumFromInt(input[0]);
    const mod: ModValue = @enumFromInt(input[1] >> 6);
    const rm: RmValue = @enumFromInt((input[1] << 5) >> 5);
    const identifier: IdentifierOld = @enumFromInt((input[1] << 2) >> 5);
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
        .regmem8_immed8 => {
            return InstructionPayload{
                .immediate_op_instruction = ImmediateOp{
                    .opcode = BinaryInstructions.regmem8_immed8,
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
        .regmem16_immed16 => {
            return InstructionPayload{
                .immediate_op_instruction = ImmediateOp{
                    .opcode = BinaryInstructions.regmem16_immed16,
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
        .signed_regmem8_immed8 => {
            return InstructionPayload{
                .immediate_op_instruction = ImmediateOp{
                    .opcode = BinaryInstructions.signed_regmem8_immed8,
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
        .sign_extend_regmem16_immed8 => {
            return InstructionPayload{
                .immediate_op_instruction = ImmediateOp{
                    .opcode = BinaryInstructions.sign_extend_regmem16_immed8,
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
pub fn decodeMovWithMod(
    mod: ModValue,
    rm: RmValue,
    input: [6]u8,
) InstructionPayload {
    const log = std.log.scoped(.decodeMovWithMod);
    const mnemonic = "mov";
    const _rm = rm;
    const _mod = mod;

    const instruction: BinaryInstructions = @enumFromInt(input[0]);

    switch (instruction) {
        .mov_regmem16_segreg,
        .mov_segreg_regmem16,
        => {
            switch (_mod) {
                ModValue.memoryModeNoDisplacement => {
                    const temp_w = input[0] << 7;
                    const w: u1 = @intCast(temp_w >> 7);

                    var temp_sr = input[1] << 3;
                    temp_sr = temp_sr >> 6;
                    const sr: u2 = @intCast(temp_sr);

                    const result = InstructionPayload{
                        .mov_with_mod_instruction = MovWithMod{
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

                    const result = InstructionPayload{
                        .mov_with_mod_instruction = MovWithMod{
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

                    const result = InstructionPayload{
                        .mov_with_mod_instruction = MovWithMod{
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

                    const result = InstructionPayload{
                        .mov_with_mod_instruction = MovWithMod{
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
        .mov_regmem8_reg8,
        .mov_regmem16_reg16,
        .mov_reg8_regmem8,
        .mov_reg16_regmem16,
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

                        const result = InstructionPayload{
                            .mov_with_mod_instruction = MovWithMod{
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

                        const result = InstructionPayload{
                            .mov_with_mod_instruction = MovWithMod{
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

                    const result = InstructionPayload{
                        .mov_with_mod_instruction = MovWithMod{
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

                    const result = InstructionPayload{
                        .mov_with_mod_instruction = MovWithMod{
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

                    const result = InstructionPayload{
                        .mov_with_mod_instruction = MovWithMod{
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
        .mov_mem8_immed8,
        .mov_mem16_immed16,
        => {
            const w: WValue = @enumFromInt((input[0] << 7) >> 7);
            switch (mod) {
                .memoryModeNoDisplacement => {
                    const result = InstructionPayload{
                        .mov_with_mod_instruction = MovWithMod{
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
                    const result = InstructionPayload{
                        .mov_with_mod_instruction = MovWithMod{
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
                    const result = InstructionPayload{
                        .mov_with_mod_instruction = MovWithMod{
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
                    const result = InstructionPayload{
                        .mov_with_mod_instruction = MovWithMod{
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
            const result = InstructionPayload{
                .err = InstructionDecodeError.NotYetImplemented,
            };
            log.err("Error: Decode mov with mod field not possible. Instruction not yet implemented.", .{});
            return result;
        },
    }
}

/// Matchin binary values against instruction- and register enum's. Returns a DecodePayload union
/// with instruction specific decoded content.
pub fn decodeMovWithoutMod(
    w: WValue,
    input: [6]u8,
) InstructionPayload {
    const log = std.log.scoped(.decodeMovWithoutMod);

    const temp_reg: u8 = input[0] << 5;
    const reg: RegValue = @enumFromInt(temp_reg >> 5);

    const instruction: BinaryInstructions = @enumFromInt(input[0]);

    switch (instruction) {
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
            switch (w) {
                .byte => {
                    const result = InstructionPayload{
                        .mov_without_mod_instruction = MovWithoutMod{
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
                    const result = InstructionPayload{
                        .mov_without_mod_instruction = MovWithoutMod{
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
        .mov_al_mem8,
        .mov_ax_mem16,
        .mov_mem8_al,
        .mov_mem16_ax,
        => {
            const result = InstructionPayload{
                .mov_without_mod_instruction = MovWithoutMod{
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
            const result = InstructionPayload{
                .err = InstructionDecodeError.NotYetImplemented,
            };
            log.err("Error: Decode mov without mod field not possible. Instruction not yet implemented.", .{});
            return result;
        },
    }
}

test decodeAdd {
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
    const output_payload_0x03_register_mode = InstructionPayload{
        .add_instruction = Add{
            .opcode = BinaryInstructions.add_reg16_regmem16,
            .mnemonic = "add",
            .d = DValue.destination,
            .w = WValue.word,
            .mod = ModValue.registerModeNoDisplacement,
            .reg = RegValue.CLCX,
            .rm = RmValue.DLDX_BPSI_BPSID8_BPSID16,
            .disp_hi = null,
            .disp_lo = null,
            .data = null,
            .w_data = null,
        },
    };
    try expectEqual(
        decodeAdd(
            ModValue.registerModeNoDisplacement,
            RmValue.DLDX_BPSI_BPSID8_BPSID16,
            input_0x03_register_mode,
        ),
        output_payload_0x03_register_mode,
    );
}

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
    const output_payload_0x83_immediate8_to_regmem16 = InstructionPayload{
        .immediate_op_instruction = ImmediateOp{
            .opcode = BinaryInstructions.sign_extend_regmem16_immed8,
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
    const output_payload_0x80_immediate8_to_regmem8 = InstructionPayload{
        .immediate_op_instruction = ImmediateOp{
            .opcode = BinaryInstructions.regmem8_immed8,
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
    const output_payload_0x81_immediate16_to_regmem16_memory_mode_no_displacement = InstructionPayload{
        .immediate_op_instruction = ImmediateOp{
            .opcode = BinaryInstructions.regmem16_immed16,
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
    const output_payload_0x81_immediate16_to_regmem16 = InstructionPayload{
        .immediate_op_instruction = ImmediateOp{
            .opcode = BinaryInstructions.regmem16_immed16,
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
    const test_output_payload_0x89_mod_register_mode_no_displacement = InstructionPayload{
        .mov_with_mod_instruction = MovWithMod{
            .opcode = BinaryInstructions.mov_regmem16_reg16,
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
    const output_payload_0x88_register_mode_no_displacement = InstructionPayload{
        .mov_with_mod_instruction = MovWithMod{
            .opcode = BinaryInstructions.mov_regmem8_reg8,
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
    const output_payload_0x88_memory_mode_with_displacement = InstructionPayload{
        .mov_with_mod_instruction = MovWithMod{
            .opcode = BinaryInstructions.mov_regmem8_reg8,
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
    const output_payload_0x89_memory_mode_no_displacement = InstructionPayload{
        .mov_with_mod_instruction = MovWithMod{
            .opcode = BinaryInstructions.mov_regmem16_reg16,
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
    const output_payload_0x89_memory_mode_8_bit_displacement = InstructionPayload{
        .mov_with_mod_instruction = MovWithMod{
            .opcode = BinaryInstructions.mov_regmem16_reg16,
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
    const test_output_payload_0x89_mod_memory_mode_16_bit_displacement = InstructionPayload{
        .mov_with_mod_instruction = MovWithMod{
            .opcode = BinaryInstructions.mov_regmem16_reg16,
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
    const output_payload_0x8A_memory_mode_16_bit_displacement = InstructionPayload{
        .mov_with_mod_instruction = MovWithMod{
            .opcode = BinaryInstructions.mov_reg8_regmem8,
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
    const output_payload_0x8B_memory_mode_8_bit_displacement = InstructionPayload{
        .mov_with_mod_instruction = MovWithMod{
            .opcode = BinaryInstructions.mov_reg16_regmem16,
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
    const output_payload_0x8B_memory_mode_16_bit_displacement = InstructionPayload{
        .mov_with_mod_instruction = MovWithMod{
            .opcode = BinaryInstructions.mov_reg16_regmem16,
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
    const output_payload_0xC6_memory_mode_no_displacement = InstructionPayload{
        .mov_with_mod_instruction = MovWithMod{
            .opcode = BinaryInstructions.mov_mem8_immed8,
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
    const output_payload_0xC7_memory_mode_16_bit_displacement = InstructionPayload{
        .mov_with_mod_instruction = MovWithMod{
            .opcode = BinaryInstructions.mov_mem16_immed16,
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
    const output_payload_0xB1_byte = InstructionPayload{
        .mov_without_mod_instruction = MovWithoutMod{
            .opcode = BinaryInstructions.mov_cl_immed8,
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
    const output_payload_0xBB_word = InstructionPayload{
        .mov_without_mod_instruction = MovWithoutMod{
            .opcode = BinaryInstructions.mov_bx_immed16,
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
    const output_payload_0xA1_memory_to_accumulator = InstructionPayload{
        .mov_without_mod_instruction = MovWithoutMod{
            .opcode = BinaryInstructions.mov_ax_mem16,
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
