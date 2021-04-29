; Jump table which makes it possible to easily expose kernel routes to external programs. If the kernel routines
; move in memory because code gets added to deleted, it's unclear what their addresses are. Thanks to this jump table
; in the beginning of ROM, the addresses will stay fixed. This file should be assembled first so it's in 
; the beginning of ROM.

J_READ_CHAR:        ; $C001 in ROM
    JMP READ_CHAR
J_WRITE_CHAR:       ; $C003 in ROM
    JMP WRITE_CHAR
J_PRINTIMM:         ; $C006 in ROM
    JMP PRINTIMM