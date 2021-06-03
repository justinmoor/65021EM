;-------------------------------------------------------------------------
;   65021EM START UP CODE
;
;   Responsible for calling the BIOS to initialize hardware
;   Once the BIOS is initialized, prompt is showed
; 
;-------------------------------------------------------------------------

.SETCPU "65C02"

.SEGMENT "VECTORS"

.WORD   NMI
.WORD   Reset
.WORD   IRQ

.CODE

.INCLUDE "jump_table.asm"
.INCLUDE "variables.asm"
.INCLUDE "macros.asm"
.INCLUDE "bios.asm"

Reset:          JMP Start
NMI:            RTI
IRQ:            RTI


Start:          LDX #$FF        ; setup stack
                TXS    
                CLD             ; Clear decimal arithmetic mode.
                CLI
                JSR InitBios
                JSR PrintBanner
                JMP StartPrompt
SoftResetOS:    LDX #$FF        ; reset stack
                TXS
                CLD             ; Clear decimal arithmetic mode.
                CLI
StartPrompt:	JSR PrintPrompt
                JSR GetLine
                CMP #CR
                BEQ ProcessInput
                JMP StartPrompt

; X contains the length of the input we've received
; Input buffer starts at $200 
ProcessInput:	
                LDA InputBuffer
                CMP #'M'
                BEQ StartMonitor
                CMP #'B'
                BEQ StartBasic
                CMP #'X'
                BEQ StartXModem
                CMP #'R'
                BEQ InvalidCommand
                CMP #'H'
                BEQ PrintHelp
                JSR PrintNewline
                JSR PrintNewline
                JSR PrintImmediate
                ASCLN "UNKNOWN COMMAND"
                JMP StartPrompt

StartMonitor:	JSR RunMonitor

StartBasic:     JSR LAB_COLD
                JMP StartPrompt

StartXModem:    JSR RunXModem
                JMP StartPrompt

InvalidCommand:	JSR PrintNewline
                JSR PrintNewline
                JSR PrintImmediate
                ASCLN "ONLY WORKS IN MONITOR MODE!"
                JMP StartPrompt

PrintHelp:      JSR PrintCommands
                JMP StartPrompt

PrintPrompt:	LDA #CR
                JSR WriteChar   ; New line
                LDA #NEWL
                JSR WriteChar
                LDA #PROMPT     ; ">"
                JSR WriteChar   ; Output it.
                LDA #$20        ; "<space>"
                JSR WriteChar     
                RTS

PrintNewline:	PHA
                LDA #CR
                JSR WriteChar
                LDA #NEWL
                JSR WriteChar
                PLA
                RTS

; converts 2 ascii hexadecimal digits to a byte
; e.g. A='1' Y='A' Returns A = $1A
Hex2Bin:		
                PHA
                TYA
                JSR A2Hex
                STA T1
                PLA
                JSR A2Hex
                ASL
                ASL
                ASL
                ASL
                ORA T1
                RTS

A2Hex:          SEC
                SBC #'0'
                CMP #10
                BCC @Return
                SBC #7
@Return:        RTS

; Converts one byte of binary data to two ascii characters.
; Entry: 
; A = binary data
; 
; Exit: 
; A = first ascii digit, high order value
; Y = second ascii digit, low order value
Bin2Hex:		
                TAX         		; save original value
                AND #$F0    		; get high nibble
                LSR
                LSR
                LSR
                LSR         		; move to lower nibble
                JSR HexDigit2Ascii	; convert to ascii
                PHA
                TXA					; convert lower nibble
                AND #$0F
                JSR HexDigit2Ascii	; convert to ascii
                TAY         		; low nibble to register y
                PLA					; high nibble to register a
                RTS

; converts a hexadecimal digit to ascii
; entry:
; A = binary data in lower nibble
; exit:
; A = ASCII char
HexDigit2Ascii:	
                CMP #10
                BCC @isDigit
                CLC
                ADC #7
@isDigit:       ADC #'0'
                RTS

; prints a byte as 2 ascii hex characters
; all registers are restored
PrintByte:		
                PHA
                PHX
                PHY
                JSR Bin2Hex
                JSR WriteChar
                TYA 
                JSR WriteChar
                PLY
                PLX
                PLA
                RTS

PrintBanner:    LDA #<Banner
                STA StrPtrLow
                LDA #>Banner
                STA StrPtrHi
                JSR Print
PrintSpecs:
                LDA #<Specs
                STA StrPtrLow
                LDA #>Specs
                STA StrPtrHi
                JSR Print
PrintCommands:
                LDA #<Commands
                STA StrPtrLow
                LDA #>Commands
                STA StrPtrHi
                JSR Print
                RTS

; This routines will read a whole line from user input. It also handles backspace. When user presses
; enter or escape, the routine will return. The key that has been pressed (enter or escape) 
; will be in the A register. The input length will be in the X register. Line is stored at $0200 (InputBuffer)
GetLine:        LDX #0                  ; reset input buffer index
@PollInput:     JSR ReadChar
                BCC @PollInput
                CMP #$60                ; is it lowercase?
                BMI @Continue           ; yes, just continue processing
                AND #$DF				; convert to uppercase
@Continue:		
                CMP #BS                 ; is it a backspace?
                BNE @NoBackspace        ; if not, branch
@OnBackspace	DEX	                    ; we got a backspace, decrement input buffer
                BMI GetLine				; just reset when there are no characters to backspace
                JSR WriteChar			; display the backspace.
                LDA #$20                ; space, overwrite the backspaced char.
                JSR WriteChar			; display space
                LDA #BS                 ; backspace again to get to correct pos.
                JSR WriteChar		
                JMP @PollInput
@NoBackspace:
                CMP #ESC				; is escape key pressed?
                BEQ @Return				; quit
                PHA	
                JSR WriteChar			; display character.
                PLA	
                CMP #CR                 ; is it an enter?
                BEQ @Return				; yes, caller can now start processing from $0200
                STA InputBuffer, x		; no we append to input buffer
                INX						; increment buffer index
                JMP @PollInput          ; poll more characters
@Return:        RTS	


Banner:
    .BYTE CR, NEWL, CR, NEWL
    .BYTE "  /    __|    \ _  ) _ |    __|   \  |", CR, NEWL
    .BYTE "  _ \ __ \  (  |  /    |    _|   |\/ |", CR, NEWL
    .BYTE "\___/ ___/ \__/ ___|  _|   ___| _|  _|", CR, NEWL
    .BYTE CR, NEWL, 0
Specs:
    .BYTE "CPU: 65C02 @ 2 Mhz", CR, NEWL
    .BYTE "RAM: 32KB - LOC.: 0000-7FFF", CR, NEWL
    .BYTE "ROM: 16KB - LOC.: C000-FFFF", CR, NEWL, CR, NEWL
    .BYTE "Welcome to the 65021EM! The following commands are available:", 0
Commands:
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