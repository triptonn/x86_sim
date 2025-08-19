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

//                                                                                      INSTRUCTION
//                                        | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 | 7 6 5 4 3 2 1 0 |
// ---------------------------------------|-----------------------------------------------------------------------------------------------------------|
// MOV: register/memory to/from register  | 1 0 0 0 1 0|D|W | MOD| REG | R/M  |    (DISP-LO)    |    (DISP-HI)    |<---------------XXX--------------->|              
// MOV: immediate to register             | 1 0 1 1|W| reg  |       data      |   data if W=1   |<-----------------------XXX------------------------->|

const BinaryInstructions = enum(u8) {
    // MOV: register/memory to/from register
    mov_regmem8_reg8        = 0x88, // mod=0b00
    mov_regmemreg16         = 0x89, // mod=0b01
    mov_reg8_regmem8        = 0x8A, // mod=0b10
    mov_reg16_regmem16      = 0x8B, // mod=0b11

    // MOV: immediate to register
    mov_immediate_AL        = 0xA0,
    mov_immediate_CL        = 0xA1,
    mov_immediate_DL        = 0xA2,
    mov_immediate_BL        = 0xA3,
    mov_immediate_AH        = 0xA4,
    mov_immediate_CH        = 0xA5,
    mov_immediate_DH        = 0xA6,
    mov_immediate_BH        = 0xA7,
    mov_immediate_AX        = 0xA8,
    mov_immediate_CX        = 0xA9,
    mov_immediate_DX        = 0xAA,
    mov_immediate_BX        = 0xAB,
    mov_immediate_SP        = 0xAC,
    mov_immediate_BP        = 0xAD,
    mov_immediate_SI        = 0xAE,
    mov_immediate_DI        = 0xAF,
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

const DecodedMovPayloadIdentifier = enum{
    err,
    instruction,
};

// Payload:
const DecodeMovPayload = union(DecodedMovPayloadIdentifier) {
    err: DecodeMovError,
    instruction: MovInstruction,
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

/// Field names encode all possible Register/Register or Register/Memory combinations together with W and Mod values
const RmValue = enum(u3) {
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

// zig fmt: off
/// Matching binary values against instruction- and register enum's. Returns names of the
/// instructions and registers as strings in an []u8.
fn decodeMov(
    mod: ModValue,
    rm: RmValue,
    input: [6]u8
) DecodeMovPayload {
// zig fmt: on
    const mnemonic = "mov";
    const _rm = rm;
    const _mod = mod;

    switch (_mod) {
        ModValue.memoryModeNoDisplacement => {
            if (_rm == RmValue.DHSI_DIRECT_ACCESS) {
                // 2 byte displacement, second byte is most significant
                return DecodeMovPayload{ .err = DecodeMovError.NotYetImplementet };
            } else {
                return DecodeMovPayload{ .err = DecodeMovError.NotYetImplementet };
            }
        },
        ModValue.memoryMode8BitDisplacement => {
            return DecodeMovPayload{ .err = DecodeMovError.NotYetImplementet };
        },
        ModValue.memoryMode16BitDisplacement => {
            return DecodeMovPayload{ .err = DecodeMovError.NotYetImplementet };
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

            std.debug.print("DEBUG: temp_reg: {b:0>3}\n", .{temp_reg});

            const d: u1 = @intCast(temp_d);
            const w: u1 = @intCast(temp_w);
            const reg: u3 = @intCast(temp_reg);

            std.debug.print("DEBUG: asm {s} d {b} w {b} mod {b:0>2} reg {b:0>3} rm {b:0>3}\n", .{
                mnemonic, d, w, _mod, reg, _rm,
            });

            const result = DecodeMovPayload{
                .instruction = MovInstruction{
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
    std.debug.print("++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n", .{});
    std.debug.print("Simulating {s}\n", .{input_file_path});

    if (@TypeOf(file) != std.fs.File) {
        std.debug.print("Yeah, not goooood: {}\n", .{});
    }

    const maxFileSizeBytes = 65535;

    var activeByte: u16 = 0;
    const file_contents = try file.readToEndAlloc(heap_allocator, maxFileSizeBytes);
    var depleted: bool = false;

    while (!depleted and activeByte < file_contents.len) : (activeByte += 2) {
        const default: u8 = 0b00000000;
        const first_byte: u8 = if (activeByte < file_contents.len) file_contents[activeByte] else default;
        const second_byte: u8 = if (activeByte + 1 < file_contents.len) file_contents[activeByte + 1] else default;
        const third_byte: u8 = if (activeByte + 2 < file_contents.len) file_contents[activeByte + 2] else default;
        const fourth_byte: u8 = if (activeByte + 3 < file_contents.len) file_contents[activeByte + 3] else default;
        // const fifth_byte: u8 = if (activeByte + 4 < file_contents.len) file_contents[activeByte + 4] else default;
        // const sixth_byte: u8 = if (activeByte + 5 < file_contents.len) file_contents[activeByte + 5] else default;

        // std.debug.print("---Preload------------------------------------------------------------------\n", .{});
        // std.debug.print("1: {b:0>8} {d},\n2: {b:0>8} {d},\n3: {b:0>8} {d},\n4: {b:0>8} {d},\n5: {b:0>8} {d},\n6: {b:0>8} {d},\n", .{
        //     first_byte,  activeByte,
        //     second_byte, activeByte + 1,
        //     third_byte,  activeByte + 2,
        //     fourth_byte, activeByte + 3,
        //     fifth_byte,  activeByte + 4,
        //     sixth_byte,  activeByte + 5,
        // });
        // std.debug.print("---Preload-------------------------------------------------------------------\n", .{});

        const instruction: BinaryInstructions = @enumFromInt(first_byte);

        std.debug.print("instruction: {any}\n", .{instruction});

        switch (instruction) {
            BinaryInstructions.mov_regmem8_reg8 => { // 0x88
                const mod: ModValue = @enumFromInt(second_byte >> 6);
                const temp_rm = second_byte << 5;
                const rm: RmValue = @enumFromInt(temp_rm >> 5);
                std.debug.print("0x88: {any}, {any}\n", .{ mod, rm });

                if (mod == ModValue.registerModeNoDisplacement and rm == RmValue.DHSI_DIRECT_ACCESS) {
                    const instruction_bytes = [6]u8{ first_byte, second_byte, third_byte, fourth_byte, 0b0000_0000, 0b0000_0000 };

                    std.debug.print("---0x88-no-displacement-----------------------------------------------------\n", .{});
                    std.debug.print("1: {b:0>8}, {d}\n2: {b:0>8}, {d}\n3: {b:0>8}, {d}\n4: {b:0>8}, {d}\n5: {b:0>8}, {d}\n6: {b:0>8}, {d}\n", .{
                        instruction_bytes[0], activeByte,
                        instruction_bytes[1], activeByte + 1,
                        instruction_bytes[2], activeByte + 2,
                        instruction_bytes[3], activeByte + 3,
                        instruction_bytes[4], activeByte + 4,
                        instruction_bytes[5], activeByte + 5,
                    });
                    std.debug.print("---0x88-no-displacement-----------------------------------------------------\n", .{});

                    const payload = decodeMov(ModValue.registerModeNoDisplacement, RmValue.DHSI_DIRECT_ACCESS, instruction_bytes);
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
                        .instruction => {
                            std.debug.print("0x{x}: {b}, {s} {b:0>3},{b:0>3}, {b:0>8}, {b:0>8}", .{
                                BinaryInstructions.mov_regmem8_reg8,
                                @intFromEnum(payload.instruction.mod),
                                payload.instruction.mnemonic,
                                @intFromEnum(payload.instruction.reg),
                                @intFromEnum(payload.instruction.rm),
                                payload.instruction.disp_lo.?,
                                payload.instruction.disp_hi.?,
                            });
                            activeByte += 4;
                        },
                    }
                } else if (mod == ModValue.registerModeNoDisplacement) {
                    // zig fmt: off
                    const instruction_bytes = [6]u8{
                        first_byte,
                        second_byte,
                        0b0000_0000,
                        0b0000_0000,
                        0b0000_0000,
                        0b0000_0000,};

                    std.debug.print("---0x88-with-no-displacement------------------------------------------------\n", .{});
                    std.debug.print("1: {b:0>8}, {d}\n2: {b:0>8}, {d}\n3: {b:0>8}, {d}\n4: {b:0>8}, {d}\n5: {b:0>8}, {d}\n6: {b:0>8}, {d}\n", .{
                        instruction_bytes[0], activeByte,
                        instruction_bytes[1], activeByte + 1,
                        instruction_bytes[2], activeByte + 2,
                        instruction_bytes[3], activeByte + 3,
                        instruction_bytes[4], activeByte + 4,
                        instruction_bytes[5], activeByte + 5,
                    });
                    std.debug.print("---0x88-with-no-displacement------------------------------------------------\n", .{});

                    activeByte += 2;
                    const payload = decodeMov(
                        mod,
                        rm,
                        instruction_bytes);

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
                        .instruction => {
                            std.debug.print(
                                "0x{x}: {b}, {s} {b:0>3},{b:0>3}\n",
                                .{
                                    BinaryInstructions.mov_regmem8_reg8,
                                    @intFromEnum(payload.instruction.mod),
                                    payload.instruction.mnemonic,
                                    @intFromEnum(payload.instruction.reg),
                                    @intFromEnum(payload.instruction.rm),
                                },
                            );
                        },
                    }
                    // zig fmt: on
                }
            },
            BinaryInstructions.mov_regmemreg16 => { // 0x89
                const mod: ModValue = @enumFromInt(second_byte >> 6);
                const temp_rm = second_byte << 5;
                const rm: RmValue = @enumFromInt(temp_rm >> 5);

                std.debug.print("0x89: {b:0>2}\n", .{mod});

                if (mod == ModValue.memoryMode16BitDisplacement) {
                    // zig fmt: off
                    const instruction_bytes = [6]u8{
                        first_byte,
                        second_byte,
                        third_byte,
                        0b0000_0000,
                        0b0000_0000,
                        0b0000_0000,};

                    std.debug.print("---0x89---------------------------------------------------------------------\n", .{});
                    std.debug.print("1: {b:0>8}, {d}\n2: {b:0>8}, {d}\n3: {b:0>8}, {d}\n4: {b:0>8}, {d}\n5: {b:0>8}, {d}\n6: {b:0>8}, {d}\n", .{
                        instruction_bytes[0], activeByte,
                        instruction_bytes[1], activeByte + 1,
                        instruction_bytes[2], activeByte + 2,
                        instruction_bytes[3], activeByte + 3,
                        instruction_bytes[4], activeByte + 4,
                        instruction_bytes[5], activeByte + 5,
                    });
                    std.debug.print("---0x89---------------------------------------------------------------------\n", .{});

                    activeByte += 3;
                    const payload = decodeMov(
                        mod,
                        rm,
                        instruction_bytes);
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
                        // zig fmt: on
                        .instruction => {
                            std.debug.print("0x{x}: {b}, {s} {b:0>3},{b:0>3}\n", .{
                                BinaryInstructions.mov_regmem8_reg8,
                                @intFromEnum(payload.instruction.mod),
                                payload.instruction.mnemonic,
                                @intFromEnum(payload.instruction.reg),
                                @intFromEnum(payload.instruction.rm),
                            });
                        },
                    }
                }
            },
            BinaryInstructions.mov_reg8_regmem8 => { // 0x8A
                const mod: ModValue = @enumFromInt(second_byte >> 6);
                const temp_rm = second_byte << 5;
                const rm: RmValue = @enumFromInt(temp_rm >> 5);

                std.debug.print("0x8A: {any}\n", .{mod});

                if (mod == ModValue.memoryMode8BitDisplacement) {
                    const instruction_bytes = [6]u8{ first_byte, second_byte, third_byte, fourth_byte, 0b0000_0000, 0b0000_0000 };

                    std.debug.print("---0x8A---------------------------------------------------------------------\n", .{});
                    std.debug.print("1: {b:0>8}, {d}\n2: {b:0>8}, {d}\n3: {b:0>8}, {d}\n4: {b:0>8}, {d}\n5: {b:0>8}, {d}\n6: {b:0>8}, {d}\n", .{
                        instruction_bytes[0], activeByte,
                        instruction_bytes[1], activeByte + 1,
                        instruction_bytes[2], activeByte + 2,
                        instruction_bytes[3], activeByte + 3,
                        instruction_bytes[4], activeByte + 4,
                        instruction_bytes[5], activeByte + 5,
                    });
                    std.debug.print("---0x8A---------------------------------------------------------------------\n", .{});

                    activeByte += 4;
                    const payload = decodeMov(
                        mod,
                        rm,
                        instruction_bytes,
                    );
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
                        .instruction => {
                            std.debug.print("0x{x}: {b}, {s} {b:0>3},{b:0>3}\n", .{
                                BinaryInstructions.mov_regmem8_reg8,
                                @intFromEnum(payload.instruction.mod),
                                payload.instruction.mnemonic,
                                @intFromEnum(payload.instruction.reg),
                                @intFromEnum(payload.instruction.rm),
                            });
                        },
                    }
                }
            },
            BinaryInstructions.mov_reg16_regmem16 => { // 0x8B
                const mod: ModValue = @enumFromInt(second_byte >> 6);
                const temp_rm = second_byte << 5;
                const rm: RmValue = @enumFromInt(temp_rm >> 5);

                std.debug.print("0x8B: {b:0>2}\n", .{mod});
                const instruction_bytes = [6]u8{ first_byte, second_byte, 0b0000_0000, 0b0000_0000, 0b0000_0000, 0b0000_0000 };

                std.debug.print("---0x8B---------------------------------------------------------------------\n", .{});
                std.debug.print("1: {b:0>8}, {d}\n2: {b:0>8}, {d}\n3: {b:0>8}, {d}\n4: {b:0>8}, {d}\n5: {b:0>8}, {d}\n6: {b:0>8}, {d}\n", .{
                    instruction_bytes[0], activeByte,
                    instruction_bytes[1], activeByte + 1,
                    instruction_bytes[2], activeByte + 2,
                    instruction_bytes[3], activeByte + 3,
                    instruction_bytes[4], activeByte + 4,
                    instruction_bytes[5], activeByte + 5,
                });
                std.debug.print("---0x8B---------------------------------------------------------------------\n", .{});

                activeByte += 2;
                const payload = decodeMov(
                    mod,
                    rm,
                    instruction_bytes,
                );
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
                    .instruction => {
                        std.debug.print("0x{x}: {b}, {s} {b:0>3},{b:0>3}\n", .{
                            BinaryInstructions.mov_regmem8_reg8,
                            @intFromEnum(payload.instruction.mod),
                            payload.instruction.mnemonic,
                            @intFromEnum(payload.instruction.reg),
                            @intFromEnum(payload.instruction.rm),
                        });
                    },
                }
            },
            else => {
                std.debug.print("ERROR: Not implemented yet\n", .{});
            },
        }
        std.debug.print("Next active byte {d}\n", .{activeByte});

        if (activeByte == maxFileSizeBytes) {
            depleted = true;
        }
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
