
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
                STA CommandBuffer + 1, X
                INX
                JMP @Loop
@Done:          STX CommandBuffer               ; store length in the beginning of command

PrintCommand:   JSR PrintImm
                ASCLN "Command length: "
                TXA
                JSR PrintByte
                JSR PrintNewline
                JSR PrintImm
                ASCLN "Command: "
PrintCommand2:  LDA #0
                STA CommandBuffer+1,x
                LDA #<CommandBuffer
                STA StrPtrLow
                LDA #>CommandBuffer
                STA StrPtrHi
                JSR Print
                RTS

MemoryDump:     JSR PrintImm
                ASCLN "Got MM!"
                RTS

MemoryModify:   JSR PrintImm
                ASCLN "Got MM!"
                RTS

STREQU:     LDY #$00        ;Compare strings, case-sensitive
            LDA ($FA),Y     ;Naturally, the zero flag is used to return if the strings are equal
            CMP ($FC),Y
            BEQ STREQU1
            RTS
STREQU1:    TAY
STREQULP:   LDA ($FC),Y
            AND #$7F
            STA $FF
            LDA ($FA),Y
            AND #$7F
            CMP $FF
            BNE STREQUEX
            DEY
            BNE STREQULP
STREQUEX:   RTS

PrintNewline:   PHA
                LDA #$0D
                JSR WriteChar
                LDA #$0A
                JSR WriteChar
                PLA
                RTS

Commands:
.byte 2, "MD", <MemoryDump           ; $00
.byte 2, "MM", <MemoryModify         ; $00
; .byte "MM", MemoryModify        ; $01
; .byte "MF", MemoryFill          ; $02
; .byte "ASM", Assemble           ; $03
; .byte "DIS", Disassmble         ; $04
; .byte "GO", RUN                 ; $05