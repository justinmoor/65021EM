; Jump table which makes it possible to easily expose kernel routes to external programs. If the kernel routines
; move in memory because code gets added to deleted, it's unclear what their addresses are. Thanks to this jump table
; in the beginning of ROM, the addresses will stay fixed. This file should be assembled first so it's in 
; the beginning of ROM.

J_WriteChar:        JMP WriteChar       ; $C000 in ROM
J_ReadChar:         JMP ReadChar        ; $C003 in ROM
J_PrintImm:         JMP PrintImmediate  ; $C006 in ROM
J_PrintByte:        JMP PrintByte       ; $C009 in ROM