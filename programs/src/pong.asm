
.SETCPU "65C02"
.ORG $5000

VRAM = $A800 ; MODE = LOW
VDPReg = $A801 ; MODE = HIGH

T1 = $00
P1 = $09

ISR = $600
ReadChar  = $C003

BallX = $1000
BallY = $1001

BallXVRAM = $1000
BallYVRAM = $1001

; Spite X = $00 - $FF
; Sprite Y = $00 - $AF

Start:          JSR InitVDPRegs
		JSR ZapVRAM
		JSR LoadSpriteAttributeTable
		JSR LoadSpritePatternTable
		JSR SetupGame
		JSR GameLoop
                RTS

SetupGame:	LDA #$77	
		STA BallX
		LDA #$4F
		STA BallY
		RTS

GameLoop:	LDA VDPReg
		AND #%10000000
		BEQ GameLoop
		JSR UpdateScreen
		JSR GetUserInput
		JMP GameLoop

UpdateScreen:	LDY #<BallXVRAM
		LDA #>BallXVRAM
		JSR SetupVRAMWriteAddress
		LDA BallY
		JSR WriteVRAM
		LDA BallX
		JSR WriteVRAM
		RTS

GetUserInput:	JSR ReadChar
		BCC @Done
		CMP #'w'
		BEQ @Up
		CMP #'s'
		BEQ @Down
		CMP #'a'
		BEQ @Left
		CMP #'d'
		BEQ @Right
		RTS
@Down:		INC BallY
		INC BallY
		INC BallY
		INC BallY
		JMP @Done
@Up:		DEC BallY
		DEC BallY
		DEC BallY
		DEC BallY
		JMP @Done
@Left:		DEC BallX
		DEC BallX
		DEC BallX
		DEC BallX
		JMP @Done
@Right:		INC BallX
		INC BallX
		INC BallX
		INC BallX
		JMP @Done
@Done:		RTS

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
		LDA P1		; check whether we've reached the end of the table
		CMP #<SpriteAttributeTableEnd
		BNE @Continue
                LDA P1 + 1
		CMP #>SpriteAttributeTableEnd
		BNE @Continue
		JMP @Done
@Continue:	INC P1		; Increment read pointer
		BNE @Next
		INC P1 + 1
		JMP @Next
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
		LDA P1		; check whether we've reached the end of the table
		CMP #<SpritePatternTableEnd
		BNE @Continue
                LDA P1 + 1
		CMP #>SpritePatternTableEnd
		BNE @Continue
		JMP @Done
@Continue:	INC P1		; Increment read pointer
		BNE @Next
		INC P1 + 1
		JMP @Next
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
.BYTE %11000001 ; R1 - 16KB VRAM, enable active display, disable interrupt, Graphics I mode
.BYTE %00000101 ; R2 - address of Name Table in VRAM = $1400 (R2 * $400)
.BYTE %10000000 ; R3 - address of Color Table in VRAM = $2000 (R3 * $40 for Graphics I mode)
.BYTE %00000001 ; R4 - address of Pattern Table in VRAM = $0800 (R4 * $800 for Graphcis I mode)
.BYTE %00100000 ; R5 - address of Sprite Attribute Table in VRAM = $1000 (R5 * $80)
.BYTE %00000000 ; R6 - address of Sprite Pattern Table in VRAM = $0000 (R6 * $800)
.BYTE $0F       ; R7 - backdrop color


SpriteAttributeTable:
.BYTE $0, $0, $0, $01	; ball
; .BYTE $30, $30, $1, $01	; paddle 1
; .BYTE $45, $50, $1, $01	; paddle 2
.BYTE $D0
SpriteAttributeTableEnd:

SpritePatternTable:
.BYTE $10, $38, $38, $10, $7C, $10, $10, $28	; 0
; .BYTE $3C, $7E, $FF, $FF, $FF, $FF, $7E, $3C	; ball
.BYTE $C0, $C0, $C0, $C0, $C0, $C0, $C0, $C0	; paddle
; .BYTE $00,$66,$FF,$FF,$FF,$7E,$3C,$18
SpritePatternTableEnd:

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
