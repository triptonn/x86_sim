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

const hardware = @import("modules/hardware.zig");
const BusInterfaceUnit = hardware.BusInterfaceUnit;
const ExecutionUnit = hardware.ExecutionUnit;
const Memory = hardware.Memory;

const decoder = @import("modules/decoder.zig");
const BinaryInstructions = decoder.BinaryInstructions;
const InstructionData = decoder.InstructionData;

const disassembler = @import("modules/disassembler.zig");

const locator = @import("modules/locator.zig");
const DisplacementFormat = locator.DisplacementFormat;
const EffectiveAddressCalculation = locator.EffectiveAddressCalculation;
const Locations = locator.Locations;
const InstructionInfo = locator.InstructionInfo;
const DestinationInfo = locator.DestinationInfo;
const SourceInfo = locator.SourceInfo;

const types = @import("modules/types.zig");
const ModValue = types.instruction_fields.MOD;
const RegValue = types.instruction_fields.REG;
const SrValue = types.instruction_fields.SR;
const RmValue = types.instruction_fields.RM;
const DValue = types.instruction_fields.Direction;
const WValue = types.instruction_fields.Width;
const SValue = types.instruction_fields.Sign;

const errors = @import("modules/errors.zig");
const InstructionDecodeError = errors.InstructionDecodeError;
const InstructionExecutionError = errors.InstructionExecutionError;
const SimulatorError = errors.SimulatorError;

/// global log level
const LogLevel: std.log.Level = .debug;
// const LogLevel: std.log.Level = .info;

/// Checks if a displacement value fits inside a 8 bit signed integer
/// or if a 16 bit signed integer is needed. Returns true if a 8 bit integer
/// suffices.
fn shouldUse8BitDisplacement(displacement: i16) bool {
    return displacement >= -128 and displacement <= 127;
}

pub const std_options: std.Options = .{
    .log_level = LogLevel,
    .logFn = projectLog,
};

pub fn projectLog(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const scope_prefix = "(" ++ switch (scope) {
        .x86sim,
        .decodeMovWithMod,
        .decodeMovWithoutMod,
        .makeAssembly,
        .runAssemblyTest,
        .compareFiles,
        std.log.default_log_scope,
        => @tagName(scope),
        .printer => "",
        else => if (@intFromEnum(level) <= @intFromEnum(std.log.Level.err)) @tagName(scope) else return,
    } ++ "): ";

    const prefix = switch (scope) {
        .printer => "",
        else => "[" ++ comptime level.asText() ++ "]" ++ scope_prefix,
    };

    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    const stderr = std.fs.File.stderr().deprecatedWriter();
    nosuspend stderr.print(prefix ++ format ++ "\n", args) catch return;
}

pub fn main() !void {
    const printer = std.log.scoped(.printer);
    const log = std.log.scoped(.x86sim);

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
    const open_mode_input_file = std.fs.File.OpenFlags{
        .mode = .read_only,
        .lock = .none,
        .lock_nonblocking = false,
        .allow_ctty = false,
    };
    const open_mode_output_file = std.fs.File.CreateFlags{
        .truncate = true,
        .exclusive = false,
        .lock = .none,
        .lock_nonblocking = false,
    };

    const input_binary_file = std.fs.cwd().openFile(input_file_path, open_mode_input_file) catch |err| {
        switch (err) {
            error.FileNotFound => {
                log.err("{s}: '{s}':{any}", .{ @errorName(err), input_file_path, @errorReturnTrace() });
                std.process.exit(1);
            },
            error.AccessDenied => {
                log.err("{s}: '{s}':{any}", .{ @errorName(err), input_file_path, @errorReturnTrace() });
                std.process.exit(1);
            },
            else => {
                log.err("{s}: Unable to open file '{s}': {any}\n", .{ @errorName(err), input_file_path, @errorReturnTrace() });
                std.process.exit(1);
            },
        }
    };
    defer input_binary_file.close();

    if (@TypeOf(input_binary_file) != std.fs.File) {
        log.err("{s}: File object is not of the correct type.", .{@errorName(SimulatorError.FileError)});
    }

    try std.fs.Dir.makePath(std.fs.cwd(), "./zig-out/test");

    const output_asm_file_path: []const u8 = "./zig-out/test/disassemble.asm";
    const output_asm_file = std.fs.cwd().createFile(output_asm_file_path, open_mode_output_file) catch |err| {
        switch (err) {
            error.FileNotFound => {
                log.err("{s}: '{s}':{any}", .{
                    @errorName(err),
                    output_asm_file_path,
                    @errorReturnTrace(),
                });
                std.process.exit(1);
            },
            error.AccessDenied => {
                log.err("{s}: '{s}':{any}", .{
                    @errorName(err),
                    output_asm_file_path,
                    @errorReturnTrace(),
                });
                std.process.exit(1);
            },
            else => {
                log.err("{s}: Unable to open file '{s}': {any}\n", .{
                    @errorName(err),
                    output_asm_file_path,
                    @errorReturnTrace(),
                });
                std.process.exit(1);
            },
        }
    };
    defer output_asm_file.close();

    var instruction_buffer: [1024]u8 = undefined;
    var writer = output_asm_file.writer(&instruction_buffer);
    var OutputWriter = &writer.interface;

    //////////////////////////////////////////
    // Initializing the Simulator           //
    //////////////////////////////////////////

    const maxFileSizeBytes = 65535;
    const u8_init_value: u8 = 0b0000_0000;
    const u16_init_value: u16 = 0b0000_0000_0000_0000;

    const eu_init_values: ExecutionUnit.InitValues = .{
        ._AF = false,
        ._CF = false,
        ._OF = false,
        ._SF = false,
        ._PF = false,
        ._ZF = false,
        ._DF = false,
        ._IF = false,
        ._TF = false,
        ._AX = u16_init_value,
        ._BX = u16_init_value,
        ._CX = u16_init_value,
        ._DX = u16_init_value,
        ._SP = u16_init_value,
        ._BP = u16_init_value,
        ._SI = u16_init_value,
        ._DI = u16_init_value,
    };
    var EU = ExecutionUnit.init(eu_init_values);
    log.debug("Test EU initialization successful.", .{});

    const biu_init_values: BusInterfaceUnit.InitValues = .{
        // Initialize Communication Registers
        ._CS = 0xFFFF,
        ._DS = u16_init_value,
        ._ES = u16_init_value,
        ._SS = u16_init_value,

        // Initialize Instruction Pointer
        ._IP = u16_init_value,
    };
    var BIU = BusInterfaceUnit.init(biu_init_values);
    log.debug("Bus Interface Unit initialization successful.", .{});

    var simulated_memory: [0xFFFFF]u1 = [_]u1{0} ** 0xFFFFF;
    const mem_ptr = &simulated_memory;
    const memory = Memory.init(mem_ptr);
    log.debug("Memory initialization successful. 0x{x} bit allocated.", .{memory._memory.len});

    // TODO: Put loaded binary input file in simulated memory, update CS to point at the base of the segment
    // TODO: Define the stack and data segments and update DS, ES and SS

    // TODO: Initialize cpu clock

    ////////////////////////////////////////////////////////////////////////////
    // Simulation //
    ////////////////////////////////////////////////////////////////////////////

    log.info("\n+++x86+Simulator++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++", .{});
    log.info("Simulating target: {s}", .{input_file_path});

    var activeByte: u16 = 0;

    var stepSize: u3 = 2;
    var InstructionBytes: [6]u8 = undefined;
    const file_contents = try input_binary_file.readToEndAlloc(heap_allocator, maxFileSizeBytes);

    // TODO: Define Segments in memory

    // TODO: Copy instruction file to memory

    // TODO: set segment registers

    // TODO: set flags

    log.debug("Instruction byte count: {d}", .{file_contents.len});
    log.info("+++Start+active+byte+{d}++++++++++++++++++++++++++++++++++++++++++++++++++++++++++", .{activeByte});

    printer.info("bits 16", .{});
    try OutputWriter.writeAll("bits 16\n\n");

    var depleted: bool = false;

    while (!depleted and activeByte < file_contents.len) : (activeByte += stepSize) {

        ////////////////////////////////////////////////////////////////////////
        // Instruction decoding //
        ////////////////////////////////////////////////////////////////////////

        const queue_size = 6;
        var queue_index: u3 = 0;
        log.debug("---BIU-Instruction-Queue-----------------------------------------------------", .{});
        while (queue_index < queue_size) : (queue_index += 1) {
            BIU.setIndex(queue_index, if (activeByte + queue_index < file_contents.len) file_contents[activeByte + queue_index] else u8_init_value);
            if (activeByte + queue_index > file_contents.len - 1) break;
            log.debug("{d}: {b:0>8}, active byte {d}, instruction 0x{x:0>2}", .{
                queue_index,
                file_contents[activeByte + queue_index],
                activeByte + queue_index,
                file_contents[activeByte + queue_index],
            });
            if (queue_index + 1 == 6) break;
        }

        const instruction_binary: u8 = BIU.getIndex(0);
        const opcode: BinaryInstructions = @enumFromInt(instruction_binary);
        log.debug("Read instruction: 0x{x:0>2}, {t}", .{ instruction_binary, opcode });

        // var s: SValue = undefined;
        var w: WValue = undefined;
        var mod: ModValue = undefined;
        var rm: RmValue = undefined;

        switch (opcode) {
            BinaryInstructions.add_regmem8_reg8,
            BinaryInstructions.add_regmem16_reg16,
            BinaryInstructions.add_reg8_regmem8,
            BinaryInstructions.add_reg16_regmem16,
            => {
                // 0x00, 0x01, 0x02, 0x03
                mod = @enumFromInt(BIU.getIndex(1) >> 6);
                rm = @enumFromInt((BIU.getIndex(1) << 5) >> 5);

                // stepSize = decoder.addGetInstructionLength(opcode, mod, rm);
                stepSize = decoder.getInstructionLength(opcode, mod, rm, null);
            },
            BinaryInstructions.add_al_immed8,
            BinaryInstructions.add_ax_immed16,
            => {
                log.err("Instruction '{t}' not yet implemented.", .{opcode});
            },
            BinaryInstructions.regmem8_immed8,
            BinaryInstructions.regmem16_immed16,
            BinaryInstructions.signed_regmem8_immed8,
            BinaryInstructions.sign_extend_regmem16_immed8,
            => {
                // 0x80, 0x81, 0x82, 0x83
                mod = @enumFromInt(BIU.getIndex(1) >> 6);
                rm = @enumFromInt((BIU.getIndex(1) << 5) >> 5);

                stepSize = decoder.immediateOpGetInstructionLength(opcode, mod, rm);
            },
            BinaryInstructions.mov_regmem8_reg8,
            BinaryInstructions.mov_regmem16_reg16,
            BinaryInstructions.mov_reg8_regmem8,
            BinaryInstructions.mov_reg16_regmem16,
            => {
                // 0x88, 0x89, 0x8A, 0x8B
                w = @enumFromInt((BIU.getIndex(0) << 7) >> 7);
                mod = @enumFromInt(BIU.getIndex(1) >> 6);
                rm = @enumFromInt((BIU.getIndex(1) << 5) >> 5);

                stepSize = decoder.movGetInstructionLength(opcode, w, mod, rm);
            },
            BinaryInstructions.mov_regmem16_segreg,
            BinaryInstructions.mov_segreg_regmem16,
            => {
                // 0x8c, 0x8e
                mod = @enumFromInt(BIU.getIndex(1) >> 6);
                rm = @enumFromInt((BIU.getIndex(1) << 5) >> 5);

                stepSize = decoder.movGetInstructionLength(opcode, w, mod, rm);
            },
            BinaryInstructions.mov_al_mem8,
            BinaryInstructions.mov_ax_mem16,
            BinaryInstructions.mov_mem8_al,
            BinaryInstructions.mov_mem16_ax,
            => {
                // 0xA0, 0xA1, 0xA2, 0xA3
                w = @enumFromInt((BIU.getIndex(0) << 7) >> 7);
                stepSize = decoder.movGetInstructionLength(opcode, w, null, null);
            },
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
                // 0xB0 - 0xBF
                w = @enumFromInt((BIU.getIndex(0) << 4) >> 7);
                stepSize = if (w == WValue.word) 3 else 2;
            },
            BinaryInstructions.mov_mem8_immed8,
            BinaryInstructions.mov_mem16_immed16,
            => {
                // 0xC6, 0xC7
                const second_byte = BIU.getIndex(1);
                w = @enumFromInt((BIU.getIndex(0) << 7) >> 7);
                mod = @enumFromInt(second_byte >> 6);
                rm = @enumFromInt((second_byte << 5) >> 5);
                stepSize = decoder.movGetInstructionLength(opcode, w, mod, rm);
            },
            else => {
                log.debug("This instruction is not yet implemented. Skipping...", .{});
            },
        }

        switch (stepSize) {
            1 => {
                InstructionBytes = [6]u8{
                    BIU.getIndex(0),
                    0b0000_0000,
                    0b0000_0000,
                    0b0000_0000,
                    0b0000_0000,
                    0b0000_0000,
                };
            },
            2 => {
                InstructionBytes = [6]u8{
                    BIU.getIndex(0),
                    BIU.getIndex(1),
                    0b0000_0000,
                    0b0000_0000,
                    0b0000_0000,
                    0b0000_0000,
                };
            },
            3 => {
                InstructionBytes = [6]u8{
                    BIU.getIndex(0),
                    BIU.getIndex(1),
                    BIU.getIndex(2),
                    0b0000_0000,
                    0b0000_0000,
                    0b0000_0000,
                };
            },
            4 => {
                InstructionBytes = [6]u8{
                    BIU.getIndex(0),
                    BIU.getIndex(1),
                    BIU.getIndex(2),
                    BIU.getIndex(3),
                    0b0000_0000,
                    0b0000_0000,
                };
            },
            5 => {
                InstructionBytes = [6]u8{
                    BIU.getIndex(0),
                    BIU.getIndex(1),
                    BIU.getIndex(2),
                    BIU.getIndex(3),
                    BIU.getIndex(4),
                    0b0000_0000,
                };
            },
            6 => {
                InstructionBytes = [6]u8{
                    BIU.getIndex(0),
                    BIU.getIndex(1),
                    BIU.getIndex(2),
                    BIU.getIndex(3),
                    BIU.getIndex(4),
                    BIU.getIndex(5),
                };
            },
            else => {
                log.err("{s}: Instruction size of {d} bytes not valid.", .{ @errorName(SimulatorError.InstructionSizeError), stepSize });
            },
        }

        log.debug("InstructionBytes(length: {d}):", .{stepSize});
        var steps: u3 = 1;
        var instruction_step_number = activeByte;
        for (InstructionBytes) |instruction_byte| {
            if (steps == 1) {
                log.debug("{b:0>8}, active byte {d}, instruction 0x{x:0>2}", .{
                    instruction_byte,
                    activeByte,
                    instruction_byte,
                });
            } else if (steps <= stepSize) {
                log.debug("{b:0>8}, active byte {d}, instruction 0x{x:0>2}", .{
                    instruction_byte,
                    instruction_step_number,
                    instruction_byte,
                });
            } else {
                log.debug("{b:0>8}, empty byte", .{instruction_byte});
            }
            instruction_step_number += 1;
            steps += 1;
        }

        const instruction_data: InstructionData = try decoder.decode(
            opcode,
            InstructionBytes,
        );

        ////////////////////////////////////////////////////////////////////////
        // Instruction execution //
        ////////////////////////////////////////////////////////////////////////

        // EU.next(
        //     instruction_data,
        // ) catch |err| {
        //     switch (err) {
        //         InstructionExecutionError.InvalidInstruction => {
        //             log.err("{s}: Instruction 0x{x:0>2} could not be executed.\ncontinue...", .{
        //                 @errorName(instruction_data.err),
        //                 InstructionBytes[0],
        //             });
        //         },
        //     }
        // };

        ////////////////////////////////////////////////////////////////////////
        // Testing //
        ////////////////////////////////////////////////////////////////////////

        disassembler.next(
            &EU,
            OutputWriter,
            instruction_data,
        ) catch |err| {
            switch (err) {
                InstructionDecodeError.DecodeError => {
                    log.err("{s}: Instruction 0x{x:0>2} could not be decoded.\ncontinue...", .{
                        @errorName(instruction_data.err),
                        InstructionBytes[0],
                    });
                },
                InstructionDecodeError.InstructionError => {
                    log.err("{s}: Instruction 0x{x:0>2} could not be decoded.\ncontinue...", .{
                        @errorName(instruction_data.err),
                        InstructionBytes[0],
                    });
                },
                InstructionDecodeError.NotYetImplemented => {
                    log.err("{s}: 0x{x:0>2} ({s}) not implemented yet.\ncontinue...", .{
                        @errorName(instruction_data.err),
                        InstructionBytes[0],
                        @tagName(opcode),
                    });
                },
                InstructionDecodeError.WriteFailed => {
                    log.err("{s}: Failed to write instruction 0x{x:0>2} ({s}) to .asm file.\ncontinue...", .{
                        @errorName(instruction_data.err),
                        InstructionBytes[0],
                        @tagName(opcode),
                    });
                },
            }
        };

        try OutputWriter.flush();

        if (activeByte + stepSize >= maxFileSizeBytes or activeByte + stepSize >= file_contents.len) {
            depleted = true;
            log.info("+++Simulation+finished++++++++++++++++++++++++++++++++++++++++++++++++++++++++++", .{});
        } else {
            if (activeByte + stepSize > 999) {
                log.debug("+++Next+active+byte+{d}++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n", .{activeByte + stepSize});
            } else if (activeByte + stepSize > 99) {
                log.debug("+++Next+active+byte+{d}+++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n", .{activeByte + stepSize});
            } else if (activeByte + stepSize > 9) {
                log.debug("+++Next+active+byte+{d}++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n", .{activeByte + stepSize});
            } else {
                log.debug("+++Next+active+byte+{d}+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n", .{activeByte + stepSize});
            }
        }
    }

    try disassembler.runAssemblyTest(args_allocator, input_file_path, output_asm_file_path);
}
