
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

InitBios:    
                LDA #%00000011      ; configure the MOSI and CLK pin as outputs, others as inputs
                STA VIADataDirB
                LDA #$FF
                STA VIADataDirA     ; configure all pins as outputs, 8 slave selects available
                STA VIADataA        ; set all to high
                JSR WriteM3100Config
                RTS

WriteM3100Config:
                PHY
                PHA
                LDY #%11000000      ; MAX3100 Config: 11000000 00001001
                LDA #%00001001      ; 19200 baud
                JSR WriteM3100
                PLY
                PLA
                RTS         
    
ReadM3100Config:
                PHY
                LDY #%01000000
                LDA #%00000000
                JSR WriteM3100
                PLY
                LDA M3100ReadBuf
                RTS    

; writes a 16 bit sequence to the MAX3100
; assumes the command is stored in the Y register and the
; actual data in the A register
WriteM3100:	
                PHA
                TYA
                STZ VIADataA           ; select MAX3100
                JSR SPIWriteByte
                STA M3100ReadBuf
                PLA
                JSR SPIWriteByte
                STA M3100ReadBuf + 1
                LDA #$FF
                STA VIADataA           ; deselect MAX3100
                RTS            

SPIWriteByte:
                STA SPIWriteBuf
                LDY #$8                 ; write 8 bits
WriteBit:       LDA #%0                 ; zero bit the output line
                ROL SPIWriteBuf         ; rotate the buffer so the bit to be written is represented by the carry flag
                BCC @Write              ; 0 in carry flag? continue to writing the zero bit
                ORA #%00000010          ; 1 in carry flag, set MOSI to high
@Write:         STA VIADataB            ; write bit
                INC VIADataB            ; set clock high
                LDA VIADataB            ; read bit
                ROL                     ; just read bit is represented in PB7, rotate it into carry
                ROL SPIReadBuf          ; rotate bit from carry into SPIReadBuf
                DEC VIADataB            ; set clock low
                DEY
                BNE WriteBit
                LDA SPIReadBuf
                RTS

; reads a character from serial. If new char is read, carry flag is set and char is in A
; registers affected: A, Y
ReadChar:	
                PHY
                LDY #0
                LDA #0
                JSR WriteM3100
                PLY
                CLC
                LDA M3100ReadBuf
                ROL
                LDA M3100ReadBuf + 1
                RTS

; writes the byte that is in A to serial. First checks if the buffer is not full
; registers affected: none
WriteChar:
                PHY
                PHA
@Wait:          JSR ReadM3100Config
                AND #%01000000
                BEQ @Wait
                PLA
                PHA
                LDY #%10000000
                JSR WriteM3100
                PLA
                PLY
                RTS

; Uses stack manipulation to print immediate string embedded in the code.
; Usage:
;	JSR PrintImmediate
;	.byte "Hello world", 0
;
PrintImmediate:
                PLA				; save original return address in T3
                STA T4
                PLA
                STA T4 + 1
                BRA @P1
@P0:            JSR WriteChar
@P1:            INC T4          ; for each character printed, increment the new return address
                BNE @P3
                INC T4 + 1
@P3:            LDA (T4)
                BNE @P0
                LDA T4 + 1		; restore stack with the new return adress
                PHA				
                LDA T4
                PHA
                RTS

Print:			
                PHY
                LDY #$00
@Loop:          LDA (P1), Y
                BEQ @Done
                JSR WriteChar
                INY
                BNE @Loop ; up to 255 chars
@Done:          PLY 
                RTS
