.SETCPU "65C02"
.ORG $1000

MODE0 = $A800 ; VRAM
MODE1 = $A801 ; Registers

ReadChar = $C003
T1 = $00

Start:
    JSR InitVDPRegisters
@Loop:
    JSR ReadChar
    BCC @Loop
    JSR A2Hex
    LDX #$07
    JSR WriteVDPReg
    JMP @Loop

WriteVDPReg:
    PHA
    STX T1
    LDA #$80
    CLC
    ADC T1
    TAX
    PLA
    STA MODE1   ; data
    TXA
    STA MODE1   ; addr
    RTS
    RTS

InitVDPRegisters:
    LDY #$80
    LDX #$0
@Loop:
    LDA ITAB, X
    STA MODE1   ; data
    STY MODE1   ; addr
    INY
    INX
    CPX #$8
    BNE @Loop
    RTS

ITAB:
    .BYTE $00   ; R0
    ;  This sets register 1 to 0xE0 (B11100000) => So bit 0, 1 & 2 are set, meaning:
	;    - Selecting 16Kb of VRAM (bit 0)
	;    - Enable the active display (bit 1)
	;    - Enable interrupt (bit 2)
	;
    .BYTE %10100000
    ; .BYTE $E0   ; R1
    .BYTE $00   ; R2
    .BYTE $00   ; R3
    .BYTE $00   ; R4
    .BYTE $00   ; R5
    .BYTE $00   ; R6
    .BYTE $07   ; R7    backdrop color

A2Hex:          SEC
                SBC #'0'
                CMP #10
                BCC @Return
                SBC #7
@Return:        RTS
    