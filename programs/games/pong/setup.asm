
InitVDPRegs:	LDY #$80
		LDX #$0
@Loop:		LDA VDPInitTable, X
		STA VDPReg   ; data
		STY VDPReg   ; addr
		INY
		INX
		CPX #$8
		BNE @Loop
		RTS

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

LoadNameTable:  
		LDA #<NameTable	; set up name table pointer
		STA P1
		LDA #>NameTable
		STA P1+1
		LDA #$14	; $1400
    		LDX #$00
    		JSR SetupVRAMWriteAddress
@Next:          LDA (P1)
                JSR WriteVRAM
		INC P1		; Increment read pointer
		BNE @Continue
		INC P1+1
@Continue:	LDA P1		; check whether we've reached the end of the table
		CMP #<NameTableEnd
		BNE @Next
                LDA P1+1
		CMP #>NameTableEnd
		BNE @Next
@Done:		RTS

LoadPatternTable:
		LDA #<PatternTable	; set up pattern table pointer
		STA P1
		LDA #>PatternTable
		STA P1+1
    		LDA #$08	        ; $0800
    		LDX #$00
    		JSR SetupVRAMWriteAddress
@Next:          LDA (P1)
                JSR WriteVRAM
		INC P1		; Increment read pointer
		BNE @Continue
		INC P1 + 1
@Continue:	LDA P1		; check whether we've reached the end of the table
		CMP #<PatternTableEnd
		BNE @Next
                LDA P1 + 1
		CMP #>PatternTableEnd
		BNE @Next
@Done:		RTS

LoadColorTable: LDA #<ColorTable	; set up color table pointer
		STA P1
		LDA #>ColorTable
		STA P1+1
                LDA #$20	        ; $2000
    		LDX #$00
    		JSR SetupVRAMWriteAddress
		LDY #$0
@Next:          LDA (P1)
                JSR WriteVRAM
		INC P1		; Increment read pointer
		BNE @Continue
		INC P1 + 1
@Continue:	LDA P1		; check whether we've reached the end of the table
		CMP #<ColorTableEnd
		BNE @Next
                LDA P1 + 1
		CMP #>ColorTableEnd
		BNE @Next
@Done:		RTS

LoadSpriteAttributeTable:
		LDA #<SpriteAttributeTable	; set up pattern table pointer
		STA P1
		LDA #>SpriteAttributeTable
		STA P1+1
    		LDA #$10	        ; $1000
    		LDX #$00
    		JSR SetupVRAMWriteAddress
                LDY #$0                
@Next:          LDA (P1)
                JSR WriteVRAM
		INC P1		; Increment read pointer
		BNE @Continue
		INC P1 + 1
@Continue:	LDA P1		; check whether we've reached the end of the table
		CMP #<SpriteAttributeTableEnd
		BNE @Next
                LDA P1 + 1
		CMP #>SpriteAttributeTableEnd
		BNE @Next
@Done:		RTS

LoadSpritePatternTable:
		LDA #<SpritePatternTable	; set up pattern table pointer
		STA P1
		LDA #>SpritePatternTable
		STA P1+1
    		LDA #$00	        ; $00
    		LDX #$00
    		JSR SetupVRAMWriteAddress
                LDY #$0                ; fist sprite
@Next:          LDA (P1)
                JSR WriteVRAM
		INC P1		; Increment read pointer
		BNE @Continue
		INC P1 + 1
@Continue:	LDA P1		; check whether we've reached the end of the table
		CMP #<SpritePatternTableEnd
		BNE @Next
                LDA P1 + 1
		CMP #>SpritePatternTableEnd
		BNE @Next
@Done:		RTS

; Writes A to VRAM and delays for the next write (assumes 2mhz system)
WriteVRAM:      STA VRAM
                NOP     ; 1 micro sec
                NOP     ; 1 micro sec
                RTS     ; 3 micro secs

; Reads VRAM into A and delays for the next read (assumes 2mhz system)
ReadVRAM:       LDA VRAM
                NOP     ; 1 micro sec
                NOP     ; 1 micro sec
                RTS     ; 3 micro secs

; Writes to the VDP registers
; Input: A = data to write, X = register to write to
; Destroys A and X
WriteVDPReg:	STA VDPReg      ; data to be written
		TXA
		ORA #%10000000  ; MSB must be a 1, the next four bits must be 0s, and the lowest three bits are the actual register number      
		STA VDPReg      ; register to write to
		RTS

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

VDPInitTable:
.BYTE %00000000 ; R0 - enable Graphics I mode
.BYTE %11000011 ; R1 - 16KB VRAM, enable active display, disable interrupt, Graphics I mode
.BYTE %00000101 ; R2 - address of Name Table in VRAM = $1400 (R2 * $400)
.BYTE %10000000 ; R3 - address of Color Table in VRAM = $2000 (R3 * $40 for Graphics I mode)
.BYTE %00000001 ; R4 - address of Pattern Table in VRAM = $0800 (R4 * $800 for Graphcis I mode)
.BYTE %00100000 ; R5 - address of Sprite Attribute Table in VRAM = $1000 (R5 * $80)
.BYTE %00000000 ; R6 - address of Sprite Pattern Table in VRAM = $0000 (R6 * $800)
.BYTE $0F       ; R7 - backdrop color

; $1000
SpriteAttributeTable:
.BYTE $0, $0, $0, $01	; ball
.BYTE $00, $05, $4, $01	; paddle 1
.BYTE $00, $F9, $4, $01	; paddle 2
SpriteAttributeTableEnd:

SpritePatternTable:
.BYTE $70, $F8, $F8, $F8, $70, $00, $00, $00	; ball
.BYTE $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00	
.BYTE $00, $00, $00, $00, $00, $00, $00, $00	

.BYTE $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0	; paddle
.BYTE $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0	
.BYTE $00, $00, $00, $00, $00, $00, $00, $00	
.BYTE $00, $00, $00, $00, $00, $00, $00, $00
SpritePatternTableEnd:

; Name Table 32*24 = 768 unique screen locations
; Each entry of this table is a pointer to a pattern that will be rendered
; at a location on the screen represented by the index of the entry.
NameTable:
.BYTE $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $03, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $03, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $03, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $03, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $03, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $03, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $03, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $03, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $03, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $03, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02, $02
NameTableEnd:

PatternTable:
.BYTE $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $FF, $FF, $FF, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $FF, $FF, $FF
.BYTE $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E0
.BYTE $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
PatternTableEnd:

ColorTable:
.BYTE $10       ; 0 - color of pattern 0 to 7
ColorTableEnd:


; VRAM is located in the VDP memory map on address 0000 - 3FFF (16KB)
; 0 transparant
; 1 black
; 2 medium green
; 3 light green
; 4 dark blue
; 5 light blue
; 6 dark red
; 7 cyan
; 8 medium red
; 9 light red
; A dark yellow
; B light yellow
; C dark green
; D magenta
; E gray
; F white

TitleScreen:
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $04, $04, $04, $04, $00, $04, $04, $04, $04, $00, $04, $04, $04, $04, $00, $04, $04, $04, $04, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $04, $00, $00, $04, $00, $04, $00, $00, $04, $00, $04, $00, $00, $04, $00, $04, $00, $00, $04, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $04, $00, $00, $04, $00, $04, $00, $00, $04, $00, $04, $00, $00, $04, $00, $04, $00, $00, $04, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $04, $00, $00, $04, $00, $04, $00, $00, $04, $00, $04, $00, $00, $04, $00, $04, $00, $00, $04, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $04, $04, $04, $04, $00, $04, $00, $00, $04, $00, $04, $00, $00, $04, $00, $04, $04, $04, $04, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $04, $00, $00, $00, $00, $04, $00, $00, $04, $00, $04, $00, $00, $04, $00, $00, $00, $00, $04, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $04, $00, $00, $00, $00, $04, $00, $00, $04, $00, $04, $00, $00, $04, $00, $00, $00, $00, $04, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $04, $00, $00, $00, $00, $04, $00, $00, $04, $00, $04, $00, $00, $04, $00, $00, $00, $00, $04, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $04, $00, $00, $00, $00, $04, $00, $00, $04, $00, $04, $00, $00, $04, $00, $00, $00, $00, $04, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $04, $00, $00, $00, $00, $04, $04, $04, $04, $00, $04, $00, $00, $04, $00, $04, $04, $04, $04, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
.BYTE $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
TitleScreenEnd:

; 0x40:   0100 0000 
; 0x2000: 0010 0000 0000 0000 

; 0000 0000
; 0000 0010
; 0000 0100