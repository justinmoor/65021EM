.SETCPU "65C02"
.ORG $5000

; from https://codebase64.org/doku.php?id=base:small_fast_8-bit_prng

PrintByte = $C00F
GetLine = $C006
WriteChar = $C000
InputBuffer = $200

Seed = $00
T1 = $09
P1 = $09

Start:		LDA #$00
                STA T1
@Loop:          LDA T1
                STA Seed
                JSR GenPRN
                JSR PrintByte
                JSR PrintNewline
                INC T1
                BNE @Loop
                RTS

GenPRN:		LDA Seed
		BEQ DoEor
		ASL
		BEQ NoEor
		BCC NoEor
DoEor:		EOR #$1D
NoEor:		STA Seed
                RTS

PrintNewline:   PHA
                LDA #$0D
                JSR WriteChar
                LDA #$0A
                JSR WriteChar
                PLA
                RTS