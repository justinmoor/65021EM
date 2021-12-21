# 65021EM
65021EM stands for 65021 Expandable Microcomputer, a 6502-based computer, made in 2021. The 65021EM runs an operating system called MP/OS (Monitor Programming Operating System).

This repository holds all the necessary resources for the project, which includes source code and schematics.

## Specifications

- **CPU:** 65C02
- **RAM**: 32KB
- **ROM**: 16KB
- **CLOCK**: 2Mhz

## Features

- 6 expansion slots
  * Slot 1: serial interface
  * Slot x: SPI interface(s) (TODO)
  * Slot x: OLED display (TODO)

## Memory Map

- **RAM**:      \$0000 - \$7FFF (binary 0xxxxxxxxxxxxxxx)
- **TMS9918**:  \$A800 - \$A80F (binary 10101xxxxxxx1111) (TODO)
- **SERIAL**:   \$B000 - \$B00F (binary 10110xxxxxxx1111)
- **ROM**:      \$C000 - \$FFFF (binary 11xxxxxxxxxxxxxx)

## MP/OS
### Available commands:

**Memory display**\
`MD addr1 (addr2)`

**Memory modify at `addr`**\
`MM addr byte1 (... byten)`

**Assemble at `addr`:**\
`ASM addr`

**Disassemble at `addr` (optionally amount of lines):**\
`DIS addr (lines)`

**Execute at `addr`:**\
`R addr`

**XMODEM receive at `addr`:**\
`XM addr`

**Start BASIC**\
`BASIC`

### To be added

**Fill memory range with byte**\
`MF addr amount byte`

**Set breakpoint at `addr`**\
`SBRK addr`

**Clear breakpoint at `addr` (will clear all breakpoints if no address is specified)**\
`CBRK (addr) `

### Assembler syntax
```
STARTING ASSEMBLING AT ADDRESS $1000
1000: LDA #01
1002: ASL A
1003: STA 3000
1006: RTS
<ESC to exit>
```

### Build
```sh
// assemble code
cl65 -t none -C memory_layout.cfg --feature labels_without_colons src/main.asm -o build/os

// write to ROM
minipro -s -p AT28C256 -w build/os

// open terminal session
picocom --b 19200 --send-cmd "sx -vv" --receive-cmd "rx -vv" /dev/ttyUSB0 // linux
picocom --b 19200 --send-cmd "lsx -vv" --receive-cmd "lrx -vv" /dev/cu.usbserial-FT4YNKSL // macos

// edit program bytes with hexeditor
hexeditor -b programs/helloworld 
```