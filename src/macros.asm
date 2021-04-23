.MACRO ASC text
    .BYTE text, 0
.ENDMACRO

; ascii text with carriage return and new line
.MACRO ASCLN text
    .BYTE text, $0D, $0A, 0
.ENDMACRO

.MACRO PRINT_PROMPT
    LDA #CR
    JSR ECHO        ; New line
    LDA #NEWL
    JSR ECHO
    LDA #PROMPT     ; ">"
    JSR ECHO        ; Output it.
    LDA #$20        ; "<space>"
    JSR ECHO     
.ENDMACRO