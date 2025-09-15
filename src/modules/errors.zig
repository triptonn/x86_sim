// ========================================================================
//
// (C) Copyright 2025, Nicolas Selig, All Rights Reserved.
//
// This software is provided 'as-is', without any express or implied
// warranty. In no event will the authors be held liable for any damages
// arising from the use of this software.
//
// ========================================================================

pub const SimulatorError = error{
    FileError,
    DecodeError,
    InstructionError,
    InstructionSizeError,
    InvalidInstruction,
    OutOfMemory,
    NotYetImplemented,
    WriteFailed,
};

pub const InstructionDecodeError = error{
    DecodeError,
    InstructionError,
    NotYetImplemented,
    WriteFailed,
};

pub const InstructionExecutionError = error{
    InvalidInstruction,
};

pub const DiassembleError = error{
    InstructionError,
    NotYetImplemented,
    WriteFailed,
    OutOfMemory,
};

/// Errors for the bus interface unit of the 8086 Processor
pub const BiuError = error{
    InvalidIndex,
};

pub const MemoryError = error{
    ValueError,
    OutOfBoundError,
};
