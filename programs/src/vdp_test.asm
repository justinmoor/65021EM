.SETCPU "65C02"
.ORG $1000

VRAM = $A800 ; MODE = LOW
VDPReg = $A801 ; MODE = HIGH

ReadChar = $C003
T1 = $00

Start:
    JSR InitVDPRegs
@Loop:
    JSR ReadChar
    BCC @Loop
    CMP #'p'
    BEQ Party
    JSR A2Hex
    LDX #$07
    JSR WriteVDPReg
    JMP @Loop

InitVDPRegs:
    LDY #$80
    LDX #$0
@Loop:
    LDA VDPInitTable, X
    STA VDPReg   ; data
    STY VDPReg   ; addr
    INY
    INX
    CPX #$8
    BNE @Loop
    RTS

; Clear all video RAM ($0000-$3FFF)
ZapVRAM:
    LDY #%01000000    ; setup VRAM address, two MSBs must be 0 and 1 respectively during write setup
    LDA #0
    STA VDPReg
    STY VDPReg
    LDX #192    ; count high
Nexf:
    LDY #0      ; count low
Fill:
    STA VRAM   ; write a zero to VRAM
    INY
    BNE Fill
    INX
    BNE Nexf    ; 192*256
    RTS

Party:
    LDY #2
@Loop:
    JSR Delay
    LDX #$07
    TYA
    JSR WriteVDPReg
    INY
    CPY #$0F
    BEQ Party
    JMP @Loop
    
Delay:
    PHX
    PHY
    LDX #$FF
    LDY #$FF
@Delay:
    DEX
    BNE @Delay
    DEY
    BNE @Delay
    PLY
    PLX
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

A2Hex:          SEC
                SBC #'0'
                CMP #10
                BCC @Return
                SBC #7
@Return:        RTS
    
; Writes to the VDP registers
; Input: A = data to write, X = register to write to
; Destroys A and X
WriteVDPReg:
    STA VDPReg      ; data to be written
    TXA
    ORA #%10000000  ; MSB must be a 1, the next four bits must be 0s, and the lowest three bits are the actual register number      
    STA VDPReg      ; register to write to
    RTS

; Set ups VRAM address and writes a byte to that address
; Input: X = most significant byte of address, Y = least significant byte of address, A = byte to write
WriteAddressedVRAM:
    PHA             ; save A
    TYA
    ORA #%01000000  ; two MSBs must be 0 and 1 respectively during write setup 
    TAY
    PHA             ; restore A
    STX VDPReg      ; setup VRAM address
    STY VDPReg
WriteVRAM:
    STA VRAM      ; write byte to address
    RTS

; Set ups VRAM address and writes a byte to that address
; Input: X = most significant byte of address, Y = least significant byte of address
; Output: A = data read from address
ReadAddressedVRAM:
    ORA #%01000000  ; two MSBs must be 0 and 1 respectively during read setup 
    STX VDPReg      ; setup VRAM address
    STY VDPReg
ReadVRAM:
    LDA VRAM      ; read byte to address
    RTS

; VDP software operations:
;   - Write a byte to VRAM
;   - Read a byte from VRAM
;   - Write to one of the eight internal registers 
;   - Set up VRAM address by writing to the 14 bit Address Register
;   - Read VDP status register
;
; VRAM is located in the VDP memory map on address 0000 - 3FFF (16KB)