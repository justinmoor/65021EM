
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

Reset:          JMP Init
NMI:            RTI
IRQ:            JMP Interrupt

Init:           LDX #$FF
                TXS
                CLD
                CLI
                JSR InitBios

Start:          JSR PrintPrompt
                JSR GetLine     
                CMP #ESC
                BEQ @Start
                TXA                 ; get input length
                BEQ Start           ; empty input, show prompt
                STZ AmountOfArgs
                JSR ReadCommand
                JSR ReadArguments
                JSR ExecuteCommand
                JMP Start

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
                ASC "INVALID COMMAND"
                RTS
@Hit:           JMP (CommandTable + 2, X)       ; Jump to the routine from the table

; Will read an address in any byte format; C000, C00, C0, C, 000C
; result will be put in T6. Digits read will be in Y
Read2Bytes:     PHX
                STZ T6
                STZ T6 + 1
@NextHex:       LDA (P1), Y     ; Get character for hex test.
                EOR #$30        ; Map digits to $0-9.
                CMP #$0A        ; Digit?
                BCC @IsDigit    ; Yes.
                ADC #$88        ; Map letter "A"-"F" to $FA-FF.
                CMP #$FA        ; Hex letter?
                BCC @NotHex     ; No, character not hex.
@IsDigit:       ASL
                ASL             ; Hex digit to MSD of A.
                ASL
                ASL
                LDX #$04        ; Shift count.
@HexShift:      ASL             ; Hex digit left MSB to carry.
                ROL T6          ; Rotate into LSD.
                ROL T6 + 1      ; Rotate into MSD's.
                DEX             ; Done 4 shifts?
                BNE @HexShift   ; No, loop.
                INY             ; Advance text index.
                BNE @NextHex    ; Always taken. Check next character for hex.
@NotHex:        PLX
                RTS

InvalidCommand: JSR PrintNewline
                JSR PrintIndent
                JSR PrintImmediate                    ; No hit at all
                ASC "INVALID COMMAND"
                RTS

; Return if a character is a valid hex digit (0-9, A-F, or a-f).
; Pass character in A.
; Returns 1 in A if valid, 0 if not valid.
; Registers affected: A
IsHexDigit:
                JSR ToUpper
                CMP #'0'
                BMI @Invalid
                CMP #'9'+1
                BMI @Okay
                CMP #'A'
                BMI @Invalid
                CMP #'F'+1
                BMI @Okay
@Invalid:       LDA #0
                RTS
@Okay:          LDA #1
                RTS

ToUpper:
                CMP #'a'                ; Is it 'a' or higher?
                BMI @NotLower
                CMP #'z'+1              ; Is it 'z' or lower?
                BPL @NotLower
                AND #%11011111          ; Convert to upper case by clearing bit 5
@NotLower:      RTS

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

; Print 16-bit address in hex
; Pass byte in X (low) and Y (high)
; Registers changed: None
PrintAddress:
                PHA
                PHX
                TYA
                JSR PrintByte
                PLX
                TXA
                JSR PrintByte
                PLA
                RTS

; prints a byte as 2 ascii hex characters
; Registers changed: none
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

PrintNewline:   PHA
                LDA #$0D
                JSR WriteChar
                LDA #$0A
                JSR WriteChar
                PLA
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

PrintIndent:    LDA #SP
                JSR WriteChar    
                LDA #SP
                JSR WriteChar
                RTS

; Zero flag is set if equal
; Destroys A and Y register 
StrComp:        LDY #0
@Loop:          LDA (StrPtr1), Y
                BEQ @2                  ; got 0
                CMP (StrPtr2), Y
                BNE @Done               ; current char is not equal
                INY
                BNE @Loop
                INC StrPtr1 + 1
                INC StrPtr2 + 1
                BCS @Loop               ; always
@2:             CMP (StrPtr2), Y        ; compare last char
@Done:          RTS

InvalidArgs:    JSR PrintNewline
                JSR PrintIndent
                JSR PrintImmediate
                ASCLN "INVALID ARGUMENTS"
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
                JSR PrintNewline
                ; TODO add detection for software interrupt or hardware interrupt; now only assumes software interrupt
                ; TODO add more debugging insights such as contents of status register, stack pointer, possibly program counter, etc.
@Break          
                JSR PrintImmediate
                ASC "   A = $"
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
                SBC	#$01    ; Decrement low byte of rtn address
                STA	$0102,X
                LDA	$0103,X
                SBC	#$00    ; Decrement high byte of rtn address (if no carry)
                STA	$0103,X

                LDA TA      ; restore A, X, and Y registers to continue execution
                LDX TX
                LDY TY

                RTI         ; return from interrupt

.INCLUDE "command_table.asm"
.INCLUDE "monitor.asm"
.INCLUDE "disassembler.asm"
.INCLUDE "assembler.asm"
.INCLUDE "xmodem.asm"