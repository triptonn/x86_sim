// ========================================================================
//
// (C) Copyright 2025, Nicolas Selig, All Rights Reserved.
//
// This software is provided 'as-is', without any express or implied
// warranty. In no event will the authors be held liable for any damages
// arising from the use of this software.
//
// ========================================================================

const types = @import("../types.zig");
const RegValue = types.instruction_field_names.RegValue;
const WValue = types.instruction_field_names.WValue;

/// Identifiers of the Internal Communication Registers as well as
/// the General Registers of the Intel 8086 CPU plus an identifier for
/// a direct address following the instruction as a 16 bit displacement.
pub const Locations = struct {
    pub const Register = enum { cs, ds, es, ss, ip, ah, al, ax, bh, bl, bx, ch, cl, cx, dh, dl, dx, sp, bp, di, si, directaccess, none };
    pub fn addressFrom(reg: RegValue, w: ?WValue) Register {
        const w_value = w orelse WValue.byte;
        switch (reg) {
            .ALAX => {
                if (w_value == WValue.word) return Register.ax else return Register.al;
            },
            .BLBX => {
                if (w_value == WValue.word) return Register.bx else return Register.bl;
            },
            .CLCX => {
                if (w_value == WValue.word) return Register.cx else return Register.cl;
            },
            .DLDX => {
                if (w_value == WValue.word) return Register.dx else return Register.dl;
            },
            .AHSP => {
                if (w_value == WValue.word) return Register.sp else return Register.ah;
            },
            .BHDI => {
                if (w_value == WValue.word) return Register.di else return Register.bh;
            },
            .CHBP => {
                if (w_value == WValue.word) return Register.bp else return Register.ch;
            },
            .DHSI => {
                if (w_value == WValue.word) return Register.si else return Register.dh;
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

pub const EffectiveAddressCalculation = struct {
    base: ?Locations.Register,
    index: ?Locations.Register,
    displacement: ?DisplacementFormat,
    displacement_value: ?u16,
    effective_address: ?u20,
};

const DestinationInfoIdentifiers = enum {
    address,
    address_calculation,
    mem_addr,
};

pub const DestinationInfo = union(DestinationInfoIdentifiers) {
    address: Locations.Register,
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
    address: Locations.Register,
    address_calculation: EffectiveAddressCalculation,
    immediate: u16,
    mem_addr: u20,
};
