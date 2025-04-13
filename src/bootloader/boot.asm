; A directive will only give a clue to the assembler & not get translated to machine code
; any label starting from . is a local label in nasm
; general layout for real mode -> segment:offset
; segment * 16 + offset = physical address
; ss -> 0, sp -> 0x7C00, 0 * 16 + 0x7C00 = 0x7C00, thus stack grows from 0x7C00 downwards
; db (define byte) -> 8-bit value
; dw (define word) -> 16-bit value
; dd (define doubleword) -> 32-bit value

; org offset -> tells assembler where we expect our code to be loaded for label addresses
org 0x7C00
bits 16 ; tells assembler to emit 16-bit code.

%define ENDL 0x0D, 0x0A

;
; FAT12 headers 
;
jmp short start
nop

bdb_oem:                    db 'MSWIN4.1'           ; 8 bytes
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_entries_count:      dw 0E0h
bdb_total_sectors:          dw 2880                 ; 2880 * 512 = 1.44MB
bdb_media_descriptor_type:  db 0F0h                 ; F0 = 3.5" floppy disk
bdb_sectors_per_fat:        dw 9                    ; 9 sectors/fat
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

; extended boot record
ebr_drive_number:           db 0                    ; 0x00 floppy, 0x80 hdd, useless
                            db 0                    ; reserved
ebr_signature:              db 29h
ebr_volume_id:              db 12h, 34h, 56h, 78h   ; serial number, value doesn't matter
ebr_volume_label:           db 'SYPSE OS   '        ; 11 bytes, padded with spaces
ebr_system_id:              db 'FAT12   '           ; 8 bytes

start:
    mov ax, 0
    mov ds, ax ; why not just mov ds, 0? -> this is not allowed and one must only move from general purpose registers
    mov es, ax

    mov ss, ax ; set stack-segment to 0x0000
    mov sp, 0x7C00 ; set stack-pointer to 0x7C00 as stack grows down this makes sure we dont overwrite our os

    push es
    push word .after
    retf

.after:
    mov [ebr_drive_number], dl

    mov si, msg_loading
    call print

    push es
    mov ah, 08h
    jc floppy_error
    pop es

    and cl, 0x3f ; remove top 2 bits
    xor ch, ch
    mov [bdb_sectors_per_track], cx ; sector count

    inc dh
    mov [bdb_heads], dh ; head count

    ; compute LBA of root dir = reserved + fats * sectors_per_fat
    mov ax, [bdb_sectors_per_fat]
    mov bl, [bdb_fat_count]
    xor bh, bh
    mul bx ; ax = (fats * sectors_per_fat)
    add ax, [bdb_reserved_sectors] ; ax = LBA of root dir
    push ax

    ; compute size of root dir = (32 * number_of_entities) / bytes_per_sector
    mov ax, [bdb_sectors_per_fat]
    shl ax, 5 ; ax *= 32
    xor dx, dx
    div word [bdb_bytes_per_sector] ; number of bytes we need to read

    test dx, dx ; if dx != 0, then add 1
    jz .root_dir_after
    inc ax ; division remainder != 0, add 1

.root_dir_after:
    ; read root dir
    mov cl, al ; cl = number of sectors to read = size of roto dir
    pop ax ; ax = LBA of root dir
    mov dl, [ebr_drive_number] ; dl = drive number
    mov bx, buffer ; es:bx = buffer
    call disk_read

    ; search for kernel.bin
    xor bx, bx
    mov di, buffer

.search_kernel:
    mov si, file_kernel_bin
    mov cx, 11 ; compare up to 11 chars
    push di
    ; repe -> repeats a string instruction while the operands are equal (zero falg = 1), or until cx reaches 0
    ; cx is decremented each iteration
    ; cmpsb -> compares 2 bytes located in memory at address ds:si and es:di
    ; si & di are incremented (if direction flag = 0) or decremented (if direction flag = 1)
    repe cmpsb
    pop di
    je .found_kernel

    add di, 32
    inc bx
    cmp bx, [bdb_dir_entries_count]
    jl .search_kernel

    ; kernel not found
    jmp kernel_not_found_error

.found_kernel:
    ; di should have the address to the entry
    mov ax, [di + 26] ; first logical cluster field (offset 26)
    mov [kernel_cluster], ax

    ; load FAT from disk into memory
    mov ax, [bdb_reserved_sectors]
    mov bx, buffer
    mov cl, [bdb_sectors_per_fat]
    mov dl, [ebr_drive_number]
    call disk_read

    ; read kernel and process FAT chain
    mov bx, KERNEL_LOAD_SEGMENT
    mov es, bx
    mov bx, KERNEL_LOAD_OFFSET

.load_kernel_loop:
    ; Read next cluster
    mov ax, [kernel_cluster]
    add ax, 31 ; first cluster = (kernel_cluster - 2) * sectors_per_cluster + start_sector
               ; start sector = reserved + fats + root_dir_size = 1 + 18 + 134 = 33
    
    mov cl, 1
    mov dl, [ebr_drive_number]
    call disk_read

    add bx, [bdb_bytes_per_sector]

    ; compute location of next cluster
    mov ax, [kernel_cluster]
    mov cx, 3
    mul cx
    mov cx, 2
    div cl ; ax = index of entry in FAT, dx = cluster mod 2

    mov si, buffer
    add si, ax
    mov ax, [ds:si] ; read entry from FAT table at index ax

    or dx, dx
    jz .even

.odd:
    shr ax, 4
    jmp .next_cluster_after

.even:
    and ax, 0x0FFF

.next_cluster_after:
    cmp ax, 0x0FF8 ; end of chain
    jae .read_finish

    mov [kernel_cluster], ax
    jmp .load_kernel_loop

.read_finish:
    ; boot device in dl
    mov dl, [ebr_drive_number]
    mov ax, KERNEL_LOAD_SEGMENT
    mov ds, ax
    mov es, ax

    jmp KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET

    jmp wait_key_and_reboot

    cli
    hlt

floppy_error:
    mov si, msg_read_failed
    call print
    jmp wait_key_and_reboot

kernel_not_found_error:
    mov si, msg_kernel_not_found
    call print
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 16h ; wait for keypress
    jmp 0FFFFh:0 ; jump to the beginning of BIOS, restart

.halt:
    cli ; disable interupts
    hlt

;
; Prints a message to screen
; Parameters
; - si: string to print
;
print:
    push si
    push ax
    push bx

.loop:
    lodsb ; loads next character in al
    ; or dest, source -> performs bitwise or & stores in dest
    or al, al ; verify if the next char is null
    jz .done ; jumps if zero flag is set

    ; call bios interrupt to print char
    mov ah, 0x0E
    mov bh, 0
    int 0x10

    jmp .loop

.done:
    pop bx
    pop ax
    pop si
    ret

;
; Disk routines
;

; Converts an LBA address to a CHS address
; Parameters :
; - ax: LBA address
; Returns:
; - cx: [bits 0-5]: sector number
; - cx: [bits 6-15]: cylinder
; - dh: head
;
lba_to_chs:
    push ax
    push dx

    xor dx, dx ; makes dx = 0
    div word [bdb_sectors_per_track] ; ax = LBA / SectorsPerTrack, dx = LBA % SectorsPerTrack
    inc dx ; dx = (LBA % SectorsPerTrack) + 1
    mov cx, dx

    xor dx, dx ; clear dx, dx = 0
    div word [bdb_heads] ; ax = (LBA / SectorsPerTrack) / Heads = cylinder, dx = (LBA / SectorsPerTrack) % Heads = head

    mov dh, dl ; dh = head
    mov ch, al ; ch = cylinder (lower 8 bits)
    shl ah, 6 ; ah <<= 6
    or cl, ah ; put upper two bits in cl

    pop ax
    mov dl, al ; restore dl
    pop ax
    ret

;
; Reads sectors from a disk
; Parameters:
; - ax: LBA address
; - cl: number of sectors to read (up to 128)
; - dl: drive number
; - es:bx: memory address where to store/read data from
;
disk_read:
    push ax
    push bx
    push cx
    push dx
    push di

    push cx ; save CL (number of sectors to read)
    call lba_to_chs ; compute CHS
    pop ax ; AL = number of sectors to read

    mov ah, 02h
    ; as in the real world floppy disks are unreliable it is recommended to retry this operation at least 3 times
    mov di, 3 ; retry count

.retry:
    pusha ; save all registers, we dont know what the bios may modify
    stc ; set carry flag as some bios'es may not
    int 13h ; carry flag cleared = success
    jnc .done

    ; read failed
    popa
    call disk_reset

    dec di
    test di, di
    jnz .retry

.fail:
    ; all retries failed
    jmp floppy_error

.done:
    popa

    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

;
; Resets disk controller
; Parameters
; - dl: drive number
;
disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret

msg_loading: db 'Reading Disk...', ENDL, 0
msg_read_failed: db 'Disk read failed!', ENDL, 0
msg_kernel_not_found: db 'Failed to locate KERNEL.BIN!', ENDL, 0
file_kernel_bin: db 'KERNEL  BIN'
kernel_cluster: dw 0

; equ, this would not use any memory and would be replaced by the value at assembling time
KERNEL_LOAD_SEGMENT equ 0x2000
KERNEL_LOAD_OFFSET equ 0

; times number instruction/data (directive) -> repeats a instruction n number of times
; $ -> special sybmol which is equal to the memory offset of the current line
; $$ -> speical symbol which is equal to the memory offset of the beginning of the current secion
; $-$$ -> gives the size of our program
times 510-($-$$) db 0

; -> writes given bytes (2 byte value, encoding -> little-endian) to the assembled binary file
dw 0AA55h ; magic number

buffer: