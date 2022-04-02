; Clear all video RAM ($0000-$3FFF)
ZapVRAM:        LDA #0    ; start at $0000
		LDX #0
    		JSR SetupVRAMWriteAddress
		LDX #$40    ; count high
Nexf:           LDY #0      ; count low
		LDA #0
Fill:           JSR WriteVRAM ; write zero
		INY
		BNE Fill
		DEX
		BNE Nexf    ; 64*256
		RTS

; ---------------------------- Video Memory Dump ----------------------------
VMemoryDump:    LDA AmountOfArgs ; check whether we received the right amount of arguments
                CMP #1
                BCS @Valid
                JMP InvalidArgs
@Valid:         JSR ParseMDArgs
                LDA T5+1
                LDX T5
                JSR SetupVRAMReadAddress
                LDA #0          ; set zero flag
@PrintRange:    BNE @PrintData
                JSR PrintNewline
                JSR PrintIndent
                LDA T5 + 1
                JSR PrintByte
                LDA T5
                JSR PrintByte
                LDA #':'        ; ":".
                JSR WriteChar   ; Output it
@PrintData:     LDA #SP         ; Space
                JSR WriteChar   ; Output it
                JSR ReadVRAM
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

; ---------------------------- Video Memory Modify ----------------------------
VMemoryModify:  LDA AmountOfArgs
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
                LDA AmountOfArgs    ; Remove the adress from amount of args
                SEC
                SBC #1
                STA AmountOfArgs
                LDA T5+1
                LDX T5
                JSR SetupVRAMWriteAddress
                LDX #0
@Loop:          INY                 ; skip space
                JSR Read2Bytes
                LDA T6
                JSR WriteVRAM
                INX
                CPX AmountOfArgs
                BNE @Loop
                RTS

; Reads VRAM into A and delays for the next read (assumes 2mhz system)
ReadVRAM:       LDA VRAM
                NOP     ; 1 micro sec
                NOP     ; 1 micro sec
                RTS     ; 3 micro secs

; Writes A to VRAM and delays for the next write (assumes 2mhz system)
WriteVRAM:      STA VRAM
                NOP     ; 1 micro sec
                NOP     ; 1 micro sec
                RTS     ; 3 micro secs

; Set ups VRAM read address
; Input: A = most significant byte of address, X = least significant byte of address
; If address to set up is $20A0 -> A = $20 and X = $A0
SetupVRAMReadAddress:
		AND #%00111111  ; two MSBs must be 0 and 0 respectively during read setup
		STX VDPReg      ; setup VRAM address
		STA VDPReg      
		RTS

; Set ups VRAM write address
; Input: A = most significant byte of address, X = least significant byte of address
; If address to set up is $20A0 -> A = $20 and X = $A0
SetupVRAMWriteAddress:
		ORA #%01000000  ; two MSBs must be 0 and 1 respectively during write setup 
		STX VDPReg      ; setup VRAM address
		STA VDPReg
		RTS
