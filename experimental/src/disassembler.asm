
; 6502/65C02 Disassembler
;
; Credits to Jeff Tranter <tranter@pobox.com>

LinesToDisAssem = $50

Disassembler:   LDA AmountOfArgs    ; check whether we received the right amount of arguments
                CMP #1
                BCS @Valid
                JMP InvalidArgs
@Valid:         LDA #20             ; default amount of lines to disassemble
                STA LinesToDisAssem
                LDA #<ArgsBuffer
                STA P1
                LDA #>ArgsBuffer
                STA P1 + 1
                LDY #0
                JSR Read2Bytes     ; Read address to disassemble from
                LDA T6    
                STA AddrD
                LDA T6+1
                STA AddrD+1
                LDA AmountOfArgs    ; Is an amount of lines specified?
                CMP #$2             ; 2 arguments?
                BCC @StartDisassembler
                INY                ; Got another argument
                JSR Read2Bytes     ; Read it as an address
                LDA T6
                STA LinesToDisAssem

@StartDisassembler:
                JSR PrintNewline
                JSR PrintNewline
                JSR PrintImm              ; Print error message
                ASC "STARTING DISASSEMBLY AT ADDRESS $"
                LDX AddrD
                LDY AddrD+1
                JSR PrintAddress
                JSR PrintNewline
Outer:
                JSR PrintNewline
                LDA LinesToDisAssem
@Loop:
                PHA
                JSR Disassemble
                PLA
                SEC
                SBC #1
                BNE @Loop
@SpaceOrEscape:
                JSR ReadChar
                BCC @SpaceOrEscape
                CMP #SP
                BEQ Outer
                CMP #ESC
                BNE @SpaceOrEscape
                RTS

; Disassemble instruction at address AddrD (low) / AddrD+1 (high). On
; return AddrD/AddrD+1 points to next instruction so it can be called
; again.
Disassemble:
                LDX #0
                LDA (AddrD,X)          ; get instruction op code
                STA OPCODE
                BMI @Upper            ; if bit 7 set, in upper half of table
                ASL A                 ; double it since table is two bytes per entry
                TAX
                LDA OPCODES1,X        ; get the instruction type (e.g. OP_LDA)
                STA OP                ; store it
                INX
                LDA OPCODES1,X        ; get addressing mode
                STA AM                ; store it
                JMP Around
@Upper: 
                ASL A                 ; double it since table is two bytes per entry
                TAX
                LDA OPCODES2,X        ; get the instruction type (e.g. OP_LDA)
                STA OP                ; store it
                INX
                LDA OPCODES2,X        ; get addressing mode
                STA AM                ; store it
Around:
                TAX                   ; put addressing mode in X
                LDA LENGTHS,X         ; get instruction length given addressing mode
                STA LEN               ; store it
                LDX AddrD
                LDY AddrD+1
                JSR PrintAddress      ; print address
                LDX #3
                JSR PrintSpaces       ; then three spaces
                LDA OPCODE            ; get instruction op code
                JSR PrintByte         ; display the opcode byte
                JSR PrintSpace
                LDA LEN               ; how many bytes in the instruction?
                CMP #3
                BEQ Three
                CMP #2
                BEQ Two
                LDX #5
                JSR PrintSpaces
                JMP One
Two:
                LDY #1
                LDA (AddrD),Y          ; get 1st operand byte
                JSR PrintByte         ; display it
                LDX #3
                JSR PrintSpaces
                JMP One
Three:
                LDY #1
                LDA (AddrD),Y          ; get 1st operand byte
                JSR PrintByte         ; display it
                JSR PrintSpace
                LDY #2
                LDA (AddrD),Y          ; get 2nd operand byte
                JSR PrintByte         ; display it
One:              
                LDX #4
                JSR PrintSpaces
                LDA OP                ; get the op code
                ASL A                 ; multiply by 2
                CLC
                ADC OP                ; add one more to multiply by 3 since table is three bytes per entry
                TAX
                LDY #3
Mnemonic:
                LDA MNEMONICS,X       ; print three chars of mnemonic
                JSR WriteChar
                INX
                DEY
                BNE Mnemonic
                ; Display any operands based on addressing mode
                LDA OP                ; is it RMB or SMB?
                CMP #OP_RMB
                BEQ DOMB
                CMP #OP_SMB
                BNE TryBB
DOMB:
                LDA OPCODE            ; get the op code
                AND #$70              ; Upper 3 bits is the bit number
                LSR                   
                LSR
                LSR
                LSR
                JSR PrintByte
                LDX #2
                JSR PrintSpaces
                JSR PrintDollar
                LDY #1
                LDA (AddrD),Y          ; get 1st operand byte (low address)
                JSR PrintByte         ; display it
                JMP DoneOps
TryBB:
                LDA OP                ; is it BBR or BBS?
                CMP #OP_BBR
                BEQ DOBB
                CMP #OP_BBS
                BNE TryImp
DOBB:           ; handle special BBRn and BBSn instructions
                LDA OPCODE            ; get the op code
                AND #$70              ; Upper 3 bits is the bit number
                LSR                   
                LSR
                LSR
                LSR
                JSR PrintByte
                LDX #2
                JSR PrintSpaces
                JSR PrintDollar
                LDY #1
                LDA (AddrD),Y          ; get 1st operand byte (address)
                JSR PrintByte         ; display it
                LDA #','
                JSR WriteChar
                JSR PrintDollar
                ; Handle relative addressing
                ; Destination address is Current address + relative (sign extended so upper byte is $00 or $FF) + 3
                LDY #2
                LDA (AddrD),Y          ; get 2nd operand byte (relative branch offset)
                STA REL               ; save low byte of offset
                BMI @Negative              ; if negative, need to sign extend
                LDA #0                ; high byte is zero
                BEQ @Add
@Negative:
                LDA #$FF              ; negative offset, high byte if $FF
@Add:
                STA REL+1             ; save offset high byte
                LDA AddrD              ; take adresss
                CLC
                ADC REL               ; add offset
                STA DEST              ; and store
                LDA AddrD+1            ; also high byte (including carry)
                ADC REL+1
                STA DEST+1
                LDA DEST              ; now need to add 3 more to the address
                CLC
                ADC #3
                STA DEST
                LDA DEST+1
                ADC #0                ; add any carry
                STA DEST+1
                JSR PrintByte         ; display high byte
                LDA DEST
                JSR PrintByte         ; display low byte
                JMP DoneOps
TryImp:
                LDA AM
                CMP #AM_IMPLICIT
                BNE TryInv
                JMP DoneOps           ; no operands
TryInv: 
                CMP #AM_INVALID
                BNE @TryAcc
                JMP DoneOps           ; no operands
@TryAcc:
                LDX #3
                JSR PrintSpaces
                CMP #AM_ACCUMULATOR
                BNE @TryImm
                JMP DoneOps
@TryImm:
                CMP #AM_IMMEDIATE
                BNE TryZP
                LDA #'#'
                JSR WriteChar
                JSR PrintDollar
                LDY #1
                LDA (AddrD),Y          ; get 1st operand byte (low address)
                JSR PrintByte         ; display it
                JMP DoneOps
TryZP:
                CMP #AM_ZEROPAGE
                BNE TryZPX
                JSR PrintDollar
                LDY #1
                LDA (AddrD),Y          ; get 1st operand byte (low address)
                JSR PrintByte         ; display it
                JMP DoneOps
TryZPX:
                CMP #AM_ZEROPAGE_X
                BNE TryZPY
                LDY #1
                LDA (AddrD),Y          ; get 1st operand byte (address)
                JSR PrintDollar
                JSR PrintByte         ; display it
                JSR PrintCommaX
                JMP DoneOps       
TryZPY:
                CMP #AM_ZEROPAGE_Y
                BNE TryRel
                LDY #1
                LDA (AddrD),Y          ; get 1st operand byte (address)
                JSR PrintByte         ; display it
                JSR PrintCommaY
                JMP DoneOps       
TryRel:
                CMP #AM_RELATIVE
                BNE TryAbs
                JSR PrintDollar
                ; Handle relative addressing
                ; Destination address is Current address + relative (sign extended so upper byte is $00 or $FF) + 2
                LDY #1
                LDA (AddrD),Y          ; get 1st operand byte (relative branch offset)
                STA REL               ; save low byte of offset
                BMI @Negative               ; if negative, need to sign extend
                LDA #0                ; high byte is zero
                BEQ @Add
@Negative:
                LDA #$FF              ; negative offset, high byte if $FF
@Add:
                STA REL+1             ; save offset high byte
                LDA AddrD              ; take adresss
                CLC
                ADC REL               ; add offset
                STA DEST              ; and store
                LDA AddrD+1            ; also high byte (including carry)
                ADC REL+1
                STA DEST+1
                LDA DEST              ; now need to add 2 more to the address
                CLC
                ADC #2
                STA DEST
                LDA DEST+1
                ADC #0                ; add any carry
                STA DEST+1
                JSR PrintByte         ; display high byte
                LDA DEST
                JSR PrintByte         ; display low byte
                JMP DoneOps
TryAbs:
                CMP #AM_ABSOLUTE
                BNE TryAbsX
                JSR PrintDollar
                LDY #2
                LDA (AddrD),Y          ; get 2nd operand byte (high address)
                JSR PrintByte         ; display it
                LDY #1
                LDA (AddrD),Y          ; get 1st operand byte (low address)
                JSR PrintByte         ; display it
                JMP DoneOps
TryAbsX:
                CMP #AM_ABSOLUTE_X
                BNE TryAbsY
                JSR PrintDollar
                LDY #2
                LDA (AddrD),Y          ; get 2nd operand byte (high address)
                JSR PrintByte         ; display it
                LDY #1
                LDA (AddrD),Y          ; get 1st operand byte (low address)
                JSR PrintByte         ; display it
                JSR PrintCommaX
                JMP DoneOps
TryAbsY:
                CMP #AM_ABSOLUTE_Y
                BNE TryInd
                JSR PrintDollar
                LDY #2
                LDA (AddrD),Y          ; get 2nd operand byte (high address)
                JSR PrintByte         ; display it
                LDY #1
                LDA (AddrD),Y          ; get 1st operand byte (low address)
                JSR PrintByte         ; display it
                JSR PrintCommaY
                JMP DoneOps
TryInd:
                CMP #AM_INDIRECT
                BNE TryIndXInd
                JSR PrintLParenDollar
                LDY #2
                LDA (AddrD),Y          ; get 2nd operand byte (high address)
                JSR PrintByte         ; display it
                LDY #1
                LDA (AddrD),Y          ; get 1st operand byte (low address)
                JSR PrintByte         ; display it
                JSR PrintRParen
                JMP DoneOps
TryIndXInd:
                CMP #AM_INDEXED_INDIRECT
                BNE TryIndIndX
                JSR PrintLParenDollar
                LDY #1
                LDA (AddrD),Y          ; get 1st operand byte (low address)
                JSR PrintByte         ; display it
                JSR PrintCommaX
                JSR PrintRParen
                JMP DoneOps
TryIndIndX:
                CMP #AM_INDIRECT_INDEXED
                BNE TryIndZ
                JSR PrintLParenDollar
                LDY #1
                LDA (AddrD),Y          ; get 1st operand byte (low address)
                JSR PrintByte         ; display it
                JSR PrintRParen
                JSR PrintCommaY
                JMP DoneOps
TryIndZ:
                CMP #AM_INDIRECT_ZEROPAGE ; [65C02 only]
                BNE TryAbIndInd
                JSR PrintLParenDollar
                LDY #1
                LDA (AddrD),Y          ; get 1st operand byte (low address)
                JSR PrintByte         ; display it
                JSR PrintRParen
                JMP DoneOps
TryAbIndInd:
                CMP #AM_ABSOLUTE_INDEXED_INDIRECT ; [65C02 only]
                BNE DoneOps
                JSR PrintLParenDollar
                LDY #2
                LDA (AddrD),Y          ; get 2nd operand byte (high address)
                JSR PrintByte         ; display it
                LDY #1
                LDA (AddrD),Y          ; get 1st operand byte (low address)
                JSR PrintByte         ; display it
                JSR PrintCommaX
                JSR PrintRParen
                JMP DoneOps
DoneOps:
                JSR PrintNewline
                LDA AddrD              ; update address to next instruction
                CLC
                ADC LEN
                STA AddrD
                LDA AddrD+1
                ADC #0                ; to add carry
                STA AddrD+1
                RTS

;------------------------------------------------------------------------
; Utility functions

; Print a dollar sign
; Registers changed: None
PrintDollar:
                PHA
                LDA #'$'
                JSR WriteChar
                PLA
                RTS

; Print ",X"
; Registers changed: None
PrintCommaX:
                PHA
                LDA #','
                JSR WriteChar
                LDA #'X'
                JSR WriteChar
                PLA
                RTS

; Print ",Y"
; Registers changed: None
PrintCommaY:
                PHA
                LDA #','
                JSR WriteChar
                LDA #'Y'
                JSR WriteChar
                PLA
                RTS

; Print "($"
; Registers changed: None
PrintLParenDollar:
                PHA
                LDA #'('
                JSR WriteChar
                LDA #'$'
                JSR WriteChar
                PLA
                RTS

; Print a right parenthesis
; Registers changed: None
PrintRParen:
                PHA
                LDA #')'
                JSR WriteChar
                PLA
                RTS

; Print number of spaces in X
; Registers changed: X
PrintSpaces:
                PHA
                LDA #SP
@Loop:          JSR WriteChar
                DEX
                BNE @Loop
                PLA
                RTS
