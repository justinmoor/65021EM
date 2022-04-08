
.SETCPU "65C02"

.SEGMENT "VECTORS"

.WORD   NMI
.WORD   Reset
.WORD   IRQ

.CODE

.INCLUDE "jump_table.asm"
.INCLUDE "variables.asm"
.INCLUDE "util.asm"
.INCLUDE "macros.asm"
.INCLUDE "bios.asm"

Reset:          JMP Init
NMI:            RTI
IRQ:            JMP Interrupt

Init:           LDX #$FF            ; initialize stack
                TXS
                CLD
                JSR InitBios
                JSR PrintWelome

@Start:         JSR PrintPrompt
                JSR GetLine     
                CMP #ESC
                BEQ @Start
                TXA                 ; get input length
                BEQ @Start          ; empty input, show prompt
                STZ AmountOfArgs
                JSR ReadCommand
                JSR ReadArguments
                JSR ExecuteCommand
                JMP @Start

; read the command from the input buffer into the command buffer
ReadCommand:    LDX #0
@Loop:          LDA InputBuffer, X  
                BEQ @Done                       ; zero means end of line
                CMP #' '                        ; space means end of command, start of arguments
                BEQ @Done
                STA CommandBuffer, X
                INX
                JMP @Loop
@Done:          STZ CommandBuffer, X            ; Terminate command buffer with 0
                RTS

ReadArguments:  LDA #' '                        ; Current reading state = space
                STA T1                          ; T1 holds current reading state
                LDY #0
@Loop:          LDA InputBuffer, X              ; read character
                CMP #0                          ; Check end of line
                BEQ @Done   
                CMP #' '                        ; Space?                        
                BNE @Word                       ; No
                STA T1                          ; Yes, set current reading state to spaces
                JMP @Next                       ; Next character
@Word:          LDA T1                          ; Reading a new word
                CMP #' '                        ; Check if state was space
                BNE @W1                         ; Was not, we don't need to increment the AmountOfArgs
                LDA AmountOfArgs                
                CMP #0                          ; Are we reading the first argument?
                BEQ @Continue                   ; If we are, we don't need to add a space
                LDA #' '                        
                STA ArgsBuffer, Y
                INY
@Continue:      LDA #'W'                        ; Reading a new word, set state to word ('W')
                STA T1                          ; Store state
                INC AmountOfArgs                ; Increment the amount of args we've read
@W1:            LDA InputBuffer, X
                STA ArgsBuffer, Y
                INY
@Next:          INX
                BNE @Loop
@Done:          LDA #0
                STA ArgsBuffer, Y               ; terminate
                RTS

ExecuteCommand: LDA #<CommandBuffer             ; Prepare string compare for each command table entry
                STA StrPtr1                     
                LDA #>CommandBuffer
                STA StrPtr1 + 1
                LDX #0
@Loop:          LDA CommandTable, X             ; String compare current entry with what's in the command buffer
                CMP #CommandTableEnd
                BEQ @NoHit                      ; End of table            
                STA StrPtr2    
                LDA CommandTable + 1, X
                STA StrPtr2 + 1
                JSR StrComp
                BEQ @Hit                        ; Got a hit, let's execute the command!
                INX                             ; No hit yet, increment 4 times because each entry in 4 bytes
                INX
                INX
                INX
                BNE @Loop
@NoHit:         JSR PrintNewline
                JSR PrintIndent
                JSR PrintImmediate                    ; No hit at all
                ASCLN "INVALID COMMAND"
                RTS
@Hit:           JMP (CommandTable + 2, X)       ; Jump to the routine from the table


InvalidArgs:    JSR PrintNewline
                JSR PrintIndent
                JSR PrintImmediate
                ASCLN "INVALID ARGUMENT(S)"
                RTS

PrintPrompt:	LDA #CR
                JSR WriteChar   ; New line
                LDA #NEWL
                JSR WriteChar
                LDA #PROMPT     ; ">"
                JSR WriteChar   ; Output it.
                LDA #$20        ; "<space>"
                JSR WriteChar     
                RTS

PrintWelome:    LDA #<Welcome
                STA P1
                LDA #>Welcome
                STA P1 + 1
                JSR Print
                RTS

; This routines will read a whole line from user input. It also handles backspace. When user presses
; enter or escape, the routine will return. The key that has been pressed (enter or escape) 
; will be in the A register. The input length will be in the X register. Input is zero-terminated.
; Line is stored at $0200 (InputBuffer)
GetLine:        LDX #0                  ; reset input buffer index
@PollInput:     JSR ReadChar
                BCC @PollInput
                CMP #$60                ; is it lowercase?
                BMI @Continue           ; yes, just continue processing
                AND #$DF				; convert to uppercase
@Continue:		
                CMP #BS                 ; is it a backspace?
                BNE @NoBackspace        ; if not, branch
@OnBackspace    DEX	                    ; we got a backspace, decrement input buffer
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
                STA InputBuffer, X		; no we append to input buffer
                INX						; increment buffer index
                JMP @PollInput          ; poll more characters
@Return:        STZ InputBuffer, X
                RTS	

Interrupt:
                STA TA  ; store A, X, Y in temp locations, stack is unsuitable for now, more info below
                STX TX
                STY TY
                PLA                 ; restore original status register
                PHA
                AND #%00010000      ; is it a software or hardware interrupt?
                BNE @Break          ; software interrupt
                JSR @ExecISR         ; hardware interrup
                JMP @EndIRQ
@ExecISR:       JMP (ISR)           ; execute ISR

@Break          JSR PrintNewline
                JSR PrintImmediate
                ASC "A = $"
                LDA TA
                JSR PrintByte
                JSR PrintImmediate
                ASC "   X = $"
                TXA
                JSR PrintByte
                JSR PrintImmediate
                ASC "   Y = $"
                TYA
                JSR PrintByte
                JSR PrintNewline
@Wait           JSR ReadChar
                BCC @Wait

                ; BRK instruction is actually a 2 byte instruction, but most assembler assemble it as a 1 byte instruction
                ; this means we need to manually decrement the return address stored on the stack before returning.
                ; Source: http://nesdev.com/the%20%27B%27%20flag%20&%20BRK%20instruction.txt
                TSX         ; Stack pointer into index register
                SEC     
                LDA	$0102,X
                SBC	#$01    ; Decrement low byte of return address
                STA	$0102,X
                LDA	$0103,X
                SBC	#$00    ; Decrement high byte of return address (if no carry)
                STA	$0103,X

@EndIRQ         LDA TA      ; restore A, X, and Y registers to continue execution
                LDX TX
                LDY TY

                RTI         ; return from interrupt

Welcome:
    .BYTE CR, NEWL, CR, NEWL
    .BYTE "65021EM", CR, NEWL
    .BYTE "CPU: 65C02 @ 2 Mhz", CR, NEWL
    .BYTE "RAM: 32KB - LOC.: 0000-7FFF", CR, NEWL
    .BYTE "ROM: 16KB - LOC.: C000-FFFF", CR, NEWL, CR, NEWL
    .BYTE "MP/OS Ready", CR, NEWL, CR, NEWL, 0

.INCLUDE "command_table.asm"
.INCLUDE "monitor.asm"
.INCLUDE "video.asm"
.INCLUDE "disassembler.asm"
.INCLUDE "assembler.asm"
.INCLUDE "xmodem.asm"
.INCLUDE "basic.asm"