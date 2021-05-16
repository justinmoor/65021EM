; --------------------------------------ZERO PAGE --------------------------------------

; GENERAL PURPOSE VARIABLES
T1          = $00       ; one byte temp register 1
T2          = $01       ; one byte temp register 2
T3          = $02       ; two byte temp register 3
T4          = $04       ; two byte temp register 4

STRING_LO   = $06       ; low address of string to print
STRIG_HI    = $07

; BIOS
SPIReadBuf  = $08       ; 1 byte (possibly 2 bytes in future)
SPIWriteBuf  = $0A       ; 1 byte (possibly 2 bytes in future)
M3100ReadBuf = $0C      ; 2 bytes

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

; ASSEMBLER / DISASSEMBLER
OPERAND = $10
ADDR_A  = $24   ; ADDRES TO ASSEMBLE

ADDR       = $37     ; instruction address, 2 bytes (low/high)
OPCODE     = $39     ; instruction opcode
OP         = $3A     ; instruction type OP_*
AM         = $41     ; addressing mode AM_*
LEN        = $42     ; instruction length
REL        = $43     ; relative addressing branch offset (2 bytes)
DEST       = $45     ; relative address destination address (2 bytes)

; XMODEM
CRC		    = $38		; CRC lo byte  (two byte variable)
CRCH	    = $39		; CRC hi byte  
TARGET	    = $3A		; pointer to store the file
BLCK_NUM    = $3C		; block number 
RETRY	    = $3D		; retry counter 
RETRY2	    = $3E		; 2nd counter
BLCK_FLAG	= $3F	    ; block flag 



; ---------------------------------OHTHER VARIABLES -----------------------------------

; -------------------------------- ASSEMBLER / DISASSEMBLER ---------------------------
IN      = $300  ; buffer to hold operand
MNEM1   = $800  ; hold three letter mnemonic string used by assembler

; ---------------------------------------- BIOS ----------------------------------------
VIADataB   = $8000
VIADataA   = $8001

VIADataDirB    = $8002
VIADataDirA    = $8003

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
ESC         = $1B       ; ESC key
SP          = $20

; XMODEM control character constants
SOH		    = $01		; start block
EOT		    = $04		; end of text marker
ACK		    = $06		; good block acknowledged
NAK		    = $15		; bad block acknowledged
CAN		    = $18		; cancel (not standard, not supported)
LF		    = $0a		; line feed
REC_CMD	    = $43
DELAY3S     = $1E		; ~ 3 secs
