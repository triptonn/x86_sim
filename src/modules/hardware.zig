//! Enter Docstring

const std = @import("std");

const errors = @import("errors.zig");
const InstructionExecutionError = errors.InstructionExecutionError;

const MemoryError = errors.MemoryError;

const types = @import("types.zig");
const ModValue = types.instruction_fields.MOD;
const RmValue = types.instruction_fields.RM;
const RegValue = types.instruction_fields.REG;
const WValue = types.instruction_fields.Width;

const locator = @import("locator.zig");
const RegisterNames = locator.RegisterNames;

const EffectiveAddressCalculation = types.data_types.EffectiveAddressCalculation;
const DisplacementFormat = types.data_types.DisplacementFormat;

const decoder = @import("decoder.zig");
const InstructionData = decoder.InstructionData;

const GeneralRegisterPayload = union {
    value8: u8,
    value16: u16,
};

// Store base pointers to four segments at a time, these are the only segments
// that can be access at that point in time.
//
// |76543210 76543210|
// |--------x--------|
// |       CS        | CS - CODE SEGMENT  64kb  - Instructions are fetched from here
// |--------x--------|
// |       DS        | DS - DATA SEGMENT  64kb  - Containing mainly program variables
// |--------x--------|                     + => 128kb for data in total
// |       ES        | ES - EXTRA SEGMENT 64kb  - typically also used for data
// |--------x--------|
// |       SS        | SS - STACK SEGMENT 64kb  - Stack
// -------------------
//
// Physical address generation
// ---------------------------------------
//      0xA234 Segment base      |  Logical
//      0x0022 Offset            |  Address
// ---------------------------------------
// Bit shift left 4 bits segment base:
//     0xA2340
// Add offset
//   + 0x00022
//   = 0xA2362H <-- Physical address
//
//  76543210 76543210
// -------------------
// |       IP        | IP - INSTRUCTION POINTER - instructions are fetched from here
// -------------------
//
// 16 bit pointer containing the offset (distance in bytes) of the next instruction
// in the current code segment (CS). Saves and restores to / from the Stack.
//

/// Simulates the bus interface unit of the 8086 Processor, consisting of
/// the Segment Registers, the Instruction Pointer and the Instruction Queue.
/// It handles effective address generation and bus control.
pub const BusInterfaceUnit = struct {
    pub const InitValues = struct {
        _CS: u16,
        _DS: u16,
        _ES: u16,
        _SS: u16,
        _IP: u16,
    };

    // Internal Communication Registers
    _CS: u16, // Pointer to Code segment base
    _DS: u16, // Pointer to Data segment base
    _ES: u16, // Pointer to Extra segment base
    _SS: u16, // Pointer to Stack segment base
    _IP: u16, // Pointer to the next instruction to execute

    InstructionQueue: [6]u8,

    pub fn init(init_values: InitValues) BusInterfaceUnit {
        return BusInterfaceUnit{
            ._CS = init_values._CS,
            ._DS = init_values._DS,
            ._ES = init_values._ES,
            ._SS = init_values._SS,
            ._IP = init_values._IP,
            .InstructionQueue = [1]u8{0} ** 6,
        };
    }

    /// Set a byte of the instruction queue by passing an index (0 - 5) and the
    /// value.
    pub fn setIndex(self: *BusInterfaceUnit, index: u3, value: u8) void {
        if (index > 5 or index < 0) unreachable;
        self.InstructionQueue[index] = value;
    }

    /// Get a byte of the instruction queue by passing an index (0 - 5).
    pub fn getIndex(self: *BusInterfaceUnit, index: u3) u8 {
        if (index < 0 or index > 5) unreachable;
        return self.InstructionQueue[index];
    }

    // Internal Communication Register Methods
    pub fn setCS(self: *BusInterfaceUnit, value: u16) void {
        self._CS = value;
    }
    pub fn getCS(self: *BusInterfaceUnit) GeneralRegisterPayload {
        return GeneralRegisterPayload{ .value16 = self._CS };
    }
    pub fn setDS(self: *BusInterfaceUnit, value: u16) void {
        self._DS = value;
    }
    pub fn getDS(self: *BusInterfaceUnit) GeneralRegisterPayload {
        return GeneralRegisterPayload{ .value16 = self._DS };
    }
    pub fn setES(self: *BusInterfaceUnit, value: u16) void {
        self._ES = value;
    }
    pub fn getES(self: *BusInterfaceUnit) GeneralRegisterPayload {
        return GeneralRegisterPayload{ .value16 = self._ES };
    }
    pub fn setSS(self: *BusInterfaceUnit, value: u16) void {
        self._SS = value;
    }
    pub fn getSS(self: *BusInterfaceUnit) GeneralRegisterPayload {
        return GeneralRegisterPayload{ .value16 = self._SS };
    }
    pub fn setIP(self: *BusInterfaceUnit, value: u16) void {
        self._IP = value;
    }
    pub fn getIP(self: *BusInterfaceUnit) GeneralRegisterPayload {
        return GeneralRegisterPayload{ .value16 = self._IP };
    }

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
    // 110 | DH |  SI  | 110 | DIRECTADDRESS  | (BP) + D8        | (BP) + D16
    // 111 | BH |  DI  | 111 | (BX)           | (BX) + D8        | (BX) + D16
    //
    // Mod = 11 => Register name
    // Mod = 00 + Rm = 110 => ?
    // mod = 00 => ?
    // Mod = 01 || 10 => EffectiveAddressCalculation
    // DIRECTACCESS

    // Effective Address Calculation
    // Segment base: 0x1000, Index (offset): 0x0022,
    // 1. Cast u16 to u20 and shift segment base left by four bits:
    //      0x01000 << 4 = 0x10000
    // 2. Add index to shifted segment base value:
    //      0x10000 + 0x0022 = 0x10022 << Physical address
    // 3. The same could be achieved by this formula:
    //      Physical address = (Segment base * 16) + Index (offset)

    // TODO: DocString

    /// Calculates physical memory address from the necessary instructions fields.
    /// Returns a EffectiveAddressCalculation type.
    pub fn calculateEffectiveAddress(
        execution_unit: *ExecutionUnit,
        w: WValue,
        mod: ModValue,
        rm: RmValue,
        disp_lo: ?u8,
        disp_hi: ?u8,
    ) EffectiveAddressCalculation {
        const Address = RegisterNames;

        return EffectiveAddressCalculation{
            .base = base: switch (mod) {
                .memoryModeNoDisplacement => switch (rm) {
                    .ALAX_BXSI_BXSID8_BXSID16,
                    .CLCX_BXDI_BXDID8_BXDID16,
                    .BHDI_BX_BXD8_BXD16,
                    => break :base Address.bx,
                    .DLDX_BPSI_BPSID8_BPSID16,
                    .BLBX_BPDI_BPDID8_BPDID16,
                    => break :base Address.bp,
                    .AHSP_SI_SID8_SID16 => break :base Address.si,
                    .CHBP_DI_DID8_DID16 => break :base Address.di,
                    .DHSI_DIRECTACCESS_BPD8_BPD16 => break :base Address.none,
                },
                .memoryMode8BitDisplacement,
                .memoryMode16BitDisplacement,
                => switch (rm) {
                    .ALAX_BXSI_BXSID8_BXSID16,
                    .CLCX_BXDI_BXDID8_BXDID16,
                    => break :base Address.bx,
                    .DLDX_BPSI_BPSID8_BPSID16,
                    .BLBX_BPDI_BPDID8_BPDID16,
                    => break :base Address.bp,
                    .AHSP_SI_SID8_SID16 => break :base Address.si,
                    .CHBP_DI_DID8_DID16 => break :base Address.di,
                    .DHSI_DIRECTACCESS_BPD8_BPD16 => break :base Address.bp,
                    .BHDI_BX_BXD8_BXD16 => break :base Address.bx,
                },

                // zig fmt: off
                .registerModeNoDisplacement => switch (rm) {
                    .ALAX_BXSI_BXSID8_BXSID16     => break :base if (w == WValue.word) Address.ax else Address.al,
                    .CLCX_BXDI_BXDID8_BXDID16     => break :base if (w == WValue.word) Address.cx else Address.cl,
                    .DLDX_BPSI_BPSID8_BPSID16     => break :base if (w == WValue.word) Address.dx else Address.dl,
                    .BLBX_BPDI_BPDID8_BPDID16     => break :base if (w == WValue.word) Address.bx else Address.bl,
                    .AHSP_SI_SID8_SID16           => break :base if (w == WValue.word) Address.sp else Address.ah,
                    .CHBP_DI_DID8_DID16           => break :base if (w == WValue.word) Address.bp else Address.ch,
                    .DHSI_DIRECTACCESS_BPD8_BPD16 => break :base if (w == WValue.word) Address.si else Address.dh,
                    .BHDI_BX_BXD8_BXD16           => break :base if (w == WValue.word) Address.bx else Address.bh,
                },
                // zig fmt: on
            },
            .index = index: switch (mod) {
                .memoryModeNoDisplacement,
                .memoryMode8BitDisplacement,
                .memoryMode16BitDisplacement,
                => switch (rm) {
                    .ALAX_BXSI_BXSID8_BXSID16,
                    .DLDX_BPSI_BPSID8_BPSID16,
                    => break :index Address.si,
                    .CLCX_BXDI_BXDID8_BXDID16,
                    .BLBX_BPDI_BPDID8_BPDID16,
                    => break :index Address.di,
                    .AHSP_SI_SID8_SID16,
                    .CHBP_DI_DID8_DID16,
                    .BHDI_BX_BXD8_BXD16,
                    .DHSI_DIRECTACCESS_BPD8_BPD16,
                    => break :index Address.none,
                },
                .registerModeNoDisplacement => Address.none,
            },
            .displacement = switch (mod) {
                .memoryModeNoDisplacement => if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) DisplacementFormat.d16 else DisplacementFormat.none,
                .memoryMode8BitDisplacement => DisplacementFormat.d8,
                .memoryMode16BitDisplacement => DisplacementFormat.d16,
                .registerModeNoDisplacement => DisplacementFormat.none,
            },
            .displacement_value = switch (mod) {
                .memoryModeNoDisplacement => if (rm == RmValue.DHSI_DIRECTACCESS_BPD8_BPD16) (@as(u16, disp_hi.?) << 8) + disp_lo.? else null,
                .memoryMode8BitDisplacement => null,
                .memoryMode16BitDisplacement => null,
                .registerModeNoDisplacement => null,
            },
            .signed_displacement_value = switch (mod) {
                .memoryModeNoDisplacement => null,
                .memoryMode8BitDisplacement => @bitCast(@as(i16, disp_lo.?)),
                .memoryMode16BitDisplacement => @bitCast((@as(u16, disp_hi.?) << 8) + disp_lo.?),
                .registerModeNoDisplacement => null,
            },
            .effective_address = ea: switch (rm) {
                .ALAX_BXSI_BXSID8_BXSID16 => switch (mod) {
                    .memoryModeNoDisplacement => {
                        const bx_value = execution_unit.getBX(WValue.word, null).value16;
                        const si_value = execution_unit.getSI();
                        break :ea (@as(u20, bx_value) << 4) + @as(u20, si_value);
                    },
                    .memoryMode8BitDisplacement => {
                        const bx_value = execution_unit.getBX(WValue.word, null).value16;
                        const si_value = execution_unit.getSI();
                        const displacement = (@as(u16, disp_lo.?));
                        break :ea (@as(u20, bx_value) << 4) + @as(u20, si_value) + displacement;
                    },
                    .memoryMode16BitDisplacement => {
                        const bx_value = execution_unit.getBX(WValue.word, null).value16;
                        const si_value = execution_unit.getSI();
                        const displacement = (@as(u16, disp_hi.?) << 4) + (@as(u16, disp_lo.?));
                        break :ea (@as(u20, bx_value) << 4) + @as(u20, si_value) + displacement;
                    },
                    .registerModeNoDisplacement => {
                        break :ea null;
                    },
                },
                .CLCX_BXDI_BXDID8_BXDID16 => switch (mod) {
                    .memoryModeNoDisplacement => {
                        const bx_value = execution_unit.getBX(WValue.word, null).value16;
                        const di_value = execution_unit.getDI();
                        break :ea (@as(u20, bx_value) << 4) + @as(u20, di_value);
                    },
                    .memoryMode8BitDisplacement => {
                        const bx_value = execution_unit.getBX(WValue.word, null).value16;
                        const di_value = execution_unit.getDI();
                        const displacement = (@as(u16, disp_lo.?));
                        break :ea (@as(u20, bx_value) << 4) + @as(u20, di_value) + displacement;
                    },
                    .memoryMode16BitDisplacement => {
                        const bx_value = execution_unit.getBX(WValue.word, null).value16;
                        const di_value = execution_unit.getDI();
                        const displacement = (@as(u16, disp_hi.?) << 4) + (@as(u16, disp_lo.?));
                        break :ea (@as(u20, bx_value) << 4) + @as(u20, di_value) + displacement;
                    },
                    .registerModeNoDisplacement => {
                        break :ea null;
                    },
                },
                .DLDX_BPSI_BPSID8_BPSID16 => switch (mod) {
                    .memoryModeNoDisplacement => {
                        const bp_value = execution_unit.getBP();
                        const si_value = execution_unit.getSI();
                        break :ea (@as(u20, bp_value) << 4) + @as(u20, si_value);
                    },
                    .memoryMode8BitDisplacement => {
                        const bp_value = execution_unit.getBP();
                        const si_value = execution_unit.getSI();
                        const displacement = (@as(u16, disp_lo.?));
                        break :ea (@as(u20, bp_value) << 4) + @as(u20, si_value) + displacement;
                    },
                    .memoryMode16BitDisplacement => {
                        const bp_value = execution_unit.getBP();
                        const si_value = execution_unit.getSI();
                        const displacement = (@as(u16, disp_hi.?) << 4) + (@as(u16, disp_lo.?));
                        break :ea (@as(u20, bp_value) << 4) + @as(u20, si_value) + displacement;
                    },
                    .registerModeNoDisplacement => {
                        break :ea null;
                    },
                },
                .BLBX_BPDI_BPDID8_BPDID16 => switch (mod) {
                    .memoryModeNoDisplacement => {
                        const bp_value = execution_unit.getBP();
                        const di_value = execution_unit.getDI();
                        break :ea (@as(u20, bp_value) << 4) + @as(u20, di_value);
                    },
                    .memoryMode8BitDisplacement => {
                        const bp_value = execution_unit.getBP();
                        const di_value = execution_unit.getDI();
                        const displacement = (@as(u16, disp_lo.?));
                        break :ea (@as(u20, bp_value) << 4) + @as(u20, di_value) + displacement;
                    },
                    .memoryMode16BitDisplacement => {
                        const bp_value = execution_unit.getBP();
                        const di_value = execution_unit.getDI();
                        const displacement = (@as(u16, disp_hi.?) << 4) + (@as(u16, disp_lo.?));
                        break :ea (@as(u20, bp_value) << 4) + @as(u20, di_value) + displacement;
                    },
                    .registerModeNoDisplacement => {
                        break :ea null;
                    },
                },
                .AHSP_SI_SID8_SID16 => switch (mod) {
                    .memoryModeNoDisplacement => {
                        const si_value = execution_unit.getSI();
                        break :ea @as(u20, si_value) << 4;
                    },
                    .memoryMode8BitDisplacement => {
                        const si_value = execution_unit.getSI();
                        const displacement = (@as(u16, disp_lo.?));
                        break :ea (@as(u20, si_value) << 4) + displacement;
                    },
                    .memoryMode16BitDisplacement => {
                        const si_value = execution_unit.getSI();
                        const displacement = (@as(u16, disp_hi.?) << 4) + (@as(u16, disp_lo.?));
                        break :ea (@as(u20, si_value) << 4) + displacement;
                    },
                    .registerModeNoDisplacement => {
                        break :ea null;
                    },
                },
                .CHBP_DI_DID8_DID16 => switch (mod) {
                    .memoryModeNoDisplacement => {
                        const di_value = execution_unit.getDI();
                        break :ea @as(u20, di_value) << 4;
                    },
                    .memoryMode8BitDisplacement => {
                        const di_value = execution_unit.getDI();
                        const displacement = (@as(u16, disp_lo.?));
                        break :ea (@as(u20, di_value) << 4) + displacement;
                    },
                    .memoryMode16BitDisplacement => {
                        const di_value = execution_unit.getDI();
                        const displacement = (@as(u16, disp_hi.?) << 4) + (@as(u16, disp_lo.?));
                        break :ea (@as(u20, di_value) << 4) + displacement;
                    },
                    .registerModeNoDisplacement => {
                        break :ea null;
                    },
                },
                .DHSI_DIRECTACCESS_BPD8_BPD16 => switch (mod) {
                    .memoryModeNoDisplacement => {
                        const displacement = (@as(u16, disp_hi.?) << 8) + (@as(u16, disp_lo.?));
                        break :ea @as(u20, displacement);
                    },
                    .memoryMode8BitDisplacement => {
                        const bp_value = execution_unit.getBP();
                        const displacement = (@as(u16, disp_lo.?));
                        break :ea (@as(u20, bp_value) << 4) + displacement;
                    },
                    .memoryMode16BitDisplacement => {
                        const bp_value = execution_unit.getBP();
                        const displacement = (@as(u16, disp_hi.?) << 8) + (@as(u16, disp_lo.?));
                        break :ea (@as(u20, bp_value) << 4) + displacement;
                    },
                    .registerModeNoDisplacement => {
                        break :ea null;
                    },
                },
                .BHDI_BX_BXD8_BXD16 => switch (mod) {
                    .memoryModeNoDisplacement => {
                        const bx_value = execution_unit.getBX(WValue.word, null).value16;
                        break :ea @as(u20, bx_value) << 4;
                    },
                    .memoryMode8BitDisplacement => {
                        const bx_value = execution_unit.getBX(WValue.word, null).value16;
                        const displacement = (@as(u16, disp_lo.?));
                        break :ea (@as(u20, bx_value) << 4) + displacement;
                    },
                    .memoryMode16BitDisplacement => {
                        const bx_value = execution_unit.getBX(WValue.word, null).value16;
                        const displacement = (@as(u16, disp_hi.?) << 8) + (@as(u16, disp_lo.?));
                        break :ea (@as(u20, bx_value) << 4) + displacement;
                    },
                    .registerModeNoDisplacement => {
                        break :ea null;
                    },
                },
            },
        };
    }
};

// 8086 Memory
// Total Memory: 1,048,576 bytes            | physical addresses range from 0x0H to 0xFFFFFH <-- 'H' signifying a physical address
// Segment: up to   65.536 bytes            | logical addresses consist of segment base + offset value
// A, B, C, D, E, F, G, H, I, J             |   -> for any given memory address the segment base value
// und K                                    |      locates the first byte of the containing segment and
//                                          |      the offset is the distance in bytes of the target
//                                          |      location from the beginning of the segment.
//                                          |      segment base and offset are u16

pub const MemoryPayload = union {
    err: MemoryError,
    value8: u8,
    value16: u16,
};

/// Simulates the memory of the 8086 Processor
pub const Memory = struct {
    _memory: [0xFFFFF]u1 = undefined,

    // byte     0x0 -    0x13 = dedicated
    // byte    0x14 -    0x7F = reserved
    // byte    0x80 - 0xFFFEF = open
    // byte 0xFFFF0 - 0xFFFFB = dedicated
    // byte 0xFFFFC - 0xFFFFF = reserved

    /// Taking a already allocated piece of memory sized 1024 kb this
    /// constructor returns a Memory instance.
    pub fn init(allocated_memory: *[0xFFFFF]u1) Memory {
        return Memory{
            ._memory = allocated_memory.*,
        };
    }

    pub fn setDirectAddress(
        self: *Memory,
        addr: u16!u8,
        value: u16,
        w: WValue,
    ) MemoryError!void {
        if (addr <= 0x7F or addr >= 0xFFFF0) {
            return MemoryError.OutOfBoundError;
        }
        if (@TypeOf(value) == u16) {
            self._memory[addr] = value[0..8];
            self._memory[addr + 1] = value[8..];
        } else if (@TypeOf(value) == u8) {
            if (w == WValue.byte) {
                self._memory[addr] = value;
            } else {
                self._memory[addr] = value;
                self._memory[addr + 1] = value >> 8;
            }
        } else {
            return MemoryError.ValueError;
        }
    }

    /// Read 8 or 16 bit of memory starting at the 16 bit memory address
    /// passed as a parameter.
    pub fn getDirectAddress(self: *Memory, addr: u16, w: WValue) MemoryPayload {
        if (0 <= addr and addr < 0xFFF) {
            if (w == WValue.byte) {
                const payload = MemoryPayload{
                    .value8 = self._memory[addr],
                };
                return payload;
            } else {
                const payload = MemoryPayload{
                    .value16 = self._memory[addr] ++ self._memory[addr + 1],
                };
                return payload;
            }
        } else {
            const payload = MemoryPayload{
                .err = MemoryError.OutOfBoundError,
            };
            return payload;
        }
    }
};

// Status Flags:
//
// AF - Auxiliary Carry flag
// CF - Carry flag
// OF - Overflow flag
// SF - Sign flag
// PF - Parity flag
// ZF - Zero flag
//
// Control Flags:
//
// DF - Direction flag
// IF - Interrupt-enable flag
// TF - Trap flag
//
// 8086 General Register
//
// |76543210 76543210|
// |--------|--------|                          AX - Word multiply, word divide, word i/o
// |   AH   |   AL   | AX - ACCUMULATOR         AL - Byte multiply, byte divide, byte i/o, translate, decimal arithmatic
// |--------|--------|                          AH - Byte multiply, byte divide
// |   BH   |   BL   | BX - BASE                BX - Translate
// |--------|--------|
// |   CH   |   CL   | CX - COUNT               CX - String operations, loops
// |--------|--------|                          CL - Variable shift and rotate
// |   DH   |   DL   | DX - DATA                DX - Word multiply, word divide, indirect i/o
// |--------|--------|
// |        SP       | SP - STACK POINTER       SP - Stack operations
// |--------X--------|
// |        BP       | BP - BASE POINTER
// |--------X--------|
// |        SI       | SI - SOURCE INDEX        SI - String operations
// |--------X--------|
// |        DI       | DI - DESTINATION INDEX   DI - String operations
// |--------X--------|
// |76543210 76543210|

/// Simulates the EU of the 8086 processor. It consists of the
/// General Registers, Opareands, the Arithmetic/Logic Unit and the Control Flags.
/// It executes decoded x86 instructions.
pub const ExecutionUnit = struct {
    pub const InitValues = struct {
        _AF: bool,
        _CF: bool,
        _OF: bool,
        _SF: bool,
        _PF: bool,
        _ZF: bool,
        _DF: bool,
        _IF: bool,
        _TF: bool,
        _AX: u16,
        _BX: u16,
        _CX: u16,
        _DX: u16,
        _SP: u16,
        _BP: u16,
        _SI: u16,
        _DI: u16,
    };

    _initialized: bool = false,

    ////////////////////////////////////////////////////////////////////////////
    // Status Flags
    ////////////////////////////////////////////////////////////////////////////

    /// Auxiliary Carry flag
    _AF: bool,
    /// Carry flag
    _CF: bool,
    /// Overflow flag
    _OF: bool,
    /// Sign flag
    _SF: bool,
    /// Parity flag
    _PF: bool,
    /// Zero flag
    _ZF: bool,

    ////////////////////////////////////////////////////////////////////////////
    // Control Flags
    ////////////////////////////////////////////////////////////////////////////

    /// Direction flag
    _DF: bool,
    /// Interrupt-enable flag
    _IF: bool,
    /// Trap flag
    _TF: bool,

    ////////////////////////////////////////////////////////////////////////////
    // General Registers
    ////////////////////////////////////////////////////////////////////////////

    /// Accumulator
    _AX: u16,
    /// Base
    _BX: u16,
    /// Count
    _CX: u16,
    /// Data
    _DX: u16,
    /// Stack Pointer
    _SP: u16,
    /// Base Pointer
    _BP: u16,
    /// Source Index (Offset)
    _DI: u16,
    /// Destination Index (Offset)
    _SI: u16,

    pub fn init(
        init_values: InitValues,
    ) ExecutionUnit {
        return .{
            ._initialized = true,
            ._AF = init_values._AF,
            ._CF = init_values._CF,
            ._OF = init_values._OF,
            ._SF = init_values._SF,
            ._PF = init_values._PF,
            ._ZF = init_values._ZF,
            ._DF = init_values._DF,
            ._IF = init_values._IF,
            ._TF = init_values._TF,
            ._AX = init_values._AX,
            ._BX = init_values._BX,
            ._CX = init_values._CX,
            ._DX = init_values._DX,
            ._SP = init_values._SP,
            ._BP = init_values._BP,
            ._SI = init_values._SI,
            ._DI = init_values._DI,
        };
    }

    pub fn getReg16FromRegValue(
        self: *ExecutionUnit,
        reg: RegValue,
    ) GeneralRegisterPayload {
        switch (reg) {
            .ALAX => {
                return GeneralRegisterPayload{
                    .value16 = self._AX,
                };
            },
            .BLBX => {
                return GeneralRegisterPayload{
                    .value16 = self._BX,
                };
            },
            .CLCX => {
                return GeneralRegisterPayload{
                    .value16 = self._CX,
                };
            },
            .DLDX => {
                return GeneralRegisterPayload{
                    .value16 = self._DX,
                };
            },
            .AHSP => {
                return GeneralRegisterPayload{
                    .value16 = self._SP,
                };
            },
            .BHDI => {
                return GeneralRegisterPayload{
                    .value16 = self._DI,
                };
            },
            .CHBP => {
                return GeneralRegisterPayload{
                    .value16 = self._BP,
                };
            },
            .DHSI => {
                return GeneralRegisterPayload{
                    .value16 = self._SI,
                };
            },
        }
    }

    pub fn next(
        instruction_data: InstructionData,
    ) InstructionExecutionError!void {
        const log = std.log.scoped(.executeInstruction);
        defer log.info("{t} has been executed", .{instruction_data});

        switch (instruction_data) {
            InstructionData.accumulator_op,
            InstructionData.escape_op,
            InstructionData.register_memory_to_from_register_op,
            InstructionData.register_memory_op,
            InstructionData.immediate_to_register_op,
            InstructionData.immediate_op,
            InstructionData.segment_register_op,
            InstructionData.identifier_add_op,
            InstructionData.identifier_rol_op,
            InstructionData.identifier_test_op,
            InstructionData.identifier_inc_op,
            InstructionData.direct_op,
            InstructionData.single_byte_op,
            => {
                log.info("Instruction execution not yet implemented.");
            },
            else => return InstructionExecutionError.InvalidInstruction,
        }
    }

    // Status Flag methods
    pub fn setAF(self: *ExecutionUnit, state: bool) void {
        self._AF = state;
    }

    pub fn getAF(self: *ExecutionUnit) bool {
        return self._AF;
    }

    pub fn setCF(self: *ExecutionUnit, state: bool) void {
        self._CF = state;
    }

    pub fn getCF(self: *ExecutionUnit) bool {
        return self._CF;
    }

    pub fn setOF(self: *ExecutionUnit, state: bool) void {
        self._OF = state;
    }

    pub fn getOF(self: *ExecutionUnit) bool {
        return self._OF;
    }

    pub fn setSF(self: *ExecutionUnit, state: bool) void {
        self._SF = state;
    }

    pub fn getSF(self: *ExecutionUnit) bool {
        return self._SF;
    }

    pub fn setPF(self: *ExecutionUnit, state: bool) void {
        self._PF = state;
    }

    pub fn getPF(self: *ExecutionUnit) bool {
        return self._PF;
    }

    pub fn setZF(self: *ExecutionUnit, state: bool) void {
        self._ZF = state;
    }

    pub fn getZF(self: *ExecutionUnit) bool {
        return self._ZF;
    }

    // Control Flag methods
    pub fn setDF(self: *ExecutionUnit, state: bool) void {
        self._DF = state;
    }

    pub fn getDF(self: *ExecutionUnit) bool {
        return self._DF;
    }

    pub fn setIF(self: *ExecutionUnit, state: bool) void {
        self._IF = state;
    }

    pub fn getIF(self: *ExecutionUnit) bool {
        return self._IF;
    }

    pub fn setTF(self: *ExecutionUnit, state: bool) void {
        self._TF = state;
    }

    pub fn getTF(self: *ExecutionUnit) bool {
        return self._TF;
    }

    // General Register methods
    pub fn setAH(self: *ExecutionUnit, value: u8) void {
        self._AX = value ++ self._AX[0..8];
    }

    pub fn setAL(self: *ExecutionUnit, value: u8) void {
        self._AX = self._AX[8..] ++ value;
    }

    pub fn setAX(self: *ExecutionUnit, value: u16) void {
        self._AX = value;
    }

    pub fn getAX(self: *ExecutionUnit, w: WValue, hilo: []const u8) GeneralRegisterPayload {
        if (w == WValue.byte) {
            if (std.mem.eql([]const u8, hilo, "hi")) {
                return self._AX[0..8];
            } else {
                return self._AX[8..];
            }
        } else {
            return self._AX;
        }
    }

    pub fn setBH(self: *ExecutionUnit, value: u8) void {
        self._BX = value ++ self._BX[0..8];
    }

    pub fn setBL(self: *ExecutionUnit, value: u8) void {
        self._BX = self._BX[8..] ++ value;
    }

    pub fn setBX(self: *ExecutionUnit, value: u16) void {
        self._BX = value;
    }

    /// Returns value of BH, BL or BX depending on w and hilo. If
    /// w = byte, hilo can be set to "hi" or "lo". If w = word hilo
    /// should be set to "hilo"
    pub fn getBX(self: *ExecutionUnit, w: WValue, hilo: ?[]const u8) GeneralRegisterPayload {
        if (w == WValue.byte) {
            if (std.mem.eql(u8, hilo.?, "hi")) {
                return GeneralRegisterPayload{ .value8 = @intCast(self._BX >> 8) };
            } else {
                self._BX = self._BX << 8;
                return GeneralRegisterPayload{ .value8 = @intCast(self._BX >> 8) };
            }
        } else {
            return GeneralRegisterPayload{ .value16 = self._BX };
        }
    }

    pub fn setCH(self: *ExecutionUnit, value: u8) void {
        self._CX = value ++ self._CX[0..8];
    }

    pub fn setCL(self: *ExecutionUnit, value: u8) void {
        self._CX = self._CX[8..] ++ value;
    }

    pub fn setCX(self: *ExecutionUnit, value: u16) void {
        self._CX = value;
    }

    pub fn getCX(self: *ExecutionUnit, w: WValue, hilo: []const u8) GeneralRegisterPayload {
        if (w == WValue.byte) {
            if (std.mem.eql([]const u8, hilo, "hi")) {
                return self._CX[0..8];
            } else {
                return self._CX[8..];
            }
        } else {
            return self._CX;
        }
    }

    pub fn setDH(self: *ExecutionUnit, value: u8) void {
        self._DX = value ++ self._DX[0..8];
    }

    pub fn setDL(self: *ExecutionUnit, value: u8) void {
        self._DX = self._DX[8..] ++ value;
    }

    pub fn setDX(self: *ExecutionUnit, value: u16) void {
        self._DX = value;
    }

    pub fn getDX(self: *ExecutionUnit, w: WValue, hilo: []const u8) GeneralRegisterPayload {
        if (w == WValue.byte) {
            if (std.mem.eql([]const u8, hilo, "hi")) {
                return self._DX[0..8];
            } else {
                return self._DX[8..];
            }
        } else {
            return self._DX;
        }
    }

    pub fn setSP(self: *ExecutionUnit, value: u16) void {
        self._SP = value;
    }

    pub fn getSP(self: *ExecutionUnit) u16 {
        return self._SP;
    }

    pub fn setBP(self: *ExecutionUnit, value: u16) void {
        self._BP = value;
    }

    pub fn getBP(self: *ExecutionUnit) u16 {
        return self._BP;
    }

    pub fn setSI(self: *ExecutionUnit, value: u16) void {
        self._SI = value;
    }

    pub fn getSI(self: *ExecutionUnit) u16 {
        return self._SI;
    }

    pub fn setDI(self: *ExecutionUnit, value: u16) void {
        self._DI = value;
    }

    pub fn getDI(self: *ExecutionUnit) u16 {
        return self._DI;
    }
};

test "BusInterfaceUnit - calculateEffectiveAddress" {
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

    const Address = locator.RegisterNames;
    try std.testing.expectEqual(
        EffectiveAddressCalculation{
            .base = Address.none,
            .index = Address.none,
            .displacement = DisplacementFormat.d16,
            .displacement_value = (@as(u16, 0b00001101) << 8) + 0b10000010,
            .effective_address = @as(u20, (@as(u16, 0b00001101) << 8) + 0b10000010),
        },
        BusInterfaceUnit.calculateEffectiveAddress(
            &EU,
            WValue.word,
            ModValue.memoryModeNoDisplacement,
            RmValue.DHSI_DIRECTACCESS_BPD8_BPD16,
            0b10000010,
            0b00001101,
        ),
    );
}

// ========================================================================
//
// (C) Copyright 2025, Nicolas Selig, All Rights Reserved.
//
// This software is provided 'as-is', without any express or implied
// warranty. In no event will the authors be held liable for any damages
// arising from the use of this software.
//
// ========================================================================
