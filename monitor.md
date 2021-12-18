# Monitor

Name: TBA

```
Start
    Forever:
        Read input
        If has input:
            Read command
            Parse command operands
            Execute command
        end
    end
end
            
```
## Command syntax
**V1**
xMD addr1 (addr2)
xMM addr
MF addr1 amount byte
xASM addr
xDIS addr (amount of lines)
xR addr
xXM addr

**V2**
SBRK addr
CBRK (addr) (will clear all breakpoints if no address is specified)