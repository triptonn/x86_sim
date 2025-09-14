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

const types = @import("types.zig");
const ModValue = types.instruction_field_names.ModValue;
const RegValue = types.instruction_field_names.RegValue;
const RmValue = types.instruction_field_names.RmValue;
const DValue = types.instruction_field_names.DValue;
const WValue = types.instruction_field_names.WValue;
const SValue = types.instruction_field_names.SValue;
const SrValue = types.instruction_field_names.SrValue;

const EffectiveAddressCalculation = types.data_types.EffectiveAddressCalculation;

const hw = @import("hardware.zig");
const ExecutionUnit = hw.ExecutionUnit;
const BusInterfaceUnit = hw.BusInterfaceUnit;

const decoder = @import("decoder.zig");
const BinaryInstructions = decoder.BinaryInstructions;
const InstructionData = decoder.InstructionData;

/// Identifiers of the Internal Communication execution_unit as well as
/// the General execution_unit of the Intel 8086 CPU plus an identifier for
/// a direct address following the instruction as a 16 bit displacement.
pub const AddressBook = struct {
    pub const RegisterNames = enum { cs, ds, es, ss, ip, ah, al, ax, bh, bl, bx, ch, cl, cx, dh, dl, dx, sp, bp, di, si, directaccess, none };

    pub fn addressFrom(reg: RegValue, w: ?WValue) RegisterNames {
        const w_value = w orelse WValue.byte;
        switch (reg) {
            .ALAX => {
                if (w_value == WValue.word) return RegisterNames.ax else return RegisterNames.al;
            },
            .BLBX => {
                if (w_value == WValue.word) return RegisterNames.bx else return RegisterNames.bl;
            },
            .CLCX => {
                if (w_value == WValue.word) return RegisterNames.cx else return RegisterNames.cl;
            },
            .DLDX => {
                if (w_value == WValue.word) return RegisterNames.dx else return RegisterNames.dl;
            },
            .AHSP => {
                if (w_value == WValue.word) return RegisterNames.sp else return RegisterNames.ah;
            },
            .BHDI => {
                if (w_value == WValue.word) return RegisterNames.di else return RegisterNames.bh;
            },
            .CHBP => {
                if (w_value == WValue.word) return RegisterNames.bp else return RegisterNames.ch;
            },
            .DHSI => {
                if (w_value == WValue.word) return RegisterNames.si else return RegisterNames.dh;
            },
        }
    }
};

/// Contains the destination as DestinationInfo and source as SourceInfo
/// objects to rebuild the ASM-86 instruction from.
pub const InstructionInfo = struct {
    destination_info: DestinationInfo,
    source_info: SourceInfo,
};

pub const DisplacementFormat = enum { d8, d16, none };

const DestinationInfoIdentifiers = enum {
    address,
    address_calculation,
    mem_addr,
};

pub const DestinationInfo = union(DestinationInfoIdentifiers) {
    address: AddressBook.RegisterNames,
    address_calculation: EffectiveAddressCalculation,
    mem_addr: u20,
};

const SourceInfoIdentifiers = enum {
    address,
    address_calculation,
    immediate,
    mem_addr,
};

pub const SourceInfo = union(SourceInfoIdentifiers) {
    address: AddressBook.RegisterNames,
    address_calculation: EffectiveAddressCalculation,
    immediate: u16,
    mem_addr: u20,
};

// TODO: DocString

pub fn getImmediateOpSourceAndDest(
    execution_unit: *ExecutionUnit,
    bus_interface_unit: *BusInterfaceUnit,
    instruction_data: InstructionData,
) InstructionInfo {
    const log = std.log.scoped(.getImmediateOpSourceAndDest);
    const Address = AddressBook.RegisterNames;
    var dest_info: DestinationInfo = undefined;
    var immediate_8: u8 = undefined;
    var immediate_16: u16 = undefined;
    var source_info: SourceInfo = undefined;
    var sign_extended_immediate: i16 = undefined;
    var signed_immediate: i16 = undefined;
    const instruction: BinaryInstructions = instruction_data.immediate_op_instruction.opcode;
    const mod: ModValue = instruction_data.immediate_op_instruction.mod;
    const rm: RmValue = instruction_data.immediate_op_instruction.rm;
    const w: WValue = instruction_data.immediate_op_instruction.w;
    switch (mod) {
        .memoryModeNoDisplacement => {
            if (rm != RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) {
                dest_info = DestinationInfo{
                    .address_calculation = bus_interface_unit.calculateEffectiveAddress(
                        execution_unit,
                        mod,
                        rm,
                        null,
                        null,
                    ),
                };
            } else {
                const disp_lo = @as(u16, instruction_data.immediate_op_instruction.disp_lo.?);
                const disp_hi = (@as(u16, instruction_data.immediate_op_instruction.disp_hi.?) << 8);
                dest_info = DestinationInfo{
                    .mem_addr = @as(u20, disp_hi + disp_lo),
                };
            }
        },
        .memoryMode8BitDisplacement => {
            dest_info = DestinationInfo{
                .address_calculation = bus_interface_unit.calculateEffectiveAddress(
                    execution_unit,
                    mod,
                    rm,
                    instruction_data.immediate_op_instruction.data_lo.?,
                    null,
                ),
            };
        },
        .memoryMode16BitDisplacement => {
            dest_info = DestinationInfo{
                .address_calculation = bus_interface_unit.calculateEffectiveAddress(
                    execution_unit,
                    mod,
                    rm,
                    instruction_data.immediate_op_instruction.disp_lo.?,
                    instruction_data.immediate_op_instruction.disp_hi.?,
                ),
            };
        },
        .registerModeNoDisplacement => {
            dest_info = DestinationInfo{
                .address = switch (rm) {
                    .ALAX_BXSI_BXSID8_BXSID16 => if (w == WValue.word) Address.ax else Address.al,
                    .CLCX_BXDI_BXDID8_BXDID16 => if (w == WValue.word) Address.cx else Address.cl,
                    .DLDX_BPSI_BPSID8_BPSID16 => if (w == WValue.word) Address.dx else Address.dl,
                    .BLBX_BPDI_BPDID8_BPDID16 => if (w == WValue.word) Address.bx else Address.bl,
                    .AHSP_SI_SID8_SID16 => if (w == WValue.word) Address.sp else Address.ah,
                    .CHBP_DI_DID8_DID16 => if (w == WValue.word) Address.bp else Address.ch,
                    .DHSI_DIRECTACCESS_BPD8_BPD16 => if (w == WValue.word) Address.si else Address.dh,
                    .BHDI_BX_BXD8_BXD16 => if (w == WValue.word) Address.di else Address.bh,
                },
            };
        },
    }

    switch (instruction) {
        .immediate8_to_regmem8 => {
            immediate_8 = instruction_data.immediate_op_instruction.data_8.?;
            source_info = SourceInfo{
                .immediate = @intCast(immediate_8),
            };
        },
        .immediate16_to_regmem16 => {
            immediate_16 = (@as(u16, instruction_data.immediate_op_instruction.data_hi.?) << 8) + instruction_data.immediate_op_instruction.data_lo.?;
            source_info = SourceInfo{
                .immediate = immediate_16,
            };
        },
        .s_immediate8_to_regmem8 => {
            sign_extended_immediate = @intCast(instruction_data.immediate_op_instruction.signed_data_8.?);
            source_info = SourceInfo{
                .immediate = @bitCast(sign_extended_immediate),
            };
        },
        .immediate8_to_regmem16 => {
            signed_immediate = instruction_data.immediate_op_instruction.data_sx.?;
            source_info = SourceInfo{
                .immediate = @bitCast(signed_immediate),
            };
        },
        else => {
            log.err("Not a valid opcode for this function: {t}", .{instruction});
        },
    }

    return InstructionInfo{
        .destination_info = dest_info,
        .source_info = source_info,
    };
}

pub fn getImmediateToRegMovDest(w: WValue, reg: RegValue, data: u8, w_data: ?u8) InstructionInfo {
    const Address = AddressBook.RegisterNames;
    var dest: Address = undefined;
    var immediate: u16 = undefined;
    if (w_data != null) {
        immediate = (@as(u16, w_data.?) << 8) + data;
    } else {
        immediate = @as(u16, data);
    }
    switch (w) {
        .byte => {
            switch (reg) {
                .ALAX => {
                    dest = Address.al;
                },
                .BLBX => {
                    dest = Address.bl;
                },
                .CLCX => {
                    dest = Address.cl;
                },
                .DLDX => {
                    dest = Address.dl;
                },
                .AHSP => {
                    dest = Address.ah;
                },
                .BHDI => {
                    dest = Address.bh;
                },
                .CHBP => {
                    dest = Address.ch;
                },
                .DHSI => {
                    dest = Address.dh;
                },
            }
        },
        .word => {
            switch (reg) {
                .ALAX => {
                    dest = Address.ax;
                },
                .BLBX => {
                    dest = Address.bx;
                },
                .CLCX => {
                    dest = Address.cx;
                },
                .DLDX => {
                    dest = Address.dx;
                },
                .AHSP => {
                    dest = Address.sp;
                },
                .BHDI => {
                    dest = Address.di;
                },
                .CHBP => {
                    dest = Address.bp;
                },
                .DHSI => {
                    dest = Address.si;
                },
            }
        },
    }
    const destination_payload = DestinationInfo{
        .address = dest,
    };
    const source_payload = SourceInfo{
        .immediate = immediate,
    };
    return InstructionInfo{
        .destination_info = destination_payload,
        .source_info = source_payload,
    };
}

pub fn getAddImmediateToAccumulatorDest(
    // execution_unit: *ExecutionUnit,
    w: WValue,
    data: u8,
    w_data: ?u8,
) InstructionInfo {
    const Address = AddressBook.RegisterNames;
    var dest: Address = undefined;
    var immediate_8: u8 = undefined;
    var immediate_16: u16 = undefined;
    if (w == WValue.byte) {
        dest = Address.al;
        immediate_8 = data;
        return InstructionInfo{
            .destination_info = DestinationInfo{
                .address = dest,
            },
            .source_info = SourceInfo{
                .immediate = @intCast(immediate_8),
            },
        };
    } else {
        dest = Address.ax;
        immediate_16 = (@as(u16, w_data.?) << 8) + @as(u16, data);
        return InstructionInfo{
            .destination_info = DestinationInfo{
                .address = dest,
            },
            .source_info = SourceInfo{
                .immediate = immediate_16,
            },
        };
    }
}

/// Given the fields decoded from the instruction bytes this function returns
/// the addresses of source and destination. These can be execution_unit or memory
/// addresses. The values are returned as InstructionInfo.
pub fn getRegMemToFromRegSourceAndDest(
    execution_unit: *ExecutionUnit,
    d: DValue,
    w: WValue,
    reg: RegValue,
    mod: ModValue,
    rm: RmValue,
    disp_lo: ?u8,
    disp_hi: ?u8,
) InstructionInfo {
    const Address = AddressBook.RegisterNames;
    var dest: Address = undefined;
    var source: Address = undefined;
    var source_mem_addr: u20 = undefined;
    var destination_mem_addr: u20 = undefined;
    var dest_address_calculation: EffectiveAddressCalculation = undefined;
    var source_address_calculation: EffectiveAddressCalculation = undefined;
    const regIsSource: bool = if (d == DValue.source) true else false;

    // Checking what the REG field encodes
    switch (w) {
        .byte => {
            switch (reg) {
                .ALAX => {
                    if (regIsSource) source = Address.al else dest = Address.al;
                },
                .CLCX => {
                    if (regIsSource) source = Address.cl else dest = Address.cl;
                },
                .DLDX => {
                    if (regIsSource) source = Address.dl else dest = Address.dl;
                },
                .BLBX => {
                    if (regIsSource) source = Address.bl else dest = Address.bl;
                },
                .AHSP => {
                    if (regIsSource) source = Address.ah else dest = Address.ah;
                },
                .CHBP => {
                    if (regIsSource) source = Address.ch else dest = Address.ch;
                },
                .DHSI => {
                    if (regIsSource) source = Address.dh else dest = Address.dh;
                },
                .BHDI => {
                    if (regIsSource) source = Address.bh else dest = Address.bh;
                },
            }
        },
        .word => {
            switch (reg) {
                .ALAX => {
                    if (regIsSource) source = Address.ax else dest = Address.ax;
                },
                .CLCX => {
                    if (regIsSource) source = Address.cx else dest = Address.cx;
                },
                .DLDX => {
                    if (regIsSource) source = Address.dx else dest = Address.dx;
                },
                .BLBX => {
                    if (regIsSource) source = Address.bx else dest = Address.bx;
                },
                .AHSP => {
                    if (regIsSource) source = Address.sp else dest = Address.sp;
                },
                .CHBP => {
                    if (regIsSource) source = Address.bp else dest = Address.bp;
                },
                .DHSI => {
                    if (regIsSource) source = Address.si else dest = Address.si;
                },
                .BHDI => {
                    if (regIsSource) source = Address.di else dest = Address.di;
                },
            }
        },
    }

    // Effective Address Calculation
    // Segment base: 0x1000, Index (offset): 0x0022,
    // 1. Cast u16 to u20 and shift segment base left by four bits:
    //      0x01000 << 4 = 0x10000
    // 2. Add index to shifted segment base value:
    //      0x10000 + 0x0022 = 0x10022 << Physical address
    // 3. The same could be achieved by this formula:
    //      Physical address = (Segment base * 16) + Index (offset)

    // Checking what the R/M field encodes
    switch (mod) {
        .memoryModeNoDisplacement => {
            switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    const bx_value: u16 = execution_unit.getBX(WValue.word, null).value16;
                    const si_value: u16 = execution_unit.getSI();
                    if (regIsSource) {
                        dest_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.si,
                            .displacement = DisplacementFormat.none,
                            .displacement_value = null,
                            .effective_address = (@as(u20, bx_value) << 4) + si_value,
                        };
                    } else if (!regIsSource) {
                        source_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.si,
                            .displacement = DisplacementFormat.none,
                            .displacement_value = null,
                            .effective_address = (@as(u20, bx_value) << 4) + si_value,
                        };
                    }
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    const bx_value: u16 = execution_unit.getBX(WValue.word, null).value16;
                    const di_value: u16 = execution_unit.getDI();
                    if (regIsSource) {
                        dest_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.di,
                            .displacement = DisplacementFormat.none,
                            .displacement_value = null,
                            .effective_address = (@as(u20, bx_value) << 4) + di_value,
                        };
                    } else if (!regIsSource) {
                        source_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.di,
                            .displacement = DisplacementFormat.none,
                            .displacement_value = null,
                            .effective_address = (@as(u20, bx_value) << 4) + di_value,
                        };
                    }
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    const bp_value = execution_unit.getBP();
                    const si_value = execution_unit.getSI();
                    if (regIsSource) {
                        dest_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.si,
                            .displacement = DisplacementFormat.none,
                            .displacement_value = null,
                            .effective_address = (@as(u20, bp_value) << 4) + si_value,
                        };
                    } else {
                        source_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.si,
                            .displacement = DisplacementFormat.none,
                            .displacement_value = null,
                            .effective_address = (@as(u20, bp_value) << 4) + si_value,
                        };
                    }
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    const bp_value = execution_unit.getBP();
                    const di_value: u16 = execution_unit.getDI();
                    if (regIsSource) {
                        dest_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.di,
                            .displacement = DisplacementFormat.none,
                            .displacement_value = null,
                            .effective_address = (@as(u20, bp_value) << 4) + di_value,
                        };
                    } else {
                        source_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.di,
                            .displacement = DisplacementFormat.none,
                            .displacement_value = null,
                            .effective_address = (@as(u20, bp_value) << 4) + di_value,
                        };
                    }
                },
                .AHSP_SI_SID8_SID16 => {
                    if (regIsSource) {
                        dest = Address.si;
                    } else if (!regIsSource) {
                        source = Address.si;
                    }
                },
                .CHBP_DI_DID8_DID16 => {
                    if (regIsSource) {
                        dest = Address.di;
                    } else if (!regIsSource) {
                        source = Address.di;
                    }
                },

                // TODO: What value should i pass along here? I think
                // it is an immediate value. Make sure!
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
                    if (regIsSource) {
                        destination_mem_addr = displacement;
                    } else if (!regIsSource) {
                        source_mem_addr = displacement;
                    }
                },
                .BHDI_BX_BXD8_BXD16 => {
                    if (regIsSource) {
                        dest = Address.bx;
                    } else if (!regIsSource) {
                        source = Address.bx;
                    }
                },
            }
        },
        .memoryMode8BitDisplacement => {
            switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    const bx_value: u16 = execution_unit.getBX(WValue.word, null).value16;
                    const effective_address_calculation: EffectiveAddressCalculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.si,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = @as(u16, disp_lo.?),
                        .effective_address = ((@as(u20, bx_value)) << 4) + execution_unit.getSI() + disp_lo.?,
                    };
                    if (regIsSource) {
                        dest_address_calculation = effective_address_calculation;
                    } else if (!regIsSource) {
                        source_address_calculation = effective_address_calculation;
                    }
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    const bx_value: u16 = execution_unit.getBX(WValue.word, null).value16;
                    const effective_address_calculation: EffectiveAddressCalculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.di,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = @as(u16, disp_lo.?),
                        .effective_address = ((@as(u20, bx_value)) << 4) + execution_unit.getDI() + disp_lo.?,
                    };
                    if (regIsSource) {
                        dest_address_calculation = effective_address_calculation;
                    } else {
                        source_address_calculation = effective_address_calculation;
                    }
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    const bp_value: u16 = execution_unit.getBP();
                    const effective_address_calculation: EffectiveAddressCalculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.si,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = @as(u16, disp_lo.?),
                        .effective_address = ((@as(u20, bp_value) << 4) + execution_unit.getSI() + disp_lo.?),
                    };
                    if (regIsSource) {
                        dest_address_calculation = effective_address_calculation;
                    } else {
                        source_address_calculation = effective_address_calculation;
                    }
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    const bp_value: u16 = execution_unit.getBP();
                    const effective_address_calculation: EffectiveAddressCalculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.di,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = @as(u16, disp_lo.?),
                        .effective_address = ((@as(u20, bp_value) << 4) + execution_unit.getDI() + disp_lo.?),
                    };
                    if (regIsSource) {
                        dest_address_calculation = effective_address_calculation;
                    } else {
                        source_address_calculation = effective_address_calculation;
                    }
                },
                .AHSP_SI_SID8_SID16 => {
                    const si_value: u16 = execution_unit.getSI();
                    const effective_address_calculation: EffectiveAddressCalculation = EffectiveAddressCalculation{
                        .base = Address.si,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = @as(u16, disp_lo.?),
                        .effective_address = ((@as(u20, si_value)) << 4) + disp_lo.?,
                    };
                    if (regIsSource) {
                        dest_address_calculation = effective_address_calculation;
                    } else {
                        source_address_calculation = effective_address_calculation;
                    }
                },
                .CHBP_DI_DID8_DID16 => {
                    const di_value: u16 = execution_unit.getDI();
                    const effective_address_calculation: EffectiveAddressCalculation = EffectiveAddressCalculation{
                        .base = Address.di,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = @as(u16, disp_lo.?),
                        .effective_address = ((@as(u20, di_value)) << 4) + disp_lo.?,
                    };
                    if (regIsSource) {
                        dest_address_calculation = effective_address_calculation;
                    } else {
                        source_address_calculation = effective_address_calculation;
                    }
                },
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    const bp_value: u16 = execution_unit.getBP();
                    const effective_address_calculation: EffectiveAddressCalculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = @as(u16, disp_lo.?),
                        .effective_address = ((@as(u20, bp_value) << 4) + disp_lo.?),
                    };
                    if (regIsSource) {
                        dest_address_calculation = effective_address_calculation;
                    } else {
                        source_address_calculation = effective_address_calculation;
                    }
                },
                .BHDI_BX_BXD8_BXD16 => {
                    const bx_value: u16 = execution_unit.getBX(WValue.word, null).value16;
                    const effective_address_calculation: EffectiveAddressCalculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = @as(u16, disp_lo.?),
                        .effective_address = ((@as(u20, bx_value) << 4) + disp_lo.?),
                    };
                    if (regIsSource) {
                        dest_address_calculation = effective_address_calculation;
                    } else {
                        source_address_calculation = effective_address_calculation;
                    }
                },
            }
        },
        .memoryMode16BitDisplacement => {
            switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    const bx_value: u16 = execution_unit.getBX(WValue.word, null).value16;
                    const si_value: u16 = execution_unit.getSI();
                    const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
                    if (regIsSource) {
                        dest_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.si,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bx_value) << 4) + si_value + displacement,
                        };
                    } else {
                        source_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.si,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bx_value) << 4) + si_value + displacement,
                        };
                    }
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    const bx_value: u16 = execution_unit.getBX(WValue.word, null).value16;
                    const di_value: u16 = execution_unit.getDI();
                    const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
                    if (regIsSource) {
                        dest_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.di,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bx_value) << 4) + di_value + displacement,
                        };
                    } else {
                        source_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.di,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bx_value) << 4) + di_value + displacement,
                        };
                    }
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    const bp_value: u16 = execution_unit.getBP();
                    const si_value: u16 = execution_unit.getSI();
                    const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
                    if (regIsSource) {
                        dest_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.si,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bp_value) << 4) + si_value + displacement,
                        };
                    } else {
                        source_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.si,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bp_value) << 4) + si_value + displacement,
                        };
                    }
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    const bp_value: u16 = execution_unit.getBP();
                    const di_value: u16 = execution_unit.getDI();
                    const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
                    if (regIsSource) {
                        dest_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.di,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bp_value) << 4) + di_value + displacement,
                        };
                    } else {
                        source_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.di,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bp_value) << 4) + di_value + displacement,
                        };
                    }
                },
                .AHSP_SI_SID8_SID16 => {
                    const si_value: u16 = execution_unit.getSI();
                    const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
                    if (regIsSource) {
                        dest_address_calculation = EffectiveAddressCalculation{
                            .base = Address.si,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, si_value) << 4) + displacement,
                        };
                    } else {
                        source_address_calculation = EffectiveAddressCalculation{
                            .base = Address.si,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, si_value) << 4) + displacement,
                        };
                    }
                },
                .CHBP_DI_DID8_DID16 => {
                    const di_value: u16 = execution_unit.getDI();
                    const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
                    if (regIsSource) {
                        dest_address_calculation = EffectiveAddressCalculation{
                            .base = Address.di,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, di_value) << 4) + displacement,
                        };
                    } else {
                        source_address_calculation = EffectiveAddressCalculation{
                            .base = Address.di,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, di_value) << 4) + displacement,
                        };
                    }
                },
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    const bp_value: u16 = execution_unit.getBP();
                    const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
                    if (regIsSource) {
                        dest_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bp_value) << 4) + displacement,
                        };
                    } else {
                        source_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bp_value) << 4) + displacement,
                        };
                    }
                },
                .BHDI_BX_BXD8_BXD16 => {
                    const bx_value: u16 = execution_unit.getBX(WValue.word, null).value16;
                    const displacement: u16 = (@as(u16, disp_hi.?) << 8) + @as(u16, disp_lo.?);
                    if (regIsSource) {
                        dest_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bx_value) << 4) + displacement,
                        };
                    } else {
                        source_address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bx_value) << 4) + displacement,
                        };
                    }
                },
            }
        },
        .registerModeNoDisplacement => {
            switch (w) {
                .byte => {
                    switch (rm) {
                        .ALAX_BXSI_BXSID8_BXSID16 => {
                            if (regIsSource) dest = Address.al else source = Address.al;
                        },
                        .CLCX_BXDI_BXDID8_BXDID16 => {
                            if (regIsSource) dest = Address.cl else source = Address.cl;
                        },
                        .DLDX_BPSI_BPSID8_BPSID16 => {
                            if (regIsSource) dest = Address.dl else source = Address.dl;
                        },
                        .BLBX_BPDI_BPDID8_BPDID16 => {
                            if (regIsSource) dest = Address.bl else source = Address.bl;
                        },
                        .AHSP_SI_SID8_SID16 => {
                            if (regIsSource) dest = Address.ah else source = Address.ah;
                        },
                        .CHBP_DI_DID8_DID16 => {
                            if (regIsSource) dest = Address.ch else source = Address.ch;
                        },
                        .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                            if (regIsSource) dest = Address.dh else source = Address.dh;
                        },
                        .BHDI_BX_BXD8_BXD16 => {
                            if (regIsSource) dest = Address.bh else source = Address.bh;
                        },
                    }
                },
                .word => {
                    switch (rm) {
                        .ALAX_BXSI_BXSID8_BXSID16 => {
                            if (regIsSource) dest = Address.ax else source = Address.ax;
                        },
                        .CLCX_BXDI_BXDID8_BXDID16 => {
                            if (regIsSource) dest = Address.cx else source = Address.cx;
                        },
                        .DLDX_BPSI_BPSID8_BPSID16 => {
                            if (regIsSource) dest = Address.dx else source = Address.dx;
                        },
                        .BLBX_BPDI_BPDID8_BPDID16 => {
                            if (regIsSource) dest = Address.bx else source = Address.bx;
                        },
                        .AHSP_SI_SID8_SID16 => {
                            if (regIsSource) dest = Address.sp else source = Address.sp;
                        },
                        .CHBP_DI_DID8_DID16 => {
                            if (regIsSource) dest = Address.bp else source = Address.bp;
                        },
                        .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                            if (regIsSource) dest = Address.si else source = Address.si;
                        },
                        .BHDI_BX_BXD8_BXD16 => {
                            if (regIsSource) dest = Address.di else source = Address.di;
                        },
                    }
                },
            }
        },
    }

    var destination_payload: DestinationInfo = undefined;
    if (mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) {
        destination_payload = DestinationInfo{
            .address = dest,
        };
    } else if (mod == ModValue.memoryModeNoDisplacement and rm != RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) {
        if (regIsSource) {
            switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16, .CLCX_BXDI_BXDID8_BXDID16, .DLDX_BPSI_BPSID8_BPSID16, .BLBX_BPDI_BPDID8_BPDID16 => {
                    destination_payload = DestinationInfo{
                        .address_calculation = dest_address_calculation,
                    };
                },
                .AHSP_SI_SID8_SID16, .CHBP_DI_DID8_DID16, .BHDI_BX_BXD8_BXD16 => {
                    destination_payload = DestinationInfo{
                        .address = dest,
                    };
                },
                else => {
                    std.debug.print("Error: Destination Address Calculation is messed up", .{});
                },
            }
        } else if (!regIsSource) {
            destination_payload = DestinationInfo{
                .address = dest,
            };
        }
    } else if (mod == ModValue.memoryMode8BitDisplacement or mod == ModValue.memoryMode16BitDisplacement) {
        if (regIsSource) {
            destination_payload = DestinationInfo{
                .address_calculation = dest_address_calculation,
            };
        } else if (!regIsSource) {
            destination_payload = DestinationInfo{
                .address = dest,
            };
        }
    } else if (mod == ModValue.registerModeNoDisplacement) {
        destination_payload = DestinationInfo{
            .address = dest,
        };
    }

    var source_payload: SourceInfo = undefined;
    if (mod == ModValue.memoryModeNoDisplacement and rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) {
        source_payload = SourceInfo{
            .mem_addr = source_mem_addr,
        };
    } else if (mod == ModValue.memoryModeNoDisplacement and rm != RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) {
        if (regIsSource) {
            source_payload = SourceInfo{
                .address = source,
            };
        } else if (!regIsSource) {
            switch (rm) {
                .AHSP_SI_SID8_SID16, .CHBP_DI_DID8_DID16, .BHDI_BX_BXD8_BXD16 => {
                    source_payload = SourceInfo{
                        .address = source,
                    };
                },
                .ALAX_BXSI_BXSID8_BXSID16, .CLCX_BXDI_BXDID8_BXDID16, .DLDX_BPSI_BPSID8_BPSID16, .BLBX_BPDI_BPDID8_BPDID16 => {
                    source_payload = SourceInfo{
                        .address_calculation = source_address_calculation,
                    };
                },
                else => {
                    std.debug.print("Error: Source Address Calculation is messed up", .{});
                },
            }
        }
    } else if (mod == ModValue.memoryMode8BitDisplacement or mod == ModValue.memoryMode16BitDisplacement) {
        if (regIsSource) {
            source_payload = SourceInfo{
                .address = source,
            };
        } else if (!regIsSource) {
            source_payload = SourceInfo{
                .address_calculation = source_address_calculation,
            };
        }
    } else if (mod == ModValue.registerModeNoDisplacement) {
        source_payload = SourceInfo{
            .address = source,
        };
    }

    return InstructionInfo{
        .destination_info = destination_payload,
        .source_info = source_payload,
    };
}

/// Get source and destination for Reg/Mem to segment register operations.
pub fn getRegMemToSegMovSourceAndDest(
    execution_unit: *ExecutionUnit,
    mod: ModValue,
    sr: SrValue,
    rm: RmValue,
    disp_lo: ?u8,
    disp_hi: ?u8,
) InstructionInfo {
    const Address = AddressBook.RegisterNames;
    var dest: Address = undefined;
    var source: Address = undefined;
    var source_address_calculation: EffectiveAddressCalculation = undefined;

    var destination_payload: DestinationInfo = undefined;
    var source_payload: SourceInfo = undefined;

    switch (mod) {
        .memoryModeNoDisplacement => {
            switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    const bx_value: u16 = execution_unit.getBX(WValue.word, null).value16;
                    const si_value: u16 = execution_unit.getSI();
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.si,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, bx_value) << 4) + si_value,
                    };
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    const bx_value: u16 = execution_unit.getBX(WValue.word, null).value16;
                    const di_value: u16 = execution_unit.getDI();
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.di,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, bx_value) << 4) + di_value,
                    };
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    const bp_value: u16 = execution_unit.getBP();
                    const si_value: u16 = execution_unit.getSI();
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.si,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, bp_value) << 4) + si_value,
                    };
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    const bp_value: u16 = execution_unit.getBP();
                    const di_value: u16 = execution_unit.getDI();
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.di,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, bp_value) << 4) + di_value,
                    };
                },
                .AHSP_SI_SID8_SID16 => {
                    const si_value: u16 = execution_unit.getSI();
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.si,
                        .index = Address.none,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, si_value) << 4),
                    };
                },
                .CHBP_DI_DID8_DID16 => {
                    const di_value: u16 = execution_unit.getDI();
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.di,
                        .index = Address.none,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, di_value) << 4),
                    };
                },
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    const displacement = (@as(u16, disp_hi.?) << 8) + disp_lo.?;
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.none,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, displacement),
                    };
                },
                .BHDI_BX_BXD8_BXD16 => {
                    const bx_value: u16 = execution_unit.getBX(WValue.word, null).value16;
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.none,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, bx_value) << 4),
                    };
                },
            }
        },
        .memoryMode8BitDisplacement => {
            switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    const bx_value = execution_unit.getBX(WValue.word, null).value16;
                    const si_value = execution_unit.getSI();
                    const displacement = @as(u16, disp_lo.?);
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.si,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, bx_value) + si_value + displacement,
                    };
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    const bx_value = execution_unit.getBX(WValue.word, null).value16;
                    const di_value = execution_unit.getDI();
                    const displacement = @as(u16, disp_lo.?);
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.di,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, bx_value) + di_value + displacement,
                    };
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    const bp_value = execution_unit.getBP();
                    const si_value = execution_unit.getSI();
                    const displacement = @as(u16, disp_lo.?);
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.si,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, bp_value) + si_value + displacement,
                    };
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    const bp_value = execution_unit.getBP();
                    const di_value = execution_unit.getDI();
                    const displacement = @as(u16, disp_lo.?);
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.di,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, bp_value) + di_value + displacement,
                    };
                },
                .AHSP_SI_SID8_SID16 => {
                    const si_value = execution_unit.getSI();
                    const displacement = @as(u16, disp_lo.?);
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.si,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, si_value) + displacement,
                    };
                },
                .CHBP_DI_DID8_DID16 => {
                    const di_value = execution_unit.getDI();
                    const displacement = @as(u16, disp_lo.?);
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.di,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, di_value) + displacement,
                    };
                },
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    const bp_value = execution_unit.getBP();
                    const displacement = @as(u16, disp_lo.?);
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, bp_value) + displacement,
                    };
                },
                .BHDI_BX_BXD8_BXD16 => {
                    const bx_value = execution_unit.getBX(WValue.word, null).value16;
                    const displacement = @as(u16, disp_lo.?);
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, bx_value) + displacement,
                    };
                },
            }
        },
        .memoryMode16BitDisplacement => {
            switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    const bx_value = execution_unit.getBX(WValue.word, null).value16;
                    const si_value = execution_unit.getSI();
                    const displacement = @as(u16, disp_hi.?) + disp_lo.?;
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.si,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = (@as(u20, bx_value) << 4) + si_value + displacement,
                    };
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    const bx_value = execution_unit.getBX(WValue.word, null).value16;
                    const di_value = execution_unit.getDI();
                    const displacement = @as(u16, disp_hi.?) + disp_lo.?;
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.di,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = (@as(u20, bx_value) << 4) + di_value + displacement,
                    };
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    const bp_value = execution_unit.getBP();
                    const si_value = execution_unit.getSI();
                    const displacement = @as(u16, disp_hi.?) + disp_lo.?;
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.si,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = (@as(u20, bp_value) << 4) + si_value + displacement,
                    };
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    const bp_value = execution_unit.getBP();
                    const di_value = execution_unit.getDI();
                    const displacement = @as(u16, disp_hi.?) + disp_lo.?;
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.di,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = (@as(u20, bp_value) << 4) + di_value + displacement,
                    };
                },
                .AHSP_SI_SID8_SID16 => {
                    const si_value = execution_unit.getSI();
                    const displacement = @as(u16, disp_hi.?) + disp_lo.?;
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.si,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, si_value) + displacement,
                    };
                },
                .CHBP_DI_DID8_DID16 => {
                    const di_value = execution_unit.getDI();
                    const displacement = @as(u16, disp_hi.?) + disp_lo.?;
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.di,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, di_value) + displacement,
                    };
                },
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    const bp_value = execution_unit.getBP();
                    const displacement = @as(u16, disp_hi.?) + disp_lo.?;
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.none,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, bp_value) + displacement,
                    };
                },
                .BHDI_BX_BXD8_BXD16 => {
                    const bx_value = execution_unit.getBX(WValue.word, null).value16;
                    const displacement = @as(u16, disp_hi.?) + disp_lo.?;
                    source_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = (@as(u20, bx_value) << 4) + displacement,
                    };
                },
            }
        },
        .registerModeNoDisplacement => {
            switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    source = Address.ax;
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    source = Address.cx;
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    source = Address.dx;
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    source = Address.bx;
                },
                .AHSP_SI_SID8_SID16 => {
                    source = Address.sp;
                },
                .CHBP_DI_DID8_DID16 => {
                    source = Address.bp;
                },
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    source = Address.si;
                },
                .BHDI_BX_BXD8_BXD16 => {
                    source = Address.di;
                },
            }
        },
    }

    if (mod == ModValue.registerModeNoDisplacement) {
        source_payload = SourceInfo{
            .address = source,
        };
    } else {
        source_payload = SourceInfo{ .address_calculation = source_address_calculation };
    }

    switch (sr) {
        .ES => {
            dest = Address.es;
        },
        .CS => {
            dest = Address.cs;
        },
        .SS => {
            dest = Address.ss;
        },
        .DS => {
            dest = Address.ds;
        },
    }

    destination_payload = DestinationInfo{
        .address = dest,
    };

    return InstructionInfo{
        .destination_info = destination_payload,
        .source_info = source_payload,
    };
}

/// Get source and destination for segment register to Reg/Mem operations.
pub fn getSegToRegMemMovSourceAndDest(
    execution_unit: *ExecutionUnit,
    mod: ModValue,
    sr: SrValue,
    rm: RmValue,
    disp_lo: ?u8,
    disp_hi: ?u8,
) InstructionInfo {
    const Address = AddressBook.RegisterNames;
    var dest: Address = undefined;
    var source: Address = undefined;
    var dest_address_calculation: EffectiveAddressCalculation = undefined;

    var destination_payload: DestinationInfo = undefined;
    var source_payload: SourceInfo = undefined;

    switch (sr) {
        .ES => {
            source = Address.es;
        },
        .CS => {
            source = Address.cs;
        },
        .SS => {
            source = Address.ss;
        },
        .DS => {
            source = Address.ds;
        },
    }

    source_payload = SourceInfo{
        .address = source,
    };

    switch (mod) {
        .memoryModeNoDisplacement => {
            switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    const bx_value: u16 = execution_unit.getBX(WValue.word, null).value16;
                    const si_value: u16 = execution_unit.getSI();
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.si,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, bx_value) << 4) + si_value,
                    };
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    const bx_value: u16 = execution_unit.getBX(WValue.word, null).value16;
                    const di_value: u16 = execution_unit.getDI();
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.di,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, bx_value) << 4) + di_value,
                    };
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    const bp_value: u16 = execution_unit.getBP();
                    const si_value: u16 = execution_unit.getSI();
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.si,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, bp_value) << 4) + si_value,
                    };
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    const bp_value: u16 = execution_unit.getBP();
                    const di_value: u16 = execution_unit.getDI();
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.di,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, bp_value) << 4) + di_value,
                    };
                },
                .AHSP_SI_SID8_SID16 => {
                    const si_value: u16 = execution_unit.getSI();
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.si,
                        .index = Address.none,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, si_value) << 4),
                    };
                },
                .CHBP_DI_DID8_DID16 => {
                    const di_value: u16 = execution_unit.getDI();
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.di,
                        .index = Address.none,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, di_value) << 4),
                    };
                },
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    const displacement = (@as(u16, disp_hi.?) << 8) + disp_lo.?;
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.none,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, displacement),
                    };
                },
                .BHDI_BX_BXD8_BXD16 => {
                    const bx_value: u16 = execution_unit.getBX(WValue.word, null).value16;
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.none,
                        .displacement = DisplacementFormat.none,
                        .displacement_value = null,
                        .effective_address = (@as(u20, bx_value) << 4),
                    };
                },
            }
        },
        .memoryMode8BitDisplacement => {
            switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    const bx_value = execution_unit.getBX(WValue.word, null).value16;
                    const si_value = execution_unit.getSI();
                    const displacement = @as(u16, disp_lo.?);
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.si,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, bx_value) + si_value + displacement,
                    };
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    const bx_value = execution_unit.getBX(WValue.word, null).value16;
                    const di_value = execution_unit.getDI();
                    const displacement = @as(u16, disp_lo.?);
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.di,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, bx_value) + di_value + displacement,
                    };
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    const bp_value = execution_unit.getBP();
                    const si_value = execution_unit.getSI();
                    const displacement = @as(u16, disp_lo.?);
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.si,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, bp_value) + si_value + displacement,
                    };
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    const bp_value = execution_unit.getBP();
                    const di_value = execution_unit.getDI();
                    const displacement = @as(u16, disp_lo.?);
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.di,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, bp_value) + di_value + displacement,
                    };
                },
                .AHSP_SI_SID8_SID16 => {
                    const si_value = execution_unit.getSI();
                    const displacement = @as(u16, disp_lo.?);
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.si,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, si_value) + displacement,
                    };
                },
                .CHBP_DI_DID8_DID16 => {
                    const di_value = execution_unit.getDI();
                    const displacement = @as(u16, disp_lo.?);
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.di,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, di_value) + displacement,
                    };
                },
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    const bp_value = execution_unit.getBP();
                    const displacement = @as(u16, disp_lo.?);
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, bp_value) + displacement,
                    };
                },
                .BHDI_BX_BXD8_BXD16 => {
                    const bx_value = execution_unit.getBX(WValue.word, null).value16;
                    const displacement = @as(u16, disp_lo.?);
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d8,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, bx_value) + displacement,
                    };
                },
            }
        },
        .memoryMode16BitDisplacement => {
            switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    const bx_value = execution_unit.getBX(WValue.word, null).value16;
                    const si_value = execution_unit.getSI();
                    const displacement = @as(u16, disp_hi.?) + disp_lo.?;
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.si,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = (@as(u20, bx_value) << 4) + si_value + displacement,
                    };
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    const bx_value = execution_unit.getBX(WValue.word, null).value16;
                    const di_value = execution_unit.getDI();
                    const displacement = @as(u16, disp_hi.?) + disp_lo.?;
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.di,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = (@as(u20, bx_value) << 4) + di_value + displacement,
                    };
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    const bp_value = execution_unit.getBP();
                    const si_value = execution_unit.getSI();
                    const displacement = @as(u16, disp_hi.?) + disp_lo.?;
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.si,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = (@as(u20, bp_value) << 4) + si_value + displacement,
                    };
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    const bp_value = execution_unit.getBP();
                    const di_value = execution_unit.getDI();
                    const displacement = @as(u16, disp_hi.?) + disp_lo.?;
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bp,
                        .index = Address.di,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = (@as(u20, bp_value) << 4) + di_value + displacement,
                    };
                },
                .AHSP_SI_SID8_SID16 => {
                    const si_value = execution_unit.getSI();
                    const displacement = @as(u16, disp_hi.?) + disp_lo.?;
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.si,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, si_value) + displacement,
                    };
                },
                .CHBP_DI_DID8_DID16 => {
                    const di_value = execution_unit.getDI();
                    const displacement = @as(u16, disp_hi.?) + disp_lo.?;
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.di,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, di_value) + displacement,
                    };
                },
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    const bp_value = execution_unit.getBP();
                    const displacement = @as(u16, disp_hi.?) + disp_lo.?;
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.none,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = @as(u20, bp_value) + displacement,
                    };
                },
                .BHDI_BX_BXD8_BXD16 => {
                    const bx_value = execution_unit.getBX(WValue.word, null).value16;
                    const displacement = @as(u16, disp_hi.?) + disp_lo.?;
                    dest_address_calculation = EffectiveAddressCalculation{
                        .base = Address.bx,
                        .index = Address.none,
                        .displacement = DisplacementFormat.d16,
                        .displacement_value = displacement,
                        .effective_address = (@as(u20, bx_value) << 4) + displacement,
                    };
                },
            }
        },
        .registerModeNoDisplacement => {
            switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    dest = Address.ax;
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    dest = Address.cx;
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    dest = Address.dx;
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    dest = Address.bx;
                },
                .AHSP_SI_SID8_SID16 => {
                    dest = Address.sp;
                },
                .CHBP_DI_DID8_DID16 => {
                    dest = Address.bp;
                },
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    dest = Address.si;
                },
                .BHDI_BX_BXD8_BXD16 => {
                    dest = Address.di;
                },
            }
        },
    }

    if (mod == ModValue.registerModeNoDisplacement) {
        destination_payload = DestinationInfo{
            .address = dest,
        };
    } else {
        destination_payload = DestinationInfo{ .address_calculation = dest_address_calculation };
    }

    return InstructionInfo{
        .destination_info = destination_payload,
        .source_info = source_payload,
    };
}

pub fn getMemToAccMovSourceAndDest(
    w: WValue,
    addr_lo: ?u8,
    addr_hi: ?u8,
) InstructionInfo {
    const Address = AddressBook.RegisterNames;
    var destination_payload: DestinationInfo = undefined;
    var source_payload: SourceInfo = undefined;
    switch (w) {
        .byte => {
            const addr = (@as(u16, addr_hi.?) << 8) + addr_lo.?;
            source_payload = SourceInfo{
                .mem_addr = @as(u20, addr),
            };
            destination_payload = DestinationInfo{
                .address = Address.al,
            };
        },
        .word => {
            const addr = (@as(u16, addr_hi.?) << 8) + addr_lo.?;
            source_payload = SourceInfo{
                .mem_addr = @as(u20, addr),
            };
            destination_payload = DestinationInfo{
                .address = Address.ax,
            };
        },
    }
    return InstructionInfo{
        .destination_info = destination_payload,
        .source_info = source_payload,
    };
}

pub fn getAccToMemMovSourceAndDest(
    w: WValue,
    addr_lo: ?u8,
    addr_hi: ?u8,
) InstructionInfo {
    const Address = AddressBook.RegisterNames;
    var destination_payload: DestinationInfo = undefined;
    var source_payload: SourceInfo = undefined;
    switch (w) {
        .byte => {
            const addr = (@as(u16, addr_hi.?) << 8) + addr_lo.?;
            destination_payload = DestinationInfo{
                .mem_addr = @as(u20, addr),
            };
            source_payload = SourceInfo{
                .address = Address.al,
            };
        },
        .word => {
            const addr = (@as(u16, addr_hi.?) << 8) + addr_lo.?;
            destination_payload = DestinationInfo{
                .mem_addr = @as(u20, addr),
            };
            source_payload = SourceInfo{
                .address = Address.ax,
            };
        },
    }

    return InstructionInfo{
        .destination_info = destination_payload,
        .source_info = source_payload,
    };
}

pub fn getImmediateToRegMemMovDest(
    execution_unit: *ExecutionUnit,
    mod: ModValue,
    rm: RmValue,
    w: WValue,
    disp_lo: ?u8,
    disp_hi: ?u8,
    data: u8,
    w_data: ?u8,
) InstructionInfo {
    const Address = AddressBook.RegisterNames;
    const source_payload: SourceInfo = SourceInfo{
        .immediate = @intCast(if (w == WValue.word) (@as(u16, w_data.?) << 8) + (@as(u16, data)) else @as(u16, data)),
    };

    var destination_payload: DestinationInfo = undefined;
    switch (mod) {
        .memoryModeNoDisplacement => {
            switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    const bx_value = execution_unit.getBX(WValue.word, null).value16;
                    const si_value = execution_unit.getSI();
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.si,
                            .displacement = DisplacementFormat.none,
                            .displacement_value = null,
                            .effective_address = (@as(u20, bx_value) << 4) + si_value,
                        },
                    };
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    const bx_value = execution_unit.getBX(WValue.word, null).value16;
                    const di_value = execution_unit.getDI();
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.di,
                            .displacement = DisplacementFormat.none,
                            .displacement_value = null,
                            .effective_address = (@as(u20, bx_value) << 4) + di_value,
                        },
                    };
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    const bp_value = execution_unit.getBP();
                    const si_value = execution_unit.getSI();
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.si,
                            .displacement = DisplacementFormat.none,
                            .displacement_value = null,
                            .effective_address = (@as(u20, bp_value) << 4) + si_value,
                        },
                    };
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    const bp_value = execution_unit.getBP();
                    const di_value = execution_unit.getDI();
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.di,
                            .displacement = DisplacementFormat.none,
                            .displacement_value = null,
                            .effective_address = (@as(u20, bp_value) << 4) + di_value,
                        },
                    };
                },
                .AHSP_SI_SID8_SID16 => {
                    const si_value = execution_unit.getSI();
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.si,
                            .index = Address.none,
                            .displacement = DisplacementFormat.none,
                            .displacement_value = null,
                            .effective_address = (@as(u20, si_value) << 4),
                        },
                    };
                },
                .CHBP_DI_DID8_DID16 => {
                    const di_value = execution_unit.getDI();
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.di,
                            .index = Address.none,
                            .displacement = DisplacementFormat.none,
                            .displacement_value = null,
                            .effective_address = (@as(u20, di_value) << 4),
                        },
                    };
                },
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    const displacement = (@as(u16, disp_hi.?) << 8) + disp_lo.?;
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.none,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = @as(u20, displacement),
                        },
                    };
                },
                .BHDI_BX_BXD8_BXD16 => {
                    const bx_value = execution_unit.getBX(WValue.word, null).value16;
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.none,
                            .displacement = DisplacementFormat.none,
                            .displacement_value = null,
                            .effective_address = (@as(u20, bx_value) << 4),
                        },
                    };
                },
            }
        },
        .memoryMode8BitDisplacement => {
            switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    const bx_value = execution_unit.getBX(WValue.word, null).value16;
                    const si_value = execution_unit.getSI();
                    const displacement = @as(u16, disp_lo.?);
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.si,
                            .displacement = DisplacementFormat.d8,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bx_value) << 4) + si_value + displacement,
                        },
                    };
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    const bx_value = execution_unit.getBX(WValue.word, null).value16;
                    const di_value = execution_unit.getDI();
                    const displacement = @as(u16, disp_lo.?);
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.di,
                            .displacement = DisplacementFormat.d8,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bx_value) << 4) + di_value + displacement,
                        },
                    };
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    const bp_value = execution_unit.getBP();
                    const si_value = execution_unit.getSI();
                    const displacement = @as(u16, disp_lo.?);
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.si,
                            .displacement = DisplacementFormat.d8,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bp_value) << 4) + si_value + displacement,
                        },
                    };
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    const bp_value = execution_unit.getBP();
                    const di_value = execution_unit.getDI();
                    const displacement = @as(u16, disp_lo.?);
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.di,
                            .displacement = DisplacementFormat.d8,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bp_value) << 4) + di_value + displacement,
                        },
                    };
                },
                .AHSP_SI_SID8_SID16 => {
                    const si_value = execution_unit.getSI();
                    const displacement = @as(u16, disp_lo.?);
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.si,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d8,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, si_value) << 4) + displacement,
                        },
                    };
                },
                .CHBP_DI_DID8_DID16 => {
                    const di_value = execution_unit.getDI();
                    const displacement = @as(u16, disp_lo.?);
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.di,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d8,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, di_value) << 4) + displacement,
                        },
                    };
                },
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    const bp_value = execution_unit.getBP();
                    const displacement = @as(u16, disp_lo.?);
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d8,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bp_value) << 4) + displacement,
                        },
                    };
                },
                .BHDI_BX_BXD8_BXD16 => {
                    const bx_value = execution_unit.getBX(WValue.word, null).value16;
                    const displacement = @as(u16, disp_lo.?);
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d8,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bx_value) << 4) + displacement,
                        },
                    };
                },
            }
        },
        .memoryMode16BitDisplacement => {
            switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    const bx_value = execution_unit.getBX(WValue.word, null).value16;
                    const si_value = execution_unit.getSI();
                    const displacement = (@as(u16, disp_hi.?) << 8) + disp_lo.?;
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.si,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bx_value) << 4) + si_value + displacement,
                        },
                    };
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    const bx_value = execution_unit.getBX(WValue.word, null).value16;
                    const di_value = execution_unit.getDI();
                    const displacement = (@as(u16, disp_hi.?) << 8) + disp_lo.?;
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.di,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bx_value) << 4) + di_value + displacement,
                        },
                    };
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    const bp_value = execution_unit.getBP();
                    const si_value = execution_unit.getSI();
                    const displacement = (@as(u16, disp_hi.?) << 8) + disp_lo.?;
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.si,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bp_value) << 4) + si_value + displacement,
                        },
                    };
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    const bp_value = execution_unit.getBP();
                    const di_value = execution_unit.getDI();
                    const displacement = (@as(u16, disp_hi.?) << 8) + disp_lo.?;
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.di,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bp_value) << 4) + di_value + displacement,
                        },
                    };
                },
                .AHSP_SI_SID8_SID16 => {
                    const si_value = execution_unit.getSI();
                    const displacement = (@as(u16, disp_hi.?) << 8) + disp_lo.?;
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.si,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, si_value) << 4) + displacement,
                        },
                    };
                },
                .CHBP_DI_DID8_DID16 => {
                    const di_value = execution_unit.getDI();
                    const displacement = (@as(u16, disp_hi.?) << 8) + disp_lo.?;
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.di,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, di_value) << 4) + displacement,
                        },
                    };
                },
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    const bp_value = execution_unit.getBP();
                    const displacement = (@as(u16, disp_hi.?) << 8) + disp_lo.?;
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bp,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bp_value) << 4) + displacement,
                        },
                    };
                },
                .BHDI_BX_BXD8_BXD16 => {
                    const bx_value = execution_unit.getBX(WValue.word, null).value16;
                    const displacement = (@as(u16, disp_hi.?) << 8) + disp_lo.?;
                    destination_payload = DestinationInfo{
                        .address_calculation = EffectiveAddressCalculation{
                            .base = Address.bx,
                            .index = Address.none,
                            .displacement = DisplacementFormat.d16,
                            .displacement_value = displacement,
                            .effective_address = (@as(u20, bx_value) << 4) + displacement,
                        },
                    };
                },
            }
        },
        .registerModeNoDisplacement => {
            switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => {
                    destination_payload = DestinationInfo{
                        .address = if (w == WValue.word) Address.ax else Address.al,
                    };
                },
                .CLCX_BXDI_BXDID8_BXDID16 => {
                    destination_payload = DestinationInfo{
                        .address = if (w == WValue.word) Address.cx else Address.cl,
                    };
                },
                .DLDX_BPSI_BPSID8_BPSID16 => {
                    destination_payload = DestinationInfo{
                        .address = if (w == WValue.word) Address.dx else Address.dl,
                    };
                },
                .BLBX_BPDI_BPDID8_BPDID16 => {
                    destination_payload = DestinationInfo{
                        .address = if (w == WValue.word) Address.bx else Address.bl,
                    };
                },
                .AHSP_SI_SID8_SID16 => {
                    destination_payload = DestinationInfo{
                        .address = if (w == WValue.word) Address.sp else Address.ah,
                    };
                },
                .CHBP_DI_DID8_DID16 => {
                    destination_payload = DestinationInfo{
                        .address = if (w == WValue.word) Address.bp else Address.ch,
                    };
                },
                .DHSI_DIRECTACCESS_BPD8_BPD16 => {
                    destination_payload = DestinationInfo{
                        .address = if (w == WValue.word) Address.si else Address.dh,
                    };
                },
                .BHDI_BX_BXD8_BXD16 => {
                    destination_payload = DestinationInfo{
                        .address = if (w == WValue.word) Address.di else Address.bh,
                    };
                },
            }
        },
    }

    return InstructionInfo{
        .destination_info = destination_payload,
        .source_info = source_payload,
    };
}
