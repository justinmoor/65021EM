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

.INCLUDE "jump_table.asm"
.INCLUDE "memory.asm"
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
    ; JSR PRINT_PROMPT
    ; JMP GET_INPUT
START_PROMPT:
    JSR PRINT_PROMPT_NEWL
	JSR GetLine
	CMP #CR
	BEQ PROCESS_INPUT
	JMP START_PROMPT

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
    JSR WRITE_CHAR        ; New line
    LDA #NEWL
    JSR WRITE_CHAR
PRINT_PROMPT:
    LDA #PROMPT     ; ">"
    JSR WRITE_CHAR        ; Output it.
    LDA #$20        ; "<space>"
    JSR WRITE_CHAR     
    RTS

CRNEWL:
    PHA
    LDA #CR
    JSR WRITE_CHAR
    LDA #NEWL
    JSR WRITE_CHAR
    PLA
    RTS

; converts 2 ascii hexadecimal digits to a byte
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

; converts one byte of binary data to two ascii characters
; entry: 
; A = binary data
; 
; exit: 
; A = first ascii digit, high order value
; Y = second ascii digit, low order value
BIN2HEX:
    TAX         ; save original value
    AND #$F0    ; get high nibble
    LSR
    LSR
    LSR
    LSR         ; move to lower nibble
    JSR HD2ASCII; convert to ascii
    PHA
    TXA         ; convert lower nibble
    AND #$0F
    JSR HD2ASCII; convert to ascii
    TAY         ; low nibble to register y
    PLA         ; high nibble to register a
    RTS

; converts a hexadecimal digit to ascii
; entry:
; A = binary data in ower nibble
; exit:
; A = ASCII char
HD2ASCII:
    CMP #10
    BCC @isDigit
    CLC
    ADC #7
@isDigit:
    ADC #'0'
    RTS

; prints a byte as 2 ascii hex characters
PRINT_BYTE:
    JSR BIN2HEX
    JSR WRITE_CHAR
    TYA 
    JSR WRITE_CHAR
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


; This routines will read a whole line from user input. It also handles backspace. When user presses
; enter or escape, the routine will return. The key that has been pressed (enter or escape) 
; will be in the A register. The input length will be in the X register
GetLine:		ldx	#0                  ; reset input buffer index
@PollInput:		jsr	READ_CHAR
				bcc	@PollInput
				cmp	#$60                ; is it lowercase?
				bmi	@Continue           ; yes, just continue processing
				and	#$df				; convert to uppercase
@Continue:
				cmp #BS                 ; is it a backspace?
				bne @NoBackspace        ; if not, branch
				dex                     ; we got a backspace, decrement input buffer
				bmi GetLine				; just reset when there are no characters to backspace
				jsr WRITE_CHAR          ; display the backspace.
				lda #$20                ; space, overwrite the backspaced char.
				jsr WRITE_CHAR			; display space
				lda #BS                 ; backspace again to get to correct pos.
				jsr WRITE_CHAR		
				jmp @PollInput
@NoBackspace:
				cmp #ESC				; is escape key pressed?
				beq @EscOrEnter			; quit
                pha
                jsr WRITE_CHAR          ; display character.
                pla
                cmp #CR                 ; is it an enter?
                beq @EscOrEnter   		; yes, caller can now start processing from $0200
                sta INPUT_BUF, x      	; no we append to input buffer
                inx                     ; increment buffer index
                jmp @PollInput          ; poll more characters
@EscOrEnter:	rts


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
.INCLUDE "assembler.asm"
.INCLUDE "disassembler.asm"
.INCLUDE "basic.asm"