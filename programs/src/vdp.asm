.SETCPU "65C02"
.ORG $1000

VRAM = $A800 ; MODE = LOW
VDPReg = $A801 ; MODE = HIGH

ReadChar = $C003
T1 = $00
P1 = $09

Start:		JSR InitVDPRegs
		JSR ZapVRAM
		JSR LoadNameTable

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
ZapVRAM:	LDA #0    ; start at $0000
		LDX #0
    		JSR SetupVRAMWriteAddress
		LDX #192    ; count high
Nexf:		LDY #0      ; count low
Fill:		JSR WriteVRAM ; write zero
		INY
		BNE Fill
		INX
		BNE Nexf    ; 192*256
		RTS

LoadNameTable:	
		LDA #<NameTable	; set up name table pointer
		STA P1
		LDA #>NameTable
		STA P1+1
		LDA #$14	; $1400
    		LDX #$00
    		JSR SetupVRAMWriteAddress
                LDX #3          ; page counter
    		LDY #0
@Next:		LDA (P1), Y
                JSR WriteVRAM
		INY
		BNE @Next
		INC P1+1
		DEX
		BNE @Next
		RTS

LoadPatternTable:
		LDA #<PatternTable	; set up pattern table pointer
		STA P1
		LDA #>PatternTable
		STA P1+1
    		LDA #$08	        ; $0800
    		LDX #$00
    		JSR SetupVRAMWriteAddress
                LDY #$0                ; fist two patterns
@Next:          LDA (P1), Y
                JSR WriteVRAM
                INY
                CPY #$0F                 ; done?
                BNE @Next
                RTS

LoadColorTable:
                LDA #<ColorTable	; set up pattern table pointer
		STA P1
		LDA #>ColorTable
		STA P1+1
                LDA #$20	        ; $2000
    		LDX #$00
    		JSR SetupVRAMWriteAddress
@Next:          LDA (P1), Y
                JSR WriteVRAM
                INY
                CPY #32                 ; done?
                BNE @Next
                RTS

; Writes A to VRAM and delays for the next write (assumes 2mhz system)
WriteVRAM:      STA VRAM
                NOP
                NOP     ; 1 micro sec
                NOP
                NOP     ; 1 micro sec
                RTS     ; 3 micro secs

; Reads VRAM into A and delays for the next read (assumes 2mhz system)
ReadVRAM:       LDA VRAM
                NOP
                NOP     ; 1 micro sec
                NOP
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
.BYTE %10000000 ; R1 - 16KB VRAM, disable active display, disable interrup, Graphics I mode
.BYTE %00000101 ; R2 - address of Name Table in VRAM = $1400 (R2 * $400)
.BYTE %10000000 ; R3 - address of Color Table in VRAM = $2000 (R3 * $40 for Graphics I mode)
.BYTE %00000001 ; R4 - address of Pattern Table in VRAM = $0800 (R4 * $800 for Graphcis I mode)
.BYTE %00100000 ; R5 - address of Sprite Attribute Table in VRAM = $1000 (R5 * $80)
.BYTE %00000000 ; R6 - address of Sprite Pattern Table in VRAM = $0000 (R6 * $800)
.BYTE $07       ; R7 - backdrop color = cyan

; Name Table 48*16 = 768 unique screen locations
; Each entry of this table is a pointer to a pattern that will be rendered
; at a location on the screen represented by the index of the entry.
NameTable:
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00
.BYTE 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00, 00

; 256 patterns max.
PatternTable:
.BYTE $00, $00, $00, $00, $00, $00, $00, $00    ; 0 
.BYTE $10, $10, $FE, $FC, $38, $6C, $44, $00    ; 1

ColorTable:
.BYTE $B0       ; 0 - color of pattern 0 to 7
.BYTE $00       ; 1
.BYTE $00       ; 2
.BYTE $00       ; 3
.BYTE $00       ; 4
.BYTE $00       ; 5
.BYTE $00       ; 6
.BYTE $00       ; 7
.BYTE $00       ; 8
.BYTE $00       ; 9
.BYTE $00       ; 10
.BYTE $00       ; 11
.BYTE $00       ; 12
.BYTE $00       ; 13
.BYTE $00       ; 14
.BYTE $00       ; 15
.BYTE $00       ; 16
.BYTE $00       ; 17
.BYTE $00       ; 18
.BYTE $00       ; 19
.BYTE $00       ; 20
.BYTE $00       ; 21
.BYTE $00       ; 22
.BYTE $00       ; 23
.BYTE $00       ; 24
.BYTE $00       ; 25
.BYTE $00       ; 26
.BYTE $00       ; 27
.BYTE $00       ; 28
.BYTE $00       ; 29
.BYTE $00       ; 30
.BYTE $00       ; 31 - color of pattern 248 - 255



; VDP software operations:
;   - Write a byte to VRAM
;   - Read a byte from VRAM
;   - Write to one of the eight internal registers 
;   - Set up VRAM address by writing to the 14 bit Address Register
;   - Read VDP status register
;
; VRAM is located in the VDP memory map on address 0000 - 3FFF (16KB)