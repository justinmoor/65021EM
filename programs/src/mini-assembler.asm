;
; 6502/65C02 Mini Assembler
;
; Copyright (C) 2012-2016 by Jeff Tranter <tranter@pobox.com>
;
; Licensed under the Apache License, Version 2.0 (the "License");
; you may not use this file except in compliance with the License.
; You may obtain a copy of the License at
;
;   http://www.apache.org/licenses/LICENSE-2.0
;
; Unless required by applicable law or agreed to in writing, software
; distributed under the License is distributed on an "AS IS" BASIS,
; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
; See the License for the specific language governing permissions and
; limitations under the License.
;

; Mini assembler syntax format:
;
; A <address>
; XXXX: instruction
; XXXX: instruction
; XXXX: <Esc>
;
; example:
;
; A 6000
; 6000: NOP
; 6001: LDX #0A
; 6003: JSR FFEF
; 6006: DEX
; 6007: BNE 6003
; 6009: <Esc>
;
; Restrictions:
; - no symbols or labels
; - all values in hex, 2 or 4 digits
; - no backspace or other editing features
;

; Variables used (defined in jmon.s)
; ADDR - instruction address
; OPCODE - instruction op code
; OP - instruction type (OP_*)
; LEN -length of instruction
; IN - input buffer holding operands
; AM - addressing mode (AM_*)
; MNEM - hold three letter mnemonic string used by assembler
; OPERAND - Holds any operands for assembled instruction (2 bytes)


; Assemble code entered a line at a time.
; On entry ADDR contains start address of code.
; Registers changed: A, X, Y.

.ORG $1000
T1          = $00       ; one byte temp register 1

AssembleLine:
        LDX ADDR                ; output address
        LDY ADDR+1
        JSR PrintAddress
        LDA #':'                ; Output colon
        JSR PrintChar
        JSR PrintSpace          ; And space

; Input three letter for mnemonic (filter for valid alphabetic characters). Esc will terminate.

        LDX #0                  ; Index into MNEM
GetMnem:
        JSR GetKey              ; Get a character
        CMP #ESC                ; <Esc> key?
        BEQ EscPressed          ; If so, handle it
        JSR ToUpper
        CMP #'A'
        BMI GetMnem             ; Ignore if less than 'A'
        CMP #'Z'+1
        BPL GetMnem             ; or greater than 'Z'
        STA MNEM,X              ; Valid, so store it.
.ifdef ECHO
        JSR PrintChar           ; Echo it
.endif
        INX                     ; Advance index
        CPX #3                  ; Done?
        BNE GetMnem             ; If not, continue until we get 3 chars

        JSR LookupMnemonic      ; Look up mnemonic to see if it is valid
        LDA OP                  ; Get the returned opcode
        CMP #OP_INV             ; Not valid?
        BNE OpOk                ; Branch if okay

        JSR PrintCR
        JSR Imprint            ; Not a valid mnemonic
        .byte "Invalid instruction", 0

EscPressed:
        JMP PrintCR             ; Return via caller

; Mnemonic is valid. Does instruction use implicit addressing mode (i.e. no operand needed)?

OpOk:
        LDA #AM_IMPLICIT
        STA AM
        JSR CheckAddressingModeValid
        BEQ GetOperands
        JMP GenerateCode                ; It is implicit, so we can jump to generating the code

; Not implicit addressing mode. Need to get operand from user.

GetOperands:
        JSR PrintSpace          ; Output a space
        JSR GetLine             ; Get line of input for operand(s)
        BCS EscPressed          ; Check if cancelled by Esc key

; Check for addressing mode. Have already checked for implicit.

; AM_ACCUMULATOR, e.g. LSR A
; Operand is just "A"
        LDA IN                        ; Get length
        CMP #1                        ; Is it 1?
        BNE TryImm
        LDA IN+1                      ; Get first char of operand
        JSR ToUpper
        CMP #'A'                      ; Is it 'A'?
        BNE TryImm
        LDA #AM_ACCUMULATOR           ; Yes, is is accumulator mode
        STA AM                        ; Save it
        JMP GenerateCode

; AM_IMMEDIATE, e.g. LDA #nn
; Operand is '#' followed by 2 hex digits.
TryImm:
        LDA IN                        ; Get length
        CMP #3                        ; Is it 3?
        BNE TryZeroPage
        LDA IN+1                      ; Get first char of operand
        CMP #'#'                      ; is it '#'?
        BNE TryZeroPage
        LDA IN+2                      ; Get second char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ TryZeroPage
        LDA IN+3                      ; Get third char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ TryZeroPage
        LDA #AM_IMMEDIATE             ; Yes, this is immediate mode
        STA AM                        ; Save it
        LDX IN+2                      ; Get operand characters
        LDY IN+3
        JSR TwoCharsToBin             ; Convert to binary
        STA OPERAND                   ; Save it as the operand
        JMP GenerateCode

; AM_ZEROPAGE e.g. LDA nn
; Operand is 2 hex digits.
TryZeroPage:
        LDA IN                        ; Get length
        CMP #2                        ; Is it 2?
        BNE TryAbsRel
        LDA IN+1                      ; Get first char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ TryAbsRel
        LDA IN+2                      ; Get second char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ TryAbsRel
        LDA #AM_ZEROPAGE              ; Yes, this is zero page
        STA AM                        ; Save it
        LDX IN+1                      ; Get operand characters
        LDY IN+2
        JSR TwoCharsToBin             ; Convert to binary
        STA OPERAND                   ; Save it as the operand
        JMP GenerateCode

; AM_ABSOLUTE, e.g. LDA nnnn or AM_RELATIVE, e.g. BEQ nnnn
; Operand is 4 hex digits.

TryAbsRel:
        LDA IN                        ; Get length
        CMP #4                        ; Is it 4?
        BNE TryZeroPageX
        LDA IN+1                      ; Get first char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ TryZeroPageX
        LDA IN+2                      ; Get second char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ TryZeroPageX
        LDA IN+3                      ; Get third char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ TryZeroPageX
        LDA IN+4                      ; Get fourth char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ TryZeroPageX

; It could be absolute or relative, depending on the instruction.
; Test both to see which one, if any, is valid.

        LDA #AM_ABSOLUTE              ; Try absolute addressing mode
        STA AM                        ; Save it
        JSR CheckAddressingModeValid
        BEQ TryRelative               ; No, try relative

Save2Operands:
        LDX IN+1                      ; Get operand characters
        LDY IN+2
        JSR TwoCharsToBin             ; Convert to binary
        STA OPERAND+1                 ; Save it as the operand
        LDX IN+3                      ; Get operand characters
        LDY IN+4
        JSR TwoCharsToBin             ; Convert to binary
        STA OPERAND                   ; Save it as the operand
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
        LDA IN                        ; Get length
        CMP #4                        ; Is it 4?
        BNE TryZeroPageY
        LDA IN+1                      ; Get first char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ TryZeroPageY
        LDA IN+2                      ; Get second char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ TryZeroPageY
        LDA IN+3                      ; Get third char of operand
        CMP #','                      ; Is it a comma?
        BNE TryZeroPageY
        LDA IN+4                      ; Get fourth char of operand
        JSR ToUpper
        CMP #'X'                      ; Is it an X?
        BNE TryZeroPageY
        LDA #AM_ZEROPAGE_X            ; Yes, this is zero page X
        STA AM                        ; Save it
        LDX IN+1                      ; Get operand characters
        LDY IN+2
        JSR TwoCharsToBin             ; Convert to binary
        STA OPERAND                   ; Save it as the operand
        JMP GenerateCode

; AM_ZEROPAGE_Y e.g. LDA nn,Y
; 2 hex digits followed by ,Y
TryZeroPageY:
        LDA IN                        ; Get length
        CMP #4                        ; Is it 4?
        BNE TryAbsoluteX
        LDA IN+1                      ; Get first char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ TryAbsoluteX
        LDA IN+2                      ; Get second char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ TryAbsoluteX
        LDA IN+3                      ; Get third char of operand
        CMP #','                      ; Is it a comma?
        BNE TryAbsoluteX
        LDA IN+4                      ; Get fourth char of operand
        JSR ToUpper
        CMP #'Y'                      ; Is it an Y?
        BNE TryAbsoluteX
        LDA #AM_ZEROPAGE_Y            ; Yes, this is zero page Y
        STA AM                        ; Save it
        LDX IN+1                      ; Get operand characters
        LDY IN+2
        JSR TwoCharsToBin             ; Convert to binary
        STA OPERAND                   ; Save it as the operand
        JMP GenerateCode

; AM_ABSOLUTE_X, e.g. LDA nnnn,X
; 4 hex digits followed by ,X
TryAbsoluteX:
        LDA IN                        ; Get length
        CMP #6                        ; Is it 6?
        BNE TryAbsoluteY
        LDA IN+1                      ; Get first char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ TryAbsoluteY
        LDA IN+2                      ; Get second char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ TryAbsoluteY
        LDA IN+3                      ; Get third char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ TryAbsoluteY
        LDA IN+4                      ; Get fourth char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ TryAbsoluteY
        LDA IN+5
        CMP #','
        BNE TryAbsoluteY
        LDA IN+6
        JSR ToUpper
        CMP #'X'
        BNE TryAbsoluteY
        LDA #AM_ABSOLUTE_X
        STA AM
        LDX IN+1                      ; Get operand characters
        LDY IN+2
        JSR TwoCharsToBin             ; Convert to binary
        STA OPERAND+1                 ; Save it as the operand
        LDX IN+3                      ; Get operand characters
        LDY IN+4
        JSR TwoCharsToBin             ; Convert to binary
        STA OPERAND                   ; Save it as the operand
        JMP GenerateCode

; AM_ABSOLUTE_Y, e.g. LDA nnnn,Y
; 4 hex digits followed by ,Y
TryAbsoluteY:
        LDA IN                        ; Get length
        CMP #6                        ; Is it 6?
        BNE TryIndexedIndirect
        LDA IN+1                      ; Get first char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ TryIndexedIndirect
        LDA IN+2                      ; Get second char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ TryIndexedIndirect
        LDA IN+3                      ; Get third char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ TryIndexedIndirect
        LDA IN+4                      ; Get fourth char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ TryIndexedIndirect
        LDA IN+5
        CMP #','
        BNE TryIndexedIndirect
        LDA IN+6
        JSR ToUpper
        CMP #'Y'
        BNE TryIndexedIndirect
        LDA #AM_ABSOLUTE_Y
        STA AM
        LDX IN+1                      ; Get operand characters
        LDY IN+2
        JSR TwoCharsToBin             ; Convert to binary
        STA OPERAND+1                 ; Save it as the operand
        LDX IN+3                      ; Get operand characters
        LDY IN+4
        JSR TwoCharsToBin             ; Convert to binary
        STA OPERAND                   ; Save it as the operand
        JMP GenerateCode

; AM_INDEXED_INDIRECT, e.g. LDA (nn,X)
TryIndexedIndirect:
        LDA IN                        ; Get length
        CMP #6                        ; Is it 6?
        BNE TryIndirectIndexed
        LDA IN+1                      ; Get first char of operand
        CMP #'('
        BNE TryIndirectIndexed
        LDA IN+2                      ; Get second char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ TryIndirectIndexed
        LDA IN+3                      ; Get third char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ TryIndirectIndexed
        LDA IN+4                      ; Get fourth char of operand
        CMP #','                      ; Is it a comma?
        BNE TryIndirectIndexed
        LDA IN+5                      ; Get fifth char of operand
        JSR ToUpper
        CMP #'X'                      ; Is it an X?
        BNE TryIndirectIndexed
        LDA IN+6                      ; Get sixth char of operand
        CMP #')'                      ; Is it an )?
        BNE TryIndirectIndexed
        LDA #AM_INDEXED_INDIRECT      ; Yes, this is indexed indirect
        STA AM                        ; Save it
        LDX IN+2                      ; Get operand characters
        LDY IN+3
        JSR TwoCharsToBin             ; Convert to binary
        STA OPERAND                   ; Save it as the operand
        JMP GenerateCode

; AM_INDIRECT_INDEXED, e.g. LDA (nn),Y
TryIndirectIndexed:
        LDA IN                        ; Get length
        CMP #6                        ; Is it 6?
        BNE TryIndirect
        LDA IN+1                      ; Get first char of operand
        CMP #'('
        BNE TryIndirect
        LDA IN+2                      ; Get second char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ TryIndirect
        LDA IN+3                      ; Get third char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ TryIndirect
        LDA IN+4                      ; Get fourth char of operand
        CMP #')'                      ; Is it a )?
        BNE TryIndirect
        LDA IN+5                      ; Get fifth char of operand
        CMP #','                      ; Is it a comma?
        BNE TryIndirect
        LDA IN+6                      ; Get sixth char of operand
        JSR ToUpper
        CMP #'Y'                      ; Is it a Y?
        BNE TryIndirect
        LDA #AM_INDIRECT_INDEXED      ; Yes, this is indirect indexed
        STA AM                        ; Save it
        LDX IN+2                      ; Get operand characters
        LDY IN+3
        JSR TwoCharsToBin             ; Convert to binary
        STA OPERAND                   ; Save it as the operand
        JMP GenerateCode

; AM_INDIRECT, e.g. JMP (nnnn)
; l paren, 4 hex digits, r paren
TryIndirect:
        LDA IN                        ; Get length
        CMP #6                        ; Is it 6?
        BNE TryIndirectZP
        LDA IN+1                      ; Get first char of operand
        CMP #'('
        BNE TryIndirectZP
        LDA IN+2                      ; Get second char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ TryIndirectZP
        LDA IN+3                      ; Get third char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ TryIndirectZP
        LDA IN+4                      ; Get fourth char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ TryIndirectZP
        LDA IN+5                      ; Get fifth char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ TryIndirectZP
        LDA IN+6                      ; Get fourth char of operand
        CMP #')'                      ; Is it a )?
        BNE TryIndirectZP
        LDA #AM_INDIRECT              ; Yes, this is indirect
        STA AM                        ; Save it

        LDX IN+2                      ; Get operand characters
        LDY IN+3
        JSR TwoCharsToBin             ; Convert to binary
        STA OPERAND+1                 ; Save it as the operand
        LDX IN+4                      ; Get operand characters
        LDY IN+5
        JSR TwoCharsToBin             ; Convert to binary
        STA OPERAND                   ; Save it as the operand
        JMP GenerateCode

; AM_INDIRECT_ZEROPAGE, e.g. LDA (nn) [65C02 only]
TryIndirectZP:
        LDA IN                        ; Get length
        CMP #4                        ; Is it 4?
        BNE TryAbsIndInd
        LDA IN+1                      ; Get first char of operand
        CMP #'('
        BNE TryAbsIndInd
        LDA IN+2                      ; Get second char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ TryAbsIndInd
        LDA IN+3                      ; Get third char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ TryAbsIndInd
        LDA IN+4                      ; Get fourth char of operand
        CMP #')'                      ; Is it a )?
        BNE TryAbsIndInd
        LDA #AM_INDIRECT_ZEROPAGE     ; Yes, this is indirect zeropage
        STA AM                        ; Save it

        LDX IN+2                      ; Get operand characters
        LDY IN+3
        JSR TwoCharsToBin             ; Convert to binary
        STA OPERAND                   ; Save it as the operand
        JMP GenerateCode

; AM_ABSOLUTE_INDEXED_INDIRECT, e.g. JMP (nnnn,X) [65C02 only]
TryAbsIndInd:
        LDA IN                        ; Get length
        CMP #8                        ; Is it 8?
        BNE InvalidOp
        LDA IN+1                      ; Get first char of operand
        CMP #'('
        BNE InvalidOp
        LDA IN+2                      ; Get second char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ InvalidOp
        LDA IN+3                      ; Get third char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ InvalidOp
        LDA IN+4                      ; Get fourth char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ InvalidOp
        LDA IN+5                      ; Get fifth char of operand
        JSR IsHexDigit                ; Is it a hex digit?
        BEQ InvalidOp
        LDA IN+6                      ; Get sixth char of operand
        CMP #','                      ; Is it a ,?
        BNE InvalidOp
        LDA IN+7                      ; Get 7th char of operand
        JSR ToUpper
        CMP #'X'                      ; Is it a X?
        BNE InvalidOp
        LDA IN+8                      ; Get 8th char of operand
        CMP #')'                      ; Is it a )?
        BNE InvalidOp
        LDA #AM_ABSOLUTE_INDEXED_INDIRECT ; Yes, this is abolute indexed indirect
        STA AM                        ; Save it

        LDX IN+2                      ; Get operand characters
        LDY IN+3
        JSR TwoCharsToBin             ; Convert to binary
        STA OPERAND+1                 ; Save it as the operand
        LDX IN+4                      ; Get operand characters
        LDY IN+5
        JSR TwoCharsToBin             ; Convert to binary
        STA OPERAND                   ; Save it as the operand
        JMP GenerateCode

; If not any of the above, report "Invalid operand" and return.

InvalidOp:
        JSR PrintCR
        JSR Imprint
        .byte "Invalid operand", 0
        JMP PrintCR             ; Return via caller

GenerateCode:
        JSR PrintCR             ; Output newline

        JSR CheckAddressingModeValid   ; See if addressing mode is valid
        BNE OperandOkay

        JSR Imprint             ; Not a valid addressing mode
        .byte "Invalid addressing mode", 0

        JMP PrintCR             ; Return via caller

OperandOkay:

; Look up instruction length based on addressing mode and save it

        LDX AM                   ; Addressing mode
        LDA LENGTHS,X            ; Get instruction length for this addressing mode
        STA LEN                  ; Save it

; Write the opcode to memory

        LDA OPCODE               ; get opcode
        LDY #0
        STA (ADDR),Y             ; store it

; Check that we can write it back (in case destination memory is not writable).

        CMP (ADDR),Y             ; Do we read back what we wrote?
        BEQ WriteOperands        ; Yes, okay

; Memory is not writable for some reason, Report error and quit.

        JSR Imprint              ; Print error message
        .byte "Unable to write to $", 0
        LDX ADDR
        LDY ADDR+1
        JSR PrintAddress
        JMP PrintCR             ; Return via caller

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
TryZp:  CMP #AM_ZEROPAGE
        BNE TryZpX
        JMP OneOperand
TryZpX: CMP #AM_ZEROPAGE_X
        BNE TryZpY
        JMP OneOperand
TryZpY: CMP #AM_ZEROPAGE_Y
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
; i.e. (OPERAND,OPERAND+1) - ADDR,ADDR+1 - 2
; Report error if branch is out of 8-bit offset range.

Relative:
         LDA OPERAND                 ; destination low byte
         SEC
         SBC ADDR                    ; subtract address low byte
         STA OPERAND                 ; Save it
         LDA OPERAND+1               ; destination high byte
         SBC ADDR+1                  ; subtract address high byte (with any borrow)
         STA OPERAND+1               ; store it

         LDA OPERAND
         SEC
         SBC #2                      ; subtract 2 more
         STA OPERAND                 ; store it
         LDA OPERAND+1               ; destination high byte
         SBC #0                      ; subtract 0 (with any borrow)
         STA OPERAND+1               ; store it

; Report error if branch is out of 8-bit offset range.
; Valid range is $0000 - $007F and $FF80 - $FFFF

         LDA OPERAND+1              ; High byte
         BEQ OkayZero               ; Should be $))
         CMP #$FF
         BEQ OkayFF                 ; Or $FF
OutOfRange:
         JSR Imprint
         .byte "Relative branch out of range", 0
         JMP PrintCR                ; Return via caller

OkayZero:
         LDA OPERAND                ; Low byte
         BMI OutOfRange             ; must be $00-$7F (i.e. positive)
         JMP OneOperand

OkayFF:
         LDA OPERAND                ; Low byte
         BPL OutOfRange             ; must be $80-$FF (i.e. negative)

; Now fall through to one operand code

OneOperand:
        LDA OPERAND                  ; Get operand
        LDY #1                       ; Offset from instruction
        STA (ADDR),Y                 ; write it
        JMP ZeroOperands             ; done

TwoOperands:
        LDA OPERAND                  ; Get operand low byte
        LDY #1                       ; Offset from instruction
        STA (ADDR),Y                 ; write it
        INY
        LDA OPERAND+1                ; Get operand high byte
        STA (ADDR),Y                 ; write it

ZeroOperands:                        ; Nothing to do

; Update current address with instruction length

       CLC
       LDA ADDR                      ; Low byte
       ADC LEN                       ; Add length
       STA ADDR                      ; Store it
       LDA ADDR+1                    ; High byte
       ADC #0                        ; Add any carry
       STA ADDR+1                    ; Store it
       JMP AssembleLine              ; loop back to start of AssembleLine

; Look up three letter mnemonic, e.g. "NOP". On entry mnemonic is stored in MNEM.
; Write index value, e.g. OP_NOP, to OP. Set sit to OP_INV if not found.
; Registers changed: A, X, Y.
LookupMnemonic:
        LDX #0                  ; Holds current table index
        LDA #<MNEMONICS         ; Store address of start of table in T1 (L/H)
        STA T1
        LDA #>MNEMONICS
        STA T1+1
Loop:
        LDY #0                  ; Holds offset of string in table entry
        LDA MNEM,Y              ; Compare first char of mnemonic to table entry
        CMP (T1),Y
        BNE NextOp              ; If different, try next opcode
        INY
        LDA MNEM,Y              ; Compare second char of mnemonic to table entry
        CMP (T1),Y
        BNE NextOp              ; If different, try next opcode
        INY
        LDA MNEM,Y              ; Compare third char of mnemonic to table entry
        CMP (T1),Y
        BNE NextOp              ; If different, try next opcode

                                ; We found a match
        STX OP                  ; Store index in table (X) in OP
        RTS                     ; And return

NextOp:
        INX                     ; Increment table index
        CLC
        LDA T1                  ; Increment pointer to table entry (T1) as 16-bit value
        ADC #3                  ; Adding three because each entry is 3 bytes
        STA T1
        LDA T1+1                ; Add possible carry to high byte
        ADC #0
        STA T1+1

        LDA T1                  ; Did we reach the last entry (MNEMONICSEND?)
        CMP #<MNEMONICSEND      ; If not, keep searching
        BNE Loop
        LDA T1+1
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
        LDA #<OPCODES           ; Store address of start of table in T1 (L/H)
        STA T1
        LDA #>OPCODES
        STA T1+1
OpLoop:
        LDY #0                  ; Holds offset into table entry
        LDA (T1),Y              ; Get a table entry (instruction)
        CMP OP                  ; Is it the instruction we are looking for?
        BNE NextInst            ; If different, try next opcode
                                ; Instruction matched. Does the addressing mode match?
        INY                     ; Want second byte of table entry (address mode)
        LDA (T1),Y              ; Get a table entry (address mode
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
        LDA T1                  ; Increment pointer to table entry (T1) as 16-bit value
        ADC #2                  ; Add two because each entry is 2 bytes
        STA T1
        LDA T1+1                ; Add possible carry to high byte
        ADC #0
        STA T1+1
        JMP OpLoop

OpNotFound:                     ; End of table reached
        LDA #0                  ; Set false return value
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
@Invalid:
        LDA #0
        RTS
@Okay:
        LDA #1
        RTS

; Convert two characters containing hex digits to binary
; Chars passed in X (first char) and Y (second char).
; Returns value in A.
; e.g. X='1' Y='A' Returns A = $1A
; Does not check that characters are valid hex digits
TwoCharsToBin:
        TXA                     ; get first digit
        JSR CharToBin           ; convert to binary
        ASL A                   ; shift to upper nibble
        ASL A
        ASL A
        ASL A
        STA T1                  ; Save it
        TYA                     ; get second digit
        JSR CharToBin           ; convert to binary
        CLC
        ADC T1                  ; Add the upper nibble
        RTS

; Convert character containing a hex digit to binary.
; Char passed in A. Returns value in A.
; e.g. A='A' Returns A=$0A
; Does not check that character is valid hex digit.
CharToBin:
        JSR ToUpper
        CMP #'9'+1              ; Is it '0'-'9'?
        BMI @Digit              ; Branch if so
        SEC                     ; Otherwise must be 'A'-'F'
        SBC #'A'-10             ; convert to value
        RTS
@Digit:
        SEC
        SBC #'0'                ; convert to value
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
 OP_BRL = $47 ; [WDC 65816 only]
 OP_COP = $48 ; [WDC 65816 only]
 OP_JML = $49 ; [WDC 65816 only]
 OP_JSL = $4A ; [WDC 65816 only]
 OP_MVN = $4B ; [WDC 65816 only]
 OP_MVP = $4C ; [WDC 65816 only]
 OP_PEA = $4D ; [WDC 65816 only]
 OP_PEI = $4E ; [WDC 65816 only]
 OP_PER = $4F ; [WDC 65816 only]
 OP_PHB = $50 ; [WDC 65816 only]
 OP_PHD = $51 ; [WDC 65816 only]
 OP_PHK = $52 ; [WDC 65816 only]
 OP_PLB = $53 ; [WDC 65816 only]
 OP_PLD = $54 ; [WDC 65816 only]
 OP_REP = $56 ; [WDC 65816 only]
 OP_RTL = $57 ; [WDC 65816 only]
 OP_SEP = $58 ; [WDC 65816 only]
 OP_TCD = $59 ; [WDC 65816 only]
 OP_TCS = $5A ; [WDC 65816 only]
 OP_TDC = $5B ; [WDC 65816 only]
 OP_TSC = $5C ; [WDC 65816 only]
 OP_TXY = $5D ; [WDC 65816 only]
 OP_TYX = $5E ; [WDC 65816 only]
 OP_WDM = $5F ; [WDC 65816 only]
 OP_XBA = $60 ; [WDC 65816 only]
 OP_XCE = $61 ; [WDC 65816 only]

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
 AM_STACK_RELATIVE = 16            ; LDA 3,S [65816 only]
 AM_DIRECT_PAGE_INDIRECT_LONG = 17 ; LDA [$55] [65816 only]
 AM_ABSOLUTE_LONG = 18             ; LDA $02F000 [65816 only]
 AM_STACK_RELATIVE_INDIRECT_INDEXED_WITH_Y = 19 ; LDA (5,S),Y [65816 only]
 AM_DIRECT_PAGE_INDIRECT_LONG_INDEXED_WITH_Y = 20 ; LDA [$55],Y [65816 only]
 AM_ABSOLUTE_LONG_INDEXED_WITH_X = 21 ; LDA $12D080,X [65816 only]
 AM_BLOCK_MOVE = 22                ; MVP 0,0 [65816 only]
 AM_PROGRAM_COUNTER_RELATIVE_LONG = 23 ; BRL JMPLABEL [65816 only]
 AM_ABSOLUTE_INDIRECT_LONG = 24    ; JMP [$2000] [65816 only]

MNEMONICS:
MNEMONICS1:
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
 .byte "STP" ; $45 [WDC 65C02 and 65816 only]
 .byte "WAI" ; $46 [WDC 65C02 and 65816 only]
 .byte "BRL" ; $47 [WDC 65816 only]
 .byte "COP" ; $48 [WDC 65816 only]
 .byte "JMP" ; $49 [WDC 65816 only]
 .byte "JSL" ; $4A [WDC 65816 only]
 .byte "MVN" ; $4B [WDC 65816 only]
 .byte "MVP" ; $4C [WDC 65816 only]
 .byte "PEA" ; $4D [WDC 65816 only]
 .byte "PEI" ; $4E [WDC 65816 only]
 .byte "PER" ; $4F [WDC 65816 only]
 .byte "PHB" ; $50 [WDC 65816 only]
 .byte "PHD" ; $51 [WDC 65816 only]
 .byte "PHK" ; $52 [WDC 65816 only]
 .byte "PLB" ; $53 [WDC 65816 only]
 .byte "PLD" ; $54 [WDC 65816 only]
MNEMONICS2:
 .byte "???" ; $55 Unused because index is $FF
 .byte "REP" ; $56 [WDC 65816 only]
 .byte "RTL" ; $57 [WDC 65816 only]
 .byte "SEP" ; $58 [WDC 65816 only]
 .byte "TCD" ; $59 [WDC 65816 only]
 .byte "TCS" ; $5A [WDC 65816 only]
 .byte "TDC" ; $5B [WDC 65816 only]
 .byte "TSC" ; $5C [WDC 65816 only]
 .byte "TXY" ; $5D [WDC 65816 only]
 .byte "TYX" ; $5E [WDC 65816 only]
 .byte "WDM" ; $5F [WDC 65816 only]
 .byte "XBA" ; $60 [WDC 65816 only]
 .byte "XCE" ; $61 [WDC 65816 only]
 MNEMONICSEND: ; address of the end of the table

 OPCODES:
OPCODES1:
 .byte OP_BRK, AM_IMPLICIT           ; $00

 .byte OP_ORA, AM_INDEXED_INDIRECT   ; $01

.ifdef D65816
 .byte OP_COP, AM_ZEROPAGE           ; $02 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $02
.endif

.ifdef D65816
 .byte OP_ORA, AM_STACK_RELATIVE     ; $03 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $03
.endif

.ifdef D65C02
 .byte OP_TSB, AM_ZEROPAGE           ; $04 [65C02 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $04
.endif

 .byte OP_ORA, AM_ZEROPAGE           ; $05

 .byte OP_ASL, AM_ZEROPAGE           ; $06

.ifdef ROCKWELL
 .byte OP_RMB, AM_ZEROPAGE           ; $07 [65C02 only]
.elseif .defined(D65816)
 .byte OP_ORA, AM_DIRECT_PAGE_INDIRECT_LONG ; $07 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $07
.endif

 .byte OP_PHP, AM_IMPLICIT           ; $08

 .byte OP_ORA, AM_IMMEDIATE          ; $09

 .byte OP_ASL, AM_ACCUMULATOR        ; $0A

.ifdef D65816
 .byte OP_PHD, AM_IMPLICIT           ; $0B [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $0B
.endif

.ifdef D65C02
 .byte OP_TSB, AM_ABSOLUTE           ; $0C [65C02 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $0C
.endif

 .byte OP_ORA, AM_ABSOLUTE           ; $0D

 .byte OP_ASL, AM_ABSOLUTE           ; $0E

.ifdef ROCKWELL
 .byte OP_BBR, AM_ABSOLUTE           ; $0F [65C02 only]
.elseif .defined(D65816)
 .byte OP_ORA, AM_ABSOLUTE_LONG      ; $0F [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $0F
.endif

 .byte OP_BPL, AM_RELATIVE           ; $10

 .byte OP_ORA, AM_INDIRECT_INDEXED   ; $11

.ifdef D65C02
 .byte OP_ORA, AM_INDIRECT_ZEROPAGE  ; $12 [65C02 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $12
.endif

.ifdef D65816
 .byte OP_ORA, AM_STACK_RELATIVE_INDIRECT_INDEXED_WITH_Y ; $13 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $12
.endif

.ifdef D65C02
 .byte OP_TRB, AM_ZEROPAGE           ; $14 [65C02 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $12
.endif

 .byte OP_ORA, AM_ZEROPAGE_X         ; $15

 .byte OP_ASL, AM_ZEROPAGE_X         ; $16

.ifdef ROCKWELL
 .byte OP_RMB, AM_ZEROPAGE           ; $17 [65C02 only]
.elseif .defined(D65816)
 .byte OP_ORA, AM_DIRECT_PAGE_INDIRECT_LONG_INDEXED_WITH_Y ; $17 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $17
.endif

 .byte OP_CLC, AM_IMPLICIT           ; $18

 .byte OP_ORA, AM_ABSOLUTE_Y         ; $19

.ifdef D65C02
 .byte OP_INC, AM_ACCUMULATOR        ; $1A [65C02 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $1A
.endif

.ifdef D65816
 .byte OP_TCS, AM_IMPLICIT           ; $1B [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $1B
.endif

.ifdef D65C02
 .byte OP_TRB, AM_ABSOLUTE           ; $1C [65C02 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $1C
.endif

 .byte OP_ORA, AM_ABSOLUTE_X         ; $1D

 .byte OP_ASL, AM_ABSOLUTE_X         ; $1E

.ifdef ROCKWELL
 .byte OP_BBR, AM_ABSOLUTE           ; $1F [65C02 only]
.elseif .defined(D65816)
 .byte OP_ORA, AM_ABSOLUTE_LONG_INDEXED_WITH_X ; $1F [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $1F
.endif

 .byte OP_JSR, AM_ABSOLUTE           ; $20

 .byte OP_AND, AM_INDEXED_INDIRECT   ; $21

 .byte OP_JSR, AM_ABSOLUTE_LONG      ; $22

 .byte OP_AND, AM_STACK_RELATIVE     ; $23

 .byte OP_BIT, AM_ZEROPAGE           ; $24

 .byte OP_AND, AM_ZEROPAGE           ; $25

 .byte OP_ROL, AM_ZEROPAGE           ; $26

.ifdef ROCKWELL
 .byte OP_RMB, AM_ZEROPAGE           ; $27 [65C02 only]
.elseif .defined (D65816)
 .byte OP_AND, AM_DIRECT_PAGE_INDIRECT_LONG ; $27 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $27
.endif

 .byte OP_PLP, AM_IMPLICIT           ; $28

 .byte OP_AND, AM_IMMEDIATE          ; $29

 .byte OP_ROL, AM_ACCUMULATOR        ; $2A

.ifdef D65816
 .byte OP_PLD, AM_IMPLICIT           ; $2B [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $2B
.endif

 .byte OP_BIT, AM_ABSOLUTE           ; $2C

 .byte OP_AND, AM_ABSOLUTE           ; $2D

 .byte OP_ROL, AM_ABSOLUTE           ; $2E

.ifdef ROCKWELL
 .byte OP_BBR, AM_ABSOLUTE           ; $2F [65C02 only]
.elseif .defined (D65816)
 .byte OP_AND, AM_ABSOLUTE_LONG      ; $2F [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $2F
.endif

 .byte OP_BMI, AM_RELATIVE           ; $30

.ifdef D65C02
 .byte OP_AND, AM_INDIRECT_INDEXED   ; $31 [65C02 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $31
.endif

.ifdef D65C02
 .byte OP_AND, AM_INDIRECT_ZEROPAGE  ; $32 [65C02 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $32
.endif

.ifdef D65816
 .byte OP_AND, AM_STACK_RELATIVE_INDIRECT_INDEXED_WITH_Y ; $33 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $33
.endif

.ifdef D65C02
 .byte OP_BIT, AM_ZEROPAGE_X         ; $34 [65C02 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $34
.endif

 .byte OP_AND, AM_ZEROPAGE_X         ; $35

 .byte OP_ROL, AM_ZEROPAGE_X         ; $36

.ifdef ROCKWELL
 .byte OP_RMB, AM_ZEROPAGE           ; $37 [65C02 only]
.elseif .defined(D65816)
 .byte OP_AND, AM_DIRECT_PAGE_INDIRECT_LONG_INDEXED_WITH_Y ; $37 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $37
.endif

 .byte OP_SEC, AM_IMPLICIT           ; $38

 .byte OP_AND, AM_ABSOLUTE_Y         ; $39

.ifdef D65C02
 .byte OP_DEC, AM_ACCUMULATOR        ; $3A [65C02 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $3A
.endif

.ifdef D65816
 .byte OP_TSC, AM_IMPLICIT           ; $3B [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $3B
.endif

.ifdef D65C02
 .byte OP_BIT, AM_ABSOLUTE_X         ; $3C [65C02 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $3C
.endif

 .byte OP_AND, AM_ABSOLUTE_X         ; $3D

 .byte OP_ROL, AM_ABSOLUTE_X         ; $3E

.ifdef ROCKWELL
 .byte OP_BBR, AM_ABSOLUTE           ; $3F [65C02 only]
.elseif .defined(D65816)
 .byte OP_AND, AM_ABSOLUTE_LONG_INDEXED_WITH_X ; $3F [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $3F
.endif

 .byte OP_RTI, AM_IMPLICIT           ; $40

 .byte OP_EOR, AM_INDEXED_INDIRECT   ; $41

.ifdef D65816
 .byte OP_WDM, AM_ZEROPAGE           ; $42 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $42
.endif

.ifdef D65816
 .byte OP_EOR, AM_STACK_RELATIVE     ; $43 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $43
.endif

.ifdef D65816
 .byte OP_MVP, AM_BLOCK_MOVE         ; $44 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $44
.endif

 .byte OP_EOR, AM_ZEROPAGE           ; $45

 .byte OP_LSR, AM_ZEROPAGE           ; $46

.ifdef ROCKWELL
 .byte OP_RMB, AM_ZEROPAGE           ; $47 [65C02 only]
.elseif .defined(D65816)
 .byte OP_EOR, AM_DIRECT_PAGE_INDIRECT_LONG ; $47 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $47
.endif

 .byte OP_PHA, AM_IMPLICIT           ; $48

 .byte OP_EOR, AM_IMMEDIATE          ; $49

 .byte OP_LSR, AM_ACCUMULATOR        ; $4A

.ifdef D65816
 .byte OP_PHK, AM_IMPLICIT           ; $4B [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4B
.endif

 .byte OP_JMP, AM_ABSOLUTE           ; $4C

 .byte OP_EOR, AM_ABSOLUTE           ; $4D

 .byte OP_LSR, AM_ABSOLUTE           ; $4E

.ifdef ROCKWELL
 .byte OP_BBR, AM_ABSOLUTE           ; $4F [65C02 only]
.elseif .defined(D65816)
 .byte OP_EOR, AM_ABSOLUTE_LONG      ; $4F [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

 .byte OP_BVC, AM_RELATIVE           ; $50

 .byte OP_EOR, AM_INDIRECT_INDEXED   ; $51

.ifdef D65C02
 .byte OP_EOR, AM_INDIRECT_ZEROPAGE  ; $52 [65C02 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $52
.endif

.ifdef D65816
 .byte OP_EOR, AM_STACK_RELATIVE_INDIRECT_INDEXED_WITH_Y ; $53 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

.ifdef D65816
 .byte OP_MVN, AM_BLOCK_MOVE         ; $54 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

 .byte OP_EOR, AM_ZEROPAGE_X         ; $55

 .byte OP_LSR, AM_ZEROPAGE_X         ; $56

.ifdef ROCKWELL
 .byte OP_RMB, AM_ZEROPAGE           ; $57 [65C02 only]
.elseif .defined(D65816)
 .byte OP_EOR, AM_DIRECT_PAGE_INDIRECT_LONG_INDEXED_WITH_Y ; $57 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $57
.endif

 .byte OP_CLI, AM_IMPLICIT           ; $58

 .byte OP_EOR, AM_ABSOLUTE_Y         ; $59

.ifdef D65C02
 .byte OP_PHY, AM_IMPLICIT           ; $5A [65C02 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $5A
.endif

.ifdef D65816
 .byte OP_TCD, AM_IMPLICIT           ; $5B [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

.ifdef D65816
 .byte OP_JML, AM_ABSOLUTE_LONG      ; $5C [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

 .byte OP_EOR, AM_ABSOLUTE_X         ; $5D

 .byte OP_LSR, AM_ABSOLUTE_X         ; $5E

.ifdef ROCKWELL
 .byte OP_BBR, AM_ABSOLUTE           ; $5F [65C02 only]
.elseif .defined(D65816)
 .byte OP_EOR, AM_ABSOLUTE_LONG_INDEXED_WITH_X ; $5F [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $5F
.endif

 .byte OP_RTS, AM_IMPLICIT           ; $60

 .byte OP_ADC, AM_INDEXED_INDIRECT   ; $61

.ifdef D65816
 .byte OP_PER, AM_PROGRAM_COUNTER_RELATIVE_LONG ; $62 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

.ifdef D65816
 .byte OP_ADC, AM_STACK_RELATIVE     ; $63 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

.ifdef D65C02
 .byte OP_STZ, AM_ZEROPAGE           ; $64 [65C02 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $64
.endif

 .byte OP_ADC, AM_ZEROPAGE           ; $65

 .byte OP_ROR, AM_ZEROPAGE           ; $66

.ifdef ROCKWELL
 .byte OP_RMB, AM_ZEROPAGE           ; $67 [65C02 only]
.elseif .defined(D65816)
 .byte OP_ADC, AM_DIRECT_PAGE_INDIRECT_LONG ; $67 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $67
.endif

 .byte OP_PLA, AM_IMPLICIT           ; $68

 .byte OP_ADC, AM_IMMEDIATE          ; $69

 .byte OP_ROR, AM_ACCUMULATOR        ; $6A

.ifdef D65816
 .byte OP_RTL, AM_IMPLICIT           ; $6B [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

 .byte OP_JMP, AM_INDIRECT           ; $6C

 .byte OP_ADC, AM_ABSOLUTE           ; $6D

 .byte OP_ROR, AM_ABSOLUTE           ; $6E

.ifdef ROCKWELL
 .byte OP_BBR, AM_ABSOLUTE           ; $6F [65C02 only]
.elseif .defined(D65816)
 .byte OP_ADC, AM_ABSOLUTE_LONG      ; $6F [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $6F
.endif

 .byte OP_BVS, AM_RELATIVE           ; $70

 .byte OP_ADC, AM_INDIRECT_INDEXED   ; $71

.ifdef D65C02
 .byte OP_ADC, AM_INDIRECT_ZEROPAGE  ; $72 [65C02 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

.ifdef D65816
 .byte OP_ADC, AM_STACK_RELATIVE_INDIRECT_INDEXED_WITH_Y ; $73 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

.ifdef D65C02
 .byte OP_STZ, AM_ZEROPAGE_X         ; $74 [65C02 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $74
.endif

 .byte OP_ADC, AM_ZEROPAGE_X         ; $75

 .byte OP_ROR, AM_ZEROPAGE_X         ; $76

.ifdef ROCKWELL
 .byte OP_RMB, AM_ZEROPAGE           ; $77 [65C02 only]
.elseif .defined(D65816)
 .byte OP_ADC, AM_DIRECT_PAGE_INDIRECT_LONG_INDEXED_WITH_Y ; $77 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $77
.endif

 .byte OP_SEI, AM_IMPLICIT           ; $78

 .byte OP_ADC, AM_ABSOLUTE_Y         ; $79

.ifdef D65C02
 .byte OP_PLY, AM_IMPLICIT           ; $7A [65C02 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $7A
.endif

.ifdef D65816
 .byte OP_TDC, AM_IMPLICIT           ; $7B [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

.ifdef D65C02
 .byte OP_JMP, AM_ABSOLUTE_INDEXED_INDIRECT ; $7C [65C02 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $7C
.endif

 .byte OP_ADC, AM_ABSOLUTE_X         ; $7D

 .byte OP_ROR, AM_ABSOLUTE_X         ; $7E

.ifdef ROCKWELL
 .byte OP_BBR, AM_ABSOLUTE           ; $7F [65C02 only]
.elseif .defined(D65816)
 .byte OP_ADC, AM_ABSOLUTE_LONG_INDEXED_WITH_X ; $7F [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $7F
.endif

 .export OPCODES2

OPCODES2:

.ifdef D65C02
 .byte OP_BRA, AM_RELATIVE           ; $80 [65C02 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $80
.endif

 .byte OP_STA, AM_INDEXED_INDIRECT   ; $81

.ifdef D65816
 .byte OP_BRL, AM_PROGRAM_COUNTER_RELATIVE_LONG ; $82 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

.ifdef D65816
 .byte OP_STA, AM_STACK_RELATIVE     ; $83 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

 .byte OP_STY, AM_ZEROPAGE           ; $84

 .byte OP_STA, AM_ZEROPAGE           ; $85

 .byte OP_STX, AM_ZEROPAGE           ; $86

.ifdef ROCKWELL
 .byte OP_SMB, AM_ZEROPAGE           ; $87 [65C02 only]
.elseif .defined(D65816)
 .byte OP_STA, AM_DIRECT_PAGE_INDIRECT_LONG ; $87 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $87
.endif

 .byte OP_DEY, AM_IMPLICIT           ; $88

.ifdef D65C02
 .byte OP_BIT, AM_IMMEDIATE          ; $89 [65C02 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $89
.endif

 .byte OP_TXA, AM_IMPLICIT           ; $8A

.ifdef D65816
 .byte OP_PHB, AM_IMPLICIT           ; $8B [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

 .byte OP_STY, AM_ABSOLUTE           ; $8C

 .byte OP_STA, AM_ABSOLUTE           ; $8D

 .byte OP_STX, AM_ABSOLUTE           ; $8E

.ifdef ROCKWELL
 .byte OP_BBS, AM_ABSOLUTE           ; $8F [65C02 only]
.elseif .defined(D65816)
 .byte OP_STA, AM_ABSOLUTE_LONG      ; $8F [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $8F
.endif

 .byte OP_BCC, AM_RELATIVE           ; $90

 .byte OP_STA, AM_INDIRECT_INDEXED   ; $91

.ifdef D65C02
 .byte OP_STA, AM_INDIRECT_ZEROPAGE  ; $92 [65C02 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $92
.endif

.ifdef D65816
 .byte OP_STA, AM_STACK_RELATIVE_INDIRECT_INDEXED_WITH_Y ; $93 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

 .byte OP_STY, AM_ZEROPAGE_X         ; $94

 .byte OP_STA, AM_ZEROPAGE_X         ; $95

 .byte OP_STX, AM_ZEROPAGE_Y         ; $96

.ifdef ROCKWELL
 .byte OP_SMB, AM_ZEROPAGE           ; $97 [65C02 only]
.elseif .defined(D65816)
 .byte OP_STA, AM_DIRECT_PAGE_INDIRECT_LONG_INDEXED_WITH_Y ; $97 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $97
.endif

 .byte OP_TYA, AM_IMPLICIT           ; $98

 .byte OP_STA, AM_ABSOLUTE_Y         ; $99

 .byte OP_TXS, AM_IMPLICIT           ; $9A

.ifdef D65816
 .byte OP_TXY, AM_IMPLICIT           ; $9B [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

.ifdef D65C02
 .byte OP_STZ, AM_ABSOLUTE           ; $9C [65C02 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $9c
.endif

 .byte OP_STA, AM_ABSOLUTE_X         ; $9D

.ifdef D65C02
 .byte OP_STZ, AM_ABSOLUTE_X         ; $9E [65C02 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $9E
.endif

.ifdef ROCKWELL
 .byte OP_BBS, AM_ABSOLUTE           ; $9F [65C02 only]
.elseif .defined(D65816)
 .byte OP_STA, AM_ABSOLUTE_LONG_INDEXED_WITH_X ; $9F [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

 .byte OP_LDY, AM_IMMEDIATE          ; $A0

 .byte OP_LDA, AM_INDEXED_INDIRECT   ; $A1

 .byte OP_LDX, AM_IMMEDIATE          ; $A2

.ifdef D65816
 .byte OP_LDA, AM_STACK_RELATIVE     ; $A3 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

 .byte OP_LDY, AM_ZEROPAGE           ; $A4

 .byte OP_LDA, AM_ZEROPAGE           ; $A5

 .byte OP_LDX, AM_ZEROPAGE           ; $A6

.ifdef ROCKWELL
 .byte OP_SMB, AM_ZEROPAGE           ; $A7 [65C02 only]
.elseif .defined(D65816)
 .byte OP_LDA, AM_DIRECT_PAGE_INDIRECT_LONG ; $A7 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $A7
.endif

 .byte OP_TAY, AM_IMPLICIT           ; $A8

 .byte OP_LDA, AM_IMMEDIATE          ; $A9

 .byte OP_TAX, AM_IMPLICIT           ; $AA

.ifdef D65816
 .byte OP_PLB, AM_IMPLICIT           ; $AB [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

 .byte OP_LDY, AM_ABSOLUTE           ; $AC

 .byte OP_LDA, AM_ABSOLUTE           ; $AD

 .byte OP_LDX, AM_ABSOLUTE           ; $AE

.ifdef ROCKWELL
 .byte OP_BBS, AM_ABSOLUTE           ; $AF [65C02 only]
.elseif .defined(D65816)
 .byte OP_LDA, AM_ABSOLUTE_LONG      ; $AF [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

 .byte OP_BCS, AM_RELATIVE           ; $B0

 .byte OP_LDA, AM_INDIRECT_INDEXED   ; $B1

.ifdef D65C02
 .byte OP_LDA, AM_INDIRECT_ZEROPAGE  ; $B2 [65C02 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $B2
.endif

.ifdef D65816
 .byte OP_LDA, AM_STACK_RELATIVE_INDIRECT_INDEXED_WITH_Y ; $B3 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

 .byte OP_LDY, AM_ZEROPAGE_X         ; $B4

 .byte OP_LDA, AM_ZEROPAGE_X         ; $B5

 .byte OP_LDX, AM_ZEROPAGE_Y         ; $B6

.ifdef ROCKWELL
 .byte OP_SMB, AM_ZEROPAGE           ; $B7 [65C02 only]
.elseif .defined(D65816)
 .byte OP_LDA, AM_DIRECT_PAGE_INDIRECT_LONG_INDEXED_WITH_Y ; $B7 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $B7
.endif

 .byte OP_CLV, AM_IMPLICIT           ; $B8

 .byte OP_LDA, AM_ABSOLUTE_Y         ; $B9

 .byte OP_TSX, AM_IMPLICIT           ; $BA

.ifdef D65816
 .byte OP_TYX, AM_IMPLICIT           ; $BB [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

 .byte OP_LDY, AM_ABSOLUTE_X         ; $BC

 .byte OP_LDA, AM_ABSOLUTE_X         ; $BD

 .byte OP_LDX, AM_ABSOLUTE_Y         ; $BE

.ifdef ROCKWELL
 .byte OP_BBS, AM_ABSOLUTE           ; $BF [65C02 only]
.elseif .defined(D65816)
 .byte OP_LDA, AM_ABSOLUTE_LONG_INDEXED_WITH_X ; $BF [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $BF
.endif

 .byte OP_CPY, AM_IMMEDIATE          ; $C0

 .byte OP_CMP, AM_INDEXED_INDIRECT   ; $C1

.ifdef D65816
 .byte OP_REP, AM_IMMEDIATE          ; $C2 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

.ifdef D65816
 .byte OP_CMP, AM_STACK_RELATIVE     ; $C3 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

 .byte OP_CPY, AM_ZEROPAGE           ; $C4

 .byte OP_CMP, AM_ZEROPAGE           ; $C5

 .byte OP_DEC, AM_ZEROPAGE           ; $C6

.ifdef ROCKWELL
 .byte OP_SMB, AM_ZEROPAGE           ; $C7 [65C02 only]
.elseif .defined(D65816)
 .byte OP_CMP, AM_DIRECT_PAGE_INDIRECT_LONG ; $C7 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $C7
.endif

 .byte OP_INY, AM_IMPLICIT           ; $C8

 .byte OP_CMP, AM_IMMEDIATE          ; $C9

 .byte OP_DEX, AM_IMPLICIT           ; $CA

.if .defined(D65C02) .or .defined(D65816)
 .byte OP_WAI, AM_IMPLICIT           ; $CB [WDC 65C02 and 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $CB
.endif

 .byte OP_CPY, AM_ABSOLUTE           ; $CC

 .byte OP_CMP, AM_ABSOLUTE           ; $CD

 .byte OP_DEC, AM_ABSOLUTE           ; $CE

.ifdef ROCKWELL
 .byte OP_BBS, AM_ABSOLUTE           ; $CF [65C02 only]
.elseif .defined(D65816)
 .byte OP_CMP, AM_ABSOLUTE_LONG      ; $CF [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $CF
.endif

 .byte OP_BNE, AM_RELATIVE           ; $D0

 .byte OP_CMP, AM_INDIRECT_INDEXED   ; $D1

.ifdef D65C02
 .byte OP_CMP, AM_INDIRECT_ZEROPAGE  ; $D2 [65C02 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $D2
.endif

.ifdef D65816
 .byte OP_CMP, AM_STACK_RELATIVE_INDIRECT_INDEXED_WITH_Y ; $D3 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

.ifdef D65816
 .byte OP_PEI, AM_INDIRECT_ZEROPAGE  ; $D4 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

 .byte OP_CMP, AM_ZEROPAGE_X         ; $D5

 .byte OP_DEC, AM_ZEROPAGE_X         ; $D6

.ifdef ROCKWELL
 .byte OP_SMB, AM_ZEROPAGE           ; $D7 [65C02 only]
.elseif .defined(D65816)
 .byte OP_CMP, AM_DIRECT_PAGE_INDIRECT_LONG_INDEXED_WITH_Y ; $D7 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $D7
.endif

 .byte OP_CLD, AM_IMPLICIT           ; $D8

 .byte OP_CMP, AM_ABSOLUTE_Y         ; $D9

.ifdef D65C02
 .byte OP_PHX, AM_IMPLICIT           ; $DA [65C02 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $CF
.endif

.if .defined(D65C02) .or .defined(D65816)
 .byte OP_STP, AM_IMPLICIT           ; $DB [WDC 65C02 and 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $DB
.endif

.ifdef D65816
 .byte OP_JML, AM_ABSOLUTE_INDIRECT_LONG ; $DC [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

 .byte OP_CMP, AM_ABSOLUTE_X         ; $DD

 .byte OP_DEC, AM_ABSOLUTE_X         ; $DE

.ifdef ROCKWELL
 .byte OP_BBS, AM_ABSOLUTE           ; $DF [65C02 only]
.elseif .defined(D65816)
 .byte OP_CMP, AM_ABSOLUTE_LONG_INDEXED_WITH_X ; $DF [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $DF
.endif

 .byte OP_CPX, AM_IMMEDIATE          ; $E0

 .byte OP_SBC, AM_INDEXED_INDIRECT   ; $E1

.ifdef D65816
 .byte OP_SEP, AM_IMMEDIATE          ; $E2 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

.ifdef D65816
 .byte OP_SBC, AM_STACK_RELATIVE     ; $E3 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

 .byte OP_CPX, AM_ZEROPAGE           ; $E4

 .byte OP_SBC, AM_ZEROPAGE           ; $E5

 .byte OP_INC, AM_ZEROPAGE           ; $E6

.ifdef ROCKWELL
 .byte OP_SMB, AM_ZEROPAGE           ; $E7 [65C02 only]
.elseif .defined(D65816)
 .byte OP_SBC, AM_DIRECT_PAGE_INDIRECT_LONG ; $E7 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $E7
.endif

 .byte OP_INX, AM_IMPLICIT           ; $E8

 .byte OP_SBC, AM_IMMEDIATE          ; $E9

 .byte OP_NOP, AM_IMPLICIT           ; $EA

.ifdef D65816
 .byte OP_XBA, AM_IMPLICIT           ; $EB [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

 .byte OP_CPX, AM_ABSOLUTE           ; $EC

 .byte OP_SBC, AM_ABSOLUTE           ; $ED

 .byte OP_INC, AM_ABSOLUTE           ; $EE

.ifdef ROCKWELL
 .byte OP_BBS, AM_ABSOLUTE           ; $EF [65C02 only]
.elseif .defined(D65816)
 .byte OP_SBC, AM_ABSOLUTE_LONG      ; $EF [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $EF
.endif

 .byte OP_BEQ, AM_RELATIVE           ; $F0

 .byte OP_SBC, AM_INDIRECT_INDEXED   ; $F1

.ifdef D65C02
 .byte OP_SBC, AM_INDIRECT_ZEROPAGE  ; $F2 [65C02 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $F2
.endif

.ifdef D65816
 .byte OP_SBC, AM_STACK_RELATIVE_INDIRECT_INDEXED_WITH_Y ; $F3 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

.ifdef D65816
 .byte OP_PEA, AM_ABSOLUTE           ; $F4 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

 .byte OP_SBC, AM_ZEROPAGE_X         ; $F5

 .byte OP_INC, AM_ZEROPAGE_X         ; $F6

.ifdef ROCKWELL
 .byte OP_SMB, AM_ZEROPAGE           ; $F7 [65C02 only]
.elseif .defined(D65816)
 .byte OP_SBC, AM_DIRECT_PAGE_INDIRECT_LONG_INDEXED_WITH_Y ; $F7 [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $F7
.endif

 .byte OP_SED, AM_IMPLICIT           ; $F8

 .byte OP_SBC, AM_ABSOLUTE_Y         ; $F9

.ifdef D65C02
 .byte OP_PLX, AM_IMPLICIT           ; $FA [65C02 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $FA
.endif

.ifdef D65816
 .byte OP_XCE, AM_IMPLICIT           ; $FB [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

.ifdef D65816
 .byte OP_JSR, AM_ABSOLUTE_INDEXED_INDIRECT ; $FC [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $4F
.endif

 .byte OP_SBC, AM_ABSOLUTE_X         ; $FD

 .byte OP_INC, AM_ABSOLUTE_X         ; $FE

.ifdef ROCKWELL
 .byte OP_BBS, AM_ABSOLUTE           ; $FF [65C02 only]
.elseif .defined(D65816)
 .byte OP_SBC, AM_ABSOLUTE_LONG_INDEXED_WITH_X ; $FF [WDC 65816 only]
.else
 .byte OP_INV, AM_IMPLICIT           ; $FF
.endif