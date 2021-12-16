; 6502/65C02 Mini Assembler
; Assemble code entered a line at a time.
; 
; Credits to Jeff Tranter
; Code modified to work on the 65021EM
;
; Mini assembler syntax format:
;
; XXXX: instruction
; XXXX: instruction
; XXXX: <Esc>

; Example:
;
; 6000: NOP
; 6001: LDA #68
; 6003: JSR C000
; 6006: DEX
; 6007: RTS
; 6009: <Esc>
;
; Restrictions:
; - no symbols or labels
; - all values in hex, 2 or 4 digits

Assembler:      LDA #<ArgsBuffer
                STA P1
                LDA #>ArgsBuffer
                STA P1 + 1
                LDY #0
                JSR Read2Bytes     ; Read address to disassemble from
                LDA T6    
                STA AddrA
                LDA T6+1
                STA AddrA+1

RunAssembler:
                JSR PrintNewline
                JSR PrintNewline
                JSR PrintImm              
                ASC "STARTING ASSEMBLING AT ADDRESS $" 
                LDX AddrA
                LDY AddrA+1
                JSR PrintAddress
                JSR PrintNewline
AssembleLine:
                LDX AddrA              ; output address
                LDY AddrA+1
                JSR PrintAddress
                LDA #':'                ; Output colon
                JSR WriteChar
                JSR PrintSpace          ; And space
                JSR GetLine             ; Get user input
                CMP #ESC				; Escape?
                BEQ EscPressed          ; Yes, return
@ProcessInput:   			            ; No escape, that implies an enter, sp start processing
                STX T1					; Save total length of input in T1		
                LDX #0                  ; copy first part of the input buffer into the Mnem
                LDA InputBuffer, X
                STA Mnem, X
                INX
                LDA InputBuffer, X
                STA Mnem, X
                INX
                LDA InputBuffer, X
                STA Mnem, X

                ; start storing operands in OprBufif we have any
                LDA T1						; get total length of input
                CMP #3
                BNE @GotOperand				; we have more than 3 characters, so also an operand
                STZ OprBuf                  ; we got no operand, just store 0 in the first byte of IN
                JMP Parse                   ; start parsing the input

; The assembler assumes that the operand is stored in IN, where the first byte is the length of the operand. We keep track of the length
; by using the Y register. After copying the operand in IN, we store Y in the first byte of IN
@GotOperand:                            
                LDY #0					; keep track of length of operand
                INX						; skip space
                INX
@Loop:	
                CPX T1
                BEQ @Done
                LDA InputBuffer, X
                STA OprBuf+ 1, Y
                INX
                INY
                JMP @Loop
@Done:          STY OprBuf
                JMP Parse

EscPressed:     JMP PrintNewline             ; Return via caller	

Parse:
                JSR LookupMnemonic      ; Look up mnemonic to see if it is valid
                LDA OP                  ; Get the returned opcode
                CMP #OP_INV             ; Not valid?
                BNE OpOk                ; Branch if okay
                JSR PrintImm            ; Not a valid mnemonic
                ASCLN "Invalid instruction"
                JSR PrintNewline
                JMP AssembleLine		

; Mnemonic is valid. Does instruction use implicit addressing mode (i.e. no operand needed)?
OpOk:
                LDA #AM_IMPLICIT
                STA AM
                JSR CheckAddressingModeValid
                BEQ GetOperands
                JMP GenerateCode    ; It is implicit, so we can jump to generating the code

; Not implicit addressing mode. Need to get operand from user.
GetOperands:
; Check for addressing mode. Have already checked for implicit.
; AM_ACCUMULATOR, e.g. LSR A
; Operand is just "A"
                LDA OprBuf                       ; Get length
                CMP #1                        ; Is it 1?
                BNE TryImm
                LDA OprBuf+1                      ; Get first char of operand
                JSR ToUpper
                CMP #'A'                      ; Is it 'A'?
                BNE TryImm
                LDA #AM_ACCUMULATOR           ; Yes, is is accumulator mode
                STA AM                        ; Save it
                JMP GenerateCode

; AM_IMMEDIATE, e.g. LDA #nn
; Operand is '#' followed by 2 hex digits.
TryImm:
                LDA OprBuf                       ; Get length
                CMP #3                        ; Is it 3?
                BNE TryZeroPage
                LDA OprBuf+1                      ; Get first char of operand
                CMP #'#'                      ; is it '#'?
                BNE TryZeroPage
                LDA OprBuf+2                      ; Get second char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ TryZeroPage
                LDA OprBuf+3                      ; Get third char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ TryZeroPage
                LDA #AM_IMMEDIATE             ; Yes, this is immediate mode
                STA AM                        ; Save it
                LDA OprBuf+2                      ; Get operand characters
                LDY OprBuf+3
                JSR Hex2Bin                     ; Convert to binary
                STA Operand                   ; Save it as the operand
                JMP GenerateCode

; AM_ZEROPAGE e.g. LDA nn
; Operand is 2 hex digits.
TryZeroPage:
                LDA OprBuf                       ; Get length
                CMP #2                        ; Is it 2?
                BNE TryAbsRel
                LDA OprBuf+1                      ; Get first char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ TryAbsRel
                LDA OprBuf+2                      ; Get second char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ TryAbsRel
                LDA #AM_ZEROPAGE              ; Yes, this is zero page
                STA AM                        ; Save it
                LDA OprBuf+1                      ; Get operand characters
                LDY OprBuf+2
                JSR Hex2Bin                     ; Convert to binary
                STA Operand                   ; Save it as the operand
                JMP GenerateCode

; AM_ABSOLUTE, e.g. LDA nnnn or AM_RELATIVE, e.g. BEQ nnnn
; Operand is 4 hex digits.
TryAbsRel:
                LDA OprBuf                       ; Get length
                CMP #4                        ; Is it 4?
                BNE TryZeroPageX
                LDA OprBuf+1                      ; Get first char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ TryZeroPageX
                LDA OprBuf+2                      ; Get second char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ TryZeroPageX
                LDA OprBuf+3                      ; Get third char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ TryZeroPageX
                LDA OprBuf+4                      ; Get fourth char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ TryZeroPageX

                ; It could be absolute or relative, depending on the instruction.
                ; Test both to see which one, if any, is valid.
                LDA #AM_ABSOLUTE              ; Try absolute addressing mode
                STA AM                        ; Save it
                JSR CheckAddressingModeValid
                BEQ TryRelative               ; No, try relative

Save2Operands:
                LDA OprBuf+1                      ; Get operand characters
                LDY OprBuf+2
                JSR Hex2Bin             ; Convert to binary
                STA Operand+1                 ; Save it as the operand
                LDA OprBuf+3                      ; Get operand characters
                LDY OprBuf+4
                JSR Hex2Bin             ; Convert to binary
                STA Operand                   ; Save it as the operand
                JMP GenerateCode

TryRelative:
                LDA #AM_RELATIVE              ; Try relative addressing mode
                STA AM                        ; Save it
                JSR CheckAddressingModeValid
                BEQ TryZeroPageX              ; No, try other modes
                JMP Save2Operands

; AM_ZEROPAGE_X e.g. LDA nn,X
; Operand is 2 hex digits followed by ,X
TryZeroPageX:
                LDA OprBuf                       ; Get length
                CMP #4                        ; Is it 4?
                BNE TryZeroPageY
                LDA OprBuf+1                      ; Get first char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ TryZeroPageY
                LDA OprBuf+2                      ; Get second char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ TryZeroPageY
                LDA OprBuf+3                      ; Get third char of operand
                CMP #','                      ; Is it a comma?
                BNE TryZeroPageY
                LDA OprBuf+4                      ; Get fourth char of operand
                JSR ToUpper
                CMP #'X'                      ; Is it an X?
                BNE TryZeroPageY
                LDA #AM_ZEROPAGE_X            ; Yes, this is zero page X
                STA AM                        ; Save it
                LDA OprBuf+1                      ; Get operand characters
                LDY OprBuf+2
                JSR Hex2Bin             ; Convert to binary
                STA Operand                   ; Save it as the operand
                JMP GenerateCode

; AM_ZEROPAGE_Y e.g. LDA nn,Y
; 2 hex digits followed by ,Y
TryZeroPageY:
                LDA OprBuf                       ; Get length
                CMP #4                        ; Is it 4?
                BNE TryAbsoluteX
                LDA OprBuf+1                      ; Get first char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ TryAbsoluteX
                LDA OprBuf+2                      ; Get second char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ TryAbsoluteX
                LDA OprBuf+3                      ; Get third char of operand
                CMP #','                      ; Is it a comma?
                BNE TryAbsoluteX
                LDA OprBuf+4                      ; Get fourth char of operand
                JSR ToUpper
                CMP #'Y'                      ; Is it an Y?
                BNE TryAbsoluteX
                LDA #AM_ZEROPAGE_Y            ; Yes, this is zero page Y
                STA AM                        ; Save it
                LDA OprBuf+1                      ; Get operand characters
                LDY OprBuf+2
                JSR Hex2Bin             ; Convert to binary
                STA Operand                   ; Save it as the operand
                JMP GenerateCode

; AM_ABSOLUTE_X, e.g. LDA nnnn,X
; 4 hex digits followed by ,X
TryAbsoluteX:
                LDA OprBuf                       ; Get length
                CMP #6                        ; Is it 6?
                BNE TryAbsoluteY
                LDA OprBuf+1                      ; Get first char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ TryAbsoluteY
                LDA OprBuf+2                      ; Get second char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ TryAbsoluteY
                LDA OprBuf+3                      ; Get third char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ TryAbsoluteY
                LDA OprBuf+4                      ; Get fourth char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ TryAbsoluteY
                LDA OprBuf+5
                CMP #','
                BNE TryAbsoluteY
                LDA OprBuf+6
                JSR ToUpper
                CMP #'X'
                BNE TryAbsoluteY
                LDA #AM_ABSOLUTE_X
                STA AM
                LDA OprBuf+1                      ; Get operand characters
                LDY OprBuf+2
                JSR Hex2Bin             ; Convert to binary
                STA Operand+1                 ; Save it as the operand
                LDA OprBuf+3                      ; Get operand characters
                LDY OprBuf+4
                JSR Hex2Bin             ; Convert to binary
                STA Operand                   ; Save it as the operand
                JMP GenerateCode

; AM_ABSOLUTE_Y, e.g. LDA nnnn,Y
; 4 hex digits followed by ,Y
TryAbsoluteY:
                LDA OprBuf                       ; Get length
                CMP #6                        ; Is it 6?
                BNE TryIndexedIndirect
                LDA OprBuf+1                      ; Get first char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ TryIndexedIndirect
                LDA OprBuf+2                      ; Get second char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ TryIndexedIndirect
                LDA OprBuf+3                      ; Get third char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ TryIndexedIndirect
                LDA OprBuf+4                      ; Get fourth char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ TryIndexedIndirect
                LDA OprBuf+5
                CMP #','
                BNE TryIndexedIndirect
                LDA OprBuf+6
                JSR ToUpper
                CMP #'Y'
                BNE TryIndexedIndirect
                LDA #AM_ABSOLUTE_Y
                STA AM
                LDA OprBuf+1                      ; Get operand characters
                LDY OprBuf+2
                JSR Hex2Bin             ; Convert to binary
                STA Operand+1                 ; Save it as the operand
                LDA OprBuf+3                      ; Get operand characters
                LDY OprBuf+4
                JSR Hex2Bin             ; Convert to binary
                STA Operand                   ; Save it as the operand
                JMP GenerateCode

; AM_INDEXED_INDIRECT, e.g. LDA (nn,X)
TryIndexedIndirect:
                LDA OprBuf                       ; Get length
                CMP #6                        ; Is it 6?
                BNE TryIndirectIndexed
                LDA OprBuf+1                      ; Get first char of operand
                CMP #'('
                BNE TryIndirectIndexed
                LDA OprBuf+2                      ; Get second char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ TryIndirectIndexed
                LDA OprBuf+3                      ; Get third char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ TryIndirectIndexed
                LDA OprBuf+4                      ; Get fourth char of operand
                CMP #','                      ; Is it a comma?
                BNE TryIndirectIndexed
                LDA OprBuf+5                      ; Get fifth char of operand
                JSR ToUpper
                CMP #'X'                      ; Is it an X?
                BNE TryIndirectIndexed
                LDA OprBuf+6                      ; Get sixth char of operand
                CMP #')'                      ; Is it an )?
                BNE TryIndirectIndexed
                LDA #AM_INDEXED_INDIRECT      ; Yes, this is indexed indirect
                STA AM                        ; Save it
                LDA OprBuf+2                      ; Get operand characters
                LDY OprBuf+3
                JSR Hex2Bin             ; Convert to binary
                STA Operand                   ; Save it as the operand
                JMP GenerateCode

; AM_INDIRECT_INDEXED, e.g. LDA (nn),Y
TryIndirectIndexed:
                LDA OprBuf                       ; Get length
                CMP #6                        ; Is it 6?
                BNE TryIndirect
                LDA OprBuf+1                      ; Get first char of operand
                CMP #'('
                BNE TryIndirect
                LDA OprBuf+2                      ; Get second char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ TryIndirect
                LDA OprBuf+3                      ; Get third char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ TryIndirect
                LDA OprBuf+4                      ; Get fourth char of operand
                CMP #')'                      ; Is it a )?
                BNE TryIndirect
                LDA OprBuf+5                      ; Get fifth char of operand
                CMP #','                      ; Is it a comma?
                BNE TryIndirect
                LDA OprBuf+6                      ; Get sixth char of operand
                JSR ToUpper
                CMP #'Y'                      ; Is it a Y?
                BNE TryIndirect
                LDA #AM_INDIRECT_INDEXED      ; Yes, this is indirect indexed
                STA AM                        ; Save it
                LDA OprBuf+2                      ; Get operand characters
                LDY OprBuf+3
                JSR Hex2Bin             ; Convert to binary
                STA Operand                   ; Save it as the operand
                JMP GenerateCode

; AM_INDIRECT, e.g. JMP (nnnn)
; l paren, 4 hex digits, r paren
TryIndirect:
                LDA OprBuf                       ; Get length
                CMP #6                        ; Is it 6?
                BNE TryIndirectZP
                LDA OprBuf+1                      ; Get first char of operand
                CMP #'('
                BNE TryIndirectZP
                LDA OprBuf+2                      ; Get second char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ TryIndirectZP
                LDA OprBuf+3                      ; Get third char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ TryIndirectZP
                LDA OprBuf+4                      ; Get fourth char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ TryIndirectZP
                LDA OprBuf+5                      ; Get fifth char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ TryIndirectZP
                LDA OprBuf+6                      ; Get fourth char of operand
                CMP #')'                      ; Is it a )?
                BNE TryIndirectZP
                LDA #AM_INDIRECT              ; Yes, this is indirect
                STA AM                        ; Save it

                LDA OprBuf+2                      ; Get operand characters
                LDY OprBuf+3
                JSR Hex2Bin             ; Convert to binary
                STA Operand+1                 ; Save it as the operand
                LDA OprBuf+4                      ; Get operand characters
                LDY OprBuf+5
                JSR Hex2Bin             ; Convert to binary
                STA Operand                   ; Save it as the operand
                JMP GenerateCode

; AM_INDIRECT_ZEROPAGE, e.g. LDA (nn) [65C02 only]
TryIndirectZP:
                LDA OprBuf                       ; Get length
                CMP #4                        ; Is it 4?
                BNE TryAbsIndInd
                LDA OprBuf+1                      ; Get first char of operand
                CMP #'('
                BNE TryAbsIndInd
                LDA OprBuf+2                      ; Get second char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ TryAbsIndInd
                LDA OprBuf+3                      ; Get third char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ TryAbsIndInd
                LDA OprBuf+4                      ; Get fourth char of operand
                CMP #')'                      ; Is it a )?
                BNE TryAbsIndInd
                LDA #AM_INDIRECT_ZEROPAGE     ; Yes, this is indirect zeropage
                STA AM                        ; Save it

                LDA OprBuf+2                      ; Get operand characters
                LDY OprBuf+3
                JSR Hex2Bin                   ; Convert to binary
                STA Operand                   ; Save it as the operand
                JMP GenerateCode

; AM_ABSOLUTE_INDEXED_INDIRECT, e.g. JMP (nnnn,X) [65C02 only]
TryAbsIndInd:
                LDA OprBuf                       ; Get length
                CMP #8                        ; Is it 8?
                BNE InvalidOp
                LDA OprBuf+1                      ; Get first char of operand
                CMP #'('
                BNE InvalidOp
                LDA OprBuf+2                      ; Get second char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ InvalidOp
                LDA OprBuf+3                      ; Get third char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ InvalidOp
                LDA OprBuf+4                      ; Get fourth char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ InvalidOp
                LDA OprBuf+5                      ; Get fifth char of operand
                JSR IsHexDigit                ; Is it a hex digit?
                BEQ InvalidOp
                LDA OprBuf+6                      ; Get sixth char of operand
                CMP #','                      ; Is it a ,?
                BNE InvalidOp
                LDA OprBuf+7                      ; Get 7th char of operand
                JSR ToUpper
                CMP #'X'                      ; Is it a X?
                BNE InvalidOp
                LDA OprBuf+8                      ; Get 8th char of operand
                CMP #')'                      ; Is it a )?
                BNE InvalidOp
                LDA #AM_ABSOLUTE_INDEXED_INDIRECT ; Yes, this is abolute indexed indirect
                STA AM                        ; Save it

                LDA OprBuf+2                      ; Get operand characters
                LDY OprBuf+3
                JSR Hex2Bin                   ; Convert to binary
                STA Operand+1                 ; Save it as the operand
                LDA OprBuf+4                      ; Get operand characters
                LDY OprBuf+5
                JSR Hex2Bin                   ; Convert to binary
                STA Operand                   ; Save it as the operand
                JMP GenerateCode

; If not any of the above, report "Invalid operand" and do line again
InvalidOp:
                JSR PrintNewline
                JSR PrintImm
                ASCLN "Invalid operand"
                JSR PrintNewline
                JMP AssembleLine	

GenerateCode:
                JSR PrintNewline                     ; Output newline
                JSR CheckAddressingModeValid    ; See if addressing mode is valid
                BNE OperandOkay
                JSR PrintImm              ; Not a valid addressing mode
                ASCLN "Invalid addressing mode"
                JSR PrintNewline
                JMP AssembleLine	

OperandOkay:
                ; Look up instruction length based on addressing mode and save it
                LDX AM                   ; Addressing mode
                LDA LENGTHS,X            ; Get instruction length for this addressing mode
                STA LEN                  ; Save it

                ; Write the opcode to memory
                LDA OPCODE               ; get opcode
                LDY #0
                STA (AddrA),Y             ; store it

                ; Check that we can write it back (in case destination memory is not writable).
                CMP (AddrA),Y            ; Do we read back what we wrote?
                BEQ WriteOperands        ; Yes, okay

                ; Memory is not writable for some reason, Report error and quit.
                JSR PrintImm              ; Print error message
                ASC "Unable to write to $"
                LDX AddrA
                LDY AddrA+1
                JSR PrintAddress
                JMP PrintNewline            

; Generate code for operands
WriteOperands:
                LDA AM                  ; get addressing mode
                CMP #AM_IMPLICIT        ; These modes take no operands
                BNE TryAcc
                JMP ZeroOperands
TryAcc:
                CMP #AM_ACCUMULATOR
                BNE TryImmed
                JMP ZeroOperands
TryImmed:
                CMP #AM_IMMEDIATE       ; These modes take one operand
                BNE TryZp
                JMP OneOperand
TryZp:  
                CMP #AM_ZEROPAGE
                BNE TryZpX
                JMP OneOperand
TryZpX: 
                CMP #AM_ZEROPAGE_X
                BNE TryZpY
                JMP OneOperand
TryZpY: 
                CMP #AM_ZEROPAGE_Y
                BEQ OneOperand
                CMP #AM_INDEXED_INDIRECT
                BEQ OneOperand
                CMP #AM_INDIRECT_INDEXED
                BEQ OneOperand
                CMP #AM_INDIRECT_ZEROPAGE ; [65C02 only]
                BEQ OneOperand

                CMP #AM_ABSOLUTE       ; These modes take two operands
                BEQ TwoOperands
                CMP #AM_ABSOLUTE_X
                BEQ TwoOperands
                CMP #AM_ABSOLUTE_Y
                BEQ TwoOperands
                CMP #AM_INDIRECT
                BEQ TwoOperands
                CMP #AM_ABSOLUTE_INDEXED_INDIRECT
                BEQ TwoOperands

                CMP #AM_RELATIVE       ; Relative is special case
                BNE ZeroOperands

; BEQ nnnn        Relative
; Write 1 byte calculated as destination - current address - instruction length
; i.e. (Operand,Operand+1) - AddrA,AddrA+1 - 2
; Report error if branch is out of 8-bit offset range.
Relative:
                LDA Operand                 ; destination low byte
                SEC
                SBC AddrA                    ; subtract address low byte
                STA Operand                 ; Save it
                LDA Operand+1               ; destination high byte
                SBC AddrA+1                  ; subtract address high byte (with any borrow)
                STA Operand+1               ; store it

                LDA Operand
                SEC
                SBC #2                      ; subtract 2 more
                STA Operand                 ; store it
                LDA Operand+1               ; destination high byte
                SBC #0                      ; subtract 0 (with any borrow)
                STA Operand+1               ; store it

; Report error if branch is out of 8-bit offset range.
; Valid range is $0000 - $007F and $FF80 - $FFFF

                LDA Operand+1              ; High byte
                BEQ OkayZero               ; Should be $))
                CMP #$FF
                BEQ OkayFF                 ; Or $FF
OutOfRange:
                JSR PrintImm
                ASCLN "Relative branch out of range"
                JSR PrintNewline
                JMP AssembleLine

OkayZero:
                LDA Operand                ; Low byte
                BMI OutOfRange             ; must be $00-$7F (i.e. positive)
                JMP OneOperand

OkayFF:
                LDA Operand                ; Low byte
                BPL OutOfRange             ; must be $80-$FF (i.e. negative)

; Now fall through to one operand code

OneOperand:
                LDA Operand                  ; Get operand
                LDY #1                       ; Offset from instruction
                STA (AddrA),Y                ; write it
                JMP ZeroOperands             ; done

TwoOperands:
                LDA Operand                  ; Get operand low byte
                LDY #1                       ; Offset from instruction
                STA (AddrA),Y               ; write it
                INY
                LDA Operand+1                ; Get operand high byte
                STA (AddrA),Y               ; write it

ZeroOperands:                        ; Nothing to do
;
                CLC                         ;Update current address with instruction length
                LDA AddrA                  ; Low byte
                ADC LEN                     ; Add length
                STA AddrA                  ; Store it
                LDA AddrA+1                ; High byte
                ADC #0                      ; Add any carry
                STA AddrA+1                ; Store it
                JMP AssembleLine            ; loop back to start of AssembleLine

; Look up three letter mnemonic, e.g. "NOP". On entry mnemonic is stored in Mnem.
; Write index value, e.g. OP_NOP, to OP. Set sit to OP_INV if not found.
; Registers changed: A, X, Y.
LookupMnemonic:
                LDX #0                  ; Holds current table index
                LDA #<MNEMONICS         ; Store address of start of table in T4 (L/H)
                STA T4
                LDA #>MNEMONICS
                STA T4+1
Loop:
                LDY #0                  ; Holds offset of string in table entry
                LDA Mnem,Y             ; Compare first char of mnemonic to table entry
                CMP (T4),Y
                BNE NextOp              ; If different, try next opcode
                INY
                LDA Mnem,Y             ; Compare second char of mnemonic to table entry
                CMP (T4),Y
                BNE NextOp              ; If different, try next opcode
                INY
                LDA Mnem,Y             ; Compare third char of mnemonic to table entry
                CMP (T4),Y
                BNE NextOp              ; If different, try next opcode
                                        ; We found a match
                STX OP                  ; Store index in table (X) in OP
                RTS                     ; And return

NextOp:
                INX                     ; Increment table index
                CLC
                LDA T4                  ; Increment pointer to table entry (T4) as 16-bit value
                ADC #3                  ; Adding three because each entry is 3 bytes
                STA T4
                LDA T4+1                ; Add possible carry to high byte
                ADC #0
                STA T4+1

                LDA T4                  ; Did we reach the last entry (MNEMONICSEND?)
                CMP #<MNEMONICSEND      ; If not, keep searching
                BNE Loop
                LDA T4+1
                CMP #>MNEMONICSEND
                BNE Loop
                                        ; End of table reached
                LDA #OP_INV             ; Value is not valid
                STA OP
                RTS

; Given an instruction and addressing mode, return if it is valid.
; When called OP should contain instruction (e.g. OP_NOP) and
; AM contain the addressing mode (e.g. AM_IMPLICIT).
; If valid, sets OPCODE to the opcode (eg. $EA for NOP) and returns 1
; in A. If not valid, returns 0 in A.
; Registers changed: A, X, Y.

CheckAddressingModeValid:
                LDX #0                  ; Holds current table index
                LDA #<OPCODES           ; Store address of start of table in T4 (L/H)
                STA T4
                LDA #>OPCODES
                STA T4+1
OpLoop:
                LDY #0                  ; Holds offset into table entry
                LDA (T4),Y              ; Get a table entry (instruction)
                CMP OP                  ; Is it the instruction we are looking for?
                BNE NextInst            ; If different, try next opcode
                                        ; Instruction matched. Does the addressing mode match?
                INY                     ; Want second byte of table entry (address mode)
                LDA (T4),Y              ; Get a table entry (address mode
                CMP AM                  ; Is it the address mode we are looking for?
                BNE NextInst            ; If different, try next opcode
                                        ; We found a match
                TXA                     ; Get index in table (X), the opcode
                STA OPCODE              ; Store it
                LDA #1                  ; Set true return value
                RTS                     ; And return

NextInst:
                INX                     ; Increment table index
                BEQ OpNotFound          ; If wrapped past $FF, we did not find what we were looking for
                CLC
                LDA T4                  ; Increment pointer to table entry (T4) as 16-bit value
                ADC #2                  ; Add two because each entry is 2 bytes
                STA T4
                LDA T4+1                ; Add possible carry to high byte
                ADC #0
                STA T4+1
                JMP OpLoop
OpNotFound:     LDA #0                  ; End of table reached, set false return value
                RTS

PrintSpace:
                PHA
                LDA #SP
                JSR WriteChar
                PLA
                RTS

; Instructions. Match indexes into entries in table MNEMONICS1/MENMONICS2.
OP_INV = $00
OP_ADC = $01
OP_AND = $02
OP_ASL = $03
OP_BCC = $04
OP_BCS = $05
OP_BEQ = $06
OP_BIT = $07
OP_BMI = $08
OP_BNE = $09
OP_BPL = $0A
OP_BRK = $0B
OP_BVC = $0C
OP_BVS = $0D
OP_CLC = $0E
OP_CLD = $0F
OP_CLI = $10
OP_CLV = $11
OP_CMP = $12
OP_CPX = $13
OP_CPY = $14
OP_DEC = $15
OP_DEX = $16
OP_DEY = $17
OP_EOR = $18
OP_INC = $19
OP_INX = $1A
OP_INY = $1B
OP_JMP = $1C
OP_JSR = $1D
OP_LDA = $1E
OP_LDX = $1F
OP_LDY = $20
OP_LSR = $21
OP_NOP = $22
OP_ORA = $23
OP_PHA = $24
OP_PHP = $25
OP_PLA = $26
OP_PLP = $27
OP_ROL = $28
OP_ROR = $29
OP_RTI = $2A
OP_RTS = $2B
OP_SBC = $2C
OP_SEC = $2D
OP_SED = $2E
OP_SEI = $2F
OP_STA = $30
OP_STX = $31
OP_STY = $32
OP_TAX = $33
OP_TAY = $34
OP_TSX = $35
OP_TXA = $36
OP_TXS = $37
OP_TYA = $38
OP_BBR = $39 ; [65C02 only]
OP_BBS = $3A ; [65C02 only]
OP_BRA = $3B ; [65C02 only]
OP_PHX = $3C ; [65C02 only]
OP_PHY = $3D ; [65C02 only]
OP_PLX = $3E ; [65C02 only]
OP_PLY = $3F ; [65C02 only]
OP_RMB = $40 ; [65C02 only]
OP_SMB = $41 ; [65C02 only]
OP_STZ = $42 ; [65C02 only]
OP_TRB = $43 ; [65C02 only]
OP_TSB = $44 ; [65C02 only]
OP_STP = $45 ; [WDC 65C02 and 65816 only]
OP_WAI = $46 ; [WDC 65C02 and 65816 only]

; Addressing Modes. OPCODES1/OPCODES2 tables list these for each instruction. LENGTHS lists the instruction length for each addressing mode.
AM_INVALID = 0                    ; example:
AM_IMPLICIT = 1                   ; RTS
AM_ACCUMULATOR = 2                ; ASL A
AM_IMMEDIATE = 3                  ; LDA #$12
AM_ZEROPAGE = 4                   ; LDA $12
AM_ZEROPAGE_X = 5                 ; LDA $12,X
AM_ZEROPAGE_Y = 6                 ; LDA $12,Y
AM_RELATIVE = 7                   ; BNE $FD
AM_ABSOLUTE = 8                   ; JSR $1234
AM_ABSOLUTE_X = 9                 ; STA $1234,X
AM_ABSOLUTE_Y = 10                ; STA $1234,Y
AM_INDIRECT = 11                  ; JMP ($1234)
AM_INDEXED_INDIRECT = 12          ; LDA ($12,X)
AM_INDIRECT_INDEXED = 13          ; LDA ($12),Y
AM_INDIRECT_ZEROPAGE = 14         ; LDA ($12) [65C02 only]
AM_ABSOLUTE_INDEXED_INDIRECT = 15 ; JMP ($1234,X) [65C02 only]

; Table of instruction strings. 3 bytes per table entry
MNEMONICS:
.byte "???" ; $00
.byte "ADC" ; $01
.byte "AND" ; $02
.byte "ASL" ; $03
.byte "BCC" ; $04
.byte "BCS" ; $05
.byte "BEQ" ; $06
.byte "BIT" ; $07
.byte "BMI" ; $08
.byte "BNE" ; $09
.byte "BPL" ; $0A
.byte "BRK" ; $0B
.byte "BVC" ; $0C
.byte "BVS" ; $0D
.byte "CLC" ; $0E
.byte "CLD" ; $0F
.byte "CLI" ; $10
.byte "CLV" ; $11
.byte "CMP" ; $12
.byte "CPX" ; $13
.byte "CPY" ; $14
.byte "DEC" ; $15
.byte "DEX" ; $16
.byte "DEY" ; $17
.byte "EOR" ; $18
.byte "INC" ; $19
.byte "INX" ; $1A
.byte "INY" ; $1B
.byte "JMP" ; $1C
.byte "JSR" ; $1D
.byte "LDA" ; $1E
.byte "LDX" ; $1F
.byte "LDY" ; $20
.byte "LSR" ; $21
.byte "NOP" ; $22
.byte "ORA" ; $23
.byte "PHA" ; $24
.byte "PHP" ; $25
.byte "PLA" ; $26
.byte "PLP" ; $27
.byte "ROL" ; $28
.byte "ROR" ; $29
.byte "RTI" ; $2A
.byte "RTS" ; $2B
.byte "SBC" ; $2C
.byte "SEC" ; $2D
.byte "SED" ; $2E
.byte "SEI" ; $2F
.byte "STA" ; $30
.byte "STX" ; $31
.byte "STY" ; $32
.byte "TAX" ; $33
.byte "TAY" ; $34
.byte "TSX" ; $35
.byte "TXA" ; $36
.byte "TXS" ; $37
.byte "TYA" ; $38
.byte "BBR" ; $39 [65C02 only]
.byte "BBS" ; $3A [65C02 only]
.byte "BRA" ; $3B [65C02 only]
.byte "PHX" ; $3C [65C02 only]
.byte "PHY" ; $3D [65C02 only]
.byte "PLX" ; $3E [65C02 only]
.byte "PLY" ; $3F [65C02 only]
.byte "RMB" ; $40 [65C02 only]
.byte "SMB" ; $41 [65C02 only]
.byte "STZ" ; $42 [65C02 only]
.byte "TRB" ; $43 [65C02 only]
.byte "TSB" ; $44 [65C02 only]
.byte "STP" ; $45 [WDC 65C02 only]
.byte "WAI" ; $46 [WDC 65C02 only]
MNEMONICSEND:

; Lengths of instructions given an addressing mode. Matches values of AM_*
LENGTHS: 
.byte 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 3, 2, 2, 2, 3

; Opcodes. Listed in order. Defines the mnemonic and addressing mode.
; 2 bytes per table entry
OPCODES:
OPCODES1:
.byte OP_BRK, AM_IMPLICIT           ; $00
.byte OP_ORA, AM_INDEXED_INDIRECT   ; $01
.byte OP_INV, AM_INVALID            ; $02
.byte OP_INV, AM_INVALID            ; $03
.byte OP_TSB, AM_ZEROPAGE           ; $04 [65C02 only]
.byte OP_ORA, AM_ZEROPAGE           ; $05
.byte OP_ASL, AM_ZEROPAGE           ; $06
.byte OP_RMB, AM_ZEROPAGE           ; $07 [65C02 only]
.byte OP_PHP, AM_IMPLICIT           ; $08
.byte OP_ORA, AM_IMMEDIATE          ; $09
.byte OP_ASL, AM_ACCUMULATOR        ; $0A
.byte OP_INV, AM_INVALID            ; $0B
.byte OP_TSB, AM_ABSOLUTE           ; $0C [65C02 only]
.byte OP_ORA, AM_ABSOLUTE           ; $0D
.byte OP_ASL, AM_ABSOLUTE           ; $0E
.byte OP_BBR, AM_ABSOLUTE           ; $0F [65C02 only]

.byte OP_BPL, AM_RELATIVE           ; $10
.byte OP_ORA, AM_INDIRECT_INDEXED   ; $11
.byte OP_ORA, AM_INDIRECT_ZEROPAGE  ; $12 [65C02 only]
.byte OP_INV, AM_INVALID            ; $13
.byte OP_TRB, AM_ZEROPAGE           ; $14 [65C02 only]
.byte OP_ORA, AM_ZEROPAGE_X         ; $15
.byte OP_ASL, AM_ZEROPAGE_X         ; $16
.byte OP_RMB, AM_ZEROPAGE           ; $17 [65C02 only]
.byte OP_CLC, AM_IMPLICIT           ; $18
.byte OP_ORA, AM_ABSOLUTE_Y         ; $19
.byte OP_INC, AM_ACCUMULATOR        ; $1A [65C02 only]
.byte OP_INV, AM_INVALID            ; $1B
.byte OP_TRB, AM_ABSOLUTE           ; $1C [65C02 only]
.byte OP_ORA, AM_ABSOLUTE_X         ; $1D
.byte OP_ASL, AM_ABSOLUTE_X         ; $1E
.byte OP_BBR, AM_ABSOLUTE           ; $1F [65C02 only]

.byte OP_JSR, AM_ABSOLUTE           ; $20
.byte OP_AND, AM_INDEXED_INDIRECT   ; $21
.byte OP_INV, AM_INVALID            ; $22
.byte OP_INV, AM_INVALID            ; $23
.byte OP_BIT, AM_ZEROPAGE           ; $24
.byte OP_AND, AM_ZEROPAGE           ; $25
.byte OP_ROL, AM_ZEROPAGE           ; $26
.byte OP_RMB, AM_ZEROPAGE           ; $27 [65C02 only]
.byte OP_PLP, AM_IMPLICIT           ; $28
.byte OP_AND, AM_IMMEDIATE          ; $29
.byte OP_ROL, AM_ACCUMULATOR        ; $2A
.byte OP_INV, AM_INVALID            ; $2B
.byte OP_BIT, AM_ABSOLUTE           ; $2C
.byte OP_AND, AM_ABSOLUTE           ; $2D
.byte OP_ROL, AM_ABSOLUTE           ; $2E
.byte OP_BBR, AM_ABSOLUTE           ; $2F [65C02 only]

.byte OP_BMI, AM_RELATIVE           ; $30
.byte OP_AND, AM_INDIRECT_INDEXED   ; $31 [65C02 only]
.byte OP_AND, AM_INDIRECT_ZEROPAGE  ; $32 [65C02 only]
.byte OP_INV, AM_INVALID            ; $33
.byte OP_BIT, AM_ZEROPAGE_X         ; $34 [65C02 only]
.byte OP_AND, AM_ZEROPAGE_X         ; $35
.byte OP_ROL, AM_ZEROPAGE_X         ; $36
.byte OP_RMB, AM_ZEROPAGE           ; $37 [65C02 only]
.byte OP_SEC, AM_IMPLICIT           ; $38
.byte OP_AND, AM_ABSOLUTE_Y         ; $39
.byte OP_DEC, AM_ACCUMULATOR        ; $3A [65C02 only]
.byte OP_INV, AM_INVALID            ; $3B
.byte OP_BIT, AM_ABSOLUTE_X         ; $3C [65C02 only]
.byte OP_AND, AM_ABSOLUTE_X         ; $3D
.byte OP_ROL, AM_ABSOLUTE_X         ; $3E
.byte OP_BBR, AM_ABSOLUTE           ; $3F [65C02 only]

.byte OP_RTI, AM_IMPLICIT           ; $40
.byte OP_EOR, AM_INDEXED_INDIRECT   ; $41
.byte OP_INV, AM_INVALID            ; $42
.byte OP_INV, AM_INVALID            ; $43
.byte OP_INV, AM_INVALID            ; $44
.byte OP_EOR, AM_ZEROPAGE           ; $45
.byte OP_LSR, AM_ZEROPAGE           ; $46
.byte OP_RMB, AM_ZEROPAGE           ; $47 [65C02 only]
.byte OP_PHA, AM_IMPLICIT           ; $48
.byte OP_EOR, AM_IMMEDIATE          ; $49
.byte OP_LSR, AM_ACCUMULATOR        ; $4A
.byte OP_INV, AM_INVALID            ; $4B
.byte OP_JMP, AM_ABSOLUTE           ; $4C
.byte OP_EOR, AM_ABSOLUTE           ; $4D
.byte OP_LSR, AM_ABSOLUTE           ; $4E
.byte OP_BBR, AM_ABSOLUTE           ; $4F [65C02 only]

.byte OP_BVC, AM_RELATIVE           ; $50
.byte OP_EOR, AM_INDIRECT_INDEXED   ; $51
.byte OP_EOR, AM_INDIRECT_ZEROPAGE  ; $52 [65C02 only]
.byte OP_INV, AM_INVALID            ; $53
.byte OP_INV, AM_INVALID            ; $54
.byte OP_EOR, AM_ZEROPAGE_X         ; $55
.byte OP_LSR, AM_ZEROPAGE_X         ; $56
.byte OP_RMB, AM_ZEROPAGE           ; $57 [65C02 only]
.byte OP_CLI, AM_IMPLICIT           ; $58
.byte OP_EOR, AM_ABSOLUTE_Y         ; $59
.byte OP_PHY, AM_IMPLICIT           ; $5A [65C02 only]
.byte OP_INV, AM_INVALID            ; $5B
.byte OP_INV, AM_INVALID            ; $5C
.byte OP_EOR, AM_ABSOLUTE_X         ; $5D
.byte OP_LSR, AM_ABSOLUTE_X         ; $5E
.byte OP_BBR, AM_ABSOLUTE           ; $5F [65C02 only]

.byte OP_RTS, AM_IMPLICIT           ; $60
.byte OP_ADC, AM_INDEXED_INDIRECT   ; $61
.byte OP_INV, AM_INVALID            ; $62
.byte OP_INV, AM_INVALID            ; $63
.byte OP_STZ, AM_ZEROPAGE           ; $64 [65C02 only]
.byte OP_ADC, AM_ZEROPAGE           ; $65
.byte OP_ROR, AM_ZEROPAGE           ; $66
.byte OP_RMB, AM_ZEROPAGE           ; $67 [65C02 only]
.byte OP_PLA, AM_IMPLICIT           ; $68
.byte OP_ADC, AM_IMMEDIATE          ; $69
.byte OP_ROR, AM_ACCUMULATOR        ; $6A
.byte OP_INV, AM_INVALID            ; $6B
.byte OP_JMP, AM_INDIRECT           ; $6C
.byte OP_ADC, AM_ABSOLUTE           ; $6D
.byte OP_ROR, AM_ABSOLUTE           ; $6E
.byte OP_BBR, AM_ABSOLUTE           ; $6F [65C02 only]

.byte OP_BVS, AM_RELATIVE           ; $70
.byte OP_ADC, AM_INDIRECT_INDEXED   ; $71
.byte OP_ADC, AM_INDIRECT_ZEROPAGE  ; $72 [65C02 only]
.byte OP_INV, AM_INVALID            ; $73
.byte OP_STZ, AM_ZEROPAGE_X         ; $74 [65C02 only]
.byte OP_ADC, AM_ZEROPAGE_X         ; $75
.byte OP_ROR, AM_ZEROPAGE_X         ; $76
.byte OP_RMB, AM_ZEROPAGE           ; $77 [65C02 only]
.byte OP_SEI, AM_IMPLICIT           ; $78
.byte OP_ADC, AM_ABSOLUTE_Y         ; $79
.byte OP_PLY, AM_IMPLICIT           ; $7A [65C02 only]
.byte OP_INV, AM_INVALID            ; $7B
.byte OP_JMP, AM_ABSOLUTE_INDEXED_INDIRECT ; $7C [65C02 only]
.byte OP_ADC, AM_ABSOLUTE_X         ; $7D
.byte OP_ROR, AM_ABSOLUTE_X         ; $7E
.byte OP_BBR, AM_ABSOLUTE           ; $7F [65C02 only]
.export OPCODES2
OPCODES2:
.byte OP_BRA, AM_RELATIVE           ; $80 [65C02 only]
.byte OP_STA, AM_INDEXED_INDIRECT   ; $81
.byte OP_INV, AM_INVALID            ; $82
.byte OP_INV, AM_INVALID            ; $83
.byte OP_STY, AM_ZEROPAGE           ; $84
.byte OP_STA, AM_ZEROPAGE           ; $85
.byte OP_STX, AM_ZEROPAGE           ; $86
.byte OP_SMB, AM_ZEROPAGE           ; $87 [65C02 only]
.byte OP_DEY, AM_IMPLICIT           ; $88
.byte OP_BIT, AM_IMMEDIATE          ; $89 [65C02 only]
.byte OP_TXA, AM_IMPLICIT           ; $8A
.byte OP_INV, AM_INVALID            ; $8B
.byte OP_STY, AM_ABSOLUTE           ; $8C
.byte OP_STA, AM_ABSOLUTE           ; $8D
.byte OP_STX, AM_ABSOLUTE           ; $8E
.byte OP_BBS, AM_ABSOLUTE           ; $8F [65C02 only]

.byte OP_BCC, AM_RELATIVE           ; $90
.byte OP_STA, AM_INDIRECT_INDEXED   ; $91
.byte OP_STA, AM_INDIRECT_ZEROPAGE  ; $92 [65C02 only]
.byte OP_INV, AM_INVALID            ; $93
.byte OP_STY, AM_ZEROPAGE_X         ; $94
.byte OP_STA, AM_ZEROPAGE_X         ; $95
.byte OP_STX, AM_ZEROPAGE_Y         ; $96
.byte OP_SMB, AM_ZEROPAGE           ; $97 [65C02 only]
.byte OP_TYA, AM_IMPLICIT           ; $98
.byte OP_STA, AM_ABSOLUTE_Y         ; $99
.byte OP_TXS, AM_IMPLICIT           ; $9A
.byte OP_INV, AM_INVALID            ; $9B
.byte OP_STZ, AM_ABSOLUTE           ; $9C [65C02 only]
.byte OP_STA, AM_ABSOLUTE_X         ; $9D
.byte OP_STZ, AM_ABSOLUTE_X         ; $9E [65C02 only]
.byte OP_BBS, AM_ABSOLUTE           ; $9F [65C02 only]

.byte OP_LDY, AM_IMMEDIATE          ; $A0
.byte OP_LDA, AM_INDEXED_INDIRECT   ; $A1
.byte OP_LDX, AM_IMMEDIATE          ; $A2
.byte OP_INV, AM_INVALID            ; $A3
.byte OP_LDY, AM_ZEROPAGE           ; $A4
.byte OP_LDA, AM_ZEROPAGE           ; $A5
.byte OP_LDX, AM_ZEROPAGE           ; $A6
.byte OP_SMB, AM_ZEROPAGE           ; $A7 [65C02 only]
.byte OP_TAY, AM_IMPLICIT           ; $A8
.byte OP_LDA, AM_IMMEDIATE          ; $A9
.byte OP_TAX, AM_IMPLICIT           ; $AA
.byte OP_INV, AM_INVALID            ; $AB
.byte OP_LDY, AM_ABSOLUTE           ; $AC
.byte OP_LDA, AM_ABSOLUTE           ; $AD
.byte OP_LDX, AM_ABSOLUTE           ; $AE
.byte OP_BBS, AM_ABSOLUTE           ; $AF [65C02 only]

.byte OP_BCS, AM_RELATIVE           ; $B0
.byte OP_LDA, AM_INDIRECT_INDEXED   ; $B1
.byte OP_LDA, AM_INDIRECT_ZEROPAGE  ; $B2 [65C02 only]
.byte OP_INV, AM_INVALID            ; $B3
.byte OP_LDY, AM_ZEROPAGE_X         ; $B4
.byte OP_LDA, AM_ZEROPAGE_X         ; $B5
.byte OP_LDX, AM_ZEROPAGE_Y         ; $B6
.byte OP_SMB, AM_ZEROPAGE           ; $B7 [65C02 only]
.byte OP_CLV, AM_IMPLICIT           ; $B8
.byte OP_LDA, AM_ABSOLUTE_Y         ; $B9
.byte OP_TSX, AM_IMPLICIT           ; $BA
.byte OP_INV, AM_INVALID            ; $BB
.byte OP_LDY, AM_ABSOLUTE_X         ; $BC
.byte OP_LDA, AM_ABSOLUTE_X         ; $BD
.byte OP_LDX, AM_ABSOLUTE_Y         ; $BE
.byte OP_BBS, AM_ABSOLUTE           ; $BF [65C02 only]

.byte OP_CPY, AM_IMMEDIATE          ; $C0
.byte OP_CMP, AM_INDEXED_INDIRECT   ; $C1
.byte OP_INV, AM_INVALID            ; $C2
.byte OP_INV, AM_INVALID            ; $C3
.byte OP_CPY, AM_ZEROPAGE           ; $C4
.byte OP_CMP, AM_ZEROPAGE           ; $C5
.byte OP_DEC, AM_ZEROPAGE           ; $C6
.byte OP_SMB, AM_ZEROPAGE           ; $C7 [65C02 only]
.byte OP_INY, AM_IMPLICIT           ; $C8
.byte OP_CMP, AM_IMMEDIATE          ; $C9
.byte OP_DEX, AM_IMPLICIT           ; $CA
.byte OP_WAI, AM_IMPLICIT           ; $CB [WDC 65C02 only]
.byte OP_CPY, AM_ABSOLUTE           ; $CC
.byte OP_CMP, AM_ABSOLUTE           ; $CD
.byte OP_DEC, AM_ABSOLUTE           ; $CE
.byte OP_BBS, AM_ABSOLUTE           ; $CF [65C02 only]

.byte OP_BNE, AM_RELATIVE           ; $D0
.byte OP_CMP, AM_INDIRECT_INDEXED   ; $D1
.byte OP_CMP, AM_INDIRECT_ZEROPAGE  ; $D2 [65C02 only]
.byte OP_INV, AM_INVALID            ; $D3
.byte OP_INV, AM_INVALID            ; $D4
.byte OP_CMP, AM_ZEROPAGE_X         ; $D5
.byte OP_DEC, AM_ZEROPAGE_X         ; $D6
.byte OP_SMB, AM_ZEROPAGE           ; $D7 [65C02 only]
.byte OP_CLD, AM_IMPLICIT           ; $D8
.byte OP_CMP, AM_ABSOLUTE_Y         ; $D9
.byte OP_PHX, AM_IMPLICIT           ; $DA [65C02 only]
.byte OP_STP, AM_IMPLICIT           ; $DB [WDC 65C02 only]
.byte OP_INV, AM_INVALID            ; $DC
.byte OP_CMP, AM_ABSOLUTE_X         ; $DD
.byte OP_DEC, AM_ABSOLUTE_X         ; $DE
.byte OP_BBS, AM_ABSOLUTE           ; $DF [65C02 only]

.byte OP_CPX, AM_IMMEDIATE          ; $E0
.byte OP_SBC, AM_INDEXED_INDIRECT   ; $E1
.byte OP_INV, AM_INVALID            ; $E2
.byte OP_INV, AM_INVALID            ; $E3
.byte OP_CPX, AM_ZEROPAGE           ; $E4
.byte OP_SBC, AM_ZEROPAGE           ; $E5
.byte OP_INC, AM_ZEROPAGE           ; $E6
.byte OP_SMB, AM_ZEROPAGE           ; $E7 [65C02 only]
.byte OP_INX, AM_IMPLICIT           ; $E8
.byte OP_SBC, AM_IMMEDIATE          ; $E9
.byte OP_NOP, AM_IMPLICIT           ; $EA
.byte OP_INV, AM_INVALID            ; $EB
.byte OP_CPX, AM_ABSOLUTE           ; $EC
.byte OP_SBC, AM_ABSOLUTE           ; $ED
.byte OP_INC, AM_ABSOLUTE           ; $EE
.byte OP_BBS, AM_ABSOLUTE           ; $EF [65C02 only]

.byte OP_BEQ, AM_RELATIVE           ; $F0
.byte OP_SBC, AM_INDIRECT_INDEXED   ; $F1
.byte OP_SBC, AM_INDIRECT_ZEROPAGE  ; $F2 [65C02 only]
.byte OP_INV, AM_INVALID            ; $F3
.byte OP_INV, AM_INVALID            ; $F4
.byte OP_SBC, AM_ZEROPAGE_X         ; $F5
.byte OP_INC, AM_ZEROPAGE_X         ; $F6
.byte OP_SMB, AM_ZEROPAGE           ; $F7 [65C02 only]
.byte OP_SED, AM_IMPLICIT           ; $F8
.byte OP_SBC, AM_ABSOLUTE_Y         ; $F9
.byte OP_PLX, AM_IMPLICIT           ; $FA [65C02 only]
.byte OP_INV, AM_INVALID            ; $FB
.byte OP_INV, AM_INVALID            ; $FC
.byte OP_SBC, AM_ABSOLUTE_X         ; $FD
.byte OP_INC, AM_ABSOLUTE_X         ; $FE
.byte OP_BBS, AM_ABSOLUTE           ; $FF [65C02 only]
