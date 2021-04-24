; --------------------------------------ZERO PAGE --------------------------------------

; GENERAL PURPOSE VARIABLES
T1          = $00       ; one byte temp register 1
T2          = $01       ; one byte temp register 2
T3          = $02       ; two byte temp register 3
T4          = $04       ; two byte temp register 4

STRING_LO   = $06       ; low address of string to print
STRIG_HI    = $07

; BIOS
SPI_RD_BUF  = $08       ; 1 byte (possibly 2 bytes in future)
SPI_WR_BUF  = $0A       ; 1 byte (possibly 2 bytes in future)
M3100_RD_BUF = $0C      ; 2 bytes

; WOZMON
XAML        = $24       ; index pointers
XAMH        = $25
STL         = $26
STH         = $27
L           = $28
H           = $29
YSAV        = $2A
MODE        = $2B
COUNTER     = $2C

; XMODEM
CRC		    = $38		; CRC lo byte  (two byte variable)
CRCH	    = $39		; CRC hi byte  
TARGET	    = $40		; pointer to store the file
BLCK_NUM    = $3c		; block number 
RETRY	    = $3d		; retry counter 
RETRY2	    = $3e		; 2nd counter
BLCK_FLAG	= $3f	    ; block flag 

; ---------------------------------------- BIOS ----------------------------------------
VIA_DATAB   = $8000
VIA_DATAA   = $8001

VIA_DDRB    = $8002
VIA_DDRA    = $8003

; ---------------------------------- OPERATING SYSTEM-------------------------------------

INPUT_BUF   = $0200     ; Input buffer

; ---------------------------------------- XMODEM ----------------------------------------

; non-zero page variables and buffers
RECV_BUF    = $500	; temp 132 byte receive buffer (place anywhere, page aligned)

; The CRCLO & CRCHI labels are used to point to a lookup table to calculate
; the CRC for the 128 byte data blocks.  Tables will be generated runtime
CRCLO       = $7D00      	; Two 256-byte tables for quick lookup
CRCHI	    = $7E00      	; (should be page-aligned for speed)

; ------------------------------------- CONSTANTS --------------------------------------

PROMPT      = '>'       ;'>' Prompt character
BS          = $08       ; Backspace key, arrow left key
BSH         = $88       ; back space high ascii
CR          = $0D       ; Carriage Return
NEWL        = $0A
ENT         = $8D
ESC         = $9B       ; ESC key

; XMODEM control character constants
SOH		    = $01		; start block
EOT		    = $04		; end of text marker
ACK		    = $06		; good block acknowledged
NAK		    = $15		; bad block acknowledged
CAN		    = $18		; cancel (not standard, not supported)
LF		    = $0a		; line feed
REC_CMD	    = $43
DELAY3S     = $1E		; ~ 3 secs
