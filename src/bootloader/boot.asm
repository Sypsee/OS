bits 16
org 0x7C00

start:
    cli
    mov ax, 0
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

load_kernel:
    mov bx, KERNEL_LOAD_SEG
    mov dh, 0x00
    mov dl, 0x80
    mov cl, 0x02
    mov ch, 0x00
    mov ah, 0x02
    mov al, 8
    int 0x13

    jc disk_read_error

clear_screen:
    mov ah, 0x0
    mov al, 0x3
    int 0x10

load_PM:
    cli
    lgdt [GDT_descriptor]
    ; change last bit of cr0 to 1
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; far jmp to code seg
    jmp CODE_SEG:start_PM

disk_read_error:
    hlt

GDT_start:
    ; null descriptor
    dq 0

    ; code seg descriptor
code_descriptor:
    dw 0xFFFF ; limit
    dw 0 ; base 16
    db 0 ; base + 8 = 24
    db 10011010b ; type flags
    db 11001111b ; other flags
    db 0 ; last +8 bits of base, = 32

    ; data seg descriptor
data_descriptor:
    dw 0xFFFF ; limit
    dw 0 ; base 16
    db 0 ; base + 8 = 24
    db 10010010b ; type flags
    db 11001111b ; other flags
    db 0 ; last +8 bits of base, = 32
GDT_end:

GDT_descriptor:
    dw GDT_end - GDT_start - 1 ; size
    dd GDT_start ; start

halt:
    cli
    hlt

bits 32
start_PM:
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov ss, ax
    mov gs, ax
    mov esp, 0x9C00
    mov ebp, esp

    ; enable A20 line
    in al, 0x92
    or al, 2
    out 0x92, al

    jmp CODE_SEG:KERNEL_START_ADDR

CODE_SEG equ code_descriptor - GDT_start
DATA_SEG equ data_descriptor - GDT_start

KERNEL_LOAD_SEG equ 0x1000
KERNEL_START_ADDR equ 0x100000

times 510-($-$$) db 0
dw 0xAA55
