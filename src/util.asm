; Will read an address in any byte format; C000, C00, C0, C, 000C
; result will be put in T6. Amount of digits read will be in Y
Read2Bytes:     PHX
                STZ T6
                STZ T6 + 1
@NextHex:       LDA (P1), Y     ; Get character for hex test.
                EOR #$30        ; Map digits to $0-9.
                CMP #$0A        ; Digit?
                BCC @IsDigit    ; Yes.
                ADC #$88        ; Map letter "A"-"F" to $FA-FF.
                CMP #$FA        ; Hex letter?
                BCC @NotHex     ; No, character not hex.
@IsDigit:       ASL
                ASL             ; Hex digit to MSD of A.
                ASL
                ASL
                LDX #$04        ; Shift count.
@HexShift:      ASL             ; Hex digit left MSB to carry.
                ROL T6          ; Rotate into LSD.
                ROL T6 + 1      ; Rotate into MSD's.
                DEX             ; Done 4 shifts?
                BNE @HexShift   ; No, loop.
                INY             ; Advance text index.
                BNE @NextHex    ; Always taken. Check next character for hex.
@NotHex:        PLX
                RTS

; Return if a character is a valid hex digit (0-9, A-F, or a-f).
; Pass character in A.
; Returns 1 in A if valid, 0 if not valid.
; Registers affected: A
IsHexDigit:
                JSR ToUpper
                CMP #'0'
                BMI @Invalid
                CMP #'9'+1
                BMI @Okay
                CMP #'A'
                BMI @Invalid
                CMP #'F'+1
                BMI @Okay
@Invalid:       LDA #0
                RTS
@Okay:          LDA #1
                RTS

ToUpper:
                CMP #'a'                ; Is it 'a' or higher?
                BMI @NotLower
                CMP #'z'+1              ; Is it 'z' or lower?
                BPL @NotLower
                AND #%11011111          ; Convert to upper case by clearing bit 5
@NotLower:      RTS

; converts 2 ascii hexadecimal digits to a byte
; e.g. A='1' Y='A' Returns A = $1A
Hex2Bin:		
                PHA
                TYA
                JSR A2Hex
                STA T1
                PLA
                JSR A2Hex
                ASL
                ASL
                ASL
                ASL
                ORA T1
                RTS

A2Hex:          SEC
                SBC #'0'
                CMP #10
                BCC @Return
                SBC #7
@Return:        RTS

; Converts one byte of binary data to two ascii characters.
; Entry: 
; A = binary data
; 
; Exit: 
; A = first ascii digit, high order value
; Y = second ascii digit, low order value
Bin2Hex:		
                TAX         		; save original value
                AND #$F0    		; get high nibble
                LSR
                LSR
                LSR
                LSR         		; move to lower nibble
                JSR HexDigit2Ascii	; convert to ascii
                PHA
                TXA					; convert lower nibble
                AND #$0F
                JSR HexDigit2Ascii	; convert to ascii
                TAY         		; low nibble to register y
                PLA					; high nibble to register a
                RTS

; converts a hexadecimal digit to ascii
; entry:
; A = binary data in lower nibble
; exit:
; A = ASCII char
HexDigit2Ascii:	
                CMP #10
                BCC @isDigit
                CLC
                ADC #7
@isDigit:       ADC #'0'
                RTS

; Print 16-bit address in hex
; Pass byte in X (low) and Y (high)
; Registers changed: None
PrintAddress:
                PHA
                PHX
                TYA
                JSR PrintByte
                PLX
                TXA
                JSR PrintByte
                PLA
                RTS

; prints a byte as 2 ascii hex characters
; Registers changed: none
PrintByte:		
                PHA
                PHX
                PHY
                JSR Bin2Hex
                JSR WriteChar
                TYA 
                JSR WriteChar
                PLY
                PLX
                PLA
                RTS

PrintNewline:   PHA
                LDA #$0D
                JSR WriteChar
                LDA #$0A
                JSR WriteChar
                PLA
                RTS

PrintIndent:    LDA #SP
                JSR WriteChar    
                LDA #SP
                JSR WriteChar
                RTS

; Zero flag is set if equal
; Destroys A and Y register 
StrComp:        LDY #0
@Loop:          LDA (StrPtr1), Y
                BEQ @2                  ; got 0
                CMP (StrPtr2), Y
                BNE @Done               ; current char is not equal
                INY
                BNE @Loop
                INC StrPtr1 + 1
                INC StrPtr2 + 1
                BCS @Loop               ; always
@2:             CMP (StrPtr2), Y        ; compare last char
@Done:          RTS
