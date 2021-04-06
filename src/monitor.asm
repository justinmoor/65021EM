;-------------------------------------------------------------------------
;   65021EM MACHINE LANGUAGE MONITOR
;
;   Basic machine language monitor based on Steve Wozniak's Wozmon
;   for the Apple 1.
;-------------------------------------------------------------------------

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

BS          = $88       ; Backspace key, arrow left key
CR          = $0D       ; Carriage Return
NEWL        = $0A
ENT         = $8D
ESC         = $9B       ; ESC key
PROMPT      = $3E       ;'>' Prompt character


START_MONITOR:
    CLI
    CLD
    LDA #<BANNER
    STA STRING_LO
    LDA #>BANNER
    STA STRIG_HI
    JSR PRINT
    LDA #<COMMANDS
    STA STRING_LO
    LDA #>COMMANDS
    STA STRIG_HI
    JSR PRINT

SOFTRESET:  
    LDA #$9B
NOTCR:
    CMP #BS         ; "<-"? * Note this was chaged to $88 which is the back space key.
    BEQ BACKSPACE   ; Yes.
    CMP #ESC        ; ESC?
    BEQ ESCAPE      ; Yes.
    INY             ; Advance text index.
    BPL NEXTCHAR    ; Auto ESC if >127.
ESCAPE:
GETLINE:
    LDA #CR
    JSR ECHO        ; * New line.
    LDA #NEWL
    JSR ECHO
    LDA #PROMPT     ; ">"
    JSR ECHO        ; Output it.
    LDA #$20
    JSR ECHO     
    LDY #$01        ; Initiallize text index.
BACKSPACE:   
    DEY             ; Backup text index.
    BMI GETLINE     ; Beyond start of line, reinitialize.
    LDA #$A0        ; *Space, overwrite the backspaced char.
    JSR ECHO
    LDA #BS         ; *Backspace again to get to correct pos.
    JSR ECHO
NEXTCHAR:    
    JSR READ_CHAR
    BCC NEXTCHAR
    CMP #$60        ; *Is it Lower case
    BMI CONVERT     ; *Nope, just convert it
    AND #$5F        ; *If lower case, convert to Upper case
CONVERT:     
    ORA #$80        ; The Apple 1 assumes high ascii, several coding tricks by Woz use this fact for memory optimalization
    STA IN,Y        ; Add to text buffer.
    JSR ECHO        ; Display character.
    CMP #ENT        ; CR?
    BNE NOTCR       ; No.
    LDY #$FF        ; Reset text index.
    LDA #$00        ; For XAM mode.
    TAX             ; 0->X.
SETSTOR:    
    ASL              ;Leaves $7B if setting STOR mode.
SETMODE:
    STA MODE        ; $00 = XAM, $7B = STOR, $AE = BLOK XAM.
BLSKIP: 
    INY             ; Advance text index.
NEXTITEM:    
    LDA IN,Y        ; Get character.
    CMP #ENT        ; CR?
    BEQ GETLINE     ; Yes, done this line.
    CMP #'.' + $80  ; "."? (high ascii $AE)
    BCC BLSKIP      ; Skip delimiter.
    BEQ SETMODE     ; Set BLOCK XAM mode.
    CMP #':' + $80  ; ":"? (high ascii $BA)
    BEQ SETSTOR     ; Yes, set STOR mode.
    CMP #'R' + $80  ; "R"? (high ascii $D2)
    BEQ RUN         ; Yes, run user program.
    CMP #'X' + $80  ; "X"? (high ascii $D8)
    BEQ XMODEM      ; Receive file using XMODEM
    CMP #'B' + $80  ; "B"? (high ascii)
    BEQ BASIC       ; start BASIC
    STX L           ; $00->L.
    STX H           ; and H.
    STY YSAV        ; Save Y for comparison.
NEXTHEX:
    LDA IN,Y        ; Get character for hex test.
    EOR #$B0        ; Map digits to $0-9.
    CMP #$0A        ; Digit?
    BCC DIG         ; Yes.
    ADC #$88        ; Map letter "A"-"F" to $FA-FF.
    CMP #$FA        ; Hex letter?
    BCC NOTHEX      ; No, character not hex.
DIG:
    ASL
    ASL             ; Hex digit to MSD of A.
    ASL
    ASL
    LDX #$04        ; Shift count.
HEXSHIFT:    
    ASL             ; Hex digit left MSB to carry.
    ROL L           ; Rotate into LSD.
    ROL H           ; Rotate into MSD's.
    DEX             ; Done 4 shifts?
    BNE HEXSHIFT    ; No, loop.
    INY             ; Advance text index.
    BNE NEXTHEX     ; Always taken. Check next character for hex.
NOTHEX:      
    CPY YSAV        ; Check if L, H empty (no hex digits).
    BNE NOESCAPE    ; * Branch out of range, had to improvise...
    JMP ESCAPE      ; Yes, generate ESC sequence.

BASIC:
    JSR LAB_COLD
    RTS

XMODEM:
    PHY
    JSR XMODEM_FILE_RECV
    PLY
    JMP SOFTRESET

RUN:
    JSR ACTRUN      ; * JSR to the Address we want to run.
    JMP SOFTRESET   ; * When returned for the program, reset EWOZ.
ACTRUN:
    JMP (XAML)      ; Run at current XAM index.

NOESCAPE:
    BIT MODE        ; Test MODE byte.
    BVC NOTSTOR     ; B6=0 for STOR, 1 for XAM and BLOCK XAM
    LDA L           ; LSD's of hex data.
    STA (STL, X)    ; Store at current "store index".
    INC STL         ; Increment store index.
    BNE NEXTITEM    ; Get next item. (no carry).
    INC STH         ; Add carry to 'store index' high order.
TONEXTITEM:
    JMP NEXTITEM    ; Get next command item.
NOTSTOR:
    BMI XAMNEXT     ; B7=0 for XAM, 1 for BLOCK XAM.
    LDX #$02        ; Byte count.
SETADR:
    LDA L-1,X       ; Copy hex data to
    STA STL-1,X     ; "store index".
    STA XAML-1,X    ; And to "XAM index'.
    DEX             ; Next of 2 bytes.
    BNE SETADR      ; Loop unless X = 0.
NXTPRNT:
    BNE PRDATA      ; NE means no address to print.
    LDA #CR
    JSR ECHO        ; * New line.
    LDA #NEWL
    JSR ECHO
    LDA #$20
    JSR ECHO    
    LDA #$20
    JSR ECHO    
    LDA XAMH        ; 'Examine index' high-order byte.
    JSR PRBYTE      ; Output it in hex format.
    LDA XAML        ; Low-order "examine index" byte.
    JSR PRBYTE      ; Output it in hex format.
    LDA #$BA        ; ":".
    JSR ECHO        ; Output it.
PRDATA:
    LDA #$A0        ; Blank.
    JSR ECHO        ; Output it.
    LDA (XAML,X)    ; Get data byte at 'examine index".
    JSR PRBYTE      ; Output it in hex format.
XAMNEXT:
    STX MODE        ; 0-> MODE (XAM mode).
    LDA XAML
    CMP L           ; Compare 'examine index" to hex data.
    LDA XAMH
    SBC H
    BCS TONEXTITEM  ; Not less, so no more data to output.
    INC XAML
    BNE MOD8CHK     ; Increment 'examine index".
    INC XAMH
MOD8CHK:
    LDA XAML        ; Check low-order 'exainine index' byte
    AND #$0F        ; 16 values per row
    BPL NXTPRNT     ; Always taken.
PRBYTE:
    PHA             ; Save A for LSD.
    LSR
    LSR
    LSR             ; MSD to LSD position.
    LSR
    JSR PRHEX       ; Output hex digit.
    PLA             ; Restore A.
PRHEX:
    AND #$0F        ; Mask LSD for hex print.
    ORA #$B0        ; Add "0".
    CMP #$BA        ; Digit?
    BCC ECHO        ; Yes, output it.
    ADC #$06        ; Add offset for letter.

ECHO:          
    PHA
    PHY
    PHX
    AND #$7F
    JSR WRITE_CHAR
    PLX
    PLY    
    PLA
    RTS

BANNER:
    .BYTE CR, NEWL, CR, NEWL
    .BYTE "  /    __|    \ _  ) _ |    __|   \  |", CR, NEWL
    .BYTE "  _ \ __ \  (  |  /    |    _|   |\/ |", CR, NEWL
    .BYTE "\___/ ___/ \__/ ___|  _|   ___| _|  _|", CR, NEWL
    .BYTE CR, NEWL
    .BYTE "CPU: 65C02 @ 2 Mhz", CR, NEWL
    .BYTE "RAM: 32KB - LOC.: 0000-7FFF", CR, NEWL
    .BYTE "ROM: 16KB - LOC.: C000-FFFF", CR, NEWL, 0
COMMANDS:
    .BYTE CR, NEWL
    .BYTE "Welcome to the 65021EM! The following commands are available:", CR, NEWL
    .BYTE "B - Start BASIC", CR, NEWL
    .BYTE "X - Receive file over XMODEM", CR, NEWL
    .BYTE "R - Run program at last selected address", CR, NEWL, 0


