; this is a directive, it will only give a clue to the assembler & not get translated to machine code
; org offset -> tells assembler where we expect our code to be loaded for label addresses
org 0x7C00
bits 16 ; tells assembler to emit 16-bit code.

%define ENDL 0x0D, 0x0A

; general layout for real mode -> segment:offset
; segment * 16 + offset = physical address
; ss -> 0, sp -> 0x7C00, 0 * 16 + 0x7C00 = 0x7C00, thus stack grows from 0x7C00 downwards

start:
    jmp main

print:
    push si
    push ax

.loop:
    lodsb ; loads next character in al
    ; or dest, source -> performs bitwise or & stores in dest
    or al, al ; verify if the next char is null
    jz .done ; jumps if zero flag is set

    ; call bios interrupt to print char
    mov ah, 0x0e
    mov bh, 0
    int 0x10

    jmp .loop

.done:
    pop ax
    pop si
    ret

main:
    mov ax, 0
    mov ds, ax ; why not just mov ds, 0? -> this is not allowed and one must only move from general purpose registers
    mov es, ax

    mov ss, ax ; set stack-segment to 0x0000
    mov sp, 0x7C00 ; set stack-pointer to 0x7C00 as stack grows down this makes sure we dont overwrite our os

    mov si, msg_hello
    call print

    hlt

; any label starting from . is a local label in nasm
.halt:
    jmp .halt

msg_hello: db 'Hello world!', ENDL, 0

; times number instruction/data (directive) -> repeats a instruction n number of times
; $ -> special sybmol which is equal to the memory offset of the current line
; $$ -> speical symbol which is equal to the memory offset of the beginning of the current secion
; $-$$ -> gives the size of our program
times 510-($-$$) db 0

; dw word1, word2, word3 ... wordn (directive) -> (declare bytes)
; -> writes given bytes (2 byte value, encoding -> little-endian) to the assembled binary file
dw 0AA55h ; magic number