;-------------------------------------------------------------------------
;   65021EM MACHINE LANGUAGE MONITOR
;
;   Basic machine language monitor based on Steve Wozniak's Wozmon
;   for the Apple 1.
;-------------------------------------------------------------------------

RunMonitor:
                JSR PrintNewline
                JSR PrintNewline
                JSR PrintImmediate
                ASCLN "MONITOR ACTIVATED"
SoftReset:      LDA #ESC
NotCR:          CMP #BSH         
                BEQ Backspace   ; Yes.
                CMP #ESC        ; ESC?
                BEQ Escape      ; Yes.
                INY             ; Advance text index.
                BPL NextChar    ; Auto ESC if >127.
Escape:
GETLINE:
                LDA #CR
                JSR Echo        ; New line.
                LDA #NEWL
                JSR Echo
                JSR PrintMonPrompt
                LDY #$01        ; Initiallize text index.
Backspace:   
                DEY             ; Backup text index.
                BMI GETLINE     ; Beyond start of line, reinitialize.
                LDA #$A0        ; *Space, overwrite the backspaced char.
                JSR Echo
                LDA #BSH        ; *Backspace again to get to correct pos.
                JSR Echo
NextChar:    
                JSR ReadChar
                BCC NextChar
                CMP #$60        ; *Is it Lower case
                BMI Convert     ; *Nope, just convert it
                AND #$5F        ; *If lower case, convert to Upper case
Convert:     
                ORA #$80        ; The Apple 1 assumes high ascii, several coding tricks by Woz use this fact for memory optimalization
                STA InputBuffer,Y ; Add to text buffer.
                JSR Echo        ; Display character.
                CMP #ENT        ; CR?
                BNE NotCR       ; No.
                LDY #$FF        ; Reset text index.
                LDA #$00        ; For XAM mode.
                TAX             ; 0->X.
SetSTOR:        ASL              ;Leaves $7B if setting STOR mode.
SetMode:        STA Mode        ; $00 = XAM, $7B = STOR, $AE = BLOK XAM.
BLSKIP:         INY             ; Advance text index.
NextItem:    
                LDA InputBuffer,Y ; Get character.
                CMP #ENT        ; CR?
                BEQ GETLINE     ; Yes, done this line.
                CMP #'.' + $80  ; "."?
                BCC BLSKIP      ; Skip delimiter.
                BEQ SetMode     ; Set BLOCK XAM mode.
                CMP #':' + $80  ; ":"? 
                BEQ SetSTOR     ; Yes, set STOR mode.
                CMP #'P' + $80  ; Program in assembler
                BEQ StartAssembler      ; Yes, start assembler
                CMP #'L' + $80          ; List disassembly
                BEQ StartDisassembler   ; Yes, start disassembler
                CMP #'R' + $80          ; "R"?
                BEQ Run                 ; Yes, run user program.
                CMP #'M' + $80          ; exit monitor
                BEQ ExitMonitor
                STX L           ; $00->L.
                STX H           ; and H.
                STY YSAV        ; Save Y for comparison.
NextHex:
                LDA InputBuffer,Y        ; Get character for hex test.
                EOR #$B0        ; Map digits to $0-9.
                CMP #$0A        ; Digit?
                BCC Dig         ; Yes.
                ADC #$88        ; Map letter "A"-"F" to $FA-FF.
                CMP #$FA        ; Hex letter?
                BCC NotHex      ; No, character not hex.
Dig:
                ASL
                ASL             ; Hex digit to MSD of A.
                ASL
                ASL
                LDX #$04        ; Shift count.
HexShift:    
                ASL             ; Hex digit left MSB to carry.
                ROL L           ; Rotate into LSD.
                ROL H           ; Rotate into MSD's.
                DEX             ; Done 4 shifts?
                BNE HexShift    ; No, loop.
                INY             ; Advance text index.
                BNE NextHex     ; Always taken. Check next character for hex.
NotHex:      
                CPY YSAV        ; Check if L, H empty (no hex digits).
                BNE NoEscape    ; * Branch out of range, had to improvise...
                JMP Escape      ; Yes, generate ESC sequence.

NextItem1:      JMP NextItem

StartAssembler:         
                JSR RunAssembler
                JMP SoftReset

StartDisassembler:      
                JSR START_DISASM
                JMP SoftReset

Run:            
                JSR @R1      ; * JSR to the Address we want to run.
                JMP SoftReset   ; * When returned for the program, reset EWOZ.
@R1:            JMP (XAML)      ; Run at current XAM index.

ExitMonitor:
                JSR PrintNewline
                JSR PrintNewline
                JSR PrintImmediate
                ASCLN "EXIT MONITOR"
                JMP SoftResetOS

NoEscape:
                BIT Mode        ; Test Mode byte.
                BVC NotSTOR     ; B6=0 for STOR, 1 for XAM and BLOCK XAM
                LDA L           ; LSD's of hex data.
                STA (STL, X)    ; Store at current "store index".
                INC STL         ; Increment store index.
                BNE NextItem1   ; Get next item. (no carry).
                INC STH         ; Add carry to 'store index' high order.
ToNextItem:     JMP NextItem    ; Get next command item.
NotSTOR:        BMI XAMNext     ; B7=0 for XAM, 1 for BLOCK XAM.
                LDX #$02        ; Byte count.
SetAdr:         LDA L-1,X       ; Copy hex data to
                STA STL-1,X     ; "store index".
                STA XAML-1,X    ; And to "XAM index'.
                DEX             ; Next of 2 bytes.
                BNE SetAdr      ; Loop unless X = 0.
NextPrint:      BNE PrintData      ; NE means no address to print.
                LDA #CR
                JSR Echo        ; * New line.
                LDA #NEWL
                JSR Echo
                LDA #$20
                JSR Echo    
                LDA #$20
                JSR Echo    
                LDA XAMH        ; 'Examine index' high-order byte.
                JSR PrByte      ; Output it in hex format.
                LDA XAML        ; Low-order "examine index" byte.
                JSR PrByte      ; Output it in hex format.
                LDA #$BA        ; ":".
                JSR Echo        ; Output it.
PrintData:      LDA #$A0        ; Blank.
                JSR Echo        ; Output it.
                LDA (XAML,X)    ; Get data byte at 'examine index".
                JSR PrByte      ; Output it in hex format.
XAMNext:        STX Mode        ; 0-> Mode (XAM mode).
                LDA XAML
                CMP L           ; Compare 'examine index" to hex data.
                LDA XAMH
                SBC H
                BCS ToNextItem  ; Not less, so no more data to output.
                INC XAML
                BNE Mod8Check     ; Increment 'examine index".
                INC XAMH
Mod8Check:      LDA XAML        ; Check low-order 'exainine index' byte
                AND #$0F        ; 16 values per row
                BPL NextPrint     ; Always taken.
PrByte:
                PHA             ; Save A for LSD.
                LSR
                LSR
                LSR             ; MSD to LSD position.
                LSR
                JSR PrHex       ; Output hex digit.
                PLA             ; Restore A.
PrHex:
                AND #$0F        ; Mask LSD for hex print.
                ORA #$B0        ; Add "0".
                CMP #$BA        ; Digit?
                BCC Echo        ; Yes, output it.
                ADC #$06        ; Add offset for letter.

Echo:          
                PHA
                PHY
                PHX
                AND #$7F
                JSR WriteChar
                PLX
                PLY    
                PLA
                RTS

PrintMonPrompt:
                LDA #'*'        ; Promp character
                JSR Echo        ; Output it.
                LDA #$20
                JSR Echo    
                RTS