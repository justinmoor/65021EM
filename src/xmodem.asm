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
;

; zero page variables (adjust these to suit your needs)
CRC		= $38		; CRC lo byte  (two byte variable)
CRCH	= $39		; CRC hi byte  

TARGET	= $24		; pointer to store the file, is equal to last examined address in the monitor (XAML)

BLCK_NUM = $3c		; block number 
RETRY	 = $3d		; retry counter 
RETRY2	 = $3e		; 2nd counter
BLCK_FLAG	= $3f	; block flag 

; non-zero page variables and buffers
RECV_BUFF	= $500	; temp 132 byte receive buffer (place anywhere, page aligned)

;  tables and constants
;
; The CRCLO & CRCHI labels are used to point to a lookup table to calculate
; the CRC for the 128 byte data blocks.  Tables will be generated runtime
CRCLO	= $7D00      	; Two 256-byte tables for quick lookup
CRCHI	= $7E00      	; (should be page-aligned for speed)

; XMODEM Control Character Constants
SOH		= $01		; start block
EOT		= $04		; end of text marker
ACK		= $06		; good block acknowledged
NAK		= $15		; bad block acknowledged
CAN		= $18		; cancel (not standard, not supported)
LF		= $0a		; line feed
REC_CMD	= $43
DELAY3S = $1E		; ~ 3 secs

XMODEM_FILE_RECV:
    JSR GENERATE_CRC_TABLE		
	JSR PRINTIMM		
	ASCLN "READY TO RECEIVE OVER XMODEM. PLEASE SELECT A FILE TO TRANSFER OR PRESS <ESC> TO CANCEL."
	LDA #$01
	STA BLCK_NUM	; set block # to 1
	STA BLCK_FLAG	; set flag to get address from block 1
START_CRC:
	LDA #REC_CMD	; "C" start with CRC mode
	JSR PUT_CHR		; send it
	LDA #DELAY3S	
	STA RETRY2		; set loop counter for ~3 sec delay
	LDA #$00
	STA CRC
	STA CRCH		; init CRC value	
	JSR GET_BYTE	; wait for input
	BCS GOT_BYTE	; byte received, process it
	BCC START_CRC	; resend "C"

START_BLCK:
	LDA #DELAY3S		 
	STA RETRY2		; set loop counter for ~3 sec delay
	LDA #$00		
	STA CRC		
	STA CRCH		; init CRC value	
	JSR GET_BYTE	; get first byte of block
	BCC START_BLCK	; timed out, keep waiting...
GOT_BYTE:
	CMP #ESC		; quitting?
	BNE GOT_BYTE1	; no
;	LDA #$FE		; Error code in "A" if desired
	RTS 			; YES - do BRK or change to RTS if desired
GOT_BYTE1:
	CMP #SOH		; start of block?
	BEQ BEGIN_BLCK	; yes
	CMP #EOT		
	BNE INCRRCT_CRC	; Not SOH or EOT, so flush buffer & send NAK	
	JMP XM_DONE		; EOT - all done!
BEGIN_BLCK:	
	LDX #$00
GET_BLCK:
	LDA #DELAY3S	; 3 sec window to receive characters
	STA RETRY2		
GET_BLCK1:
	JSR GET_BYTE	; get next character
	BCC INCRRCT_CRC	; chr rcv error, flush and send NAK
GET_BLCK2:
	STA RECV_BUFF,X	; good char, save it in the rcv buffer
	INX				; inc buffer pointer	
	CPX #$84		; <01> <FE> <128 bytes> <CRCH> <CRCL>
	BNE GET_BLCK	; get 132 characters
	LDX #$00		;
	LDA RECV_BUFF,X	; get block # from buffer
	CMP BLCK_NUM	; compare to expected block #	
	BEQ GOOD_BLCK1	; matched!
	JSR PRINTIMM		; Unexpected block number - abort	
	ASCLN "UPLOAD ERROR!"
	JSR FLUSH		; mismatched - flush buffer and then do BRK
;	LDA #$FD		; put error code in "A" if desired
	RTS 			; unexpected block # - fatal error - BRK or RTS
GOOD_BLCK1:	
	EOR #$ff		; 1's comp of block #
	INX 		
	CMP RECV_BUFF,x	; compare with expected 1's comp of block #
	BEQ GOOD_BLCK2 	; matched!
	JSR PRINTIMM		; Unexpected block number - abort	
	ASCLN "UPLOAD ERROR!"
	JSR FLUSH		; mismatched - flush buffer and then do BRK
;	LDA	#$FC		; put error code in "A" if desired
	RTS				; bad 1's comp of block#	
GOOD_BLCK2:	
	LDY	#$02		 
CALC_CRC:		
	LDA RECV_BUFF,y	; calculate the CRC for the 128 bytes of data	
	JSR UPD_CRC		; could inline sub here for speed
	INY 		
	CPY #$82		; 128 bytes
	BNE CALC_CRC	;
	LDA RECV_BUFF,y	; get hi CRC from buffer
	CMP CRCH		; compare to calculated hi CRC
	BNE INCRRCT_CRC	; bad CRC, send NAK
	INY 		
	LDA RECV_BUFF,y	; get lo CRC from buffer
	CMP CRC			; compare to calculated lo CRC
	BEQ CORRECT_CRC	; good CRC
INCRRCT_CRC:
	JSR FLUSH		; flush the input port
	LDA #NAK		
	JSR PUT_CHR		; send NAK to resend block
	JMP START_BLCK	; start over, get the block again			
CORRECT_CRC:
	LDX #$02		
	LDA BLCK_NUM	; get the block number
	CMP #$01		; 1st block?
	BNE COPY_BLCK	; no, copy all 128 bytes
	LDA BLCK_FLAG	; is it really block 1, not block 257, 513 etc.
	BEQ COPY_BLCK	; no, copy all 128 bytes
	DEC BLCK_FLAG	; set the flag so we won't get another address		
COPY_BLCK:		
	LDY #$00		; set offset to zero
COPY_BLCK3:
	LDA RECV_BUFF,x	; get data byte from buffer
	STA (TARGET),y	; save to target
	INC TARGET		; point to next address
	BNE COPY_BLCK4	; did it step over page boundary?
	INC TARGET+1	; adjust high address for page crossing
COPY_BLCK4:
	INX 			; point to next data byte
	CPX #$82		; is it the last byte
	BNE COPY_BLCK3	; no, get the next one
INC_BLCK:
	INC BLCK_NUM	; done.  Inc the block #
	LDA #ACK		; send ACK
	JSR PUT_CHR		
	JMP START_BLCK	; get next block
XM_DONE:			; xmodem done
	LDA #ACK		; last block, send ACK and exit.
	JSR PUT_CHR		
	JSR FLUSH		; get leftover characters, if any
	JSR PRINTIMM
	ASCLN "UPLOAD SUCCESFULL!"
	RTS			

GET_BYTE:
	LDA #$00		; wait for chr input and cycle timing loop
	STA RETRY		; set low value of timing loop
START_CRC_LP:	
	JSR GET_CHAR	; get chr from serial port, don't wait 
	BCS GET_BYTE1	; got one, so exit
	DEC RETRY		; no character received, so dec counter
	BNE START_CRC_LP	
	DEC RETRY2		; dec hi byte of counter
	BNE START_CRC_LP	; look for character again
	CLC				; if loop times out, CLC, else SEC and return
GET_BYTE1:
	RTS 			; with character in "A"

FLUSH:
	LDA #$09		; flush receive buffer
	STA RETRY2		; flush until empty for ~1 sec.
FLUSH1:		
	JSR GET_BYTE	; read the port
	BCS FLUSH		; if chr recvd, wait for another
	RTS				; else done

;======================================================================
;  I/O Device Specific Routines
;
;  Two routines are used to communicate with the I/O device.
;
; "GET_CHAR" routine will scan the input port for a character.  It will
; return without waiting with the Carry flag CLEAR if no character is
; present or return with the Carry flag SET and the character in the "A"
; register if one was present.
;
; "PUT_CHR" routine will write one byte to the output port.  Its alright
; if this routine waits for the port to be ready.  its assumed that the 
; character was send upon return from this routine.
GET_CHAR:
	JSR READ_CHAR
	RTS

PUT_CHR:	   	
	PHA             ; save registers
	JSR WRITE_CHAR
	PLA
	RTS             ; done

; CRC subroutines 
UPD_CRC:
	EOR CRC+1 		; Quick CRC computation with lookup tables
	TAX		 		; updates the two bytes at CRC & CRC+1
	LDA CRC			; with the byte send in the "A" register
	EOR CRCHI,X
	STA CRC+1
	LDA CRCLO,X
	STA CRC
	RTS

; subroutine to generate CRC lookup tables, needs to be ran before XMODEM transfer
GENERATE_CRC_TABLE:
	LDX #$00
	LDA #$00
ZERO_LOOP:
	STA CRCLO,x
	STA CRCHI,x
	INX
	BNE ZERO_LOOP
	LDX #$00
FETCH:	
	TXA
	EOR CRCHI,x
	STA CRCHI,x
	LDY #$08
FETCH1:	
	ASL CRCLO,x
	ROL CRCHI,x
	BCC FETCH2
	LDA CRCHI,x
	EOR #$10
	STA CRCHI,x
	LDA CRCLO,x
	EOR #$21
	STA CRCLO,x
FETCH2:
	DEY
	BNE FETCH1
	INX
	BNE FETCH
	RTS