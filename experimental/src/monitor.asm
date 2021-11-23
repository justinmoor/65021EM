
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
PrintByte = $C00F

StrPtr1 = $0
StrPtr2 = $02

CommandBuffer = $300
ArgBuffer = $400

Start:          JSR PrintPrompt
                JSR GetLine     
                CMP #CR
                BEQ ReadCommand
                RTS

; read the command from the input buffer into the command buffer
ReadCommand:    JSR PrintNewline
                LDX #0
@Loop:          LDA InputBuffer, X
                BEQ @Done                       ; zero means end of line
                CMP #' '                        ; space means end of command, start of arguments
                BEQ ReadArguments
                STA CommandBuffer, X
                INX
                JMP @Loop
@Done:          STZ CommandBuffer, X            ; terminate command buffer with 0
                JMP LookupCommand

; if there are arguments we read those into the argument buffer for easy parsing later
ReadArguments:  STZ CommandBuffer, X            ; terminate command buffer, continue with args
                LDY #0                          ; index in args buffer
                INX                             ; continue current index in input buffer
@Loop:          LDA InputBuffer, X
                STA ArgBuffer, Y
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

MemoryDump:     JSR PrintImm
                ASCLN "Got MD!"
                RTS

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
