bits 32

global _start
extern kernel_main

_start:
    call kernel_main
    
    jmp $ ; should NOT happen, but in case we return

times 512-($-$$) db 0
