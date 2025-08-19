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

    /// 8 bit Register/memory to/from register except R/M=DHSI_DIRECT_ACCESS
    mov_source_regmem8_reg8     = 0x88,
    /// 16 bit Register/memory to/from register
    mov_source_regmemreg16      = 0x89,
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

// Payload:
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
            if (rm == RmValue.DHSI_DIRECT_ACCESS) return 4 else return 2;
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

// zig fmt: off
/// Matching binary values against instruction- and register enum's. Returns names of the
/// instructions and registers as strings in an []u8.
fn decodeMov(
    mod: ModValue,
    rm: RmValue,
    input: [6]u8
) DecodePayload {
// zig fmt: on
    const mnemonic = "mov";
    const _rm = rm;
    const _mod = mod;

    switch (_mod) {
        ModValue.memoryModeNoDisplacement => {
            if (_rm == RmValue.DHSI_DIRECT_ACCESS) {
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
            var temp_d = input[0] >> 1;
            temp_d = temp_d <<| 7;
            temp_d = temp_d >> 7;
            var temp_w = input[0] <<| 7;
            temp_w = temp_w >> 7;
            var temp_reg = input[1] >> 3;
            temp_reg = temp_reg <<| 6;
            temp_reg = temp_reg >> 6;

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

/// Simulates the General register of the 8086 Processor
const GeneralRegisters = struct {
    AX: u16,
    BX: u16,
    CX: u16,
    DX: u16,
    SP: u16,
    BP: u16,
    DI: u16,
    SI: u16,
    pub fn setAH(self: *GeneralRegisters, value: u8) void {
        self.AX = value ++ self.AX[8..];
    }
    pub fn setAL(self: *GeneralRegisters, value: u8) void {
        self.AX = self.AX[0..8] ++ value;
    }
    pub fn setBH(self: *GeneralRegisters, value: u8) void {
        self.BX = value ++ self.BX[8..];
    }
    pub fn setBL(self: *GeneralRegisters, value: u8) void {
        self.BX = self.BX[0..8] ++ value;
    }
    pub fn setCH(self: *GeneralRegisters, value: u8) void {
        self.CX = value ++ self.CX[8..];
    }
    pub fn setCL(self: *GeneralRegisters, value: u8) void {
        self.CX = self.CX[0..8] ++ value;
    }
    pub fn setDH(self: *GeneralRegisters, value: u8) void {
        self.DX = value ++ self.DX[8..];
    }
    pub fn setDL(self: *GeneralRegisters, value: u8) void {
        self.DX = self.DX[0..8] ++ value;
    }
    pub fn setSP(self: *GeneralRegisters, value: u16) void {
        self.SP = value;
    }
    pub fn setBP(self: *GeneralRegisters, value: u16) void {
        self.BP = value;
    }
    pub fn setSI(self: *GeneralRegisters, value: u16) void {
        self.SI = value;
    }
    pub fn setDI(self: *GeneralRegisters, value: u16) void {
        self.DI = value;
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
    var stepSize: u3 = 2;
    var instruction_bytes: [6]u8 = undefined;
    const file_contents = try file.readToEndAlloc(heap_allocator, maxFileSizeBytes);
    std.debug.print("Instruction byte count: {d}\n", .{file_contents.len});

    var depleted: bool = false;

    while (!depleted and activeByte < file_contents.len) : (activeByte += stepSize) {
        const default: u8 = 0b00000000;
        const first_byte: u8 = if (activeByte < file_contents.len) file_contents[activeByte] else default;
        const second_byte: u8 = if (activeByte + 1 < file_contents.len) file_contents[activeByte + 1] else default;
        const third_byte: u8 = if (activeByte + 2 < file_contents.len) file_contents[activeByte + 2] else default;
        const fourth_byte: u8 = if (activeByte + 3 < file_contents.len) file_contents[activeByte + 3] else default;
        const fifth_byte: u8 = if (activeByte + 4 < file_contents.len) file_contents[activeByte + 4] else default;
        const sixth_byte: u8 = if (activeByte + 5 < file_contents.len) file_contents[activeByte + 5] else default;

        // std.debug.print("---Data-Range----------------------------------------------------------------\n", .{});
        // std.debug.print("1: {b:0>8} {d},\n2: {b:0>8} {d},\n3: {b:0>8} {d},\n4: {b:0>8} {d},\n5: {b:0>8} {d},\n6: {b:0>8} {d},\n", .{
        //     first_byte,  activeByte,
        //     second_byte, activeByte + 1,
        //     third_byte,  activeByte + 2,
        //     fourth_byte, activeByte + 3,
        //     fifth_byte,  activeByte + 4,
        //     sixth_byte,  activeByte + 5,
        // });

        const instruction: BinaryInstructions = @enumFromInt(first_byte);

        // std.debug.print("DEBUG: instruction: {any}\n", .{instruction});
        var mod: ModValue = undefined;
        var rm: RmValue = undefined;
        switch (instruction) {
            BinaryInstructions.mov_source_regmem8_reg8 => { // 0x88
                mod = @enumFromInt(second_byte >> 6);
                const temp_rm = second_byte << 5;
                rm = @enumFromInt(temp_rm >> 5);

                stepSize = movGetInstructionLength(mod, rm);
                // std.debug.print("DEBUG: 0x88: Mod {any}, R/M {any} = {d} bytes\n", .{ mod, rm, stepSize });
            },
            BinaryInstructions.mov_source_regmemreg16 => { // 0x89
                mod = @enumFromInt(second_byte >> 6);
                const temp_rm = second_byte << 5;
                rm = @enumFromInt(temp_rm >> 5);

                stepSize = movGetInstructionLength(mod, rm);
                // std.debug.print("DEBUG: 0x89: Mod {any}, R/M {any} = {d} bytes\n", .{ mod, rm, stepSize });
            },
            BinaryInstructions.mov_dest_reg8_regmem8 => { // 0x8A
                mod = @enumFromInt(second_byte >> 6);
                const temp_rm = second_byte << 5;
                rm = @enumFromInt(temp_rm >> 5);

                stepSize = movGetInstructionLength(mod, rm);
                // std.debug.print("DEBUG: 0x8A: Mod {any}, R/M {any} = {d} bytes\n", .{ mod, rm, stepSize });
            },
            BinaryInstructions.mov_dest_reg16_regmem16 => { // 0x8B
                mod = @enumFromInt(second_byte >> 6);
                const temp_rm = second_byte << 5;
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
                instruction_bytes = [6]u8{
                    first_byte,
                    second_byte,
                    0b0000_0000,
                    0b0000_0000,
                    0b0000_0000,
                    0b0000_0000,
                };
            },
            3 => {
                instruction_bytes = [6]u8{
                    first_byte,
                    second_byte,
                    third_byte,
                    0b0000_0000,
                    0b0000_0000,
                    0b0000_0000,
                };
            },
            4 => {
                instruction_bytes = [6]u8{
                    first_byte,
                    second_byte,
                    third_byte,
                    fourth_byte,
                    0b0000_0000,
                    0b0000_0000,
                };
            },
            5 => {
                instruction_bytes = [6]u8{
                    first_byte,
                    second_byte,
                    third_byte,
                    fourth_byte,
                    fifth_byte,
                    0b0000_0000,
                };
            },
            6 => {
                instruction_bytes = [6]u8{
                    first_byte,
                    second_byte,
                    third_byte,
                    fourth_byte,
                    fifth_byte,
                    sixth_byte,
                };
            },
            else => {
                std.debug.print("InstructionError: Instruction size {} invalid", .{stepSize});
            },
        }

        std.debug.print("--------------------------------------------------------------------------------\n", .{});
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
                payload = decodeMov(mod, rm, instruction_bytes);
            },
            .mov_source_regmemreg16 => {
                payload = decodeMov(mod, rm, instruction_bytes);
            },
            .mov_dest_reg8_regmem8 => {
                payload = decodeMov(mod, rm, instruction_bytes);
            },
            .mov_dest_reg16_regmem16 => {
                payload = decodeMov(mod, rm, instruction_bytes);
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
                std.debug.print("Instruction: 0x{x}: Mod {b}, Mnemonic {s} Reg {any}, R/M {any}, DISP-LO {b:0>8}, DISP-HI {b:0>8}\n", .{
                    @intFromEnum(instruction),
                    @intFromEnum(payload.mov_instruction.mod),
                    payload.mov_instruction.mnemonic,
                    payload.mov_instruction.reg,
                    payload.mov_instruction.rm,
                    if (stepSize == 3 or stepSize == 4) payload.mov_instruction.disp_lo.? else instruction_bytes[2],
                    if (stepSize == 4) payload.mov_instruction.disp_hi.? else instruction_bytes[3],
                });

                const d: DValue = payload.mov_instruction.d;
                const w: WValue = payload.mov_instruction.w;
                const reg: RegValue = payload.mov_instruction.reg;
                switch (w) {
                    0 => {
                        switch (reg) {
                            .ALAX => {},
                            .CLCX => {},
                            .DLDX => {},
                            .BLBX => {},
                            .AHSP => {},
                            .CHBP => {},
                            .DHSI => {},
                            .BHDI => {},
                            else => {
                                std.debug.print("ERROR: Reg value not set.\n", .{});
                            },
                        }
                    },
                    1 => {
                        switch (reg) {
                            .ALAX => {},
                            .CLCX => {},
                            .DLDX => {},
                            .BLBX => {},
                            .AHSP => {},
                            .CHBP => {},
                            .DHSI => {},
                            .BHDI => {},
                            else => {
                                std.debug.print("ERROR: Reg value not set.\n", .{});
                            },
                        }
                    },
                }
                var dest: GeneralRegisters = undefined;
                var source: GeneralRegisters = undefined;
                switch (payload.mov_instruction.mod) {
                    .memoryModeNoDisplacement => {
                        switch (payload.mov_instruction.rm) {
                            .ALAX_BXSI_BXSID8_BXSID16 => {},
                            .CLCX_BXDI_BXDID8_BXDID16 => {},
                            .DLDX_BPSI_BPSID8_BPSID16 => {},
                            .BLBX_BPDI_BPDID8_BPDID16 => {},
                            .AHSP_SI_SID8_SID16 => {},
                            .CHBP_DI_DID8_DID16 => {},
                            .DHSI_DIRECTACCESS_BPD8_BPD16 => {},
                            .BHDI_BX_BXD8_BXD16 => {},
                            else => {
                                std.debug.print("ERROR: R/M value not set.\n", .{});
                            },
                        }
                    },
                    .memoryMode8BitDisplacement => {
                        switch (rm) {
                            .ALAX_BXSI_BXSID8_BXSID16 => {},
                            .CLCX_BXDI_BXDID8_BXDID16 => {},
                            .DLDX_BPSI_BPSID8_BPSID16 => {},
                            .BLBX_BPDI_BPDID8_BPDID16 => {},
                            .AHSP_SI_SID8_SID16 => {},
                            .CHBP_DI_DID8_DID16 => {},
                            .DHSI_DIRECTACCESS_BPD8_BPD16 => {},
                            .BHDI_BX_BXD8_BXD16 => {},
                            else => {
                                std.debug.print("ERROR: R/M value not set.\n", .{});
                            },
                        }
                    },
                    .memoryMode16BitDisplacement => {
                        switch (rm) {
                            .ALAX_BXSI_BXSID8_BXSID16 => {},
                            .CLCX_BXDI_BXDID8_BXDID16 => {},
                            .DLDX_BPSI_BPSID8_BPSID16 => {},
                            .BLBX_BPDI_BPDID8_BPDID16 => {},
                            .AHSP_SI_SID8_SID16 => {},
                            .CHBP_DI_DID8_DID16 => {},
                            .DHSI_DIRECTACCESS_BPD8_BPD16 => {},
                            .BHDI_BX_BXD8_BXD16 => {},
                            else => {
                                std.debug.print("ERROR: R/M value not set.\n", .{});
                            },
                        }
                    },
                    .registerModeNoDisplacement => {
                        switch (rm) {
                            .ALAX_BXSI_BXSID8_BXSID16 => {
                                switch (d) {
                                    .source => {
                                        dest = if (w == WValue.byte) "al" else "ax";
                                        source = reg;
                                    },
                                    .destination => {
                                        dest = reg;
                                        source = if (w == WValue.byte) "al" else "ax";
                                    },
                                }
                            },
                            .CLCX_BXDI_BXDID8_BXDID16 => {},
                            .DLDX_BPSI_BPSID8_BPSID16 => {},
                            .BLBX_BPDI_BPDID8_BPDID16 => {},
                            .AHSP_SI_SID8_SID16 => {},
                            .CHBP_DI_DID8_DID16 => {},
                            .DHSI_DIRECTACCESS_BPD8_BPD16 => {},
                            .BHDI_BX_BXD8_BXD16 => {},
                            else => {
                                std.debug.print("ERROR: R/M value not set.\n", .{});
                            },
                        }
                    },
                    else => {
                        std.debug.print("ERROR: Mod value not set.\n", .{});
                    },
                }

                std.debug.print("ASM-86 {s} {s},{s}", .{ payload.mov_instruction.mnemonic, dest, source });
            },
        }

        if (activeByte + stepSize == maxFileSizeBytes or activeByte + stepSize >= file_contents.len) {
            depleted = true;
            std.debug.print("+++Simulation+finished++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n", .{});
        } else {
            std.debug.print("+++Next+active+byte+{d}+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n", .{activeByte + stepSize});
        }

        // switch (instruction) {
        //     BinaryInstructions.mov_source_regmem8_reg8 => { // 0x88
        //         const mod: ModValue = @enumFromInt(second_byte >> 6);
        //         const temp_rm = second_byte << 5;
        //         const rm: RmValue = @enumFromInt(temp_rm >> 5);

        //         const ByteCount = movGetInstructionLength(mod, rm);
        //         std.debug.print("0x88: Mod {any}, R/M {any} = {d} bytes\n", .{ mod, rm, ByteCount });
        //         switch (ByteCount) {
        //             2 => {
        //                 instruction_bytes = [6]u8{
        //                     first_byte,
        //                     second_byte,
        //                     0b0000_0000,
        //                     0b0000_0000,
        //                     0b0000_0000,
        //                     0b0000_0000,
        //                 };
        //             },
        //             3 => {
        //                 instruction_bytes = [6]u8{
        //                     first_byte,
        //                     second_byte,
        //                     third_byte,
        //                     0b0000_0000,
        //                     0b0000_0000,
        //                     0b0000_0000,
        //                 };
        //             },
        //             4 => {
        //                 instruction_bytes = [6]u8{
        //                     first_byte,
        //                     second_byte,
        //                     third_byte,
        //                     fourth_byte,
        //                     0b0000_0000,
        //                     0b0000_0000,
        //                 };
        //             },
        //             else => {
        //                 std.debug.print("ERROR: Invalid byte count for move instruction: {d}", .{ByteCount});
        //             },
        //         }

        //         std.debug.print("---0x88-{any}-{any}---------------------------------------------------\n", .{ mod, rm });
        //         std.debug.print("1: {b:0>8}, {d}\n2: {b:0>8}, {d}\n3: {b:0>8}, {d}\n4: {b:0>8}, {d}\n5: {b:0>8}, {d}\n6: {b:0>8}, {d}\n", .{
        //             instruction_bytes[0], activeByte,
        //             instruction_bytes[1], activeByte + 1,
        //             instruction_bytes[2], activeByte + 2,
        //             instruction_bytes[3], activeByte + 3,
        //             instruction_bytes[4], activeByte + 4,
        //             instruction_bytes[5], activeByte + 5,
        //         });
        //         std.debug.print("---0x88-{any}-{any}---------------------------------------------------\n", .{ mod, rm });

        //         const payload = decodeMov(mod, rm, instruction_bytes);
        //         switch (payload) {
        //             .err => {
        //                 switch (payload.err) {
        //                     DecodeMovError.DecodeError => {
        //                         std.debug.print("Error: {any}\ncontinue...\n", .{payload.err});
        //                         continue;
        //                     },
        //                     DecodeMovError.NotYetImplementet => {
        //                         std.debug.print("Error: {any}\ncontinue...\n", .{payload.err});
        //                         continue;
        //                     },
        //                 }
        //             },
        //             .mov_instruction => {
        //                 std.debug.print("Instruction: 0x{x}: Mod {b}, Mnemonic {s} Reg {b:0>3}, R/M {b:0>3}, DISP-LO {b:0>8}, DISP-HI {b:0>8}\n", .{
        //                     BinaryInstructions.mov_source_regmem8_reg8,
        //                     @intFromEnum(payload.mov_instruction.mod),
        //                     payload.mov_instruction.mnemonic,
        //                     @intFromEnum(payload.mov_instruction.reg),
        //                     @intFromEnum(payload.mov_instruction.rm),
        //                     if (ByteCount == 3 or ByteCount == 4) payload.mov_instruction.disp_lo.? else instruction_bytes[2],
        //                     if (ByteCount == 4) payload.mov_instruction.disp_hi.? else instruction_bytes[3],
        //                 });
        //                 activeByte += ByteCount;
        //                 std.debug.print("+++++NEXT+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n", .{});
        //             },
        //         }
        //     },
        //     BinaryInstructions.mov_source_regmemreg16 => { // 0x89
        //         const mod: ModValue = @enumFromInt(second_byte >> 6);
        //         const temp_rm = second_byte << 5;
        //         const rm: RmValue = @enumFromInt(temp_rm >> 5);

        //         const ByteCount = movGetInstructionLength(mod, rm);
        //         std.debug.print("0x89: Mod {any}, R/M {any} = {d} bytes\n", .{ mod, rm, ByteCount });
        //         var instruction_bytes: [6]u8 = undefined;

        //         switch (ByteCount) {
        //             2 => {
        //                 instruction_bytes = [6]u8{
        //                     first_byte,
        //                     second_byte,
        //                     0b0000_0000,
        //                     0b0000_0000,
        //                     0b0000_0000,
        //                     0b0000_0000,
        //                 };
        //             },
        //             3 => {
        //                 instruction_bytes = [6]u8{
        //                     first_byte,
        //                     second_byte,
        //                     third_byte,
        //                     0b0000_0000,
        //                     0b0000_0000,
        //                     0b0000_0000,
        //                 };
        //             },
        //             4 => {
        //                 instruction_bytes = [6]u8{
        //                     first_byte,
        //                     second_byte,
        //                     third_byte,
        //                     fourth_byte,
        //                     0b0000_0000,
        //                     0b0000_0000,
        //                 };
        //             },
        //         }
        //         std.debug.print("---0x89---------------------------------------------------------------------\n", .{});
        //         std.debug.print("1: {b:0>8}, {d}\n2: {b:0>8}, {d}\n3: {b:0>8}, {d}\n4: {b:0>8}, {d}\n5: {b:0>8}, {d}\n6: {b:0>8}, {d}\n", .{
        //             instruction_bytes[0], activeByte,
        //             instruction_bytes[1], activeByte + 1,
        //             instruction_bytes[2], activeByte + 2,
        //             instruction_bytes[3], activeByte + 3,
        //             instruction_bytes[4], activeByte + 4,
        //             instruction_bytes[5], activeByte + 5,
        //         });
        //         std.debug.print("---0x89---------------------------------------------------------------------\n", .{});

        //         activeByte += ByteCount;
        //         const payload = decodeMov(mod, rm, instruction_bytes);
        //         switch (payload) {
        //             .err => {
        //                 switch (payload.err) {
        //                     DecodeMovError.DecodeError => {
        //                         std.debug.print("Error: {any}\ncontinue...\n", .{payload.err});
        //                         continue;
        //                     },
        //                     DecodeMovError.NotYetImplementet => {
        //                         std.debug.print("Error: {any}\ncontinue...\n", .{payload.err});
        //                         continue;
        //                     },
        //                 }
        //             },
        //             // zig fmt: on
        //             .mov_instruction => {
        //                 std.debug.print("0x{x}: {b}, {s} {b:0>3},{b:0>3}\n", .{
        //                     BinaryInstructions.mov_source_regmem8_reg8,
        //                     @intFromEnum(payload.mov_instruction.mod),
        //                     payload.mov_instruction.mnemonic,
        //                     @intFromEnum(payload.mov_instruction.reg),
        //                     @intFromEnum(payload.mov_instruction.rm),
        //                 });
        //                 std.debug.print("+++++NEXT+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n", .{});
        //             },
        //         }
        //     },
        //     BinaryInstructions.mov_dest_reg8_regmem8 => { // 0x8A
        //         const mod: ModValue = @enumFromInt(second_byte >> 6);
        //         const temp_rm = second_byte << 5;
        //         const rm: RmValue = @enumFromInt(temp_rm >> 5);
        //         const ByteCount = movGetInstructionLength(mod, rm);
        //         std.debug.print("0x8A: Mod {any}, R/M {any} = {d} bytes\n", .{ mod, rm, ByteCount });

        //         if (mod == ModValue.memoryMode8BitDisplacement) {
        //             const instruction_bytes = [6]u8{ first_byte, second_byte, third_byte, fourth_byte, 0b0000_0000, 0b0000_0000 };

        //             std.debug.print("---0x8A---------------------------------------------------------------------\n", .{});
        //             std.debug.print("1: {b:0>8}, {d}\n2: {b:0>8}, {d}\n3: {b:0>8}, {d}\n4: {b:0>8}, {d}\n5: {b:0>8}, {d}\n6: {b:0>8}, {d}\n", .{
        //                 instruction_bytes[0], activeByte,
        //                 instruction_bytes[1], activeByte + 1,
        //                 instruction_bytes[2], activeByte + 2,
        //                 instruction_bytes[3], activeByte + 3,
        //                 instruction_bytes[4], activeByte + 4,
        //                 instruction_bytes[5], activeByte + 5,
        //             });
        //             std.debug.print("---0x8A---------------------------------------------------------------------\n", .{});

        //             activeByte += 4;
        //             const payload = decodeMov(
        //                 mod,
        //                 rm,
        //                 instruction_bytes,
        //             );
        //             switch (payload) {
        //                 .err => {
        //                     switch (payload.err) {
        //                         DecodeMovError.DecodeError => {
        //                             std.debug.print("Error: {any}\ncontinue...\n", .{payload.err});
        //                             continue;
        //                         },
        //                         DecodeMovError.NotYetImplementet => {
        //                             std.debug.print("Error: {any}\ncontinue...\n", .{payload.err});
        //                             continue;
        //                         },
        //                     }
        //                 },
        //                 .mov_instruction => {
        //                     std.debug.print("0x{x}: {b}, {s} {b:0>3},{b:0>3}\n", .{
        //                         BinaryInstructions.mov_source_regmem8_reg8,
        //                         @intFromEnum(payload.mov_instruction.mod),
        //                         payload.mov_instruction.mnemonic,
        //                         @intFromEnum(payload.mov_instruction.reg),
        //                         @intFromEnum(payload.mov_instruction.rm),
        //                     });
        //                     std.debug.print("+++++NEXT+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n", .{});
        //                 },
        //             }
        //         }
        //     },
        //     BinaryInstructions.mov_dest_reg16_regmem16 => { // 0x8B
        //         const mod: ModValue = @enumFromInt(second_byte >> 6);
        //         const temp_rm = second_byte << 5;
        //         const rm: RmValue = @enumFromInt(temp_rm >> 5);
        //         const ByteCount = movGetInstructionLength(mod, rm);
        //         std.debug.print("0x8B: Mod {any}, R/M {any} = {d} bytes\n", .{ mod, rm, ByteCount });

        //         const instruction_bytes = [6]u8{ first_byte, second_byte, 0b0000_0000, 0b0000_0000, 0b0000_0000, 0b0000_0000 };

        //         std.debug.print("---0x8B---------------------------------------------------------------------\n", .{});
        //         std.debug.print("1: {b:0>8}, {d}\n2: {b:0>8}, {d}\n3: {b:0>8}, {d}\n4: {b:0>8}, {d}\n5: {b:0>8}, {d}\n6: {b:0>8}, {d}\n", .{
        //             instruction_bytes[0], activeByte,
        //             instruction_bytes[1], activeByte + 1,
        //             instruction_bytes[2], activeByte + 2,
        //             instruction_bytes[3], activeByte + 3,
        //             instruction_bytes[4], activeByte + 4,
        //             instruction_bytes[5], activeByte + 5,
        //         });
        //         std.debug.print("---0x8B---------------------------------------------------------------------\n", .{});

        //         activeByte += 2;
        //         const payload = decodeMov(
        //             mod,
        //             rm,
        //             instruction_bytes,
        //         );
        //         switch (payload) {
        //             .err => {
        //                 switch (payload.err) {
        //                     DecodeMovError.DecodeError => {
        //                         std.debug.print("Error: {any}\ncontinue...\n", .{payload.err});
        //                         continue;
        //                     },
        //                     DecodeMovError.NotYetImplementet => {
        //                         std.debug.print("Error: {any}\ncontinue...\n", .{payload.err});
        //                         continue;
        //                     },
        //                 }
        //             },
        //             .mov_instruction => {
        //                 std.debug.print("0x{x}: {b}, {s} {b:0>3},{b:0>3}\n", .{
        //                     BinaryInstructions.mov_source_regmem8_reg8,
        //                     @intFromEnum(payload.mov_instruction.mod),
        //                     payload.mov_instruction.mnemonic,
        //                     @intFromEnum(payload.mov_instruction.reg),
        //                     @intFromEnum(payload.mov_instruction.rm),
        //                 });
        //                 std.debug.print("+++++NEXT+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n", .{});
        //             },
        //         }
        //     },
        //     else => {
        //         std.debug.print("ERROR: Not implemented yet\n", .{});
        //     },
        // }
    }
}

test "activeByte moves along correct" {
    // Since the index of the byte array loaded from file needs
    // to move allong at the correct speed, meaning if a
    // instruction takes three bytes the cursor also needs to
    // move forward three bytes.

    // zls fmt:off

    // MOV
    // listing_0037_single_register_mov
    // 0x89
    // Mod: 0b11, R/M != 0b110,
    const test_input_register_mode_no_displacement: [6]u8 = [_]u8{
        0b1000_1001, // mov, d=source, w=word
        0b1101_1001, // mod=
        0b0000_0000,
        0b0000_0000,
        0b0000_0000,
        0b0000_0000,
    };
    const test_output_register_mode_no_displacement = MovInstruction{
        .mnemonic = "mov",
        .d = DValue.source,
        .w = WValue.word,
        .mod = ModValue.registerModeNoDisplacement,
        .reg = RegValue.BLBX,
        .rm = RmValue.CLCX_BXDI,
    };
    try std.testing.expect(decodeMov(
        ModValue.memoryModeNoDisplacement,
        test_input_register_mode_no_displacement,
    ) == test_output_register_mode_no_displacement);

    // const test_input_memory_mode_8_bit_displacement: [6]u8 = []u8{
    //     0b0000_0000,
    //     0b0000_0000,
    //     0b0000_0000,
    //     0b0000_0000,
    //     0b0000_0000,
    //     0b0000_0000,
    // };
    // const test_output_memory_mode_8_bit_displacement = .{};
    // try std.testing.expect(
    //     decodeMove(
    //         ModValue.memoryMode8BitDisplacement,
    //         test_input_memory_mode_8_bit_displacement,
    //     ) == test_output_memory_mode_8_bit_displacement,
    // );
    // zls fmt:on
}
