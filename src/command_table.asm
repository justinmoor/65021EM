CommandTableEnd = '0'

CommandTable:
.byte <MD, >MD, <MemoryDump, >MemoryDump
.byte <MM, >MM, <MemoryModify, >MemoryModify
.byte <VMD, >VMD, <VMemoryDump, >VMemoryDump
.byte <VMM, >VMM, <VMemoryModify, >VMemoryModify
.byte <ZAPVRAM, >ZAPVRAM, <ZapVRAM, >ZapVRAM
.byte <MF, >MF, <MemoryFill, >MemoryFill
.byte <RUN, >RUN, <Run, >Run
.byte <ASM, >ASM, <Assembler, >Assembler
.byte <DIS, >DIS, <Disassembler, >Disassembler
.byte <XM, >XM, <XModem, >XModem
.byte <BASIC, >BASIC, <Basic, >Basic
.byte CommandTableEnd   ; terminate whole table with ascii '0'

Commands:
MD: .byte "MD", 0
MM: .byte "MM", 0
RUN: .byte "R", 0
MF: .byte "MF", 0
VMD: .byte "VMD", 0
VMM: .byte "VMM", 0
ZAPVRAM: .byte "ZAPVRAM", 0
ASM: .byte "ASM", 0
DIS: .byte "DIS", 0
XM: .byte "XM", 0
BASIC: .byte "BASIC", 0