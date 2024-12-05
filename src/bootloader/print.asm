org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

jmp short start
nop

start:
	mov ah, 0x0E
	mov bh,0 
    mov al, 0x4C
	int 0x10

    mov ah, 0 
    int 16h           ; wait for keypress
    jmp 0FFFFh:0


times 510-($-$$) db 0


dw 0AA55h
