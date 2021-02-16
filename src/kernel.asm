    .setcpu "65C02"

    .segment "VECTORS"

    .word   NMI
    .word   RESET
    .word   IRQ

    .code

    VIA_DATAB = $8000
    VIA_DATAA = $8001

    VIA_DDRB = $8002
    VIA_DDRA = $8003

    spiWriteBuffer = $20

    max3100ReadBuffer = $30
    spiReadBuffer = $10

RESET:  JMP INIT
NMI:    RTI
IRQ:    RTI

INIT:
INIT_VIA:
    LDX #$FF        ; setup stack
    TXS        
    LDA #%00000011  ; configure the MOSI and CLK pin as outputs, others as inputs
    STA VIA_DDRB
    LDA #$FF
    STA VIA_DDRA    ; configure all pins as outputs, 8 slave selects available
    STA VIA_DATAA   ; set all to high
    JSR WRITE_MAX3100_CONFIG

    LDX #0
LOOP:
    LDA text,x
    BEQ STOP
    JSR WRITE_CHAR
    INX
    JMP LOOP
STOP:
    JSR READ_CHAR
    BCC STOP
    JSR WRITE_CHAR
    JMP STOP    

WRITE_MAX3100_CONFIG:
    PHY
    PHA
    LDY #%11000000          ; MAX3100 Config: 11000000 00001010
    LDA #%00001010          ; 9600 baud
    JSR WRITE_MAX
    PLY
    PLA
    RTS                     

READ_MAX3100_CONFIG:
    PHY
    LDY #%01000000
    LDA #%00000000
    JSR WRITE_MAX
    PLY
    LDA max3100ReadBuffer
    RTS                     ; A holds higher byte of DIN when returning

READ_CHAR:
    PHY
    LDY #0
    LDA #0
    JSR WRITE_MAX
    PLY
    CLC
    LDA max3100ReadBuffer
    ROL
    LDA max3100ReadBuffer + 1
    RTS

WRITE_CHAR:
WAIT:
    PHY
    PHA
    JSR READ_MAX3100_CONFIG
    AND #%01000000
    BEQ WAIT
    PLA
    LDY #%10000000
    JSR WRITE_MAX
    PLY
    RTS
; writes a 16 bit sequence to the MAX3100
; assumes the command is stored in the Y register and the
; actual data in the A register
WRITE_MAX:
    PHA
    TYA
    STZ VIA_DATAA           ; select MAX3100
    JSR SPI_WRITE_BYTE
    STA max3100ReadBuffer
    PLA
    JSR SPI_WRITE_BYTE
    STA max3100ReadBuffer + 1
    LDA #$FF
    STA VIA_DATAA           ; deselect MAX3100
    RTS

SPI_WRITE_BYTE:
    STA spiWriteBuffer
    LDY #$8                 ; write 8 bits
WRITE_BIT:
    LDA #%0                 ; zero bit the output line
    ROL spiWriteBuffer         ; rotate the buffer so the bit to be written is represented by the carry flag
    BCC WRITE               ; 0 in carry flag? continue to writing the zero bit
    ORA #%00000010          ; 1 in carry flag, set MOSI to high
WRITE:
    STA VIA_DATAB           ; write bit
    INC VIA_DATAB           ; set clock high
    LDA VIA_DATAB           ; read bit
    ROL                     ; just read bit is represented in PB7, rotate it into carry
    ROL spiReadBuffer          ; rotate bit from carry into spiReadBuffer
    DEC VIA_DATAB           ; set clock low
    DEY
    BNE WRITE_BIT
    LDA spiReadBuffer
    RTS

text:
    .asciiz "welcome"
