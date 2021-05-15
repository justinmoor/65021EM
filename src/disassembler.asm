
; 6502/65C02 Disassembler
;
; Credits to Jeff Tranter <tranter@pobox.com>

START_DISASM:
  LDA XAML    
  STA ADDR
  LDA XAMH
  STA ADDR+1
  JSR CRNEWL
  JSR CRNEWL
	JSR PRINTIMM              ; Print error message
	.byte "STARTING DISASSEMBLY AT ADDRESS $", 0
	LDX ADDR
	LDY ADDR+1
	JSR PrintAddress
  JSR CRNEWL
OUTER:
  JSR CRNEWL
  LDA #23
LOOP:
  PHA
  JSR DISASM
  PLA
  SEC
  SBC #1
  BNE LOOP
@SpaceOrEscape:
  JSR READ_CHAR
  BCC @SpaceOrEscape
  CMP #'l'
  BEQ OUTER
  CMP #ESC
  BNE @SpaceOrEscape
  RTS

; Disassemble instruction at address ADDR (low) / ADDR+1 (high). On
; return ADDR/ADDR+1 points to next instruction so it can be called
; again.
DISASM:
  LDX #0
  LDA (ADDR,X)          ; get instruction op code
  STA OPCODE
  BMI UPPER             ; if bit 7 set, in upper half of table
  ASL A                 ; double it since table is two bytes per entry
  TAX
  LDA OPCODES1,X        ; get the instruction type (e.g. OP_LDA)
  STA OP                ; store it
  INX
  LDA OPCODES1,X        ; get addressing mode
  STA AM                ; store it
  JMP AROUND
UPPER: 
  ASL A                 ; double it since table is two bytes per entry
  TAX
  LDA OPCODES2,X        ; get the instruction type (e.g. OP_LDA)
  STA OP                ; store it
  INX
  LDA OPCODES2,X        ; get addressing mode
  STA AM                ; store it
AROUND:
  TAX                   ; put addressing mode in X
  LDA LENGTHS,X         ; get instruction length given addressing mode
  STA LEN               ; store it
  LDX ADDR
  LDY ADDR+1
  JSR PrintAddress      ; print address
  LDX #3
  JSR PrintSpaces       ; then three spaces
  LDA OPCODE            ; get instruction op code
  JSR PrintByte         ; display the opcode byte
  JSR PrintSpace
  LDA LEN               ; how many bytes in the instruction?
  CMP #3
  BEQ THREE
  CMP #2
  BEQ TWO
  LDX #5
  JSR PrintSpaces
  JMP ONE
TWO:
  LDY #1
  LDA (ADDR),Y          ; get 1st operand byte
  JSR PrintByte         ; display it
  LDX #3
  JSR PrintSpaces
  JMP ONE
THREE:
  LDY #1
  LDA (ADDR),Y          ; get 1st operand byte
  JSR PrintByte         ; display it
  JSR PrintSpace
  LDY #2
  LDA (ADDR),Y          ; get 2nd operand byte
  JSR PrintByte         ; display it
ONE:              
  LDX #4
  JSR PrintSpaces
  LDA OP                ; get the op code
  ASL A                 ; multiply by 2
  CLC
  ADC OP                ; add one more to multiply by 3 since table is three bytes per entry
  TAX
  LDY #3
MNEM:
  LDA MNEMONICS,X       ; print three chars of mnemonic
  JSR PrintChar
  INX
  DEY
  BNE MNEM
; Display any operands based on addressing mode
  LDA OP                ; is it RMB or SMB?
  CMP #OP_RMB
  BEQ DOMB
  CMP #OP_SMB
  BNE TRYBB
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
  LDA (ADDR),Y          ; get 1st operand byte (low address)
  JSR PrintByte         ; display it
  JMP DONEOPS
TRYBB:
  LDA OP                ; is it BBR or BBS?
  CMP #OP_BBR
  BEQ DOBB
  CMP #OP_BBS
  BNE TRYIMP
DOBB:                   ; handle special BBRn and BBSn instructions
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
  LDA (ADDR),Y          ; get 1st operand byte (address)
  JSR PrintByte         ; display it
  LDA #','
  JSR PrintChar
  JSR PrintDollar
; Handle relative addressing
; Destination address is Current address + relative (sign extended so upper byte is $00 or $FF) + 3
  LDY #2
  LDA (ADDR),Y          ; get 2nd operand byte (relative branch offset)
  STA REL               ; save low byte of offset
  BMI @NEG              ; if negative, need to sign extend
  LDA #0                ; high byte is zero
  BEQ @ADD
@NEG:
  LDA #$FF              ; negative offset, high byte if $FF
@ADD:
  STA REL+1             ; save offset high byte
  LDA ADDR              ; take adresss
  CLC
  ADC REL               ; add offset
  STA DEST              ; and store
  LDA ADDR+1            ; also high byte (including carry)
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
  JMP DONEOPS
TRYIMP:
  LDA AM
  CMP #AM_IMPLICIT
  BNE TRYINV
  JMP DONEOPS           ; no operands
TRYINV: 
  CMP #AM_INVALID
  BNE TRYACC
  JMP DONEOPS           ; no operands
TRYACC:
  LDX #3
  JSR PrintSpaces
  CMP #AM_ACCUMULATOR
  BNE TRYIMM
  JMP DONEOPS
TRYIMM:
  CMP #AM_IMMEDIATE
  BNE TRYZP
  LDA #'#'
  JSR PrintChar
  JSR PrintDollar
  LDY #1
  LDA (ADDR),Y          ; get 1st operand byte (low address)
  JSR PrintByte         ; display it
  JMP DONEOPS
TRYZP:
  CMP #AM_ZEROPAGE
  BNE TRYZPX
  JSR PrintDollar
  LDY #1
  LDA (ADDR),Y          ; get 1st operand byte (low address)
  JSR PrintByte         ; display it
  JMP DONEOPS
TRYZPX:
  CMP #AM_ZEROPAGE_X
  BNE TRYZPY
  LDY #1
  LDA (ADDR),Y          ; get 1st operand byte (address)
  JSR PrintDollar
  JSR PrintByte         ; display it
  JSR PrintCommaX
  JMP DONEOPS       
TRYZPY:
  CMP #AM_ZEROPAGE_Y
  BNE TRYREL
  LDY #1
  LDA (ADDR),Y          ; get 1st operand byte (address)
  JSR PrintByte         ; display it
  JSR PrintCommaY
  JMP DONEOPS       
TRYREL:
  CMP #AM_RELATIVE
  BNE TRYABS
  JSR PrintDollar
; Handle relative addressing
; Destination address is Current address + relative (sign extended so upper byte is $00 or $FF) + 2
  LDY #1
  LDA (ADDR),Y          ; get 1st operand byte (relative branch offset)
  STA REL               ; save low byte of offset
  BMI NEG               ; if negative, need to sign extend
  LDA #0                ; high byte is zero
  BEQ ADD
NEG:
  LDA #$FF              ; negative offset, high byte if $FF
ADD:
  STA REL+1             ; save offset high byte
  LDA ADDR              ; take adresss
  CLC
  ADC REL               ; add offset
  STA DEST              ; and store
  LDA ADDR+1            ; also high byte (including carry)
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
  JMP DONEOPS
TRYABS:
  CMP #AM_ABSOLUTE
  BNE TRYABSX
  JSR PrintDollar
  LDY #2
  LDA (ADDR),Y          ; get 2nd operand byte (high address)
  JSR PrintByte         ; display it
  LDY #1
  LDA (ADDR),Y          ; get 1st operand byte (low address)
  JSR PrintByte         ; display it
  JMP DONEOPS
TRYABSX:
  CMP #AM_ABSOLUTE_X
  BNE TRYABSY
  JSR PrintDollar
  LDY #2
  LDA (ADDR),Y          ; get 2nd operand byte (high address)
  JSR PrintByte         ; display it
  LDY #1
  LDA (ADDR),Y          ; get 1st operand byte (low address)
  JSR PrintByte         ; display it
  JSR PrintCommaX
  JMP DONEOPS
TRYABSY:
  CMP #AM_ABSOLUTE_Y
  BNE TRYIND
  JSR PrintDollar
  LDY #2
  LDA (ADDR),Y          ; get 2nd operand byte (high address)
  JSR PrintByte         ; display it
  LDY #1
  LDA (ADDR),Y          ; get 1st operand byte (low address)
  JSR PrintByte         ; display it
  JSR PrintCommaY
  JMP DONEOPS
TRYIND:
  CMP #AM_INDIRECT
  BNE TRYINDXIND
  JSR PrintLParenDollar
  LDY #2
  LDA (ADDR),Y          ; get 2nd operand byte (high address)
  JSR PrintByte         ; display it
  LDY #1
  LDA (ADDR),Y          ; get 1st operand byte (low address)
  JSR PrintByte         ; display it
  JSR PrintRParen
  JMP DONEOPS
TRYINDXIND:
  CMP #AM_INDEXED_INDIRECT
  BNE TRYINDINDX
  JSR PrintLParenDollar
  LDY #1
  LDA (ADDR),Y          ; get 1st operand byte (low address)
  JSR PrintByte         ; display it
  JSR PrintCommaX
  JSR PrintRParen
  JMP DONEOPS
TRYINDINDX:
  CMP #AM_INDIRECT_INDEXED
  BNE TRYINDZ
  JSR PrintLParenDollar
  LDY #1
  LDA (ADDR),Y          ; get 1st operand byte (low address)
  JSR PrintByte         ; display it
  JSR PrintRParen
  JSR PrintCommaY
  JMP DONEOPS
TRYINDZ:
  CMP #AM_INDIRECT_ZEROPAGE ; [65C02 only]
  BNE TRYABINDIND
  JSR PrintLParenDollar
  LDY #1
  LDA (ADDR),Y          ; get 1st operand byte (low address)
  JSR PrintByte         ; display it
  JSR PrintRParen
  JMP DONEOPS
TRYABINDIND:
  CMP #AM_ABSOLUTE_INDEXED_INDIRECT ; [65C02 only]
  BNE DONEOPS
  JSR PrintLParenDollar
  LDY #2
  LDA (ADDR),Y          ; get 2nd operand byte (high address)
  JSR PrintByte         ; display it
  LDY #1
  LDA (ADDR),Y          ; get 1st operand byte (low address)
  JSR PrintByte         ; display it
  JSR PrintCommaX
  JSR PrintRParen
  JMP DONEOPS
DONEOPS:
  JSR CRNEWL
  LDA ADDR              ; update address to next instruction
  CLC
  ADC LEN
  STA ADDR
  LDA ADDR+1
  ADC #0                ; to add carry
  STA ADDR+1
  RTS

;------------------------------------------------------------------------
; Utility functions

; Print a dollar sign
; Registers changed: None
PrintDollar:
  PHA
  LDA #'$'
  JSR PrintChar
  PLA
  RTS

; Print ",X"
; Registers changed: None
PrintCommaX:
  PHA
  LDA #','
  JSR PrintChar
  LDA #'X'
  JSR PrintChar
  PLA
  RTS

; Print ",Y"
; Registers changed: None
PrintCommaY:
  PHA
  LDA #','
  JSR PrintChar
  LDA #'Y'
  JSR PrintChar
  PLA
  RTS

; Print "($"
; Registers changed: None
PrintLParenDollar:
  PHA
  LDA #'('
  JSR PrintChar
  LDA #'$'
  JSR PrintChar
  PLA
  RTS

; Print a right parenthesis
; Registers changed: None
PrintRParen:
  PHA
  LDA #')'
  JSR PrintChar
  PLA
  RTS

; Print number of spaces in X
; Registers changed: X
PrintSpaces:
  PHA
  LDA #SP
@LOOP:
  JSR PrintChar
  DEX
  BNE @LOOP
  PLA
  RTS
