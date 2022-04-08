; ----------------------------- Memory Display -----------------------------
MemoryDump:     LDA AmountOfArgs ; check whether we received the right amount of arguments
                CMP #1
                BCS @Valid
                JMP InvalidArgs
@Valid:         JSR ParseMDArgs
                LDA #0          ; set zero flag
@PrintRange:    BNE @PrintData
                JSR PrintNewline
                JSR PrintIndent
                LDA T5 + 1
                JSR PrintByte
                LDA T5
                JSR PrintByte
                LDA #':'        ; ":"
                JSR WriteChar   ; Output it
@PrintData:     LDA #SP         ; Space
                JSR WriteChar   ; Output it
                LDA (T5)        ; Get byte
                JSR PrintByte   ; Output it
                LDA T5          ; Compare with ohter operand to check whether we're done printing the range
                CMP T6
                LDA T5 + 1
                SBC T6 + 1
                BCS @Done       ; Not less, so no more data to output
                INC T5          ; Increment to the next address to read      
                BNE @Mod16Check
                INC T5 + 1
@Mod16Check:    LDA T5
                AND #$0F
                BPL @PrintRange     ; Always
@Done:          RTS

; Syntax: MD C000 C500
; First address will be in T5 and second address in T6
ParseMDArgs:    LDA #<ArgsBuffer
                STA P1
                LDA #>ArgsBuffer
                STA P1 + 1
                LDY #0
                JSR Read2Bytes      ; read first address from the ArgsBuffer
                LDA T6
                STA T5              ; store first one in T5
                LDA T6 + 1
                STA T5 + 1
                LDA AmountOfArgs    ; Did we get a range?
                CMP #$2             ; 2 arguments?
                BCC @Done
                INY                 ; Got another argument
                JSR Read2Bytes      ; Read it as an address
@Done:          RTS

; ---------------------------- Memory Modify ----------------------------
MemoryModify:   LDA AmountOfArgs
                CMP #2
                BCS @Valid
                JMP InvalidArgs
@Valid:         LDA #<ArgsBuffer
                STA P1
                LDA #>ArgsBuffer
                STA P1 + 1
                LDY #0
                JSR Read2Bytes     ; Read address to modify
                LDA T6
                STA T5              ; Store in T5 so T6 can be reused
                LDA T6 + 1
                STA T5 + 1
                LDX #0
                LDA AmountOfArgs    ; Remove the adress from amount of args
                SEC
                SBC #1
                STA AmountOfArgs
@Loop:          INY                 ; skip space
                JSR Read2Bytes
                PHY                 ; TXY
                TXA
                TAY
                LDA T6
                STA (T5), Y
                PLY
                INX
                CPX AmountOfArgs
                BNE @Loop
                RTS

; ------------------------- Run (Execute program) -----------------------
Run:            LDA AmountOfArgs
                CMP #1
                BCS @Valid
                JMP InvalidArgs
@Valid:         LDA #<ArgsBuffer
                STA P1
                LDA #>ArgsBuffer
                STA P1 + 1
                LDY #0
                JSR Read2Bytes     ; Read address to disassemble from
                JSR @Exec
                RTS
@Exec:          JMP (T6)

; ------------------------- Memory Fill -----------------------
MemoryFill:     LDA AmountOfArgs
                CMP #3
                BCS @Valid
                JMP InvalidArgs
@Valid          LDA #<ArgsBuffer
                STA P1
                LDA #>ArgsBuffer
                STA P1 + 1
                LDY #0
                JSR Read2Bytes      ; read first address from the ArgsBuffer
                LDA T6
                STA T4              ; store first one in T4
                LDA T6 + 1
                STA T4 + 1
                INY                 ; Got another argument
                JSR Read2Bytes      ; Read it as an address
                LDA T6
                STA T5              ; store second one in T5
                LDA T6 + 1
                STA T5 + 1
                INY
                JSR Read2Bytes
                LDA T6
                STA T1
@Loop:          LDA T1
                STA (T4)
                LDA T4          
                CMP T5
                LDA T4 + 1
                SBC T5 + 1
                BCS @Done       ; Not less, so no more data to output
                INC T4          ; Increment to the next address to read      
                BNE @Loop
                INC T4 + 1
                JMP @Loop
@Done:          RTS