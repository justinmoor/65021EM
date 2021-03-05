# 65021EM
65021EM stands for 65021 Expandable Microcomputer, a 6502-based computer, made in 2021. This repository holds all the necessary resources for the project, which includes source code and schematics.

The code is currently more focused on being readable than being optimized for performance (this could also be an excuse for writing bad assembly code ;) ).

### Specifications

- **CPU:** 65C02
- **RAM**: 32KB
- **ROM**: 16KB
- **CLOCK**: 2Mhz

### Features

- 6 expansion slots
  * slot 1: serial interface
  * slot x: SPI interface(s)
  * slot x: OLED display

### Memory Map

- **RAM**: \$0000 - \$7FFF (binary 0xxxxxxxxxxxxxxx)
- **ROM**: \$C000 - \$FFFF (binary 11xxxxxxxxxxxxxx)
- **SERIAL**: \$8000 - \$800F (binary 1000000000001111)

### Build
```sh
// assemble code
cl65 -t none -C memory_layout.cfg src/main.asm -o build/os

// write to ROM
minipro -s -p AT28C256 -w build/os

// open terminal session
picocom --b 19200 --send-cmd "sx -vv" --receive-cmd "rx -vv" /dev/ttyUSB0
```
