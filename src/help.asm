Help:
                LDA #<HelpMenu
                STA P1
                LDA #>HelpMenu
                STA P1 + 1
                JSR Print
                RTS

HelpMenu: 
        .BYTE CR, NEWL, NEWL
        
        .BYTE "Memory map: ", CR, NEWL, NEWL
        .BYTE "RAM      - 32KB          - LOC.: 0000-7FFF", CR, NEWL
        .BYTE "TMS9918  - VDP           - LOC.: A800-A80F", CR, NEWL
        .BYTE "6522 VIA - Serial        - LOC.: B000-B00F", CR, NEWL
        .BYTE "ROM      - 16KB          - LOC.: C000-FFFF", CR, NEWL
        
        .BYTE CR, NEWL, NEWL
        .BYTE "Kernel routines: ", CR, NEWL, NEWL
        .BYTE "WriteChar                - LOC.: C000", CR, NEWL
        .BYTE "ReadChar                 - LOC.: C003", CR, NEWL
        .BYTE "GetLine                  - LOC.: C006", CR, NEWL
        .BYTE "Print                    - LOC.: C009", CR, NEWL
        .BYTE "PrintImmediate           - LOC.: C00C", CR, NEWL
        .BYTE "PrintByte                - LOC.: C00F", CR, NEWL

        .BYTE CR, NEWL, NEWL
        .BYTE "Available commands:", CR, NEWL, NEWL
        .BYTE "MD aaaa (aaaa)           - Display contents of memory", CR, NEWL
        .BYTE "MM aaaa bb (...bb)       - Modify memory starting from address", CR, NEWL
        .BYTE "MF aaaa aaaa bb          - Fill memory range with specified byte", CR, NEWL
        .BYTE "ASM aaaa                 - Start assembler at address", CR, NEWL
        .BYTE "DIS aaaa (lines)         - Start disassembler at address", CR, NEWL
        .BYTE "R aaaa                   - Execute code from address", CR, NEWL
        .BYTE "XM aaaa                  - XMODEM receive at address", CR, NEWL
        .BYTE "VMD aaaa (aaaa)          - Display contents of video memory", CR, NEWL
        .BYTE "VMM aaaa bb (...bb)      - Modify video memory starting from address", CR, NEWL
        .BYTE "ZAPVRAM                  - Clears all video memory", CR, NEWL
        .BYTE "HELP                     - Display this menu", CR, NEWL

        .BYTE 0