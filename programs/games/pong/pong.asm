
.SETCPU "65C02"
.ORG $5000

VRAM = $A800 ; MODE = LOW
VDPReg = $A801 ; MODE = HIGH

P1 = $09

; Constants
; BallVelocityM = $FD ; -3
; BallVelocityP = $03 ; 3

BallVelocityM = $FE ; -3
BallVelocityP = $02 ; 3

Paddle1X = $05
Paddle2X = $F9

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

; Velocity is either +3 ($03) or -3 ($FE) - using two's complements
BallXVelocity = $1100
BallYVelocity = $1101

KeyState = $00

; The range of an 8-bit signed number is -128 to 127. 
; The values -128 through -1 are, in hex, $80 through $FF, respectively. 
; The values 0 through 127 are, in hex, $00 through $7F, respectively. 

; Spite X = $00 - $FF
; Sprite Y = $00 - $AF

Start:          JSR InitVDPRegs
		JSR ZapVRAM
                JSR LoadPatternTable
		JSR LoadColorTable
		JSR ShowTitleScreen
		JSR LoadSpriteAttributeTable
		JSR LoadSpritePatternTable
		JSR LoadNameTable
		JSR SetupGame
		JSR GameLoop
                RTS

SetupGame:	LDA #XMiddle-1
		STA BallX
		LDA #YMiddle
		STA BallY
		LDA #YMiddle
		STA Paddle1Y
		LDA #YMiddle
		STA Paddle2Y
		LDA #BallVelocityM
		STA BallXVelocity
		STA BallYVelocity
		STZ KeyState
		CLC
		RTS

GameLoop:	JSR GetUserInput
		BCS Quit
		; JSR ProcessUserInput
		LDA VDPReg
		AND #%10000000
		BEQ GameLoop
		JSR UpdateScreen
		; JSR ProcessUserInput
		; BCS Quit
		JSR CheckPaddleCollisions
		JSR CheckWallCollisions
		JSR MoveBall
		JSR MoveAI
		JMP GameLoop
Quit:		RTS

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

MoveAI:
		; JSR MovePaddle1
		JSR MovePaddle2
		RTS

MovePaddle1:
		LDA BallX
		CMP #XMiddle
		BCS @Done
		LDA BallY
		SEC 
		SBC #08
		CMP Paddle1Y
		BCS @MoveDown
@MoveUp:	SEC
		LDA Paddle1Y
		SBC #02
		STA Paddle1Y
		JMP @Done
@MoveDown:	CLC
		LDA Paddle1Y
		ADC #02
		STA Paddle1Y
@Done:		RTS

MovePaddle2:
		LDA BallX
		CMP #XMiddle
		BCC @Done
		LDA BallY
		SEC 
		SBC #08
		CMP Paddle2Y
		BCS @MoveDown
@MoveUp:	SEC
		LDA Paddle2Y
		SBC #02
		STA Paddle2Y
		JMP @Done
@MoveDown:	CLC
		LDA Paddle2Y
		ADC #02
		STA Paddle2Y
@Done:		RTS

; bit		7 6 5 4 3 x x x
; button	w s i k esc
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
		CMP #$1B 		;esc
		BEQ @Escape
		RTS			; no input
@Paddle1Up:	LDA Paddle1Y
		SEC
		SBC #PVelocity
		STA Paddle1Y
		JMP @Done
@Paddle1Down:	LDA Paddle1Y
		CLC
		ADC #PVelocity
		STA Paddle1Y
		JMP @Done
@Paddle2Up:	LDA Paddle2Y
		SEC
		SBC #PVelocity
		STA Paddle2Y
		JMP @Done
@Paddle2Down:	LDA Paddle2Y
		CLC
		ADC #PVelocity
		STA Paddle2Y
		JMP @Done
@Escape:	SEC
		RTS
@Done:		CLC
		RTS

MoveBall:	LDA BallYVelocity
		CLC
		ADC BallY
		STA BallY
		LDA BallXVelocity
		CLC
		ADC BallX
		STA BallX
		RTS

CheckPaddleCollisions:
		JSR CheckPaddle1
		JSR CheckPaddle2
		RTS

CheckPaddle1:
		LDA BallX
		CMP #Paddle1X + 8
		BCS @Done ; exit early if not on same X
		LDA Paddle1Y
		CMP BallY
		BCS @Done
		CLC
		ADC #$0F	; paddle1 y + 16
		CMP BallY
		BCS @Collide
		JMP @Done
@Collide:	LDA #BallVelocityP
		STA BallXVelocity
@Done:		RTS

CheckPaddle2:
		LDA BallX
		CMP #Paddle2X - 8
		BCC @Done ; exit early if not on same X
		LDA Paddle2Y
		CMP BallY
		BCS @Done
		CLC
		ADC #$0F	; paddle2 y + 16
		CMP BallY
		BCS @Collide
		JMP @Done
@Collide:	LDA #BallVelocityM
		STA BallXVelocity
@Done:		RTS


CheckWallCollisions:
@TopWall:	LDA BallY
		CMP #$FE
		BCC @BottomWall
		LDA #BallVelocityP
		STA BallYVelocity
		JMP @Done
@BottomWall:	LDA BallY
		CMP #$AA
		BCC @RightWall
		LDA #BallVelocityM
		STA BallYVelocity
		JMP @Done
@RightWall:	LDA BallX
		CMP #$FE	
		BCC @LeftWall
		LDA #YMiddle
		STA BallY
		LDA #XMiddle
		STA BallX
		JMP @Done
@LeftWall:	LDA BallX
		CMP #$5		
		BCS @Done
		LDA #YMiddle
		STA BallY
		LDA #XMiddle
		STA BallX
@Done:		RTS

ShowTitleScreen:
		LDA #<TitleScreen 
		STA P1
		LDA #>TitleScreen
		STA P1+1
		LDA #$14	
    		LDX #$00
    		JSR SetupVRAMWriteAddress
@Next:          LDA (P1)
                JSR WriteVRAM
		INC P1		; Increment read pointer
		BNE @Continue
		INC P1+1
@Continue:	LDA P1		; check whether we've reached the end of the table
		CMP #<TitleScreenEnd
		BNE @Next
                LDA P1+1
		CMP #>TitleScreenEnd
		BNE @Next
@Loop:		JSR ReadChar
		BCC @Loop
@Done:		RTS

.INCLUDE "setup.asm"
