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
MD addr1 (addr2)
MM addr
MF addr1 amount byte
ASM addr
DIS addr
RUN addr
XM addr

**V2**
SBRK addr
CBRK (addr) (will clear all breakpoints if no address is specified)
