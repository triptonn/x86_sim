pub const SimulatorError = error{
    FileError,
    DecodeError,
    InstructionError,
    InstructionSizeError,
    InvalidInstruction,
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
};
