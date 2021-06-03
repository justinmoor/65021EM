# 65021EM
65021EM stands for 65021 Expandable Microcomputer, a 6502-based computer, made in 2021. This repository holds all the necessary resources for the project, which includes source code and schematics.

### Specifications

- **CPU:** 65C02
- **RAM**: 32KB
- **ROM**: 16KB
- **CLOCK**: 2Mhz

### Features

- 6 expansion slots
  * Slot 1: serial interface
  * Slot x: SPI interface(s) (TODO)
  * Slot x: OLED display (TODO)

### Memory Map

- **RAM**: \$0000 - \$7FFF (binary 0xxxxxxxxxxxxxxx)
- **ROM**: \$C000 - \$FFFF (binary 11xxxxxxxxxxxxxx)
- **SERIAL**: \$8000 - \$800F (binary 1000000000001111)

### Machine Language Monitor Usage
```
> M                               press M to activate monitor

MONITOR ACTIVATED

* 1000.102F                       show bytes of address range
  1000: FF FF FF FF FF FF FF 1A 2B 60 86 B2 20 72 13 20
  1010: 43 14 C9 43 D0 12 A2 1F BD 0A 15 95 50 CA 10 F8
  1020: A2 1B 86 DC A9 CC D0 19 C9 45 D0 0E 20 BB 11 38
* 1000: AA AA AA 10 20 30 40 50   write specified bytes at address 1000
  1000: FF
* 1000.100F
  1000: AA AA AA 10 20 30 40 50 2B 60 86 B2 20 72 13 20
* C000                            select address
  C000: 4C                        
* L                               <L> to disassemble bytes at last selected address

STARTING DISASSEMBLY AT ADDRESS $C000

C000   4C 7F C0    JMP   $C07F
C003   4C 6F C0    JMP   $C06F
C006   4C 92 C0    JMP   $C092
C009   4C B2 C1    JMP   $C1B2
C00C   4C E5 C1    JMP   $C1E5
C00F   A9 03       LDA   #$03
C011   8D 02 80    STA   $8002
C014   A9 FF       LDA   #$FF
C016   8D 03 80    STA   $8003
C019   8D 01 80    STA   $8001
C01C   20 20 C0    JSR   $C020
C01F   60          RTS
C020   5A          PHY
C021   48          PHA
C022   A0 C0       LDY   #$C0
C024   A9 09       LDA   #$09
C026   20 38 C0    JSR   $C038
C029   7A          PLY
C02A   68          PLA
C02B   60          RTS
C02C   5A          PHY
C02D   A0 40       LDY   #$40
C02F   A9 00       LDA   #$00

* 1000                          select address 1000
  1000: AA
* P                             <P> to start assembler at last selected address

STARTING ASSEMBLING ON ADDRESS $1000
1000: LDA #00
1002: STA 3000
1005: RTS
1006: 

* 1000                          select address 1000
  1000: A9
* R                             <R> to run from last selected address
* 3000
  3000: 00
```

### Build
```sh
// assemble code
cl65 -t none -C memory_layout.cfg --feature labels_without_colons src/main.asm -o build/os

// write to ROM
minipro -s -p AT28C256 -w build/os

// open terminal session
picocom --b 19200 --send-cmd "sx -vv" --receive-cmd "rx -vv" /dev/ttyUSB0

// edit program bytes with hexeditor
hexeditor -b programs/helloworld 
```
