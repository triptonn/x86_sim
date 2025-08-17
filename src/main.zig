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

const DecodeError = error{ InvalidInstruction, InvalidRegister, NotYetImplemented };

// zig fmt: off

//                                                                                      INSTRUCTION
//                                        | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 |
// ---------------------------------------|-----------------------------------------------------------------------------------------------------------|
// MOV: register/memory to/from register  | 1 0 0 0 1 0|D|W | MOD| REG | R/M  |    (DISP-LO)    |    (DISP-HI)    |                 |                 |

const MovInstructionCodes = enum(u8) {
    mov_regmem8_reg8        = 0b100010_0_0, // 0x88
    mov_regmemreg16         = 0b100010_0_1, // 0x89
    mov_reg8_regmem8        = 0b100010_1_0, // 0x8A
    mov_regmem16_segreg     = 0b100010_1_1, // 0x8B
};


/// (* .memoryModeNoDisplacement has 16 Bit displacement if
/// R/M = 110)
const ModValues = enum(u2) {
    memoryModeNoDisplacement    = 0b00,
    memoryMode8BitDisplacement  = 0b01,
    memoryMode16BitDisplacement = 0b10,
    registerModeNoDisplacement  = 0b11,
};

/// Field names represent W = 0, W = 1, as in Reg 000 with w = 0 is AL,
/// with w = 1 it's AX
const RegValues = enum(u3) {
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

/// Field names encode all possible Register/Register or Register/Memory combinations together with W and Mod values
const RmValues = enum(u3) {
    ALAX_BXSI           = 0b000,
    CLCX_BXDI           = 0b001,
    DLDX_BPSI           = 0b010,
    BLBX_BPSI           = 0b011,
    AHSP_SI             = 0b100,
    CHBP_DI             = 0b101,
    DHSI_DIRECT_ACCESS  = 0b110,
    BHDI_BX             = 0b111,
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

/// Matching binary values against instruction- and register enum's. Returns names of the
/// instructions and registers as strings in an []u8.
fn decodeMove(input: [6]u8) DecodeError!struct { inst: []const u8, d: u1, w: u1, mod: u2, reg: u3, rm: u3 } {
    const asm_name = "mov";
    // std.debug.print("DEBUG: asm_name: {s}\n", .{asm_name});

    const mod: u2 = @intCast(input[1] >> 6);
    // std.debug.print("DEBUG: mod: {b:0>2}\n", .{mod});
    const temp_rm = input[1] << 5;
    const rm: u3 = @intCast(temp_rm >> 5);
    // std.debug.print("DEBUG: rm: {b:0>3}\n", .{rm});

    if (mod == 0b00) {
        return DecodeError.NotYetImplemented;
    } else if (mod == 0b01) {
        return DecodeError.NotYetImplemented;
    } else if (mod == 0b10) {
        return DecodeError.NotYetImplemented;
    } else if (mod == 0b11) {
        if (rm == 0b110) {
            // 2 byte displacement, second byte is most significant
            return DecodeError.NotYetImplemented;
        } else {
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
            //     asm_name, d, w, mod, reg, rm,
            // });
            return .{ .inst = asm_name, .d = d, .w = w, .mod = mod, .reg = reg, .rm = rm };
            // No displacement (register mode)
        }
    } else {
        return DecodeError.NotYetImplemented;
    }
}

pub fn main() !void {
    const open_mode = std.fs.File.OpenFlags{
        .mode = .read_only,
        .lock = .none,
        .lock_nonblocking = false,
        .allow_ctty = false,
    };

    const path = "C:\\Users\\Student\\Documents\\Coding\\Zig\\x86_sim\\test_data\\part1\\";
    const file_name = "listing_0037_single_register_mov";

    // zig fmt: off
    const file = try std.fs.openFileAbsolute(
        path ++ file_name,
        open_mode);
    // zig fmt: on

    if (@TypeOf(file) != std.fs.File) {
        std.debug.print("Yeah, not goooood: {}\n", .{});
    }

    const file_ptr = &file;

    defer std.fs.File.close(file);

    var input = [6]u8{ 0b0000_0000, 0b0000_0000, 0b0000_0000, 0b0000_0000, 0b0000_0000, 0b0000_0000 };

    _ = try std.fs.File.read(file_ptr.*, &input);

    std.debug.print("----------------------------------------------------------------------------\n", .{});
    std.debug.print("1: {b:0>8},\n2: {b:0>8},\n3: {b:0>8},\n4: {b:0>8},\n5: {b:0>8},\n6: {b:0>8},\n", .{
        input[0],
        input[1],
        input[2],
        input[3],
        input[4],
        input[5],
    });
    std.debug.print("----------------------------------------------------------------------------\n", .{});

    // const input_ptr = &input;

    const first_byte = input[0];

    const first_six_bit: u6 = @intCast(first_byte >> 2);

    // mov_reg8_regmem8
    const mov_reg8_regmem8: u6 = @intCast(@intFromEnum(MovInstructionCodes.mov_reg8_regmem8) >> 2);

    if (first_six_bit == mov_reg8_regmem8) {
        const instruction = try decodeMove(input);
        std.debug.print("Output: {s} {b:0>3},{b:0>3}\n", .{ instruction.inst, instruction.reg, instruction.rm });
    }
}
