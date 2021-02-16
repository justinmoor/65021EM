# 65021EM
65021ME stands for 65021 Expandable Microcomputer, a 6502-based computer, made in 2021. This repository is holds all the resources necessary for the project, which includes source code and schematics.

### Specifications

- **CPU:** 65C02
- **RAM**: 32KB
- **ROM**: 16KB

### Features

- Serial interface 
- SPI interface (todo)

### Memory Map

- **RAM**: \$0000 - \$7FFF (binary 0xxxxxxxxxxxxxxx)
- **ROM**: \$C000 - \$FFFF (binary 11xxxxxxxxxxxxxx)
- **SERIAL**: \$8000 - \$800F (binary 1000000000001111)

### Build
```sh
// assemble code
cl65 -C memory_layout.cfg src/kernel.asm -o build/program

// write to ROM
minipro -s -p AT28C256 -w build/program
```