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

.INCLUDE "variables.asm"
.INCLUDE "macros.asm"
.INCLUDE "bios.asm"

RESET:  JMP START
NMI:    RTI
IRQ:    RTI

START:
    LDX #$FF        ; setup stack
    TXS    
    CLD             ; Clear decimal arithmetic mode.
    CLI
    JSR INIT_BIOS
    JSR PRINT_START_MSG
    JMP START_PROMPT
SOFT_RESET_OS:
    LDX #$FF        ; reset stack
    TXS
    CLD             ; Clear decimal arithmetic mode.
    CLI
    JSR PRINT_PROMPT
    JMP GET_INPUT
START_PROMPT:
    JSR PRINT_PROMPT_NEWL
GET_INPUT:   
    LDX #0                  ; reset input buffer index
@POLL_INPUT:
    JSR READ_CHAR
    BCC @POLL_INPUT
    CMP #$60                ; is it lowercase?
    BMI @CONTINUE           ; yes, just continue processing
    AND #$DF
@CONTINUE:
    PHA
    JSR WRITE_CHAR          ; display character.
    PLA
    CMP #BS                 ; is it a backspace?
    BNE @NO_BACKSP           ; if not, branch
    DEX                     ; we got a backspace, decrement input buffer
    BMI START_PROMPT
    LDA #$20                ; space, overwrite the backspaced char.
    JSR ECHO
    LDA #BS                 ; *Backspace again to get to correct pos.
    JSR ECHO
    JMP @POLL_INPUT
@NO_BACKSP:
    CMP #CR                 ; is it an enter?
    BEQ PROCESS_INPUT       ; yes, we start processing
    STA INPUT_BUF, X        ; no we append to input buffer
    INX                     ; increment buffer index
    JMP @POLL_INPUT          ; poll more characters

; X contains the length of the input we've received
; Input buffer starts at $200 
PROCESS_INPUT:
    LDA INPUT_BUF
    CMP #'M'
    BEQ START_MONITOR
    CMP #'B'
    BEQ START_BASIC
    CMP #'X'
    BEQ START_XMODEM
    CMP #'R'
    BEQ RUN_INVALID
    CMP #'H'
    BEQ PRINT_COMMANDS
    JSR CRNEWL
    JSR CRNEWL
    JSR PRINTIMM
    ASCLN "UNKNOWN COMMAND"
    JMP START_PROMPT

START_MONITOR:
    JSR START_MON

START_BASIC:
    JSR LAB_COLD
    JMP START_PROMPT

START_XMODEM:
    PHY
    JSR XMODEM_FILE_RECV
    PLY
    JMP START_PROMPT

RUN_INVALID:
    JSR CRNEWL
    JSR CRNEWL
    JSR PRINTIMM
    ASCLN "ONLY WORKS IN MONITOR MODE!"
    JMP START_PROMPT

PRINT_COMMANDS:
    JSR PRINT_COMMS
    JMP START_PROMPT

PRINT_PROMPT_NEWL:
    LDA #CR
    JSR ECHO        ; New line
    LDA #NEWL
    JSR ECHO
PRINT_PROMPT:
    LDA #PROMPT     ; ">"
    JSR ECHO        ; Output it.
    LDA #$20        ; "<space>"
    JSR ECHO     
    RTS

CRNEWL:
    PHA
    LDA #CR
    JSR ECHO
    LDA #NEWL
    JSR ECHO
    PLA
    RTS

HEX2BIN:
	PHA
	TYA
	JSR A2HEX
	STA T1
	PLA
	JSR A2HEX
	ASL
	ASL
	ASL
	ASL
	ORA T1
	RTS
A2HEX:
	SEC
	SBC #'0'
	CMP #10
	BCC @A2HEX1
	SBC #7
@A2HEX1:
	RTS

PRINT_START_MSG:
    LDA #<BANNER
    STA STRING_LO
    LDA #>BANNER
    STA STRIG_HI
    JSR PRINT
PRINT_SPECS:
    LDA #<SPECS
    STA STRING_LO
    LDA #>SPECS
    STA STRIG_HI
    JSR PRINT
PRINT_COMMS:
    LDA #<COMMANDS
    STA STRING_LO
    LDA #>COMMANDS
    STA STRIG_HI
    JSR PRINT
    RTS

BANNER:
    .BYTE CR, NEWL, CR, NEWL
    .BYTE "  /    __|    \ _  ) _ |    __|   \  |", CR, NEWL
    .BYTE "  _ \ __ \  (  |  /    |    _|   |\/ |", CR, NEWL
    .BYTE "\___/ ___/ \__/ ___|  _|   ___| _|  _|", CR, NEWL
    .BYTE CR, NEWL, 0
SPECS:
    .BYTE "CPU: 65C02 @ 2 Mhz", CR, NEWL
    .BYTE "RAM: 32KB - LOC.: 0000-7FFF", CR, NEWL
    .BYTE "ROM: 16KB - LOC.: C000-FFFF", CR, NEWL, CR, NEWL
    .BYTE "Welcome to the 65021EM! The following commands are available:", 0
COMMANDS:
    .BYTE CR, NEWL, CR, NEWL
    .BYTE "B - Start BASIC", CR, NEWL
    .BYTE "X - Receive file over XMODEM", CR, NEWL
    .BYTE "M - Start machine code monitor", CR, NEWL 
    .BYTE "R - Run program at last selected address (only in monitor mode)", CR, NEWL
    .BYTE "H - Print available commands", CR, NEWL, 0

.INCLUDE "xmodem.asm"
.INCLUDE "monitor.asm"
.INCLUDE "basic.asm"