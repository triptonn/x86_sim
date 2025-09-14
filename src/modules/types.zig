// ========================================================================
//
// (C) Copyright 2025, Nicolas Selig, All Rights Reserved.
//
// This software is provided 'as-is', without any express or implied
// warranty. In no event will the authors be held liable for any damages
// arising from the use of this software.
//
// ========================================================================

const locator = @import("locator.zig");
const AddressBook = locator.AddressBook;
const DisplacementFormat = locator.DisplacementFormat;

pub const instruction_field_names = struct {
    /// 0 for no sign extension, 1 for extending 8-bit immediate data to 16 bits if W = 1
    pub const SValue = enum(u1) { no_sign = 0b0, sign_extend = 0b1 };

    /// Defines if instructions operates on byte or word data
    pub const WValue = enum(u1) { byte = 0b0, word = 0b1 };

    /// If the Reg value holds the instruction source or destination
    pub const DValue = enum(u1) { source = 0b0, destination = 0b1 };

    /// Shift/Rotate count is either one or is specified in the CL register
    pub const VValue = enum(u1) { one = 0b0, in_CL = 0b1 };
    /// Repeat/Loop while zero flag is clear or set
    pub const ZValue = enum(u1) { clear = 0b0, set = 0b1 };

    /// (* .memoryModeNoDisplacement has 16 Bit displacement if
    /// R/M = 110)
    pub const ModValue = enum(u2) {
        memoryModeNoDisplacement = 0b00,
        memoryMode8BitDisplacement = 0b01,
        memoryMode16BitDisplacement = 0b10,
        registerModeNoDisplacement = 0b11,
    };

    /// Field names represent W = 0, W = 1, as in Reg 000 with w = 0 is AL,
    /// with w = 1 it's AX
    pub const RegValue = enum(u3) {
        ALAX = 0b000,
        CLCX = 0b001,
        DLDX = 0b010,
        BLBX = 0b011,
        AHSP = 0b100,
        CHBP = 0b101,
        DHSI = 0b110,
        BHDI = 0b111,
    };

    /// Segment Register values
    pub const SrValue = enum(u2) {
        ES = 0b00,
        CS = 0b01,
        SS = 0b10,
        DS = 0b11,
    };

    /// Field names encode all possible Register/Register or Register/Memory combinations.
    /// The combinations are in the naming starting with mod=11_mod=00_mod=01_mod=10. In the
    /// case of mod=11, register mode, the first two letters of the name are used if W=0,
    /// while the 3rd and 4th letter are valid if W=1.
    pub const RmValue = enum(u3) {
        ALAX_BXSI_BXSID8_BXSID16 = 0b000,
        CLCX_BXDI_BXDID8_BXDID16 = 0b001,
        DLDX_BPSI_BPSID8_BPSID16 = 0b010,
        BLBX_BPDI_BPDID8_BPDID16 = 0b011,
        AHSP_SI_SID8_SID16 = 0b100,
        CHBP_DI_DID8_DID16 = 0b101,
        DHSI_DIRECTACCESS_BPD8_BPD16 = 0b110,
        BHDI_BX_BXD8_BXD16 = 0b111,
    };
};

pub const data_types = struct {
    pub const EffectiveAddressCalculation = struct {
        base: ?AddressBook.RegisterNames,
        index: ?AddressBook.RegisterNames,
        displacement: ?DisplacementFormat,
        displacement_value: ?u16,
        effective_address: ?u20,
    };
};
