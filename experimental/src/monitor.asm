
.SETCPU "65C02"

.MACRO ASCLN text
    .BYTE text, $0D, $0A, 0
.ENDMACRO

.ORG $1000

WriteChar = $C000
GetLine = $C006
Print = $C009
PrintImm = $C00C
PrintByte = $C00F

CR = $0D
StrPtrLow   = $06       ; low address of string to print
StrPtrHi    = $07

Str1            = $0
Str2            = $02

InputBuffer   = $200
CommandBuffer = $300
OperandBuffer = $400

Start:          JSR GetLine     
                CMP #CR
                BEQ ReadCommand
                RTS

; read the command from the input buffer
ReadCommand:    LDX #0
@Loop:          LDA InputBuffer, X
                CMP #' '                        ; space means end of command, start of operands
                BEQ @Done
                STA CommandBuffer, X
                INX
                JMP @Loop
@Done:          STZ CommandBuffer, X            ; terminate string

PrintCommand:   
                ; JSR PrintImm
                ; ASCLN "Command length: "
                ; TXA
                ; JSR PrintByte
                JSR PrintNewline
                JSR PrintImm
                ASCLN "Command: "
PrintCommand2:  
                ; LDA #0
                ; STA CommandBuffer+1,x
                LDA #<CommandBuffer
                STA StrPtrLow
                LDA #>CommandBuffer
                STA StrPtrHi
                JSR Print
                JSR PrintNewline
                JSR PrintNewline

TestStrComp:    LDA #<CommandBuffer
                STA Str1
                LDA #>CommandBuffer
                STA Str1 + 1

                LDA #<Kak
                STA Str2
                LDA #>Kak
                STA Str2 + 1

                JSR StrComp
                BEQ @Eq
                JSR PrintImm
                ASCLN "Not equal"
                RTS
@Eq:            JSR PrintImm
                ASCLN "Equal"
                RTS



PrintNewline:   PHA
                LDA #$0D
                JSR WriteChar
                LDA #$0A
                JSR WriteChar
                PLA
                RTS

; Zero flag is set if equal
; Destroys A and Y register 
StrComp:
                LDY #0
@Loop:          LDA (Str1), Y
                BEQ @2          ; got 0
                CMP (Str2), Y
                BNE @Done       ; current char is not equal
                INY
                BNE @Loop
                INC Str1 + 1
                INC Str2 + 1
                BCS @Loop       ; always
@2:             CMP (Str2), Y   ; compare last char
@Done:          RTS

Commands:
.byte "MD", 0
.byte "MM", 0
; .byte "MF", MemoryFill          ; $02
; .byte "ASM", Assemble           ; $03
; .byte "DIS", Disassmble         ; $04
; .byte "GO", RUN                 ; $05

; CommandRoutines:
; .byte <MemoryDump, >MemoryDump
; .byte <MemoryModify, >MemoryModify
