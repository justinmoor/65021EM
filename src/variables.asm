; ============================== ZERO PAGE VARIABLES ================================

T1 = $00 ; one byte temp register 1
T2 = $01 ; one byte temp register 2
T3 = $02 ; one byte temp register 3

T4 = $03 ; two byte temp register 4
T5 = $05 ; two byte temp register 5
T6 = $07 ; two byte temp register 6

P1 = $09 ; pointer 1
P2 = $0B ; pointer 2
P3 = $0D ; pointer 3

StrPtr1 = $0F
StrPtr2 = $11

; ---------------------------------- OS -----------------------------

AmountOfArgs = $40

; ---------------------------------- BIOS ----------------------------

TA  = $F6       ; temp storage for A register when debug breakpoint
TX  = $F7       ; temp storage for X register when debug breakpoint
TY  = $F8       ; temp storage for Y register when debug breakpoint

SPIReadBuf  = $F9       ; 1 byte (possibly 2 bytes in future)
SPIWriteBuf  = $FB      ; 1 byte (possibly 2 bytes in future)
M3100ReadBuf = $FD      ; 2 bytes

VRAM = $A800    ; MODE = LOW
VDPReg = $A801  ; MODE = HIGH

; ------------------------- ASSEMBLER / DISASSEMBLER -------------------

Operand     = $10
AddrA       = $24       ; Address to assemble
AddrD       = $37     ; instruction address, 2 bytes (low/high)
OPCODE      = $39     ; instruction opcode
LinesToDisAssem = $50
OP          = $3A     ; instruction type OP_*
AM          = $41     ; addressing mode AM_*
LEN         = $42     ; instruction length
REL         = $43     ; relative addressing branch offset (2 bytes)
DEST        = $45     ; relative address destination address (2 bytes)

; ----------------------------------- XMODEM -----------------------------------
CRC         = $38		; CRC lo byte  (two byte variable)
CRCH	    = $39		; CRC hi byte  
Target	    = $3A		; pointer to store the file
BlockNumber = $3C		; block number 
Retry	    = $3D		; retry counter 
Retry2	    = $3E		; 2nd counter
BlockFlag   = $3F	    ; block flag 


; ===================   =============== OHTHER VARIABLES ==================================

; -------------------------------- ASSEMBLER / DISASSEMBLER ---------------------------
OprBuf      = $300  ; buffer to hold operand
Mnem        = $800  ; hold three letter mnemonic string used by assembler

; ---------------------------------------- BIOS ----------------------------------------

VIADataB   = $B000
VIADataA   = $B001

VIADataDirB    = $B002
VIADataDirA    = $B003

; ---------------------------------- OPERATING SYSTEM-------------------------------------

InputBuffer   = $0200     ; Input buffer
CommandBuffer = $300
ArgsBuffer = $400
; vector to interrup service routine, user code can put a function pointer to custom routine
; will be called with JMP (ISR)
ISR = $600

; ---------------------------------------- XMODEM ----------------------------------------

; non-zero page variables and buffers
ReceiveBuf    = $500	; temp 132 byte receive buffer (place anywhere, page aligned)

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
