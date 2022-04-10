
.SETCPU "65C02"
.ORG $5000

VRAM = $A800 ; MODE = LOW
VDPReg = $A801 ; MODE = HIGH

T1 = $00
P1 = $09

; Constants
BallVelocity = $FB
YMiddle = $4F
XMiddle = $77

;
ISR = $600
ReadChar  = $C003
WriteChar = $C000

BallY = $1000
BallX = $1001
Paddle1Y = $1002
Paddle2Y = $1003

BallYVRAM = $1000
BallXVRAM = $1001

Paddle1YVRAM = $1004
Paddle2YVRAM = $1008

PVelocity = $0F

; Velocity is either +5 ($05) or -5 ($FB) - using two's complements
BallXVelocity = $1100
BallYVelocity = $1101

; The range of an 8-bit signed number is -128 to 127. 
; The values -128 through -1 are, in hex, $80 through $FF, respectively. 
; The values 0 through 127 are, in hex, $00 through $7F, respectively. 

; Spite X = $00 - $FF
; Sprite Y = $00 - $AF

Start:          JSR InitVDPRegs
		JSR ZapVRAM
		JSR LoadSpriteAttributeTable
		JSR LoadSpritePatternTable
		JSR SetupGame
		JSR GameLoop
                RTS

SetupGame:	
		LDA #XMiddle
		STA BallX
		LDA #YMiddle
		STA BallY
		LDA #YMiddle
		STA Paddle1Y
		LDA #YMiddle
		STA Paddle2Y
		LDA #BallVelocity	; 5
		STA BallXVelocity
		RTS

GameLoop:	LDA VDPReg
		AND #%10000000
		BEQ GameLoop
		JSR UpdateScreen
		JSR GetUserInput
		JSR CheckCollisions
		JSR MoveBall
		JMP GameLoop

UpdateScreen:	
		LDX #<BallYVRAM
		LDA #>BallYVRAM
		JSR SetupVRAMWriteAddress
		LDA BallY
		JSR WriteVRAM
		LDA BallX
		JSR WriteVRAM

		LDX #<Paddle1YVRAM
		LDA #>Paddle1YVRAM
		JSR SetupVRAMWriteAddress
		LDA Paddle1Y
		JSR WriteVRAM

		LDX #<Paddle2YVRAM
		LDA #>Paddle2YVRAM
		JSR SetupVRAMWriteAddress
		LDA Paddle2Y
		JSR WriteVRAM
		RTS

GetUserInput:	JSR ReadChar
		BCC @Done
		CMP #'w'
		BEQ @Paddle1Up
		CMP #'s'
		BEQ @Paddle1Down
		CMP #'i'
		BEQ @Paddle2Up
		CMP #'k'
		BEQ @Paddle2Down
		RTS
@Paddle1Up:	SEC
		LDA Paddle1Y
		SBC #PVelocity
		STA Paddle1Y
		JMP @Done
@Paddle1Down:	CLC
		LDA Paddle1Y
		ADC #PVelocity
		STA Paddle1Y
		JMP @Done
@Paddle2Up:	SEC
		LDA Paddle2Y
		SBC #PVelocity
		STA Paddle2Y
		JMP @Done
@Paddle2Down:	CLC
		LDA Paddle2Y
		ADC #PVelocity
		STA Paddle2Y
		JMP @Done
@Done:		RTS

MoveBall:	LDA BallXVelocity
		CLC
		ADC BallX
		STA BallX
@Done:		RTS

CheckCollisions:
@RightWall:	LDA BallX
		CMP #$F9	
		BCC @LeftWall
		LDA #$FB  ; -5
		STA BallXVelocity
		JMP @Done
@LeftWall:	LDA BallX
		CMP #$5		
		BCS @Done
		LDA #$05
		STA BallXVelocity
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

; 5033   A0 04       LDY   #$04
; 5035   A9 10       LDA   #$10
; 5037   20 04 51    JSR   $5104
; 503A   AD 02 10    LDA   $1002
; 503D   20 E5 50    JSR   $50E5
; 5040   60          RTS