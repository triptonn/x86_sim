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
