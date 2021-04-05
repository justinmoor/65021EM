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
    LDX #$FF        ; setup stack
    TXS    
    CLD             ; Clear decimal arithmetic mode.
    JSR INIT_BIOS
    JSR START_MONITOR