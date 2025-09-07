# x86 Simulator (16 bit) for the 8086 Intel CPU in Zig

Following the ['Performance Aware Programming' series by Casey Muratory](https://www.computerenhance.com/p/table-of-contents).

Even though i'm not far into the course yet this is already one of the best learning experiences regarding microprocessors i ever had. The module 'Fundamentals of Microprocessors' (Mikroprozessortechnik) at university didn't even come close!

1. [Info](#info)    
    1.1 [Intel 8086 Family User's Manual](#intel-8086-family-users-manual)  
    1.2 [Test data](#test-data)     
    1.3 [ASM-86 Implementation State](#asm-86-implementation-state)     
2. [Learnings](#learnings)
3. [Dependencies](#dependencies)
4. [Installation](#installation-wip)
5. [Usage](#usage-wip)


## Info
#### Intel 8086 Family User's Manual
Using the information [provided by Intel](https://archive.org/details/bitsavers_intel80869lyUsersManualOct79_62967963/mode/2up?view=theater).


#### Test data
Test data is available [here](https://github.com/cmuratori/computer_enhance).

#### ASM-86 Implementation State
[x] mov     
[ ] add     
[ ] sub     
[ ] cmp     
[ ] jnz



## Learnings
- How to write performant code accross all languages (Thanks Casey Muratory!)
- Zig
- x86 instructions
- Bit operations
- Refresh of assembler programming (ASM-86)

## Dependencies
- [zig-x86_64-windows-0.15.1](https://ziglang.org/download/)        
or
- [zig-x86-64-linux-0.15.1](https://ziglang.org/download/)

## Installation (WIP)
#### Clone this repository
```
git clone https:/github.com/tripton/x86_sim.git
```

#### Build
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