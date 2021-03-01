; XMODEM/CRC Receiver for the 65C02
;
; By Daryl Rictor & Ross Archer  Aug 2002
;
; 21st century code for 20th century CPUs (tm?)
; 
; A simple file transfer program to allow upload from a console device
; to the SBC utilizing the x-modem/CRC transfer protocol.  Requires just
; under 1k of either RAM or ROM, 132 bytes of RAM for the receive buffer,
; and 8 bytes of zero page RAM for variable storage.
;
;**************************************************************************
; This implementation of XMODEM/CRC does NOT conform strictly to the 
; XMODEM protocol standard in that it (1) does not accurately time character
; reception or (2) fall back to the Checksum mode.

; (1) For timing, it uses a crude timing loop to provide approximate
; delays.  These have been calibrated against a 1MHz CPU clock.  I have
; found that CPU clock speed of up to 5MHz also work but may not in
; every case.  Windows HyperTerminal worked quite well at both speeds!
;
; (2) Most modern terminal programs support XMODEM/CRC which can detect a
; wider range of transmission errors so the fallback to the simple checksum
; calculation was not implemented to save space.
;**************************************************************************
;
; Files uploaded via XMODEM-CRC must be
; in .o64 format -- the first two bytes are the load address in
; little-endian format:  
;  FIRST BLOCK
;     offset(0) = lo(load start address),
;     offset(1) = hi(load start address)
;     offset(2) = data byte (0)
;     offset(n) = data byte (n-2)
;
; Subsequent blocks
;     offset(n) = data byte (n)
;
; The TASS assembler and most Commodore 64-based tools generate this
; data format automatically and you can transfer their .obj/.o64 output
; file directly.  
;   
; The only time you need to do anything special is if you have 
; a raw memory image file (say you want to load a data
; table into memory). For XMODEM you'll have to 
; "insert" the start address bytes to the front of the file.
; Otherwise, XMODEM would have no idea where to start putting
; the data.

; zero page variables (adjust these to suit your needs)
crc		= $38		; CRC lo byte  (two byte variable)
crch 	= $39		; CRC hi byte  

ptr		= $3a		; data pointer (two byte variable)
ptrh	= $3b		;   "    "

blkno	= $3c		; block number 
retry	= $3d		; retry counter 
retry2	= $3e		; 2nd counter
bflag	= $3f		; block flag 

; non-zero page variables and buffers
Rbuff	= $500	; temp 132 byte receive buffer (place anywhere, page aligned)
;
;  tables and constants
;
; The crclo & crchi labels are used to point to a lookup table to calculate
; the CRC for the 128 byte data blocks.  There are two implementations of these
; tables.  One is to use the tables included (defined towards the end of this
; file) and the other is to build them at run-time.  If building at run-time,
; then these two labels will need to be un-commented and declared in RAM.
;
crclo	= $7D00      	; Two 256-byte tables for quick lookup
crchi	= $7E00      	; (should be page-aligned for speed)

; XMODEM Control Character Constants
SOH		= $01		; start block
EOT		= $04		; end of text marker
ACK		= $06		; good block acknowledged
NAK		= $15		; bad block acknowledged
CAN		= $18		; cancel (not standard, not supported)
LF		= $0a		; line feed
REC_CMD	= $43
DELAY3S = $1E		; 3 secs

XMODEM_FILE_RECV:
    JSR GENERATE_CRC_TABLE		
	JSR	PrintMsg	; send prompt and info
	LDA	#$01
	STA blkno		; set block # to 1
	STA bflag		; set flag to get address from block 1
START_CRC:	
	LDA	#REC_CMD	; "C" start with CRC mode
	JSR	Put_Chr		; send it
	LDA	#DELAY3S	
	STA retry2		; set loop counter for ~3 sec delay
	LDA	#$00
	STA crc
	STA crch		; init CRC value	
	JSR	GetByte		; wait for input
	BCS	GotByte		; byte received, process it
	BCC	START_CRC	; resend "C"

StartBlk:
	LDA	#DELAY3S		 
	STA retry2		; set loop counter for ~3 sec delay
	LDA	#$00		
	STA crc		
	STA crch		; init CRC value	
	JSR	GetByte		; get first byte of block
	BCC	StartBlk	; timed out, keep waiting...
GotByte:
	CMP	#ESC		; quitting?
	BNE	GotByte1	; no
;	LDA	#$FE		; Error code in "A" if desired
	RTS ;brk		; YES - do BRK or change to RTS if desired
GotByte1:
	CMP	#SOH		; start of block?
	BEQ	BegBlk		; yes
	CMP	#EOT		
	BNE	BadCrc		; Not SOH or EOT, so flush buffer & send NAK	
	JMP	Done		; EOT - all done!
BegBlk:	
	LDX	#$00
GetBlk:
	LDA	#DELAY3S	; 3 sec window to receive characters
	STA retry2		
GetBlk1:
	JSR	GetByte		; get next character
	BCC	BadCrc		; chr rcv error, flush and send NAK
GetBlk2:
	STA Rbuff,x		; good char, save it in the rcv buffer
	INX				; inc buffer pointer	
	CPX	#$84		; <01> <FE> <128 bytes> <CRCH> <CRCL>
	BNE	GetBlk		; get 132 characters
	LDX	#$00		;
	LDA	Rbuff,x		; get block # from buffer
	CMP	blkno		; compare to expected block #	
	BEQ	GoodBlk1	; matched!
	JSR	Print_Err	; Unexpected block number - abort	
	JSR	Flush		; mismatched - flush buffer and then do BRK
;	LDA	#$FD		; put error code in "A" if desired
	RTS ;brk		; unexpected block # - fatal error - BRK or RTS
GoodBlk1:	
	EOR	#$ff		; 1's comp of block #
	INX			
	CMP	Rbuff,x		; compare with expected 1's comp of block #
	BEQ	GoodBlk2 	; matched!
	JSR	Print_Err	; Unexpected block number - abort	
	JSR Flush		; mismatched - flush buffer and then do BRK
;	LDA	#$FC		; put error code in "A" if desired
	RTS	;brk		; bad 1's comp of block#	
GoodBlk2:	
	LDY	#$02		; 
CalcCrc:		
	LDA	Rbuff,y		; calculate the CRC for the 128 bytes of data	
	JSR	UpdCrc		; could inline sub here for speed
	INY			
	CPY	#$82		; 128 bytes
	BNE	CalcCrc		;
	LDA	Rbuff,y		; get hi CRC from buffer
	CMP	crch		; compare to calculated hi CRC
	BNE	BadCrc		; bad crc, send NAK
	INY			
	LDA	Rbuff,y		; get lo CRC from buffer
	CMP	crc			; compare to calculated lo CRC
	BEQ	GoodCrc		; good CRC
BadCrc:
	JSR	Flush		; flush the input port
	LDA	#NAK		;
	JSR	Put_Chr		; send NAK to resend block
	JMP	StartBlk	; start over, get the block again			
GoodCrc:
	LDX	#$02		
	LDA	blkno		; get the block number
	CMP	#$01		; 1st block?
	BNE	CopyBlk		; no, copy all 128 bytes
	LDA	bflag		; is it really block 1, not block 257, 513 etc.
	BEQ	CopyBlk		; no, copy all 128 bytes
	LDA	Rbuff,x		; get target address from 1st 2 bytes of blk 1
	STA ptr			; save lo address
	INX			
	LDA	Rbuff,x		; get hi address
	STA ptr+1		; save it
	INX				; point to first byte of data
	DEC bflag		; set the flag so we won't get another address		
CopyBlk:		
	LDY	#$00		; set offset to zero
CopyBlk3:
	LDA	Rbuff,x		; get data byte from buffer
	STA (ptr),y		; save to target
	INC ptr			; point to next address
	BNE	CopyBlk4	; did it step over page boundary?
	INC ptr+1		; adjust high address for page crossing
CopyBlk4:
	INX				; point to next data byte
	CPX	#$82		; is it the last byte
	BNE	CopyBlk3	; no, get the next one
IncBlk:
	INC blkno		; done.  Inc the block #
	LDA	#ACK		; send ACK
	JSR	Put_Chr		
	JMP	StartBlk	; get next block
Done:		
	LDA	#ACK		; last block, send ACK and exit.
	JSR	Put_Chr		
	JSR	Flush		; get leftover characters, if any
	JSR	Print_Good	
	RTS				

;^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
; subroutines
;
GetByte:
	LDA	#$00		; wait for chr input and cycle timing loop
	STA retry		; set low value of timing loop
StartCrcLp:	
	JSR	Get_Chr		; get chr from serial port, don't wait 
	BCS	GetByte1	; got one, so exit
	DEC retry		; no character received, so dec counter
	BNE	StartCrcLp	;
	DEC retry2		; dec hi byte of counter
	BNE	StartCrcLp	; look for character again
	clc				; if loop times out, CLC, else SEC and return
GetByte1:
	RTS				; with character in "A"

Flush:
	LDA	#$0F		; flush receive buffer
	STA retry2		; flush until empty for ~1 sec.
Flush1:		
	JSR	GetByte		; read the port
	BCS	Flush		; if chr recvd, wait for another
	RTS				; else done
;
PrintMsg:	
	LDX	#$00		; PRINT starting message
PrtMsg1:		
	LDA Msg,x		
	BEQ	PrtMsg2			
	JSR	Put_Chr
	INX
	BNE	PrtMsg1
PrtMsg2:		
	RTS
Msg:		
	.BYTE	"begin xmodem/crc transfer. press <esc> to abort..."
	.BYTE  	CR, LF, 0

Print_Err:	
	LDX	#$00		; PRINT Error message
PrtErr1:		
	LDA ErrMsg,x
	BEQ	PrtErr2
	JSR	Put_Chr
	INX
	BNE	PrtErr1
PrtErr2:		
	RTS
ErrMsg:	
	.BYTE 	"upload error!"
	.BYTE  	CR, LF, 0
;
Print_Good:	
	LDX	#$00		; PRINT Good Transfer message
Prtgood1:	
	LDA GoodMsg,x
	BEQ	Prtgood2
	JSR	Put_Chr
	INX
	BNE	Prtgood1
Prtgood2:	
	RTS
GoodMsg:		
	.BYTE 	"upload successful!"
	.BYTE  	CR, LF, 0
;
;
;======================================================================
;  I/O Device Specific Routines
;
;  Two routines are used to communicate with the I/O device.
;
; "Get_Chr" routine will scan the input port for a character.  It will
; return without waiting with the Carry flag CLEAR if no character is
; present or return with the Carry flag SET and the character in the "A"
; register if one was present.
;
; "Put_Chr" routine will write one byte to the output port.  Its alright
; if this routine waits for the port to be ready.  its assumed that the 
; character was send upon return from this routine.
;

Get_Chr:
	JSR READ_CHAR
	RTS

Put_Chr:	   	
	PHA                 ; save registers
	JSR WRITE_CHAR
	PLA
	RTS                 ; done
;=========================================================================
;  CRC subroutines 
UpdCrc:
	EOR crc+1 		; Quick CRC computation with lookup tables
	TAX		 		; updates the two bytes at crc & crc+1
	LDA crc			; with the byte send in the "A" register
	EOR crchi,X
	STA crc+1
	LDA crclo,X
	STA crc
	RTS
;
; Alternate solution is to build the two lookup tables at run-time.  This might
; be desirable if the program is running from ram to reduce binary upload time.
; The following code generates the data for the lookup tables.  You would need to
; un-comment the variable declarations for crclo & crchi in the Tables and Constants
; section above and call this routine to build the tables before calling the
; "xmodem" routine.
GENERATE_CRC_TABLE:
	LDX	#$00
	LDA	#$00
zeroloop:
	STA crclo,x
	STA crchi,x
	INX
	BNE	zeroloop
	LDX	#$00
fetch:	
	TXA
	EOR	crchi,x
	STA crchi,x
	LDY	#$08
fetch1:	
	ASL	crclo,x
	ROL	crchi,x
	BCC	fetch2
	LDA	crchi,x
	EOR	#$10
	STA crchi,x
	LDA	crclo,x
	EOR	#$21
	STA crclo,x
fetch2:
	DEY
	BNE	fetch1
	INX
	BNE	fetch
	RTS