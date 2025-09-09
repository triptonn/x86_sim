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
const WValue = types.instruction_field_names.WValue;
const SValue = types.instruction_field_names.SValue;
const SrValue = types.instruction_field_names.SrValue;

const errors = @import("../errors.zig");
const InstructionDecodeError = errors.InstructionDecodeError;

// zig fmt: off
pub const BinaryInstructions = enum(u8) {

    // ASM-86 ADD INSTRUCTIONS                | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 |
    // ---------------------------------------|-----------------------------------------------------------------------------------------------------------|
    // ADD: Reg/memory with register to either| 0 0 0 0 0 0|D|W | MOD| REG | R/M  |    (DISP-LO)    |    (DISP-HI)    |<---------------XXX--------------->|

    /// Register 8 bit with register/memory to register/memory 8 bit
    add_reg8_source_regmem8_dest        = 0x00,
    /// Register 16 bit with register/memory to register/memory 16 bit
    add_reg16_source_regmem16_dest      = 0x01,
    /// Register/Memory 8 bit with register to register 8 bit
    add_regmem8_source_reg8_dest        = 0x02,
    /// Register/Memory 16 bit with register to register 16 bit
    add_regmem16_source_reg16_dest      = 0x03,

    // ASM-86 ADD INSTRUCTIONS                | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 |
    // ---------------------------------------|-----------------------------------------------------------------------------------------------------------|
    // ADD: Immediate to accumulator          | 0 0 0 0 0 1 0|W |       data      |   data if W=1   |<------------------------XXX------------------------>|

    // TODO: Implement
    // /// DocString
    add_immediate_8_bit_to_acc  = 0x04,
    // /// DocString
    add_immediate_16_bit_to_acc = 0x05,

    // ASM-86 Immediate INSTRUCTIONS          | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 |
    // ---------------------------------------|-----------------------------------------------------------------------------------------------------------|
    // ADD: Immediate to register/memory      | 1 0 0 0 0 0|S|W | MOD|0 0 0| R/M  |    (DISP-LO)    |    (DISP-HI)    |       data      | data if S: w=01 |
    // OR: Immediate with register/memory     | 1 0 0 0 0 0 0|W | MOD|0 0 1| R/M  |    (DISP-LO)    |    (DISP-HI)    |       data      | data if S: w=01 |
    // ADC: Immediate to register/memory      | 1 0 0 0 0 0|S|W | MOD|0 1 0| R/M  |    (DISP-LO)    |    (DISP-HI)    |       data      | data if S: w=01 |
    // SBB: Immediate from register/memory    | 1 0 0 0 0 0|S|W | MOD|0 1 1| R/M  |    (DISP-LO)    |    (DISP-HI)    |       data      | data if S: w=01 |
    // AND: Immediate with register/memory    | 1 0 0 0 0 0 0|W | MOD|1 0 0| R/M  |    (DISP-LO)    |    (DISP-HI)    |       data      | data if S: w=01 |
    // SUB: Immediate from register/memory    | 1 0 0 0 0 0|S|W | MOD|1 0 1| R/M  |    (DISP-LO)    |    (DISP-HI)    |       data      | data if S: w=01 |
    // XOR: Immediate with register/memory    | 1 0 0 0 0 0 0|W | MOD|1 1 0| R/M  |    (DISP-LO)    |    (DISP-HI)    |       data      | data if S: w=01 |
    // CMP: Immediate with register/memory    | 1 0 0 0 0 0|S|W | MOD|1 1 1| R/M  |    (DISP-LO)    |    (DISP-HI)    |       data      | data if S: w=01 |

    /// Immediate 8 bit value <action> to/with/from 8 bit register/memory operation (DATA-8).
    immediate8_to_regmem8       = 0x80,
    /// Immediate 16 bit value <action> to/with/from 16 bit register/memory operation (DATA-LO, DATA-HI).
    immediate16_to_regmem16     = 0x81,
    /// Signed immediate value <action> to/with/from 16 bit register/memory operation (DATA-8).
    s_immediate8_to_regmem8     = 0x82,
    /// Auto-sign-extend immediate 8 bit value <action> to/with/from 16 bit register/memory operation (DATA-SX).
    immediate8_to_regmem16      = 0x83,

    // ASM-86 MOV INSTRUCTIONS                | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 |
    // ---------------------------------------|-----------------------------------------------------------------------------------------------------------|
    // MOV: Register/memory to/from register  | 1 0 0 0 1 0|D|W | MOD| REG | R/M  |    (DISP-LO)    |    (DISP-HI)    |<---------------XXX--------------->|

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

    // ASM-86 MOV INSTRUCTIONS                | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 |
    // ---------------------------------------|-----------------------------------------------------------------------------------------------------------|
    // MOV: Segment reg. to register/memory   | 1 0 0 0 1 1 0 0 | MOD|0|SR | R/M  |    (DISP-LO)    |    (DISP-HI)    |<---------------XXX--------------->|

    /// Segment register to register/memory if second byte of format 0x|MOD|0|SR|R/M|
    mov_seg_regmem              = 0x8C,

    // ASM-86 MOV INSTRUCTIONS                | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 |
    // ---------------------------------------|-----------------------------------------------------------------------------------------------------------|
    // MOV: Register/memory to segment reg.   | 1 0 0 0 1 1 1 0 | MOD|0|SR | R/M  |    (DISP-LO)    |    (DISP-HI)    |<---------------XXX--------------->|

    /// Register/memory to segment register if second byte of format 0x|MOD|0|SR|R/M|
    mov_regmem_seg              = 0x8E,

    // ASM-86 MOV INSTRUCTIONS                | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 |
    // ---------------------------------------|-----------------------------------------------------------------------------------------------------------|
    // MOV: Memory to accumulator             | 1 0 1 0 0 0 0|W |     addr-lo     |     addr-hi     |<-----------------------XXX------------------------->|

    /// Memory to accumulator
    mov_mem8_acc8               = 0xA0,
    /// Memory to accumulator
    mov_mem16_acc16             = 0xA1,

    // ASM-86 MOV INSTRUCTIONS                | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 |
    // ---------------------------------------|-----------------------------------------------------------------------------------------------------------|
    // MOV: Accumulator to memory             | 1 0 1 0 0 0 1|W |     addr-lo     |     addr-hi     |<-----------------------XXX------------------------->|

    /// Accumulator to memory
    mov_acc8_mem8               = 0xA2,
    /// Accumulator to memory
    mov_acc16_mem16             = 0xA3,

    // ASM-86 MOV INSTRUCTIONS                | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 |
    // ---------------------------------------|-----------------------------------------------------------------------------------------------------------|
    // MOV: Immediate to register             | 1 0 1 1|W| reg  |      data       |   data if W=1   |<-----------------------XXX------------------------->|

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

    // ASM-86 MOV INSTRUCTIONS                | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 |
    // ---------------------------------------|-----------------------------------------------------------------------------------------------------------|
    // MOV: Immediate to register/memory      | 1 1 0 0 0 1 1|W | MOD|0 0 0| R/M  |    (DISP-LO)    |    (DISP-HI)    |       data      |   data if W=1   |

    /// Immediate to register/memory
    mov_immediate_to_regmem8    = 0xC6,
    /// Immediate to register/memory
    mov_immediate_to_regmem16   = 0xC7,
};
// zig fmt: on

/// Add instructions
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
pub const ImmediateOp = struct {
    opcode: BinaryInstructions,
    mnemonic: []const u8,
    s: SValue,
    w: WValue,
    mod: ModValue,
    rm: RmValue,
    disp_lo: ?u8,
    disp_hi: ?u8,
    data_lo: ?u8,
    data_hi: ?u8,
    data_8: ?u8,
    signed_data_8: ?i8,
    data_sx: ?i16,
};

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
        .add_reg8_source_regmem8_dest,
        .add_reg16_source_regmem16_dest,
        .add_regmem8_source_reg8_dest,
        .add_regmem16_source_reg16_dest,
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
        .add_immediate_8_bit_to_acc => {
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
        .add_immediate_16_bit_to_acc => {
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
            return InstructionPayload{
                .immediate_op_instruction = ImmediateOp{
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
            return InstructionPayload{
                .immediate_op_instruction = ImmediateOp{
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
            return InstructionPayload{
                .immediate_op_instruction = ImmediateOp{
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
            return InstructionPayload{
                .immediate_op_instruction = ImmediateOp{
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
        .mov_immediate_to_regmem8,
        .mov_immediate_to_regmem16,
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
        .mov_mem8_acc8,
        .mov_mem16_acc16,
        .mov_acc8_mem8,
        .mov_acc16_mem16,
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
            .opcode = BinaryInstructions.add_regmem16_source_reg16_dest,
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
    const output_payload_0x80_immediate8_to_regmem8 = InstructionPayload{
        .immediate_op_instruction = ImmediateOp{
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
    const output_payload_0x81_immediate16_to_regmem16_memory_mode_no_displacement = InstructionPayload{
        .immediate_op_instruction = ImmediateOp{
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
    const output_payload_0x81_immediate16_to_regmem16 = InstructionPayload{
        .immediate_op_instruction = ImmediateOp{
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
    const test_output_payload_0x89_mod_register_mode_no_displacement = InstructionPayload{
        .mov_with_mod_instruction = MovWithMod{
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
    const output_payload_0x88_register_mode_no_displacement = InstructionPayload{
        .mov_with_mod_instruction = MovWithMod{
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
    const output_payload_0x88_memory_mode_with_displacement = InstructionPayload{
        .mov_with_mod_instruction = MovWithMod{
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
    const output_payload_0x89_memory_mode_no_displacement = InstructionPayload{
        .mov_with_mod_instruction = MovWithMod{
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
    const output_payload_0x89_memory_mode_8_bit_displacement = InstructionPayload{
        .mov_with_mod_instruction = MovWithMod{
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
    const test_output_payload_0x89_mod_memory_mode_16_bit_displacement = InstructionPayload{
        .mov_with_mod_instruction = MovWithMod{
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
    const output_payload_0x8A_memory_mode_16_bit_displacement = InstructionPayload{
        .mov_with_mod_instruction = MovWithMod{
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
    const output_payload_0x8B_memory_mode_8_bit_displacement = InstructionPayload{
        .mov_with_mod_instruction = MovWithMod{
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
    const output_payload_0x8B_memory_mode_16_bit_displacement = InstructionPayload{
        .mov_with_mod_instruction = MovWithMod{
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
    const output_payload_0xC6_memory_mode_no_displacement = InstructionPayload{
        .mov_with_mod_instruction = MovWithMod{
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
    const output_payload_0xC7_memory_mode_16_bit_displacement = InstructionPayload{
        .mov_with_mod_instruction = MovWithMod{
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
    const output_payload_0xB1_byte = InstructionPayload{
        .mov_without_mod_instruction = MovWithoutMod{
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
    const output_payload_0xBB_word = InstructionPayload{
        .mov_without_mod_instruction = MovWithoutMod{
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
    const output_payload_0xA1_memory_to_accumulator = InstructionPayload{
        .mov_without_mod_instruction = MovWithoutMod{
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
