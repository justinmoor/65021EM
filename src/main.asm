;-------------------------------------------------------------------------
;   65021EM START UP CODE
;
;   Responsible for calling the BIOS to initialize hardware
;   Once the BIOS is initialized, the monitor is started
; 
;-------------------------------------------------------------------------

.SETCPU "65C02"


.SEGMENT "VECTORS"

.WORD   NMI
.WORD   RESET
.WORD   IRQ

.CODE
.INCLUDE "macros.asm"
.INCLUDE "bios.asm"
.INCLUDE "xmodem.asm"
.INCLUDE "monitor.asm"
.INCLUDE "basic.asm"

RESET:  JMP START
NMI:    RTI
IRQ:    RTI

START:
    LDA #'*'
    LDX #$FF        ; setup stack
    TXS    
    CLD             ; Clear decimal arithmetic mode.
    CLI
    JSR INIT_BIOS

PRINT_START_MSG:
    LDA #<BANNER
    STA STRING_LO
    LDA #>BANNER
    STA STRIG_HI
    JSR PRINT
    LDA #<COMMANDS
    STA STRING_LO
    LDA #>COMMANDS
    STA STRIG_HI
    JSR PRINT

    PRINT_PROMPT

GET_INPUT:    
    JSR READ_CHAR
    BCC GET_INPUT
    JSR ECHO        ; Display character.
    JMP GET_INPUT

BANNER:
    .BYTE CR, NEWL, CR, NEWL
    .BYTE "  /    __|    \ _  ) _ |    __|   \  |", CR, NEWL
    .BYTE "  _ \ __ \  (  |  /    |    _|   |\/ |", CR, NEWL
    .BYTE "\___/ ___/ \__/ ___|  _|   ___| _|  _|", CR, NEWL
    .BYTE CR, NEWL
    .BYTE "CPU: 65C02 @ 2 Mhz", CR, NEWL
    .BYTE "RAM: 32KB - LOC.: 0000-7FFF", CR, NEWL
    .BYTE "ROM: 16KB - LOC.: C000-FFFF", CR, NEWL, 0
COMMANDS:
    .BYTE CR, NEWL
    .BYTE "Welcome to the 65021EM! The following commands are available:", CR, NEWL
    .BYTE "S - Start BASIC", CR, NEWL
    .BYTE "X - Receive file over XMODEM", CR, NEWL
    .BYTE "R - Run program at last selected address", CR, NEWL, 0