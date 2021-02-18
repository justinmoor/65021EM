;-------------------------------------------------------------------------
;   65021EM START UP CODE
;
;   Responsible for calling the BIOS to initialize hardware
;   Once the BIOS is initialized, the monitor is started
; 
;-------------------------------------------------------------------------

.SETCPU "65C02"

.INCLUDE "bios.asm"
.INCLUDE "monitor.asm"

.SEGMENT "VECTORS"

.WORD   NMI
.WORD   RESET
.WORD   IRQ

.CODE

RESET:  JMP START
NMI:    RTI
IRQ:    RTI

START:
    LDX #$FF        ; setup stack
    TXS    
    JSR INIT_BIOS
    JSR START_MONITOR