const std = @import("std");

const locator = @import("locator.zig");
const RegisterNames = locator.RegisterNames;

const errors = @import("errors.zig");
const InstructionDecodeError = errors.InstructionDecodeError;
const DisassembleError = errors.DiassembleError;

const types = @import("types.zig");
const ModValue = types.instruction_fields.MOD;
const RegValue = types.instruction_fields.REG;
const SrValue = types.instruction_fields.SR;
const RmValue = types.instruction_fields.RM;
const DValue = types.instruction_fields.Direction;
const VValue = types.instruction_fields.Variable;
const WValue = types.instruction_fields.Width;
const SValue = types.instruction_fields.Sign;

const EffectiveAddressCalculation = types.data_types.EffectiveAddressCalculation;
const DisplacementFormat = types.data_types.DisplacementFormat;
const InstructionInfo = types.data_types.InstructionInfo;
const DestinationInfo = types.data_types.DestinationInfo;
const SourceInfo = types.data_types.SourceInfo;

const decoder = @import("decoder.zig");
const InstructionScope = decoder.InstructionScope;
const BinaryInstructions = decoder.BinaryInstructions;
const InstructionData = decoder.InstructionData;
const AccumulatorOp = decoder.AccumulatorOp;
const EscapeOp = decoder.EscapeOp;
const RegisterMemoryToFromRegisterOp = decoder.RegisterMemoryToFromRegisterOp;
const RegisterMemoryOp = decoder.RegisterMemoryOp;
const RegisterOp = decoder.RegisterOp;
const ImmediateToRegisterOp = decoder.ImmediateToRegisterOp;
const ImmediateToMemoryOp = decoder.ImmediateToMemoryOp;
const SegmentRegisterOp = decoder.SegmentRegisterOp;
const AddSet = decoder.AddSet;
const IdentifierAddOp = decoder.IdentifierAddOp;
const RolSet = decoder.RolSet;
const IdentifierRolOp = decoder.IdentifierRolOp;
const TestSet = decoder.TestSet;
const IdentifierTestOp = decoder.IdentifierTestOp;
const IncSet = decoder.IncSet;
const IdentifierIncOp = decoder.IdentifierIncOp;
const DirectOp = decoder.DirectOp;
const SingleByteOp = decoder.SingleByteOp;

const hardware = @import("hardware.zig");
const ExecutionUnit = hardware.ExecutionUnit;
const BusInterfaceUnit = hardware.BusInterfaceUnit;

/// Formats and returns the ASM-86 instruction line as a string object.
/// A memory allocator, the mnemonic as well the InstructionInfo object
/// need to be provided as parameters.
fn prepareInstructionLine(
    allocator: std.mem.Allocator,
    opcode: BinaryInstructions,
    mnemonic: []const u8,
    instruction_info: InstructionInfo,
) ![]const u8 {
    const destination: DestinationInfo = instruction_info.destination_info;
    const source: SourceInfo = instruction_info.source_info;

    const dest: []const u8 = dest_switch: switch (destination) {
        DestinationInfo.address => {
            const res = try std.fmt.allocPrint(
                allocator,
                " {t}",
                .{
                    destination.address,
                },
            );
            break :dest_switch res;
        },
        DestinationInfo.address_calculation => {
            const Address = RegisterNames;

            const base = destination.address_calculation.base;
            const index = destination.address_calculation.index;
            const displacement = destination.address_calculation.displacement;
            const displacement_value = destination.address_calculation.displacement_value;
            const signed_displacement_value = destination.address_calculation.signed_displacement_value;

            const only_displacement = base == Address.none;
            const no_index: bool = index == Address.none;
            const no_displacement: bool = displacement == DisplacementFormat.none;

            if (no_displacement) {
                if (no_index) {
                    const res = try std.fmt.allocPrint(
                        allocator,
                        " [{t}]",
                        .{base.?},
                    );
                    break :dest_switch res;
                } else {
                    const res = try std.fmt.allocPrint(
                        allocator,
                        " [{t} + {t}]",
                        .{ base.?, index.? },
                    );
                    break :dest_switch res;
                }
            } else {
                if (only_displacement) {
                    const res = try std.fmt.allocPrint(
                        allocator,
                        " [{d}]",
                        .{displacement_value.?},
                    );
                    break :dest_switch res;
                } else if (no_index and signed_displacement_value.? >= 0) {
                    const res = try std.fmt.allocPrint(
                        allocator,
                        " [{t} + {d}]",
                        .{ base.?, signed_displacement_value.? },
                    );
                    break :dest_switch res;
                } else if (no_index) {
                    const res = try std.fmt.allocPrint(
                        allocator,
                        " [{t} - {d}]",
                        .{ base.?, signed_displacement_value.? },
                    );
                    break :dest_switch res;
                } else if (signed_displacement_value.? >= 0) {
                    const res = try std.fmt.allocPrint(
                        allocator,
                        " [{t} + {t} + {d}]",
                        .{ base.?, index.?, signed_displacement_value.? },
                    );
                    break :dest_switch res;
                } else {
                    const res = try std.fmt.allocPrint(
                        allocator,
                        " [{t} + {t} - {d}]",
                        .{ base.?, index.?, signed_displacement_value.? },
                    );
                    break :dest_switch res;
                }
            }
        },
        DestinationInfo.mem_addr => {
            const res = try std.fmt.allocPrint(
                allocator,
                " [{d}]",
                .{
                    destination.mem_addr,
                },
            );
            break :dest_switch res;
        },
        DestinationInfo.none => "",
    };

    const src: []const u8 = source_switch: switch (source) {
        SourceInfo.address => {
            const res = try std.fmt.allocPrint(allocator, " {t}", .{source.address});
            break :source_switch res;
        },
        SourceInfo.address_calculation => {
            const Address = RegisterNames;

            const base = source.address_calculation.base;
            const index = source.address_calculation.index;
            const displacement = source.address_calculation.displacement;
            const displacement_value = source.address_calculation.displacement_value;
            const signed_displacement_value = source.address_calculation.signed_displacement_value;

            const only_displacement = base == Address.none;
            const no_index: bool = index == Address.none;
            const no_displacement: bool = displacement == DisplacementFormat.none;

            if (no_displacement) {
                if (no_index) {
                    const res = try std.fmt.allocPrint(
                        allocator,
                        " [{t}]",
                        .{base.?},
                    );
                    break :source_switch res;
                } else {
                    const res = try std.fmt.allocPrint(
                        allocator,
                        " [{t} + {t}]",
                        .{ base.?, index.? },
                    );
                    break :source_switch res;
                }
            } else {
                if (only_displacement) {
                    const res = try std.fmt.allocPrint(
                        allocator,
                        " [{d}]",
                        .{displacement_value.?},
                    );
                    break :source_switch res;
                } else if (no_index and signed_displacement_value.? >= 0) {
                    const res = try std.fmt.allocPrint(
                        allocator,
                        " [{t} + {d}]",
                        .{ base.?, signed_displacement_value.? },
                    );
                    break :source_switch res;
                } else if (no_index) {
                    const res = try std.fmt.allocPrint(
                        allocator,
                        " [{t} - {d}]",
                        .{ base.?, signed_displacement_value.? },
                    );
                    break :source_switch res;
                } else if (signed_displacement_value.? >= 0) {
                    const res = try std.fmt.allocPrint(
                        allocator,
                        " [{t} + {t} + {d}]",
                        .{ base.?, index.?, signed_displacement_value.? },
                    );
                    break :source_switch res;
                } else {
                    const res = try std.fmt.allocPrint(
                        allocator,
                        " [{t} + {t} - {d}]",
                        .{ base.?, index.?, signed_displacement_value.? },
                    );
                    break :source_switch res;
                }
            }
        },
        SourceInfo.immediate => switch (opcode) {
            BinaryInstructions.mov_mem8_immed8 => {
                const res = try std.fmt.allocPrint(
                    allocator,
                    " byte {d}",
                    .{
                        source.immediate,
                    },
                );
                break :source_switch res;
            },
            BinaryInstructions.mov_mem16_immed16 => {
                const res = try std.fmt.allocPrint(
                    allocator,
                    " word {d}",
                    .{
                        source.immediate,
                    },
                );
                break :source_switch res;
            },
            else => {
                const res = try std.fmt.allocPrint(
                    allocator,
                    " {d}",
                    .{
                        source.immediate,
                    },
                );
                break :source_switch res;
            },
        },
        SourceInfo.unsigned_immediate => switch (opcode) {
            BinaryInstructions.mov_mem8_immed8 => {
                const res = try std.fmt.allocPrint(
                    allocator,
                    " byte {d}",
                    .{
                        source.immediate,
                    },
                );
                break :source_switch res;
            },
            BinaryInstructions.mov_mem16_immed16 => {
                const res = try std.fmt.allocPrint(
                    allocator,
                    " word {d}",
                    .{
                        source.immediate,
                    },
                );
                break :source_switch res;
            },
            else => {
                const res = try std.fmt.allocPrint(
                    allocator,
                    " {d}",
                    .{
                        source.immediate,
                    },
                );
                break :source_switch res;
            },
        },
        SourceInfo.mem_addr => {
            const res = try std.fmt.allocPrint(
                allocator,
                " [{d}]",
                .{
                    source.mem_addr,
                },
            );
            break :source_switch res;
        },
        SourceInfo.none => "",
    };

    const sep: []const u8 = if (src.len > 0) "," else "";

    const result: []const u8 = try std.fmt.allocPrint(
        allocator,
        "{s}{s}{s}{s}",
        .{
            mnemonic,
            dest,
            sep,
            src,
        },
    );

    return result;
}

pub fn next(
    EU: *ExecutionUnit,
    OutputWriter: *std.io.Writer,
    opcode: BinaryInstructions,
    // instruction_scope: InstructionScope,
    instruction_data: InstructionData,
) InstructionDecodeError!void {
    const printer = std.log.scoped(.printer);
    // const log = std.log.scoped(.next);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const inst_info: InstructionInfo = locator.getInstructionSourceAndDest(
        EU,
        opcode,
        instruction_data,
    ) catch return InstructionDecodeError.NotYetImplemented;

    const inst_line = prepareInstructionLine(
        allocator,
        opcode,
        switch (instruction_data) {
            .err => return InstructionDecodeError.NotYetImplemented,
            .accumulator_op => instruction_data.accumulator_op.mnemonic,
            .direct_op => instruction_data.direct_op.mnemonic,
            .escape_op => instruction_data.escape_op.mnemonic,
            .identifier_add_op => instruction_data.identifier_add_op.mnemonic,
            .identifier_inc_op => instruction_data.identifier_inc_op.mnemonic,
            .identifier_rol_op => instruction_data.identifier_rol_op.mnemonic,
            .identifier_test_op => instruction_data.identifier_test_op.mnemonic,
            .immediate_to_memory_op => instruction_data.immediate_to_memory_op.mnemonic,
            .immediate_to_register_op => instruction_data.immediate_to_register_op.mnemonic,
            .register_memory_op => instruction_data.register_memory_op.mnemonic,
            .register_memory_to_from_register_op => instruction_data.register_memory_to_from_register_op.mnemonic,
            .register_op => instruction_data.register_op.mnemonic,
            .segment_register_op => instruction_data.segment_register_op.mnemonic,
            .single_byte_op => instruction_data.single_byte_op.mnemonic,
        },
        inst_info,
    ) catch return InstructionDecodeError.NotYetImplemented;
    defer allocator.free(inst_line);
    printer.info("{s}", .{inst_line});
    try OutputWriter.print("{s}\n", .{inst_line});
}

pub fn runAssemblyTest(
    allocator: std.mem.Allocator,
    path_to_binary_input: []const u8,
    asm_file_path: []const u8,
) !void {
    const log = std.log.scoped(.runAssemblyTest);

    log.info("\n+++Testing+Phase++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++", .{});
    log.info("Assembler generates .asm file and compares it with the original binary input...", .{});

    const cwd_path: []const u8 = try std.process.getCwdAlloc(allocator);
    defer allocator.free(cwd_path);
    const assembled_binary_path: []u8 = try std.fs.path.join(allocator, &[_][]const u8{ cwd_path, "zig-out", "test", "reassemble" });
    defer allocator.free(assembled_binary_path);

    const assemble_args = [_][]const u8{
        "nasm",
        "-f",
        "bin",
        asm_file_path,
        "-o",
        assembled_binary_path,
    };

    var assemble_process = std.process.Child.init(&assemble_args, allocator);
    assemble_process.stdout_behavior = .Pipe;
    assemble_process.stderr_behavior = .Pipe;

    try assemble_process.spawn();
    const assemble_result = try assemble_process.wait();

    if (assemble_process.stderr) |stderr| {
        var buffer: [4096]u8 = undefined;
        var stderr_reader = stderr.reader(&buffer);
        var err_buffer: [10240]u8 = undefined;
        const bytes_read = try stderr_reader.read(&err_buffer);
        const stderr_msg = err_buffer[0..bytes_read];
        // defer allocator.free(&stderr_msg);

        switch (assemble_result) {
            .Exited => |code| {
                if (code == 0) {
                    log.info("Assembly successfull.", .{});
                } else {
                    log.err("Assembly failed with exit code: {d}\nError: {s}", .{ code, stderr_msg });
                    return;
                }
            },
            else => {
                log.err("Assembly process terminated unexpectedly\nError: {s}", .{stderr_msg});
                return;
            },
        }
    }

    // defer std.fs.cwd().deleteFile(assembled_binary_path) catch {};
    const compare_result = try compareFiles(
        allocator,
        path_to_binary_input,
        assembled_binary_path,
    );

    if (compare_result) {
        log.info("SUCCESS: The generated assembly matches the original binary!", .{});
    } else {
        log.info("FAILURE: The generated assembly does NOT match the original binary.", .{});
    }

    log.info("+++Testing+Complete+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n", .{});
}

fn compareFiles(
    allocator: std.mem.Allocator,
    path_to_binary_input: []const u8,
    assembled_binary_path: []const u8,
) !bool {
    const log = std.log.scoped(.compareFiles);
    const input = std.fs.cwd().openFile(path_to_binary_input, .{}) catch |err| {
        log.err("Error opening input {s}: {s}", .{ path_to_binary_input, @errorName(err) });
        return false;
    };
    defer input.close();

    const output = std.fs.cwd().openFile(assembled_binary_path, .{}) catch |err| {
        log.err("Error opening output {s}: {s}\n", .{ assembled_binary_path, @errorName(err) });
        return false;
    };
    defer output.close();

    const input_size = try input.getEndPos();
    const output_size = try output.getEndPos();

    if (input_size != output_size) {
        log.info("File sizes differ: input size {d} vs output size {d} bytes.", .{ input_size, output_size });
    }

    const max_file_size = 0xFFF;
    const input_content = try input.readToEndAlloc(allocator, max_file_size);
    defer allocator.free(input_content);
    const output_content = try output.readToEndAlloc(allocator, max_file_size);
    defer allocator.free(output_content);

    return std.mem.eql(u8, input_content, output_content);
}
