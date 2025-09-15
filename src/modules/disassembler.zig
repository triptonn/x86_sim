const std = @import("std");

const locator = @import("locator.zig");
const EffectiveAddressCalculation = locator.EffectiveAddressCalculation;
const AddressBook = locator.AddressBook;
const DisplacementFormat = locator.DisplacementFormat;
const InstructionInfo = locator.InstructionInfo;
const DestinationInfo = locator.DestinationInfo;
const SourceInfo = locator.SourceInfo;

const errors = @import("errors.zig");
const InstructionDecodeError = errors.InstructionDecodeError;
const DisassembleError = errors.DiassembleError;

const types = @import("types.zig");
const ModValue = types.instruction_field_names.ModValue;
const RegValue = types.instruction_field_names.RegValue;
const RmValue = types.instruction_field_names.RmValue;
const DValue = types.instruction_field_names.DValue;
const WValue = types.instruction_field_names.WValue;
const SValue = types.instruction_field_names.SValue;
const SrValue = types.instruction_field_names.SrValue;

const decoder = @import("decoder.zig");
const BinaryInstructions = decoder.BinaryInstructions;
const InstructionData = decoder.InstructionData;
const AccumulatorOp = decoder.AccumulatorOp;
const EscapeOp = decoder.EscapeOp;
const RegisterMemoryToFromRegisterOp = decoder.RegisterMemoryToFromRegisterOp;
const RegisterMemoryOp = decoder.RegisterMemoryOp;
const RegisterOp = decoder.RegisterOp;
const ImmediateToRegisterOp = decoder.ImmediateToRegisterOp;
const ImmediateOp = decoder.ImmediateOp;
const SegmentRegisterOp = decoder.SegmentRegisterOp;
const IdentifierAddOp = decoder.IdentifierAddOp;
const IdentifierRolOp = decoder.IdentifierRolOp;
const IdentifierTestOp = decoder.IdentifierTestOp;
const IdentifierIncOp = decoder.IdentifierIncOp;
const DirectOp = decoder.DirectOp;
const SingleByteOp = decoder.SingleByteOp;

const hardware = @import("hardware.zig");
const ExecutionUnit = hardware.ExecutionUnit;
const BusInterfaceUnit = hardware.BusInterfaceUnit;

fn printEffectiveAddressCalculationDest(
    OutputWriter: *std.io.Writer,
    address_calculation: EffectiveAddressCalculation,
) void {
    const log = std.log.scoped(.printEffectiveAddressCalculationDest);
    const Address = AddressBook.RegisterNames;
    if (address_calculation.index == Address.none) {
        if (address_calculation.displacement == DisplacementFormat.none) {
            log.info("[{t}], ", .{
                address_calculation.base.?,
            });
            OutputWriter.print("[{t}], ", .{
                address_calculation.base.?,
            }) catch |err| {
                log.err(
                    "{s}: Something went wrong trying to write destination effective address calculation {any} to the output file.",
                    .{ @errorName(err), address_calculation },
                );
            };
        } else if (address_calculation.displacement != DisplacementFormat.none and address_calculation.displacement_value.? == 0) {
            log.info("[{t}], ", .{
                address_calculation.base.?,
            });
            OutputWriter.print("[{t}], ", .{
                address_calculation.base.?,
            }) catch |err| {
                log.err(
                    "{s}: Something went wrong trying to write destination effective address calculation {any} to the output file.",
                    .{ @errorName(err), .address_calculation },
                );
            };
        } else if (address_calculation.displacement != DisplacementFormat.none) {
            const disp_u16: u16 = @intCast(address_calculation.displacement_value.?);
            const disp_signed: i16 = if (address_calculation.displacement == DisplacementFormat.d8) blk: {
                const u8val: u8 = @intCast(disp_u16 & 0xFF);
                const s8: i8 = @bitCast(u8val);
                break :blk @as(i16, s8);
            } else blk: {
                const s16: i16 = @bitCast(disp_u16);
                break :blk s16;
            };
            if (disp_signed < 0) {
                log.info("[{t} - {d}], ", .{
                    address_calculation.base.?,
                    -disp_signed,
                });
                OutputWriter.print("[{t} - {d}], ", .{
                    address_calculation.base.?,
                    -disp_signed,
                }) catch |err| {
                    log.err(
                        "{s}: Something went wrong trying to write destination effective address calculation {any} to the output file.",
                        .{ @errorName(err), address_calculation },
                    );
                };
            } else {
                log.info("[{t} + {d}], ", .{
                    address_calculation.base.?,
                    disp_signed,
                });
                OutputWriter.print("[{t} + {d}], ", .{
                    address_calculation.base.?,
                    disp_signed,
                }) catch |err| {
                    log.err(
                        "{s}: Something went wrong trying to write destination effective address calculation {any} to the output file.",
                        .{ @errorName(err), address_calculation },
                    );
                };
            }
        }
    } else if (address_calculation.index != Address.none) {
        if (address_calculation.displacement == DisplacementFormat.none) {
            log.info("[{t} + {t}], ", .{
                address_calculation.base.?,
                address_calculation.index.?,
            });
            OutputWriter.print("[{t} + {t}], ", .{
                address_calculation.base.?,
                address_calculation.index.?,
            }) catch |err| {
                log.err(
                    "{s}: Something went wrong trying to write destination effective address calculation {any} to the output file.",
                    .{ @errorName(err), address_calculation },
                );
            };
        } else if (address_calculation.displacement != DisplacementFormat.none) {
            const disp_u16: u16 = @intCast(address_calculation.displacement_value.?);
            const disp_signed: i16 = if (address_calculation.displacement == DisplacementFormat.d8) blk: {
                const u8val: u8 = @intCast(disp_u16 & 0xFF);
                const s8: i8 = @bitCast(u8val);
                break :blk @as(i16, s8);
            } else blk: {
                const s16: i16 = @bitCast(disp_u16);
                break :blk s16;
            };
            if (disp_signed < 0) {
                log.info("[{t} + {t} - {d}], ", .{
                    address_calculation.base.?,
                    address_calculation.index.?,
                    -disp_signed,
                });
                OutputWriter.print("[{t} + {t} - {d}], ", .{
                    address_calculation.base.?,
                    address_calculation.index.?,
                    -disp_signed,
                }) catch |err| {
                    log.err(
                        "{s}: Something went wrong trying to write destination effective address calculation {any} to the output file.",
                        .{ @errorName(err), address_calculation },
                    );
                };
            } else {
                log.info("[{t} + {t} + {d}], ", .{
                    address_calculation.base.?,
                    address_calculation.index.?,
                    disp_signed,
                });
                OutputWriter.print("[{t} + {t} + {d}], ", .{
                    address_calculation.base.?,
                    address_calculation.index.?,
                    disp_signed,
                }) catch |err| {
                    log.err(
                        "{s}: Something went wrong trying to write destination effective address calculation {any} to the output file.",
                        .{ @errorName(err), address_calculation },
                    );
                };
            }
        }
    }
}

fn printEffectiveAddressCalculationSource(
    OutputWriter: *std.io.Writer,
    address_calculation: EffectiveAddressCalculation,
) void {
    const log = std.log.scoped(.printEffectiveAddressCalculationSource);
    const Address = AddressBook.RegisterNames;
    if (address_calculation.index == Address.none) {
        if (address_calculation.displacement == DisplacementFormat.none) {
            log.info("[{t}]", .{
                address_calculation.base.?,
            });
            OutputWriter.print("[{t}]\n", .{
                address_calculation.base.?,
            }) catch |err| {
                log.err(
                    "{s}: Something went wrong trying to write source effective address calculation {any} to the output file.",
                    .{ @errorName(err), address_calculation },
                );
            };
        } else if (address_calculation.displacement != DisplacementFormat.none and address_calculation.displacement_value.? == 0) {
            log.info("[{t}]", .{
                address_calculation.base.?,
            });
            OutputWriter.print("[{t}]\n", .{
                address_calculation.base.?,
            }) catch |err| {
                log.err(
                    "{s}: Something went wrong trying to write source effective address calculation {any} to the output file.",
                    .{ @errorName(err), address_calculation },
                );
            };
        } else if (address_calculation.displacement != DisplacementFormat.none) {
            const disp_u16: u16 = @intCast(address_calculation.displacement_value.?);
            const disp_signed: i16 = if (address_calculation.displacement == DisplacementFormat.d8) blk: {
                const u8val: u8 = @intCast(disp_u16 & 0xFF);
                const s8: i8 = @bitCast(u8val);
                break :blk @as(i16, s8);
            } else blk: {
                const s16: i16 = @bitCast(disp_u16);
                break :blk s16;
            };
            if (disp_signed < 0) {
                log.info("[{t} - {d}]", .{
                    address_calculation.base.?,
                    -disp_signed,
                });
                OutputWriter.print("[{t} - {d}]\n", .{
                    address_calculation.base.?,
                    -disp_signed,
                }) catch |err| {
                    log.err(
                        "{s}: Something went wrong trying to write source effective address calculation {any} to the output file.",
                        .{ @errorName(err), address_calculation },
                    );
                };
            } else if (disp_signed == 0) {
                log.info("[{t}]", .{
                    address_calculation.base.?,
                });
                OutputWriter.print("[{t}]\n", .{
                    address_calculation.base.?,
                }) catch |err| {
                    log.err(
                        "{s}: Something went wrong trying to write source effective address calculation {any} to the output file.",
                        .{ @errorName(err), address_calculation },
                    );
                };
            } else {
                log.info("[{t} + {d}]", .{
                    address_calculation.base.?,
                    disp_signed,
                });
                OutputWriter.print("[{t} + {d}]\n", .{
                    address_calculation.base.?,
                    disp_signed,
                }) catch |err| {
                    log.err(
                        "{s}: Something went wrong trying to write source effective address calculation {any} to the output file.",
                        .{ @errorName(err), address_calculation },
                    );
                };
            }
        }
    } else if (address_calculation.index != Address.none) {
        if (address_calculation.displacement == DisplacementFormat.none) {
            log.info("[{t} + {t}]", .{
                address_calculation.base.?,
                address_calculation.index.?,
            });
            OutputWriter.print("[{t} + {t}]\n", .{
                address_calculation.base.?,
                address_calculation.index.?,
            }) catch |err| {
                log.err(
                    "{s}: Something went wrong trying to write source effective address calculation {any} to the output file.",
                    .{ @errorName(err), address_calculation },
                );
            };
        } else if (address_calculation.displacement != DisplacementFormat.none) {
            const disp_u16: u16 = @intCast(address_calculation.displacement_value.?);
            const disp_signed: i16 = if (address_calculation.displacement == DisplacementFormat.d8) blk: {
                const u8val: u8 = @intCast(disp_u16 & 0xFF);
                const s8: i8 = @bitCast(u8val);
                break :blk @as(i16, s8);
            } else blk: {
                const s16: i16 = @bitCast(disp_u16);
                break :blk s16;
            };
            if (disp_signed < 0) {
                log.info("[{t} + {t} - {d}]", .{
                    address_calculation.base.?,
                    address_calculation.index.?,
                    -disp_signed,
                });
                OutputWriter.print("[{t} + {t} - {d}]\n", .{
                    address_calculation.base.?,
                    address_calculation.index.?,
                    -disp_signed,
                }) catch |err| {
                    log.err(
                        "{s}: Something went wrong trying to write source effective address calculation {any} to the output file.",
                        .{ @errorName(err), address_calculation },
                    );
                };
            } else {
                log.info("[{t} + {t} + {d}]", .{
                    address_calculation.base.?,
                    address_calculation.index.?,
                    disp_signed,
                });
                OutputWriter.print("[{t} + {t} + {d}]\n", .{
                    address_calculation.base.?,
                    address_calculation.index.?,
                    disp_signed,
                }) catch |err| {
                    log.err(
                        "{s}: Something went wrong trying to write source effective address calculation {any} to the output file.",
                        .{ @errorName(err), address_calculation },
                    );
                };
            }
        }
    }
}

/// Formats and returns the ASM-86 instruction line as a string object.
/// A memory allocator, the mnemonic as well the InstructionInfo object
/// need to be provided as parameters.
fn prepareInstructionLine(
    allocator: std.mem.Allocator,
    opcode: BinaryInstructions,
    mnemonic: []const u8,
    instruction_info: InstructionInfo,
) ![]const u8 {
    // const log = std.log.scoped(.prepareInstructionLine);

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
            const Address = AddressBook.RegisterNames;

            const base = destination.address_calculation.base;
            const index = destination.address_calculation.index;
            const displacement = destination.address_calculation.displacement;
            const displacement_value = destination.address_calculation.displacement_value;

            const no_index: bool = index == Address.none;
            const no_displacement: bool = displacement == DisplacementFormat.none;

            if (no_index) {
                if (no_displacement) {
                    const res = try std.fmt.allocPrint(
                        allocator,
                        " [{t}]",
                        .{
                            base.?,
                        },
                    );
                    break :dest_switch res;
                } else if (!no_displacement and displacement_value.? == 0) {
                    const res = try std.fmt.allocPrint(
                        allocator,
                        "[{t} + {d}], ",
                        .{
                            base.?,
                            displacement_value.?,
                        },
                    );
                    break :dest_switch res;
                } else {
                    const disp_u16: u16 = @intCast(displacement_value.?);
                    const disp_signed: i16 = if (displacement == DisplacementFormat.d8) blk: {
                        const u8val: u8 = @intCast(disp_u16 & 0xFF);
                        const s8: i8 = @bitCast(u8val);
                        break :blk @as(i16, s8);
                    } else blk: {
                        const s16: i16 = @bitCast(disp_u16);
                        break :blk s16;
                    };

                    if (disp_signed < 0) {
                        const res = try std.fmt.allocPrint(
                            allocator,
                            "[{t} - {d}], ",
                            .{
                                base.?,
                                -disp_signed,
                            },
                        );
                        break :dest_switch res;
                    } else {
                        const res = try std.fmt.allocPrint(
                            allocator,
                            "[{t} + {d}], ",
                            .{
                                base.?,
                                disp_signed,
                            },
                        );
                        break :dest_switch res;
                    }
                }
            } else {
                if (displacement == DisplacementFormat.none) {
                    const res = try std.fmt.allocPrint(
                        allocator,
                        " [{t} + {t}]",
                        .{
                            base.?,
                            index.?,
                        },
                    );
                    break :dest_switch res;
                } else {
                    const disp_u16: u16 = @intCast(displacement_value.?);
                    const disp_signed: i16 = if (displacement == DisplacementFormat.d8) blk: {
                        const u8val: u8 = @intCast(disp_u16 & 0xFF);
                        const s8: i8 = @bitCast(u8val);
                        break :blk @as(i16, s8);
                    } else blk: {
                        const s16: i16 = @bitCast(disp_u16);
                        break :blk s16;
                    };
                    if (disp_signed < 0) {
                        const res = try std.fmt.allocPrint(
                            allocator,
                            " [{t} + {t} - {d}]",
                            .{
                                base.?,
                                index.?,
                                -disp_signed,
                            },
                        );
                        break :dest_switch res;
                    } else {
                        const res = try std.fmt.allocPrint(
                            allocator,
                            " [{t} + {t} + {d}]",
                            .{
                                base.?,
                                index.?,
                                disp_signed,
                            },
                        );
                        break :dest_switch res;
                    }
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
            const Address = AddressBook.RegisterNames;

            const base = source.address_calculation.base;
            const index = source.address_calculation.index;
            const displacement = source.address_calculation.displacement;
            const displacement_value = source.address_calculation.displacement_value;

            if (index == Address.none) {
                if (displacement == DisplacementFormat.none) {
                    const res = try std.fmt.allocPrint(
                        allocator,
                        " [{t}]",
                        .{
                            base.?,
                        },
                    );
                    break :source_switch res;
                } else if (displacement != DisplacementFormat.none and displacement_value.? == 0) {
                    const res = try std.fmt.allocPrint(
                        allocator,
                        " [{t}]",
                        .{
                            base.?,
                        },
                    );
                    break :source_switch res;
                } else {
                    const disp_u16: u16 = @intCast(displacement_value.?);
                    const disp_signed: i16 = if (displacement == DisplacementFormat.d8) blk: {
                        const u8val: u8 = @intCast(disp_u16 & 0xFF);
                        const s8: i8 = @bitCast(u8val);
                        break :blk @as(i16, s8);
                    } else blk: {
                        const s16: i16 = @bitCast(disp_u16);
                        break :blk s16;
                    };
                    if (disp_signed < 0) {
                        const res = try std.fmt.allocPrint(
                            allocator,
                            " [{t} - {d}]",
                            .{
                                base.?,
                                -disp_signed,
                            },
                        );
                        break :source_switch res;
                    } else {
                        const res = try std.fmt.allocPrint(
                            allocator,
                            " [{t} + {d}]",
                            .{
                                base.?,
                                disp_signed,
                            },
                        );
                        break :source_switch res;
                    }
                }
            } else {
                if (displacement == DisplacementFormat.none) {
                    const res = try std.fmt.allocPrint(
                        allocator,
                        " [{t} + {t}]",
                        .{
                            base.?,
                            index.?,
                        },
                    );
                    break :source_switch res;
                } else {
                    const disp_u16: u16 = @intCast(displacement_value.?);
                    const disp_signed: i16 = if (displacement == DisplacementFormat.d8) blk: {
                        const u8val: u8 = @intCast(disp_u16 & 0xFF);
                        const s8: i8 = @bitCast(u8val);
                        break :blk @as(i16, s8);
                    } else blk: {
                        const s16: i16 = @bitCast(disp_u16);
                        break :blk s16;
                    };
                    if (disp_signed < 0) {
                        const res = try std.fmt.allocPrint(
                            allocator,
                            " [{t} + {t} - {d}]",
                            .{
                                base.?,
                                index.?,
                                -disp_signed,
                            },
                        );
                        break :source_switch res;
                    } else {
                        const res = try std.fmt.allocPrint(
                            allocator,
                            " [{t} + {t} + {d}]",
                            .{
                                base.?,
                                index.?,
                                disp_signed,
                            },
                        );
                        break :source_switch res;
                    }
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
    // BIU: *BusInterfaceUnit,
    OutputWriter: *std.io.Writer,
    instruction_data: InstructionData,
) InstructionDecodeError!void {
    const printer = std.log.scoped(.printer);
    const log = std.log.scoped(.next);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    switch (instruction_data) {
        .err => |err| {
            log.err("{s}: {any} occured.", .{ @errorName(err), err });
        },
        .accumulator_op => {
            const accumulator_op: AccumulatorOp = instruction_data.accumulator_op;

            const opcode = accumulator_op.opcode;
            const mnemonic = accumulator_op.mnemonic;
            const w = accumulator_op.w;
            const data_8 = accumulator_op.data_8;
            const data_lo = accumulator_op.data_lo;
            const data_hi = accumulator_op.data_hi;
            const addr_lo = accumulator_op.addr_lo;
            const addr_hi = accumulator_op.addr_hi;

            const instruction_info: InstructionInfo = switch (opcode) {

                // Immediate to accumulator instructions
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
                BinaryInstructions.in_al_dx,
                BinaryInstructions.in_ax_dx,
                BinaryInstructions.out_al_dx,
                BinaryInstructions.out_ax_dx,
                => locator.getImmediateToAccumulatorDest(
                    w.?,
                    data_8,
                    data_lo,
                    data_hi,
                ),

                // Direct address (offset) addr_lo, addr_hi
                BinaryInstructions.mov_al_mem8,
                BinaryInstructions.mov_ax_mem16,
                => locator.getMemToAccSourceAndDest(
                    w.?,
                    addr_lo,
                    addr_hi,
                ),
                BinaryInstructions.mov_mem8_al,
                BinaryInstructions.mov_mem16_ax,
                => locator.getAccToMemSourceAndDest(
                    w.?,
                    addr_lo,
                    addr_hi,
                ),
                else => return InstructionDecodeError.InstructionError,
            };

            const instruction_line: []const u8 = prepareInstructionLine(
                allocator,
                opcode,
                mnemonic,
                instruction_info,
            ) catch {
                return InstructionDecodeError.NotYetImplemented;
            };
            defer allocator.free(instruction_line);
            printer.debug("{s}", .{instruction_line});
            try OutputWriter.print("{s}\n", .{instruction_line});
        },
        .escape_op => {
            const escape_op: EscapeOp = instruction_data.escape_op;
            try OutputWriter.print("{s} ", .{escape_op.mnemonic});
        },
        .register_memory_to_from_register_op => {
            const register_memory_to_from_register_op: RegisterMemoryToFromRegisterOp = instruction_data.register_memory_to_from_register_op;

            const opcode = register_memory_to_from_register_op.opcode;
            const mnemonic = register_memory_to_from_register_op.mnemonic;
            const d = register_memory_to_from_register_op.d;
            const w = register_memory_to_from_register_op.w;
            const mod = register_memory_to_from_register_op.mod;
            const reg = register_memory_to_from_register_op.reg;
            const rm = register_memory_to_from_register_op.rm;

            const instruction_info: InstructionInfo = locator.getRegMemToFromRegSourceAndDest(
                EU,
                d.?,
                w.?,
                reg,
                mod,
                rm,
                switch (mod) {
                    ModValue.memoryModeNoDisplacement => if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) register_memory_to_from_register_op.disp_lo else null,
                    ModValue.memoryMode8BitDisplacement => register_memory_to_from_register_op.disp_lo,
                    ModValue.memoryMode16BitDisplacement => register_memory_to_from_register_op.disp_lo,
                    ModValue.registerModeNoDisplacement => null,
                },
                switch (mod) {
                    ModValue.memoryModeNoDisplacement => if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) register_memory_to_from_register_op.disp_hi else null,
                    ModValue.memoryMode8BitDisplacement => null,
                    ModValue.memoryMode16BitDisplacement => register_memory_to_from_register_op.disp_hi,
                    ModValue.registerModeNoDisplacement => null,
                },
            );

            const instruction_line: []const u8 = prepareInstructionLine(
                allocator,
                opcode,
                mnemonic,
                instruction_info,
            ) catch {
                return InstructionDecodeError.NotYetImplemented;
            };
            defer allocator.free(instruction_line);
            printer.debug("{s}", .{instruction_line});
            try OutputWriter.print("{s}\n", .{instruction_line});
        },
        .register_op => {
            const register_op: RegisterOp = instruction_data.register_op;
            const opcode: BinaryInstructions = register_op.opcode;
            const mnemonic: []const u8 = register_op.mnemonic;
            const reg: RegValue = register_op.reg;

            const instruction_info: InstructionInfo = locator.getRegisterOpSourceAndDest(
                opcode,
                reg,
            );
            const instruction_line: []const u8 = prepareInstructionLine(
                allocator,
                opcode,
                mnemonic,
                instruction_info,
            ) catch {
                return InstructionDecodeError.NotYetImplemented;
            };
            defer allocator.free(instruction_line);
            printer.debug("{s}", .{instruction_line});
            try OutputWriter.print("{s}\n", .{instruction_line});
        },
        .immediate_to_register_op => {
            const immediate_to_register_op: ImmediateToRegisterOp = instruction_data.immediate_to_register_op;
            try OutputWriter.print("{s} ", .{immediate_to_register_op.mnemonic});
        },
        .immediate_op => {
            const immediate_op: ImmediateOp = instruction_data.immediate_op;
            try OutputWriter.print("{s} ", .{immediate_op.mnemonic});
        },
        .segment_register_op => {
            const segment_register_op: SegmentRegisterOp = instruction_data.segment_register_op;
            try OutputWriter.print("{s} ", .{segment_register_op.mnemonic});
        },
        .identifier_add_op => {
            const identifier_add_op: IdentifierAddOp = instruction_data.identifier_add_op;
            try OutputWriter.print("{s} ", .{identifier_add_op.mnemonic});
        },
        .identifier_rol_op => {
            const identifier_rol_op: IdentifierRolOp = instruction_data.identifier_rol_op;
            try OutputWriter.print("{s} ", .{identifier_rol_op.mnemonic});
        },
        .identifier_test_op => {
            const identifier_test_op: IdentifierTestOp = instruction_data.identifier_test_op;
            try OutputWriter.print("{s} ", .{identifier_test_op.mnemonic});
        },
        .identifier_inc_op => {
            const identifier_inc_op: IdentifierIncOp = instruction_data.identifier_inc_op;
            try OutputWriter.print("{s} ", .{identifier_inc_op.mnemonic});
        },
        .direct_op => {
            const direct_op: DirectOp = instruction_data.direct_op;
            try OutputWriter.print("{s} ", .{direct_op.mnemonic});
        },
        .single_byte_op => {
            const single_byte_op: SingleByteOp = instruction_data.single_byte_op;
            try OutputWriter.print("{s} ", .{single_byte_op.mnemonic});
        },
    }
}

// /// Writes decoded asm-86 instructions to a test file.
// pub fn disassemble(
//     EU: *ExecutionUnit,
//     BIU: *BusInterfaceUnit,
//     OutputWriter: *std.io.Writer,
//     // InstructionBytes: [6]u8,
//     instruction_data: InstructionData,
// ) InstructionDecodeError!void {
//     const log = std.log.scoped(.disassemble);

//     switch (instruction_data) {
//         .err => {
//             return instruction_data.err;
//         },
//         .identifier_add_op => {
//             log.info("{s} ", .{instruction_data.add_instruction.mnemonic});
//             OutputWriter.print("{s} ", .{instruction_data.add_instruction.mnemonic}) catch |err| {
//                 return err;
//             };

//             var instruction_info: InstructionInfo = undefined;

//             // TODO: in case of add_immediate_8/16_to_acc there is no d, reg, mod, rm or displacement
//             switch (instruction_data.identifier_add_op.opcode) {
//                 .add_regmem8_reg8,
//                 .add_regmem16_reg16,
//                 .add_reg8_regmem8,
//                 .add_reg16_regmem16,
//                 => {
//                     instruction_info = BIU.getRegMemToFromRegSourceAndDest(
//                         EU,
//                         instruction_data.identifier_add_op.d.?,
//                         instruction_data.identifier_add_op.w,
//                         instruction_data.identifier_add_op.reg.?,
//                         instruction_data.identifier_add_op.mod.?,
//                         instruction_data.identifier_add_op.rm.?,
//                         instruction_data.identifier_add_op.disp_lo,
//                         instruction_data.identifier_add_op.disp_hi,
//                     );
//                 },
//                 .add_al_immed8,
//                 .add_ax_immed16,
//                 => {
//                     instruction_info = BIU.getAddImmediateToAccumulatorDest(
//                         // registers,
//                         instruction_data.identifier_add_op.w,
//                         instruction_data.identifier_add_op.data.?,
//                         instruction_data.identifier_add_op.w_data,
//                     );
//                 },
//                 else => {
//                     log.err("Opening add_instruction payload, but no valid add opcode inside.", .{});
//                 },
//             }

//             const destination: DestinationInfo = instruction_info.destination_info;
//             var destinationIsEffectiveAddressCalculation: bool = undefined;
//             switch (destination) {
//                 .address => {
//                     destinationIsEffectiveAddressCalculation = false;
//                     log.info("{t}, ", .{destination.address});
//                     OutputWriter.print(
//                         "{t}, ",
//                         .{destination.address},
//                     ) catch |err| {
//                         log.err(
//                             "{s}: Something went wrong trying to write destination {t} the output file.",
//                             .{ @errorName(err), destination.address },
//                         );
//                     };
//                 },
//                 .address_calculation => {
//                     destinationIsEffectiveAddressCalculation = true;
//                     printEffectiveAddressCalculationDest(OutputWriter, destination.address_calculation);
//                 },
//                 .mem_addr => {
//                     destinationIsEffectiveAddressCalculation = false;
//                     log.info("[{d}],", .{destination.mem_addr});
//                     OutputWriter.print("[{d}], ", .{
//                         destination.mem_addr,
//                     }) catch |err| {
//                         log.err(
//                             "{s}: Something went wrong trying to write to memory address [{d}] to the output file.",
//                             .{ @errorName(err), destination.mem_addr },
//                         );
//                     };
//                 },
//             }

//             const source: SourceInfo = instruction_info.source_info;
//             switch (source) {
//                 .address => {
//                     log.info("{t}", .{source.address});
//                     OutputWriter.print(
//                         "{t}\n",
//                         .{source.address},
//                     ) catch |err| {
//                         log.err(
//                             "{s}: Something went wrong trying to write source {any} to the output file.",
//                             .{ @errorName(err), source.address },
//                         );
//                     };
//                 },
//                 .address_calculation => {
//                     printEffectiveAddressCalculationSource(OutputWriter, source.address_calculation);
//                 },
//                 .immediate => {
//                     log.err("ERROR: Immediate value source for add not yet implemented", .{});
//                 },
//                 .mem_addr => {
//                     log.info("[{d}]", .{source.mem_addr});
//                     OutputWriter.print(
//                         "[{d}]\n",
//                         .{source.mem_addr},
//                     ) catch |err| {
//                         log.err(
//                             "{s}: Something went wrong trying to write source index {any} to the output file.",
//                             .{ @errorName(err), source.mem_addr },
//                         );
//                     };
//                 },
//             }
//         },
//         .immediate_to_register_op => {
//             log.info("{s} ", .{instruction_data.immediate_op_instruction.mnemonic});
//             OutputWriter.print("{s} ", .{instruction_data.immediate_to_register_op.mnemonic}) catch |err| {
//                 return err;
//             };

//             const instruction_info: InstructionInfo = BIU.getImmediateOpSourceAndDest(EU, instruction_data);
//             const destination: DestinationInfo = instruction_info.destination_info;
//             switch (destination) {
//                 .address => {
//                     log.info("{t},", .{destination.address});
//                     OutputWriter.print("{t}, ", .{destination.address}) catch |err| {
//                         return err;
//                     };
//                 },
//                 .address_calculation => {
//                     printEffectiveAddressCalculationDest(OutputWriter, destination.address_calculation);
//                 },
//                 .mem_addr => {
//                     log.info("[{d}],", .{destination.mem_addr});
//                     OutputWriter.print("[{d}], ", .{destination.mem_addr}) catch |err| {
//                         return err;
//                     };
//                 },
//             }
//             const source: SourceInfo = instruction_info.source_info;
//             switch (source) {
//                 .address => {
//                     log.info("{t}", .{destination.address});
//                     OutputWriter.print("{t}\n", .{destination.address}) catch |err| {
//                         return err;
//                     };
//                 },
//                 .address_calculation => {
//                     printEffectiveAddressCalculationSource(OutputWriter, source.address_calculation);
//                 },
//                 .immediate => {
//                     log.info("{d}", .{source.immediate});
//                     OutputWriter.print("{d}\n", .{source.immediate}) catch |err| {
//                         return err;
//                     };
//                 },
//                 .mem_addr => {
//                     log.info("[{d}]", .{source.mem_addr});
//                     OutputWriter.print("[{d}]\n", .{source.mem_addr}) catch |err| {
//                         return err;
//                     };
//                 },
//             }
//         },
//         .register_memory_to_from_register_op => {
//             log.info("{s} ", .{instruction_data.register_memory_to_from_register_op.mnemonic});
//             OutputWriter.print("{s} ", .{instruction_data.register_memory_to_from_register_op.mnemonic}) catch |err| {
//                 return err;
//             };

//             const mod = instruction_data.register_memory_to_from_register_op.mod;
//             const rm = instruction_data.register_memory_to_from_register_op.rm;
//             const instruction: BinaryInstructions = instruction_data.register_memory_to_from_register_op.opcode;
//             var instruction_info: InstructionInfo = undefined;
//             switch (instruction) {
//                 .mov_regmem8_reg8,
//                 .mov_regmem16_reg16,
//                 .mov_reg8_regmem8,
//                 .mov_reg16_regmem16,
//                 => {
//                     const d: DValue = instruction_data.mov_with_mod_instruction.d.?;
//                     const reg: RegValue = instruction_data.mov_with_mod_instruction.reg.?;
//                     instruction_info = BIU.getRegMemToFromRegSourceAndDest(
//                         EU,
//                         d,
//                         instruction_data.mov_with_mod_instruction.w.?,
//                         reg,
//                         mod,
//                         rm,
//                         // if (mod == ModValue.memoryMode8BitDisplacement or mod == ModValue.memoryMode16BitDisplacement or (mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16)) InstructionBytes[2] else null,
//                         if (mod == ModValue.memoryMode8BitDisplacement or mod == ModValue.memoryMode16BitDisplacement or (mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16)) instruction_data.mov_with_mod_instruction.disp_lo.? else null,
//                         // if (mod == ModValue.memoryMode16BitDisplacement or (mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16)) InstructionBytes[3] else null,
//                         if (mod == ModValue.memoryMode16BitDisplacement or (mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16)) instruction_data.mov_with_mod_instruction.disp_hi.? else null,
//                     );
//                 },
//                 .mov_regmem16_segreg => {
//                     const sr: SrValue = instruction_data.mov_with_mod_instruction.sr.?;
//                     instruction_info = BIU.getSegToRegMemMovSourceAndDest(
//                         EU,
//                         mod,
//                         sr,
//                         rm,
//                         if (mod == ModValue.memoryMode8BitDisplacement or mod == ModValue.memoryMode16BitDisplacement or (mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16)) instruction_data.mov_with_mod_instruction.disp_lo.? else null,
//                         if (mod == ModValue.memoryMode16BitDisplacement or (mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16)) instruction_data.mov_with_mod_instruction.disp_hi.? else null,
//                     );
//                 },
//                 .mov_segreg_regmem16 => {
//                     const sr: SrValue = instruction_data.mov_with_mod_instruction.sr.?;
//                     instruction_info = BIU.getRegMemToSegMovSourceAndDest(
//                         EU,
//                         mod,
//                         sr,
//                         rm,
//                         if (mod == ModValue.memoryMode8BitDisplacement or mod == ModValue.memoryMode16BitDisplacement or (mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16)) instruction_data.mov_with_mod_instruction.disp_lo.? else null,
//                         if (mod == ModValue.memoryMode16BitDisplacement or (mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16)) instruction_data.mov_with_mod_instruction.disp_hi.? else null,
//                     );
//                 },
//                 .mov_mem8_immed8,
//                 .mov_mem16_immed16,
//                 => {
//                     const w = instruction_data.mov_with_mod_instruction.w.?;
//                     instruction_info = BIU.getImmediateToRegMemMovDest(
//                         EU,
//                         mod,
//                         rm,
//                         w,
//                         if ((mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) or mod == ModValue.memoryMode8BitDisplacement or mod == ModValue.memoryMode16BitDisplacement) instruction_data.mov_with_mod_instruction.disp_lo.? else null,
//                         if ((mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) or mod == ModValue.memoryMode16BitDisplacement) instruction_data.mov_with_mod_instruction.disp_hi.? else null,
//                         instruction_data.mov_with_mod_instruction.data.?,
//                         if (w == WValue.word) instruction_data.mov_with_mod_instruction.w_data.? else null,
//                     );
//                 },
//                 else => {
//                     log.err("Error: Instruction 0x{x} not implemented yet", .{instruction});
//                 },
//             }

//             const destination = instruction_info.destination_info;
//             switch (destination) {
//                 .address => {
//                     log.info("{t}, ", .{destination.address});
//                     OutputWriter.print(
//                         "{t}, ",
//                         .{destination.address},
//                     ) catch |err| {
//                         log.err(
//                             "{s}: Something went wrong trying to write destination {t} the output file.",
//                             .{ @errorName(err), destination.address },
//                         );
//                     };
//                 },
//                 .address_calculation => {
//                     const Address = AddressBook.RegisterNames;
//                     if (destination.address_calculation.index == Address.none) {
//                         if (destination.address_calculation.displacement == DisplacementFormat.none) {
//                             log.info("[{t}], ", .{
//                                 destination.address_calculation.base.?,
//                             });
//                             OutputWriter.print("[{t}], ", .{
//                                 destination.address_calculation.base.?,
//                             }) catch |err| {
//                                 log.err(
//                                     "{s}: Something went wrong trying to write destination effective address calculation {any} to the output file.",
//                                     .{ @errorName(err), destination.address_calculation },
//                                 );
//                             };
//                         } else if (destination.address_calculation.displacement != DisplacementFormat.none and destination.address_calculation.displacement_value.? == 0) {
//                             log.info("[{t}], ", .{
//                                 destination.address_calculation.base.?,
//                             });
//                             OutputWriter.print("[{t}], ", .{
//                                 destination.address_calculation.base.?,
//                             }) catch |err| {
//                                 log.err(
//                                     "{s}: Something went wrong trying to write destination effective address calculation {any} to the output file.",
//                                     .{ @errorName(err), destination.address_calculation },
//                                 );
//                             };
//                         } else if (destination.address_calculation.displacement != DisplacementFormat.none) {
//                             const disp_u16: u16 = @intCast(destination.address_calculation.displacement_value.?);
//                             const disp_signed: i16 = if (destination.address_calculation.displacement == DisplacementFormat.d8) blk: {
//                                 const u8val: u8 = @intCast(disp_u16 & 0xFF);
//                                 const s8: i8 = @bitCast(u8val);
//                                 break :blk @as(i16, s8);
//                             } else blk: {
//                                 const s16: i16 = @bitCast(disp_u16);
//                                 break :blk s16;
//                             };
//                             if (disp_signed < 0) {
//                                 log.info("[{t} - {d}], ", .{
//                                     destination.address_calculation.base.?,
//                                     -disp_signed,
//                                 });
//                                 OutputWriter.print("[{t} - {d}], ", .{
//                                     destination.address_calculation.base.?,
//                                     -disp_signed,
//                                 }) catch |err| {
//                                     log.err(
//                                         "{s}: Something went wrong trying to write destination effective address calculation {any} to the output file.",
//                                         .{ @errorName(err), destination.address_calculation },
//                                     );
//                                 };
//                             } else {
//                                 log.info("[{t} + {d}], ", .{
//                                     destination.address_calculation.base.?,
//                                     disp_signed,
//                                 });
//                                 OutputWriter.print("[{t} + {d}], ", .{
//                                     destination.address_calculation.base.?,
//                                     disp_signed,
//                                 }) catch |err| {
//                                     log.err(
//                                         "{s}: Something went wrong trying to write destination effective address calculation {any} to the output file.",
//                                         .{ @errorName(err), destination.address_calculation },
//                                     );
//                                 };
//                             }
//                         }
//                     } else if (destination.address_calculation.index != Address.none) {
//                         if (destination.address_calculation.displacement == DisplacementFormat.none) {
//                             log.info("[{t} + {t}], ", .{
//                                 destination.address_calculation.base.?,
//                                 destination.address_calculation.index.?,
//                             });
//                             OutputWriter.print("[{t} + {t}], ", .{
//                                 destination.address_calculation.base.?,
//                                 destination.address_calculation.index.?,
//                             }) catch |err| {
//                                 log.err(
//                                     "{s}: Something went wrong trying to write destination effective address calculation {any} to the output file.",
//                                     .{ @errorName(err), destination.address_calculation },
//                                 );
//                             };
//                         } else if (destination.address_calculation.displacement != DisplacementFormat.none) {
//                             const disp_u16: u16 = @intCast(destination.address_calculation.displacement_value.?);
//                             const disp_signed: i16 = if (destination.address_calculation.displacement == DisplacementFormat.d8) blk: {
//                                 const u8val: u8 = @intCast(disp_u16 & 0xFF);
//                                 const s8: i8 = @bitCast(u8val);
//                                 break :blk @as(i16, s8);
//                             } else blk: {
//                                 const s16: i16 = @bitCast(disp_u16);
//                                 break :blk s16;
//                             };
//                             if (disp_signed < 0) {
//                                 log.info("[{t} + {t} - {d}], ", .{
//                                     destination.address_calculation.base.?,
//                                     destination.address_calculation.index.?,
//                                     -disp_signed,
//                                 });
//                                 OutputWriter.print("[{t} + {t} - {d}], ", .{
//                                     destination.address_calculation.base.?,
//                                     destination.address_calculation.index.?,
//                                     -disp_signed,
//                                 }) catch |err| {
//                                     log.err(
//                                         "{s}: Something went wrong trying to write destination effective address calculation {any} to the output file.",
//                                         .{ @errorName(err), destination.address_calculation },
//                                     );
//                                 };
//                             } else {
//                                 log.info("[{t} + {t} + {d}], ", .{
//                                     destination.address_calculation.base.?,
//                                     destination.address_calculation.index.?,
//                                     disp_signed,
//                                 });
//                                 OutputWriter.print("[{t} + {t} + {d}], ", .{
//                                     destination.address_calculation.base.?,
//                                     destination.address_calculation.index.?,
//                                     disp_signed,
//                                 }) catch |err| {
//                                     log.err(
//                                         "{s}: Something went wrong trying to write destination effective address calculation {any} to the output file.",
//                                         .{ @errorName(err), destination.address_calculation },
//                                     );
//                                 };
//                             }
//                         }
//                     }
//                 },
//                 .mem_addr => {
//                     log.info("[{d}],", .{destination.mem_addr});
//                     OutputWriter.print("[{d}], ", .{
//                         destination.mem_addr,
//                     }) catch |err| {
//                         log.err(
//                             "{s}: Something went wrong trying to write to memory address [{d}] to the output file.",
//                             .{ @errorName(err), destination.mem_addr },
//                         );
//                     };
//                 },
//             }

//             const source: SourceInfo = instruction_info.source_info;
//             switch (source) {
//                 .address => {
//                     log.info("{t}", .{source.address});
//                     OutputWriter.print(
//                         "{t}\n",
//                         .{source.address},
//                     ) catch |err| {
//                         log.err(
//                             "{s}: Something went wrong trying to write source {any} to the output file.",
//                             .{ @errorName(err), source.address },
//                         );
//                     };
//                 },
//                 .address_calculation => {
//                     const Address = AddressBook.RegisterNames;
//                     if (source.address_calculation.index == Address.none) {
//                         if (source.address_calculation.displacement == DisplacementFormat.none) {
//                             log.info("[{t}]", .{
//                                 source.address_calculation.base.?,
//                             });
//                             OutputWriter.print("[{t}]\n", .{
//                                 source.address_calculation.base.?,
//                             }) catch |err| {
//                                 log.err(
//                                     "{s}: Something went wrong trying to write source effective address calculation {any} to the output file.",
//                                     .{ @errorName(err), source.address_calculation },
//                                 );
//                             };
//                         } else if (source.address_calculation.displacement != DisplacementFormat.none and source.address_calculation.displacement_value.? == 0) {
//                             log.info("[{t}]", .{
//                                 source.address_calculation.base.?,
//                             });
//                             OutputWriter.print("[{t}]\n", .{
//                                 source.address_calculation.base.?,
//                             }) catch |err| {
//                                 log.err(
//                                     "{s}: Something went wrong trying to write source effective address calculation {any} to the output file.",
//                                     .{ @errorName(err), source.address_calculation },
//                                 );
//                             };
//                         } else if (source.address_calculation.displacement != DisplacementFormat.none) {
//                             const disp_u16: u16 = @intCast(source.address_calculation.displacement_value.?);
//                             const disp_signed: i16 = if (source.address_calculation.displacement == DisplacementFormat.d8) blk: {
//                                 const u8val: u8 = @intCast(disp_u16 & 0xFF);
//                                 const s8: i8 = @bitCast(u8val);
//                                 break :blk @as(i16, s8);
//                             } else blk: {
//                                 const s16: i16 = @bitCast(disp_u16);
//                                 break :blk s16;
//                             };
//                             if (disp_signed < 0) {
//                                 log.info("[{t} - {d}]", .{
//                                     source.address_calculation.base.?,
//                                     -disp_signed,
//                                 });
//                                 OutputWriter.print("[{t} - {d}]\n", .{
//                                     source.address_calculation.base.?,
//                                     -disp_signed,
//                                 }) catch |err| {
//                                     log.err(
//                                         "{s}: Something went wrong trying to write source effective address calculation {any} to the output file.",
//                                         .{ @errorName(err), source.address_calculation },
//                                     );
//                                 };
//                             } else {
//                                 log.info("[{t} + {d}]", .{
//                                     source.address_calculation.base.?,
//                                     disp_signed,
//                                 });
//                                 OutputWriter.print("[{t} + {d}]\n", .{
//                                     source.address_calculation.base.?,
//                                     disp_signed,
//                                 }) catch |err| {
//                                     log.err(
//                                         "{s}: Something went wrong trying to write source effective address calculation {any} to the output file.",
//                                         .{ @errorName(err), source.address_calculation },
//                                     );
//                                 };
//                             }
//                         }
//                     } else if (source.address_calculation.index != Address.none) {
//                         if (source.address_calculation.displacement == DisplacementFormat.none) {
//                             log.info("[{t} + {t}]", .{
//                                 source.address_calculation.base.?,
//                                 source.address_calculation.index.?,
//                             });
//                             OutputWriter.print("[{t} + {t}]\n", .{
//                                 source.address_calculation.base.?,
//                                 source.address_calculation.index.?,
//                             }) catch |err| {
//                                 log.err(
//                                     "{s}: Something went wrong trying to write source effective address calculation {any} to the output file.",
//                                     .{ @errorName(err), source.address_calculation },
//                                 );
//                             };
//                         } else if (source.address_calculation.displacement != DisplacementFormat.none) {
//                             const disp_u16: u16 = @intCast(source.address_calculation.displacement_value.?);
//                             const disp_signed: i16 = if (source.address_calculation.displacement == DisplacementFormat.d8) blk: {
//                                 const u8val: u8 = @intCast(disp_u16 & 0xFF);
//                                 const s8: i8 = @bitCast(u8val);
//                                 break :blk @as(i16, s8);
//                             } else blk: {
//                                 const s16: i16 = @bitCast(disp_u16);
//                                 break :blk s16;
//                             };
//                             if (disp_signed < 0) {
//                                 log.info("[{t} + {t} - {d}]", .{
//                                     source.address_calculation.base.?,
//                                     source.address_calculation.index.?,
//                                     -disp_signed,
//                                 });
//                                 OutputWriter.print("[{t} + {t} - {d}]\n", .{
//                                     source.address_calculation.base.?,
//                                     source.address_calculation.index.?,
//                                     -disp_signed,
//                                 }) catch |err| {
//                                     log.err(
//                                         "{s}: Something went wrong trying to write source effective address calculation {any} to the output file.",
//                                         .{ @errorName(err), source.address_calculation },
//                                     );
//                                 };
//                             } else {
//                                 log.info("[{t} + {t} + {d}]", .{
//                                     source.address_calculation.base.?,
//                                     source.address_calculation.index.?,
//                                     disp_signed,
//                                 });
//                                 OutputWriter.print("[{t} + {t} + {d}]\n", .{
//                                     source.address_calculation.base.?,
//                                     source.address_calculation.index.?,
//                                     disp_signed,
//                                 }) catch |err| {
//                                     log.err(
//                                         "{s}: Something went wrong trying to write source effective address calculation {any} to the output file.",
//                                         .{ @errorName(err), source.address_calculation },
//                                     );
//                                 };
//                             }
//                         }
//                     }
//                 },
//                 .immediate => {
//                     if (instruction == BinaryInstructions.mov_immediate_to_regmem8) {
//                         log.info("byte {d}", .{source.immediate});
//                         OutputWriter.print(
//                             "byte {d}\n",
//                             .{source.immediate},
//                         ) catch |err| {
//                             log.err(
//                                 "{s}: Something went wrong trying to write source index {any} to the output file.",
//                                 .{ @errorName(err), source.immediate },
//                             );
//                         };
//                     } else if (instruction == BinaryInstructions.mov_immediate_to_regmem16) {
//                         log.info("word {d}", .{source.immediate});
//                         OutputWriter.print(
//                             "word {d}\n",
//                             .{source.immediate},
//                         ) catch |err| {
//                             log.err(
//                                 "{s}: Something went wrong trying to write source index {any} to the output file.",
//                                 .{ @errorName(err), source.immediate },
//                             );
//                         };
//                     } else {
//                         log.info("{d}", .{source.immediate});
//                         OutputWriter.print(
//                             "{d}\n",
//                             .{source.immediate},
//                         ) catch |err| {
//                             log.err(
//                                 "{s}: Something went wrong trying to write source index {any} to the output file.",
//                                 .{ @errorName(err), source.immediate },
//                             );
//                         };
//                     }
//                 },
//                 .mem_addr => {
//                     log.info("[{d}]", .{source.mem_addr});
//                     OutputWriter.print(
//                         "[{d}]\n",
//                         .{source.mem_addr},
//                     ) catch |err| {
//                         log.err(
//                             "{s}: Something went wrong trying to write source index {any} to the output file.",
//                             .{ @errorName(err), source.mem_addr },
//                         );
//                     };
//                 },
//             }
//         },
//         .register_op => {
//             log.info("{s} ", .{instruction_data.mov_without_mod_instruction.mnemonic});
//             OutputWriter.print("{s} ", .{instruction_data.mov_without_mod_instruction.mnemonic}) catch |err| {
//                 return err;
//             };

//             const instruction: BinaryInstructions = instruction_data.mov_without_mod_instruction.opcode;
//             var instruction_info: InstructionInfo = undefined;
//             switch (instruction) {
//                 .mov_immediate_reg_al,
//                 .mov_immediate_reg_cl,
//                 .mov_immediate_reg_dl,
//                 .mov_immediate_reg_bl,
//                 .mov_immediate_reg_ah,
//                 .mov_immediate_reg_ch,
//                 .mov_immediate_reg_dh,
//                 .mov_immediate_reg_bh,
//                 .mov_immediate_reg_ax,
//                 .mov_immediate_reg_cx,
//                 .mov_immediate_reg_dx,
//                 .mov_immediate_reg_bx,
//                 .mov_immediate_reg_bp,
//                 .mov_immediate_reg_sp,
//                 .mov_immediate_reg_si,
//                 .mov_immediate_reg_di,
//                 => {
//                     instruction_info = BIU.getImmediateToRegMovDest(
//                         instruction_data.mov_without_mod_instruction.w,
//                         instruction_data.mov_without_mod_instruction.reg.?,
//                         instruction_data.mov_without_mod_instruction.data.?,
//                         if (instruction_data.mov_without_mod_instruction.w == WValue.word) instruction_data.mov_without_mod_instruction.w_data.? else null,
//                     );
//                 },
//                 .mov_mem8_acc8,
//                 .mov_mem16_acc16,
//                 => {
//                     instruction_info = BIU.getMemToAccMovSourceAndDest(
//                         instruction_data.mov_without_mod_instruction.w,
//                         instruction_data.mov_without_mod_instruction.addr_lo,
//                         instruction_data.mov_without_mod_instruction.addr_hi,
//                     );
//                 },
//                 .mov_acc8_mem8,
//                 .mov_acc16_mem16,
//                 => {
//                     instruction_info = BIU.getAccToMemMovSourceAndDest(
//                         instruction_data.mov_without_mod_instruction.w,
//                         instruction_data.mov_without_mod_instruction.addr_lo,
//                         instruction_data.mov_without_mod_instruction.addr_hi,
//                     );
//                 },
//                 else => {
//                     log.err("Error: Instruction 0x{x} not implemented yet", .{instruction});
//                 },
//             }

//             const destination = instruction_info.destination_info;
//             switch (destination) {
//                 .address => {
//                     log.info("{t},", .{destination.address});
//                     OutputWriter.print("{t}, ", .{
//                         destination.address,
//                     }) catch |err| {
//                         log.err(
//                             "{s}: Something went wrong trying to write destination register {t} to the output file.",
//                             .{ @errorName(err), destination.address },
//                         );
//                     };
//                 },
//                 .mem_addr => {
//                     log.info("[{d}],", .{destination.mem_addr});
//                     OutputWriter.print("[{d}], ", .{
//                         destination.mem_addr,
//                     }) catch |err| {
//                         log.err(
//                             "{s}: Something went wrong trying to write to memory address [{d}] to the output file.",
//                             .{ @errorName(err), destination.mem_addr },
//                         );
//                     };
//                 },
//                 else => {
//                     log.err("Error: Not a valid destination address.", .{});
//                 },
//             }

//             const source = instruction_info.source_info;
//             switch (source) {
//                 .address => {
//                     log.info("{t}", .{source.address});
//                     OutputWriter.print("{t}\n", .{
//                         source.address,
//                     }) catch |err| {
//                         log.err(
//                             "{s}: Something went wrong trying to write destination register {t} to the output file.",
//                             .{ @errorName(err), source.address },
//                         );
//                     };
//                 },
//                 .mem_addr => {
//                     log.info("[{d}],", .{source.mem_addr});
//                     OutputWriter.print("[{d}]\n", .{
//                         source.mem_addr,
//                     }) catch |err| {
//                         log.err(
//                             "{s}: Something went wrong trying to write to memory address [{d}] to the output file.",
//                             .{ @errorName(err), source.mem_addr },
//                         );
//                     };
//                 },
//                 .immediate => {
//                     const immediate_value: u16 = source.immediate;
//                     const signed_immediate: i16 = @bitCast(immediate_value);
//                     log.info("{d}", .{signed_immediate});
//                     OutputWriter.print("{d}\n", .{signed_immediate}) catch |err| {
//                         log.err(
//                             "{s}: Something went wrong trying to write immediate value {any} to the output file.",
//                             .{ @errorName(err), signed_immediate },
//                         );
//                     };
//                 },
//                 else => {
//                     log.err("Error: Not a valid destination address.", .{});
//                 },
//             }
//         },
//     }
// }

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
