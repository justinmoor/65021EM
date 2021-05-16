; Jump table which makes it possible to easily expose kernel routes to external programs. If the kernel routines
; move in memory because code gets added to deleted, it's unclear what their addresses are. Thanks to this jump table
; in the beginning of ROM, the addresses will stay fixed. This file should be assembled first so it's in 
; the beginning of ROM.

J_ReadChar:        ; $C000 in ROM
    JMP ReadChar
J_WriteChar:       ; $C003 in ROM
    JMP WriteChar
J_PrintImmediate:         ; $C006 in ROM
    JMP PrintImmediate
J_Print_BYTE:       ; $C009 in ROM
    JMP Print_BYTE 