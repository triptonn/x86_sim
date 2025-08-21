# x86 Simulator (16 bit) for the 8086 Intel CPU in Zig

Following the ['Performance Aware Programming' series by Casey Muratory](https://www.computerenhance.com/p/table-of-contents).

Even though i'm not far into the course yet this is already one of the best learning experiences regarding microprocessors i ever had. The module 'Fundamentals of Microprocessors' (Mikroprozessortechnik) at university didn't even come close!

Using the information [provided by Intel](https://archive.org/details/bitsavers_intel80869lyUsersManualOct79_62967963/mode/2up?view=theater).

Test data is available [here](https://github.com/cmuratori/computer_enhance).

## Learning:
- How to write performant code accross all languages (Thanks Casey Muratory!)
- Zig
- x86 instructions
- Bit operations
- Refresh of assembler programming (ASM-86)

## Dependencies
- [zig-x86_64-windows-0.15.0-dev.1552+b87b95868](https://ziglang.org/download/)

## Installation (WIP)
### Clone this repository
```
git clone https:/github.com/tripton/x86_sim.git
```

### Build
on Windows:
```bash
cd PATH/TO/REPOSITORY
zig build
```

## Usage (WIP)
on Windows:
```bash
cd PATH/TO/REPOSITORY/zig-out/bin
x86sim path/to/binary
```

