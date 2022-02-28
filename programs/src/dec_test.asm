.ORG $1000

Start:
    LDA #0
    STA $A800
    NOP
    NOP
    NOP
    JMP Start

Start2:
    LDA #0
    LDA $A800
    NOP
    NOP
    NOP
    JMP Start2
    