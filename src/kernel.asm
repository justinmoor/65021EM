;-------------------------------------------------------------------------
;   65021EM Kernel code
;   Responsible for initializing hardware
;   Contains basic IO routines (SPI bitbang, serial write)
; 
;   User starts in a basic monitor based on Steve Wozniak's Wozmon 
;   for the Apple 1
;-------------------------------------------------------------------------

    .setcpu "65C02"

    .segment "VECTORS"

    .word   NMI
    .word   RESET
    .word   IRQ

    .code


IN          = $0200     ;*Input buffer
XAML        = $24       ;*Index pointers
XAMH        = $25
STL         = $26
STH         = $27
L           = $28
H           = $29
YSAV        = $2A
MODE        = $2B
MSGL        = $2C
MSGH        = $2D
COUNTER     = $2E
CRC         = $2F
CRCCHECK    = $30

BS          = $88       ; Backspace key, arrow left key
CR          = $0D       ; Carriage Return
NEWL        = $0A
ENT         = $8D
ESC         = $9B       ; ESC key
PROMPT      = $5C       ;'\' Prompt character

VIA_DATAB = $8000
VIA_DATAA = $8001

VIA_DDRB = $8002
VIA_DDRA = $8003

spiWriteBuffer = $100

max3100ReadBuffer = $130
spiReadBuffer = $110

RESET:  JMP INIT
NMI:    RTI
IRQ:    RTI

INIT: 
    LDX #$FF        ; setup stack
    TXS        
    LDA #%00000011  ; configure the MOSI and CLK pin as outputs, others as inputs
    STA VIA_DDRB
    LDA #$FF
    STA VIA_DDRA    ; configure all pins as outputs, 8 slave selects available
    STA VIA_DATAA   ; set all to high
    JSR WRITE_MAX3100_CONFIG

    CLD             ;Clear decimal arithmetic mode.
    CLI
    LDA #NEWL
    JSR ECHO
    LDA #CR
    JSR ECHO        ;* New line.
    LDA #<MSG1
    STA MSGL
    LDA #>MSG1
    STA MSGH
    JSR SHWMSG      ;* Show Welcome.

SOFTRESET:  
    LDA #$9B
NOTCR:
    CMP #BS         ;"<-"? * Note this was chaged to $88 which is the back space key.
    BEQ BACKSPACE   ;Yes.
    CMP #ESC        ;ESC?
    BEQ ESCAPE      ;Yes.
    INY             ;Advance text index.
    BPL NEXTCHAR    ;Auto ESC if >127.
ESCAPE:
    LDA #CR
    JSR ECHO        ;* New line.
    LDA #NEWL
    JSR ECHO
    LDA #PROMPT      ;"\"
    JSR ECHO        ;Output it.
GETLINE:     
    LDA #NEWL
    JSR ECHO
    LDA #CR         ;CR.
    JSR ECHO        ;Output it.
    LDY #$01        ;Initiallize text index.
BACKSPACE:   
    DEY             ;Backup text index.
    BMI GETLINE     ;Beyond start of line, reinitialize.
    LDA #$A0        ;*Space, overwrite the backspaced char.
    JSR ECHO
    LDA #$88        ;*Backspace again to get to correct pos.
    JSR ECHO
NEXTCHAR:    
    JSR READ_CHAR
    BCC NEXTCHAR
    CMP #$60        ;*Is it Lower case
    BMI CONVERT     ;*Nope, just convert it
    AND #$5F        ;*If lower case, convert to Upper case
CONVERT:     
    ORA #$80        ;*Convert it to "ASCII Keyboard" Input
    STA IN,Y        ;Add to text buffer.
    JSR ECHO        ;Display character.
    CMP #ENT        ;CR?
    BNE NOTCR       ;No.
    LDY #$FF        ;Reset text index.
    LDA #$00        ;For XAM mode.
    TAX             ;0->X.
SETSTOR:    
    ASL             ;Leaves $7B if setting STOR mode.
SETMODE:
    STA MODE        ;$00 = XAM, $7B = STOR, $AE = BLOK XAM.
BLSKIP: 
    INY             ;Advance text index.
NEXTITEM:    
    LDA IN,Y        ;Get character.
    CMP #ENT        ;CR?
    BEQ GETLINE     ;Yes, done this line.
    CMP #$AE        ;"."?
    BCC BLSKIP      ;Skip delimiter.
    BEQ SETMODE     ;Set BLOCK XAM mode.
    CMP #$BA        ;":"?
    BEQ SETSTOR     ;Yes, set STOR mode.
    CMP #$D2        ;"R"?
    BEQ RUN         ;Yes, run user program.
    STX L           ;$00->L.
    STX H           ; and H.
    STY YSAV        ;Save Y for comparison.
NEXTHEX:
    LDA IN,Y        ;Get character for hex test.
    EOR #$B0        ;Map digits to $0-9.
    CMP #$0A        ;Digit?
    BCC DIG         ;Yes.
    ADC #$88        ;Map letter "A"-"F" to $FA-FF.
    CMP #$FA        ;Hex letter?
    BCC NOTHEX      ;No, character not hex.
DIG:
    ASL
    ASL             ;Hex digit to MSD of A.
    ASL
    ASL
    LDX #$04        ;Shift count.
HEXSHIFT:    
    ASL             ;Hex digit left MSB to carry.
    ROL L           ;Rotate into LSD.
    ROL H           ;Rotate into MSD's.
    DEX             ;Done 4 shifts?
    BNE HEXSHIFT    ;No, loop.
    INY             ;Advance text index.
    BNE NEXTHEX     ;Always taken. Check next character for hex.
NOTHEX:      
    CPY YSAV        ;Check if L, H empty (no hex digits).
    BNE NOESCAPE    ;* Branch out of range, had to improvise...
    JMP ESCAPE      ;Yes, generate ESC sequence.

RUN:
    JSR ACTRUN      ;* JSR to the Address we want to run.
    JMP SOFTRESET   ;* When returned for the program, reset EWOZ.
ACTRUN:
    JMP (XAML)      ;Run at current XAM index.

NOESCAPE:
    BIT MODE        ;Test MODE byte.
    BVC NOTSTOR     ;B6=0 for STOR, 1 for XAM and BLOCK XAM
    LDA L           ;LSD's of hex data.
    STA (STL, X)    ;Store at current "store index".
    INC STL         ;Increment store index.
    BNE NEXTITEM    ;Get next item. (no carry).
    INC STH         ;Add carry to 'store index' high order.
TONEXTITEM:
    JMP NEXTITEM    ;Get next command item.
NOTSTOR:
    BMI XAMNEXT     ;B7=0 for XAM, 1 for BLOCK XAM.
    LDX #$02        ;Byte count.
SETADR:
    LDA L-1,X       ;Copy hex data to
    STA STL-1,X     ;"store index".
    STA XAML-1,X    ;And to "XAM index'.
    DEX             ;Next of 2 bytes.
    BNE SETADR      ;Loop unless X = 0.
NXTPRNT:
    BNE PRDATA      ;NE means no address to print.
    LDA #CR
    JSR ECHO        ;* New line.
    LDA #NEWL
    JSR ECHO
    LDA XAMH        ;'Examine index' high-order byte.
    JSR PRBYTE      ;Output it in hex format.
    LDA XAML        ;Low-order "examine index" byte.
    JSR PRBYTE      ;Output it in hex format.
    LDA #$BA        ;":".
    JSR ECHO        ;Output it.
PRDATA:
    LDA #$A0        ;Blank.
    JSR ECHO        ;Output it.
    LDA (XAML,X)    ;Get data byte at 'examine index".
    JSR PRBYTE      ;Output it in hex format.
XAMNEXT:
    STX MODE        ;0-> MODE (XAM mode).
    LDA XAML
    CMP L           ;Compare 'examine index" to hex data.
    LDA XAMH
    SBC H
    BCS TONEXTITEM  ;Not less, so no more data to output.
    INC XAML
    BNE MOD8CHK     ;Increment 'examine index".
    INC XAMH
MOD8CHK:
    LDA XAML        ;Check low-order 'exainine index' byte
    AND #$0F        ;For MOD 8=0 ** changed to $0F to get 16 values per row **
    BPL NXTPRNT     ;Always taken.
PRBYTE:
    PHA             ;Save A for LSD.
    LSR
    LSR
    LSR             ;MSD to LSD position.
    LSR
    JSR PRHEX       ;Output hex digit.
    PLA             ;Restore A.
PRHEX:
    AND #$0F        ;Mask LSD for hex print.
    ORA #$B0        ;Add "0".
    CMP #$BA        ;Digit?
    BCC ECHO        ;Yes, output it.
    ADC #$06        ;Add offset for letter.

ECHO:          
    PHA
    AND #$7F
    JSR WRITE_CHAR
    PLA
    RTS

SHWMSG:
    LDY #$0
PRINT:      
    LDA (MSGL),Y
    BEQ DONE
    JSR ECHO
    INY 
    BNE PRINT
DONE:       
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
    LDA max3100ReadBuffer
    RTS    

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
    ROL spiWriteBuffer      ; rotate the buffer so the bit to be written is represented by the carry flag
    BCC WRITE               ; 0 in carry flag? continue to writing the zero bit
    ORA #%00000010          ; 1 in carry flag, set MOSI to high
WRITE:
    STA VIA_DATAB           ; write bit
    INC VIA_DATAB           ; set clock high
    LDA VIA_DATAB           ; read bit
    ROL                     ; just read bit is represented in PB7, rotate it into carry
    ROL spiReadBuffer       ; rotate bit from carry into spiReadBuffer
    DEC VIA_DATAB           ; set clock low
    DEY
    BNE WRITE_BIT
    LDA spiReadBuffer
    RTS

MSG1:       .BYTE "welcome to the 65021em", 0
