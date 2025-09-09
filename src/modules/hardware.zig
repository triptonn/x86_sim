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

const types = @import("../types.zig");
const RegValue = types.instruction_field_names.RegValue;
const WValue = types.instruction_field_names.WValue;

/// Simulates the bus interface unit of the 8086 Processor, mainly the
/// instruction queue.
pub const BusInterfaceUnit = struct {
    InstructionQueue: [6]u8 = [1]u8{0} ** 6,

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
};

const RegisterPayload = union {
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
// AF - Auxiliary Carry flag
// CF - Carry flag
// OF - Overflow flag
// SF - Sign flag
// PF - Parity flag
// ZF - Zero flag
//
// Additional flags
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

/// Simulates the Internal Communication and General Registers of the
/// Intel 8086 Processor.
pub const Register = struct {
    // Internal Communication Registers
    _CS: u16, // Pointer to Code segment base
    _DS: u16, // Pointer to Data segment base
    _ES: u16, // Pointer to Extra segment base
    _SS: u16, // Pointer to Stack segment base
    _IP: u16, // Pointer to the next instruction to execute

    // Status Flags
    _AF: bool, // Auxiliary Carry flag
    _CF: bool, // Carry flag
    _OF: bool, // Overflow flag
    _SF: bool, // Sign flag
    _PF: bool, // Parity flag
    _ZF: bool, // Zero flag

    // Control Flags
    _DF: bool, // Direction flag
    _IF: bool, // Interrupt-enable flag
    _TF: bool, // Trap flag

    // General Registers
    _AX: u16, // Accumulator
    _BX: u16, // Base
    _CX: u16, // Count
    _DX: u16, // Data
    _SP: u16, // Stack Pointer
    _BP: u16, // Base Pointer
    _DI: u16, // Source Index (Offset)
    _SI: u16, // Destination Index (Offset)

    pub fn getReg16FromRegValue(self: *Register, reg: RegValue) RegisterPayload {
        switch (reg) {
            .ALAX => {
                return RegisterPayload{
                    .value16 = self._AX,
                };
            },
            .BLBX => {
                return RegisterPayload{
                    .value16 = self._BX,
                };
            },
            .CLCX => {
                return RegisterPayload{
                    .value16 = self._CX,
                };
            },
            .DLDX => {
                return RegisterPayload{
                    .value16 = self._DX,
                };
            },
            .AHSP => {
                return RegisterPayload{
                    .value16 = self._SP,
                };
            },
            .BHDI => {
                return RegisterPayload{
                    .value16 = self._DI,
                };
            },
            .CHBP => {
                return RegisterPayload{
                    .value16 = self._BP,
                };
            },
            .DHSI => {
                return RegisterPayload{
                    .value16 = self._SI,
                };
            },
        }
    }

    // Internal Communication Register Methods
    pub fn setCS(self: *Register, value: u16) void {
        self._CS = value;
    }
    pub fn getCS(self: *Register) RegisterPayload {
        return RegisterPayload{ .value16 = self._CS };
    }
    pub fn setDS(self: *Register, value: u16) void {
        self._DS = value;
    }
    pub fn getDS(self: *Register) RegisterPayload {
        return RegisterPayload{ .value16 = self._DS };
    }
    pub fn setES(self: *Register, value: u16) void {
        self._ES = value;
    }
    pub fn getES(self: *Register) RegisterPayload {
        return RegisterPayload{ .value16 = self._ES };
    }
    pub fn setSS(self: *Register, value: u16) void {
        self._SS = value;
    }
    pub fn getSS(self: *Register) RegisterPayload {
        return RegisterPayload{ .value16 = self._SS };
    }
    pub fn setIP(self: *Register, value: u16) void {
        self._IP = value;
    }
    pub fn getIP(self: *Register) RegisterPayload {
        return RegisterPayload{ .value16 = self._IP };
    }

    // Flag Methods
    pub fn setAF(self: *Register, state: bool) void {
        self._AF = state;
    }
    pub fn getAF(self: *Register) bool {
        return self._AF;
    }
    pub fn setCF(self: *Register, state: bool) void {
        self._CF = state;
    }
    pub fn getCF(self: *Register) bool {
        return self._CF;
    }
    pub fn setOF(self: *Register, state: bool) void {
        self._OF = state;
    }
    pub fn getOF(self: *Register) bool {
        return self._OF;
    }
    pub fn setSF(self: *Register, state: bool) void {
        self._SF = state;
    }
    pub fn getSF(self: *Register) bool {
        return self._SF;
    }
    pub fn setPF(self: *Register, state: bool) void {
        self._PF = state;
    }
    pub fn getPF(self: *Register) bool {
        return self._PF;
    }
    pub fn setZF(self: *Register, state: bool) void {
        self._ZF = state;
    }
    pub fn getZF(self: *Register) bool {
        return self._ZF;
    }
    pub fn setDF(self: *Register, state: bool) void {
        self._DF = state;
    }
    pub fn getDF(self: *Register) bool {
        return self._DF;
    }
    pub fn setIF(self: *Register, state: bool) void {
        self._IF = state;
    }
    pub fn getIF(self: *Register) bool {
        return self._IF;
    }
    pub fn setTF(self: *Register, state: bool) void {
        self._TF = state;
    }
    pub fn getTF(self: *Register) bool {
        return self._TF;
    }

    // General Register Methods
    pub fn setAH(self: *Register, value: u8) void {
        self._AX = value ++ self._AX[0..8];
    }
    pub fn setAL(self: *Register, value: u8) void {
        self._AX = self._AX[8..] ++ value;
    }
    pub fn setAX(self: *Register, value: u16) void {
        self._AX = value;
    }
    pub fn getAX(self: *Register, w: WValue, hilo: []const u8) RegisterPayload {
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
    pub fn setBH(self: *Register, value: u8) void {
        self._BX = value ++ self._BX[0..8];
    }
    pub fn setBL(self: *Register, value: u8) void {
        self._BX = self._BX[8..] ++ value;
    }
    pub fn setBX(self: *Register, value: u16) void {
        self._BX = value;
    }

    /// Returns value of BH, BL or BX depending on w and hilo. If
    /// w = byte, hilo can be set to "hi" or "lo". If w = word hilo
    /// should be set to "hilo"
    pub fn getBX(self: *Register, w: WValue, hilo: ?[]const u8) RegisterPayload {
        if (w == WValue.byte) {
            if (std.mem.eql(u8, hilo.?, "hi")) {
                return RegisterPayload{ .value8 = @intCast(self._BX >> 8) };
            } else {
                self._BX = self._BX << 8;
                return RegisterPayload{ .value8 = @intCast(self._BX >> 8) };
            }
        } else {
            return RegisterPayload{ .value16 = self._BX };
        }
    }
    pub fn setCH(self: *Register, value: u8) void {
        self._CX = value ++ self._CX[0..8];
    }
    pub fn setCL(self: *Register, value: u8) void {
        self._CX = self._CX[8..] ++ value;
    }
    pub fn setCX(self: *Register, value: u16) void {
        self._CX = value;
    }
    pub fn getCX(self: *Register, w: WValue, hilo: []const u8) RegisterPayload {
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
    pub fn setDH(self: *Register, value: u8) void {
        self._DX = value ++ self._DX[0..8];
    }
    pub fn setDL(self: *Register, value: u8) void {
        self._DX = self._DX[8..] ++ value;
    }
    pub fn setDX(self: *Register, value: u16) void {
        self._DX = value;
    }
    pub fn getDX(self: *Register, w: WValue, hilo: []const u8) RegisterPayload {
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
    pub fn setSP(self: *Register, value: u16) void {
        self._SP = value;
    }
    pub fn getSP(self: *Register) u16 {
        return self._SP;
    }
    pub fn setBP(self: *Register, value: u16) void {
        self._BP = value;
    }
    pub fn getBP(self: *Register) u16 {
        return self._BP;
    }
    pub fn setSI(self: *Register, value: u16) void {
        self._SI = value;
    }
    pub fn getSI(self: *Register) u16 {
        return self._SI;
    }
    pub fn setDI(self: *Register, value: u16) void {
        self._DI = value;
    }
    pub fn getDI(self: *Register) u16 {
        return self._DI;
    }
};

// TODO: Move MemoryError to errors.zig

const MemoryError = error{
    ValueError,
    OutOfBoundError,
};

// TODO: Move MemoryPayload to types.zig

const MemoryPayload = union {
    err: MemoryError,
    value8: u8,
    value16: u16,
};

// 8086 Memory
// Total Memory: 1,048,576 bytes            | physical addresses range from 0x0H to 0xFFFFFH <-- 'H' signifying a physical address
// Segment: up to   65.536 bytes            | logical addresses consist of segment base + offset value
// A, B, C, D, E, F, G, H, I, J             |   -> for any given memory address the segment base value
// und K                                    |      locates the first byte of the containing segment and
//                                          |      the offset is the distance in bytes of the target
//                                          |      location from the beginning of the segment.
//                                          |      segment base and offset are u16

/// Simulates the memory of the 8086 Processor
pub const Memory = struct {
    _memory: [0xFFFFF]u8 = undefined,

    // byte     0x0 -    0x13 = dedicated
    // byte    0x14 -    0x7F = reserved
    // byte    0x80 - 0xFFFEF = open
    // byte 0xFFFF0 - 0xFFFFB = dedicated
    // byte 0xFFFFC - 0xFFFFF = reserved
    pub fn init(self: *Memory) void {
        self._memory = [1]u8{0} ** 0xFFFFF;
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
