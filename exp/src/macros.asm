.MACRO ASC text
    .BYTE text, 0
.ENDMACRO

; ascii text with carriage return and new line
.MACRO ASCLN text
    .BYTE text, $0D, $0A, 0
.ENDMACRO

.MACRO DEBUG_PRINT msg
    PHA
    PHX
    PHY
    JSR PrintImm                    
    .BYTE msg, $0D, $0A, 0
    PLY
    PLX
    PLA
.ENDMACRO