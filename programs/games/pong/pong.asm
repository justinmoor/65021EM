
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
		JSR LoadNameTable
                JSR LoadPatternTable
		JSR LoadColorTable
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

.INCLUDE "setup.asm"
