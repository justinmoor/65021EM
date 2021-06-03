; XMODEM/CRC Receiver for the 65C02
;
; Implementation from: http://www.6502.org/source/io/xmodem/xmodem.htm
; Changes:
;	- Removed o64 file format requirements (file will be stored at last examined memory address)
;	- CRC lookup tables are generated runtime
;	- Delay fix
; 
; A simple file transfer program to allow upload from a console device
; to the SBC utilizing the x-modem/CRC transfer protocol.  Requires just
; under 1k of either RAM or ROM, 132 bytes of RAM for the receive buffer,
; and 8 bytes of zero page RAM for variable storage.

RunXModem:
				JSR GenerateCRCTable
				JSR PrintNewline
				JSR PrintImmediate
				ASC "WHERE TO STORE? "
				JSR GetLine
				CMP #CR
				BEQ @Start
				RTS				; Did not get <enter>, so an escape, quit XModem and return
@Start
				JSR StoreTarget
				JSR PrintNewline
				JSR PrintImmediate
				ASCLN "READY TO RECEIVE OVER XMODEM. PLEASE SELECT A FILE TO TRANSFER OR PRESS <ESC> TO CANCEL."
				LDA #$01
				STA BLCK_NUM	; set block # to 1
				STA BLCK_FLAG	; set flag to get address from block 1
StartCRC:
				LDA #REC_CMD	; "C" start with CRC mode
				JSR PutChr		; send it
				LDA #DELAY3S	
				STA RETRY2		; set loop counter for ~3 sec delay
				LDA #$00
				STA CRC
				STA CRCH		; init CRC value	
				JSR GetByte		; wait for input
				BCS GotByte		; byte received, process it
				BCC StartCRC	; resend "C"

StartBlock:		LDA #DELAY3S		 
				STA RETRY2		; set loop counter for ~3 sec delay
				LDA #$00		
				STA CRC		
				STA CRCH		; init CRC value	
				JSR GetByte		; get first byte of block
				BCC StartBlock	; timed out, keep waiting...
GotByte:
				CMP #ESC		; quitting?
				BNE GotByte1	; no
				LDA #$FE		; Error code in "A" if desired
				RTS 			; YES - do BRK or change to RTS if desired
GotByte1:
				CMP #SOH		; start of block?
				BEQ BeginBlock	; yes
				CMP #EOT		
				BNE IncorrectCRC	; Not SOH or EOT, so flush buffer & send NAK	
				JMP XModemDone		; EOT - all done!

BeginBlock:		
				LDX #$00
GetBlock:		LDA #DELAY3S	; 3 sec window to receive characters
				STA RETRY2		
GetBlock1:		JSR GetByte		; get next character
				BCC IncorrectCRC	; chr rcv error, flush and send NAK
GetBlock2:		STA RECV_BUF,X	; good char, save it in the rcv buffer
				INX				; inc buffer pointer	
				CPX #$84		; <01> <FE> <128 bytes> <CRCH> <CRCL>
				BNE GetBlock	; get 132 characters
				LDX #$00		;
				LDA RECV_BUF,X	; get block # from buffer
				CMP BLCK_NUM	; compare to expected block #	
				BEQ GoodBlock	; matched!
				JSR PrintImmediate		; Unexpected block number - abort	
				ASCLN "UPLOAD ERROR!"
				JSR Flush		; mismatched - flush buffer and then do BRK
				LDA #$FD		; put error code in "A" if desired
				RTS 			; unexpected block # - fatal error - BRK or RTS
GoodBlock:	
				EOR #$FF		; 1's comp of block #
				INX 		
				CMP RECV_BUF,X	; compare with expected 1's comp of block #
				BEQ GoodBlock2 	; matched!
				JSR PrintImmediate		; Unexpected block number - abort	
				ASCLN "UPLOAD ERROR!"
				JSR Flush		; mismatched - flush buffer and then do BRK
				LDA #$FC		; put error code in "A" if desired
				RTS
								; bad 1's comp of block#	
GoodBlock2:		LDY	#$02		 
CalculateCRC:	LDA RECV_BUF,y	; calculate the CRC for the 128 bytes of data	
				JSR UpdateCRC		; could inline sub here for speed
				INY 		
				CPY #$82		; 128 bytes
				BNE CalculateCRC	
				LDA RECV_BUF,y	; get hi CRC from buffer
				CMP CRCH		; compare to calculated hi CRC
				BNE IncorrectCRC	; bad CRC, send NAK
				INY 		
				LDA RECV_BUF,y	; get lo CRC from buffer
				CMP CRC			; compare to calculated lo CRC
				BEQ CorrectCRC	; good CRC

IncorrectCRC:	JSR Flush		; flush the input port
				LDA #NAK		
				JSR PutChr		; send NAK to resend block
				JMP StartBlock	; start over, get the block again			

CorrectCRC:		LDX #$02		
				LDA BLCK_NUM	; get the block number
				CMP #$01		; 1st block?
				BNE CopyBlock	; no, copy all 128 bytes
				LDA BLCK_FLAG	; is it really block 1, not block 257, 513 etc.
				BEQ CopyBlock	; no, copy all 128 bytes
				DEC BLCK_FLAG	; set the flag so we won't get another address		

CopyBlock:		LDY #$00		; set offset to zero
CopyBlock3:		LDA RECV_BUF,x	; get data byte from buffer
				STA (TARGET),y	; save to target
				INC TARGET		; point to next address
				BNE CopyBlock4	; did it step over page boundary?
				INC TARGET+1	; adjust high address for page crossing
CopyBlock4:		INX 			; point to next data byte
				CPX #$82		; is it the last byte
				BNE CopyBlock3	; no, get the next one
IncBlock:		INC BLCK_NUM	; done.  Inc the block #
				LDA #ACK		; send ACK
				JSR PutChr		
				JMP StartBlock	; get next block

XModemDone:	
				LDA #ACK		; last block, send ACK and exit.
				JSR PutChr		
				JSR Flush		; get leftover characters, if any
				JSR PrintImmediate
				ASCLN "UPLOAD SUCCESFULL!"
				RTS

GetByte:		LDA #$00		; wait for chr input and cycle timing loop
				STA RETRY		; set low value of timing loop
StartCRC_LP:	JSR ReadChar	; get chr from serial port, don't wait 
				BCS @Done		; got one, so exit
				DEC RETRY		; no character received, so dec counter
				BNE StartCRC_LP	
				DEC RETRY2		; dec hi byte of counter
				BNE StartCRC_LP	; look for character again
				CLC				; if loop times out, CLC, else SEC and return
@Done:			RTS 			; with character in "A"

Flush:
				LDA #$09		; flush receive buffer
				STA RETRY2		; flush until empty for ~1 sec.
				JSR GetByte		; read the port
				BCS Flush		; if chr recvd, wait for another
				RTS				; else done

;======================================================================
;  I/O Device Specific Routines
;
;  Two routines are used to communicate with the I/O device.
;
; "ReadChar" routine will scan the input port for a character.  It will
; return without waiting with the Carry flag CLEAR if no character is
; present or return with the Carry flag SET and the character in the "A"
; register if one was present.
;
; "PutChr" routine will write one byte to the output port.  Its alright
; if this routine waits for the port to be ready.  its assumed that the 
; character was send upon return from this routine.
PutChr:	   	
				PHA             ; save registers
				JSR WriteChar
				PLA
				RTS             ; done

; CRC subroutines
UpdateCRC:
				EOR CRC+1 		; Quick CRC computation with lookup tables
				TAX		 		; updates the two bytes at CRC & CRC+1
				LDA CRC			; with the byte send in the "A" register
				EOR CRCHI,X
				STA CRC+1
				LDA CRCLO,X
				STA CRC
				RTS

; Subroutine to generate CRC lookup tables, needs to be ran before XMODEM transfer
GenerateCRCTable:
				LDX #$00
				LDA #$00
ZeroLoop:
				STA CRCLO,x
				STA CRCHI,x
				INX
				BNE ZeroLoop
				LDX #$00
Fetch:	
				TXA
				EOR CRCHI,x
				STA CRCHI,x
				LDY #$08
Fetch1:			ASL CRCLO,x
				ROL CRCHI,x
				BCC Fetch2
				LDA CRCHI,x
				EOR #$10
				STA CRCHI,x
				LDA CRCLO,x
				EOR #$21
				STA CRCLO,x
Fetch2:			DEY
				BNE Fetch1
				INX
				BNE Fetch
				RTS

StoreTarget:
				LDX #0
				LDA InputBuffer, X
				INX
				LDY InputBuffer, X
				JSR Hex2Bin
				STA TARGET + 1
				INX
				LDA InputBuffer, X
				INX
				LDY InputBuffer, X
				JSR Hex2Bin
				STA TARGET
				RTS
