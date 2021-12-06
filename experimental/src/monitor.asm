
.SETCPU "65C02"
.INCLUDE "../../src/variables.asm"

.MACRO ASCLN text
    .BYTE text, $0D, $0A, 0
.ENDMACRO

.ORG $1000

WriteChar = $C000
GetLine = $C006
Print = $C009
PrintImm = $C00C
; PrintByte = $C00F

StrPtr1 = $0
StrPtr2 = $02

CommandBuffer = $300
ArgsBuffer = $400
AmountOfArgs = $40

XL = $50
XH = $51

Start:          JSR PrintPrompt
                JSR GetLine     
                CMP #CR
                BEQ ReadCommand
                RTS

; read the command from the input buffer into the command buffer
ReadCommand:    LDX #0
@Loop:          LDA InputBuffer, X  
                BEQ @Done                       ; zero means end of line
                CMP #' '                        ; space means end of command, start of arguments
                BEQ ReadArguments
                STA CommandBuffer, X
                INX
                JMP @Loop
@Done:          STZ CommandBuffer, X            ; terminate command buffer with 0
                JMP LookupCommand

; If there are arguments we read those into the argument buffer for easy parsing later
ReadArguments:  STZ CommandBuffer, X            ; terminate command buffer, continue with args
                LDA #1
                STA AmountOfArgs                ; at least one
                LDY #0                          ; index in args buffer
                INX                             ; continue current index in input buffer
@Loop:          LDA InputBuffer, X
                STA ArgsBuffer, Y
                CMP #' '                        ; is space?
                BNE @Continue
                INC AmountOfArgs                ; yes, increment the amount of args
@Continue:      CMP #$0
                BEQ LookupCommand               ; reuse 0 terminated line as termination in args buffer
                INX
                INY
                JMP @Loop

LookupCommand:  LDA #<CommandBuffer             ; prepare string compare for each command table entry
                STA StrPtr1                     
                LDA #>CommandBuffer
                STA StrPtr1 + 1
                LDX #0
@Loop:          LDA CommandTable, X             ; string compare current entry with what's in the command buffer
                STA StrPtr2                     
                LDA CommandTable + 1, X
                STA StrPtr2 + 1
                JSR StrComp
                BEQ @Hit                        ; got a hit, let's branch!
                INX                             ; no hit, increment 4 times because each entry in 4 bytes
                INX
                INX
                INX
                BNE @Loop
                JSR PrintImm                    ; no hit at all
                ASCLN "INVALID COMMAND"
                JMP Start

@Hit:           JSR ExecCommand
                JMP Start

ExecCommand:    JMP (CommandTable + 2, X)       ; jump to the routine from the table

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

MemoryDump:     JSR ParseMDArgs
                LDA #00
@PrintRange:    BNE @PrintData
                JSR PrintNewline
                LDA #$20
                JSR WriteChar    
                LDA #$20
                JSR WriteChar
                LDA T5 + 1
                JSR PrintByte
                LDA T5
                JSR PrintByte
                LDA #':'        ; ":".
                JSR WriteChar   ; Output it
@PrintData:     LDA #SP         ; Space
                JSR WriteChar   ; Output it
                LDA (T5)        ; Get byte
                JSR PrintByte
@XAMNext:       LDA T5
                CMP T6
                LDA T5 + 1
                SBC T6 + 1
                BCS @Done             ; not less, so no more data to output
                INC T5
                BNE @Mod8Check
                INC T5 + 1
@Mod8Check:     LDA T5
                AND #$0F
                BPL @PrintRange     ; always
@Done:          RTS

; Syntax: MD C000 C500
; First address will be in T5 and second address in T6
ParseMDArgs:    LDA #<ArgsBuffer
                STA P1
                LDA #>ArgsBuffer
                STA P1 + 1
                LDY #0
                JSR ReadAddress     ; read 2 addresses from the ArgsBuffer
                LDA T6
                STA T5              ; store first one in T5
                LDA T6 + 1
                STA T5 + 1
                LDA AmountOfArgs    ; Did we get a range?
                CMP #$2             ; 2 arguments?
                BNE @Done
                INY                 ; Got another argument
                JSR ReadAddress     ; Read it as an address
@Done:          RTS

; will read an address in any byte format; C000, C00, C0, C, 000C
; result will be put in T4. Digits read will be in Y
ReadAddress:    
                ; LDY #00
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
                ROL T6+1        ; Rotate into MSD's.
                DEX             ; Done 4 shifts?
                BNE @HexShift   ; No, loop.
                INY             ; Advance text index.
                BNE @NextHex    ; Always taken. Check next character for hex.
@NotHex:        RTS

MemoryModify:   JSR PrintImm
                ASCLN "Got MM!"
                RTS

CommandTable:
.byte <MD, >MD, <MemoryDump, >MemoryDump
.byte <MM, >MM, <MemoryModify, >MemoryModify

Commands:
MD: .byte "MD", 0
MM: .byte "MM", 0
MF: .byte "MF", 0
ASM: .byte "ASM", 0
DIS: .byte "DIS", 0
GO: .byte "GO", 0

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
                CMP #'z' + 1              ; Is it 'z' or lower?
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