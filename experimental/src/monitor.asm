
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

StrPtr1            = $0
StrPtr2            = $02

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
                BEQ @Done                       ; zero means end of line
                CMP #' '                        ; space means end of command, start of operands
                BEQ @Done
                STA CommandBuffer, X
                INX
                JMP @Loop
@Done:          STZ CommandBuffer, X            ; terminate string

PrintCommand:   
                JSR PrintNewline
                JSR PrintImm
                ASCLN "Command: "

                LDA #<CommandBuffer
                STA StrPtrLow
                LDA #>CommandBuffer
                STA StrPtrHi
                JSR Print
                JSR PrintNewline
                JSR PrintNewline

TestStrComp:    LDA #<CommandBuffer
                STA StrPtr1
                LDA #>CommandBuffer
                STA StrPtr1 + 1

                LDA #<TestStr
                STA StrPtr2
                LDA #>TestStr
                STA StrPtr2 + 1

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

Commands:
.byte "MD", 0
.byte "MM", 0
.byte "MF", 0
.byte "ASM", 0
.byte "DIS", 0
.byte "GO", 0

; CommandRoutines:
; .byte <MemoryDump, >MemoryDump
; .byte <MemoryModify, >MemoryModify

TestStr: .byte "123456", 0