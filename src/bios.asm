
;-------------------------------------------------------------------------
;   65021EM BIOS
;
;   The BIOS is responsible for initializing the 6522, which 
;   is used to talk to the MAX3100. The MAX3100 is initialized
;   by sending 16 bit commands over SPI by bitbanging the protocol.
;
;   The MAX3100 is responsible for UART communication.
;
;-------------------------------------------------------------------------

VIA_DATAB = $8000
VIA_DATAA = $8001

VIA_DDRB = $8002
VIA_DDRA = $8003

SPI_RD_BUFF = $110
SPI_WR_BUFF = $100

MAX3100_RD_BUFF = $130

INIT_BIOS:    
    LDA #%00000011  ; configure the MOSI and CLK pin as outputs, others as inputs
    STA VIA_DDRB
    LDA #$FF
    STA VIA_DDRA    ; configure all pins as outputs, 8 slave selects available
    STA VIA_DATAA   ; set all to high
    JSR WRITE_MAX3100_CONFIG
    RTS

WRITE_MAX3100_CONFIG:
    PHY
    PHA
    LDY #%11000000      ; MAX3100 Config: 11000000 00001010
    LDA #%00001001      ; 9600 baud
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
    LDA MAX3100_RD_BUFF
    RTS    

; writes a 16 bit sequence to the MAX3100
; assumes the command is stored in the Y register and the
; actual data in the A register
WRITE_MAX:
    PHA
    TYA
    STZ VIA_DATAA           ; select MAX3100
    JSR SPI_WRITE_BYTE
    STA MAX3100_RD_BUFF
    PLA
    JSR SPI_WRITE_BYTE
    STA MAX3100_RD_BUFF + 1
    LDA #$FF
    STA VIA_DATAA           ; deselect MAX3100
    RTS            

SPI_WRITE_BYTE:
    STA SPI_WR_BUFF
    LDY #$8                 ; write 8 bits
WRITE_BIT:
    LDA #%0                 ; zero bit the output line
    ROL SPI_WR_BUFF         ; rotate the buffer so the bit to be written is represented by the carry flag
    BCC WRITE               ; 0 in carry flag? continue to writing the zero bit
    ORA #%00000010          ; 1 in carry flag, set MOSI to high
WRITE:
    STA VIA_DATAB           ; write bit
    INC VIA_DATAB           ; set clock high
    LDA VIA_DATAB           ; read bit
    ROL                     ; just read bit is represented in PB7, rotate it into carry
    ROL SPI_RD_BUFF         ; rotate bit from carry into SPI_RD_BUFF
    DEC VIA_DATAB           ; set clock low
    DEY
    BNE WRITE_BIT
    LDA SPI_RD_BUFF
    RTS

READ_CHAR:
    PHY
    LDY #0
    LDA #0
    JSR WRITE_MAX
    PLY
    CLC
    LDA MAX3100_RD_BUFF
    ROL
    LDA MAX3100_RD_BUFF + 1
    RTS

WRITE_CHAR:
@WAIT:
    PHY
    PHA
    JSR READ_MAX3100_CONFIG
    AND #%01000000
    BEQ @WAIT
    PLA
    LDY #%10000000
    JSR WRITE_MAX
    PLY
    RTS