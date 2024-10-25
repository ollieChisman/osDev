org 0x0
bits 16

%define ENDL 0x0D, 0x0A

start:
	jmp main

;
;Prints a string to the screen
;Params:
;   - ds:si points to the string
;

puts:
	; save registers we will modify
	push si
	push ax

.loop:
	lodsb 		; loads next character in al
	or al, al 	; verify if the next character is null
	jz .done

	mov ah, 0x0e
	mov bh,0 
	int 0x10
	jmp .loop
	
.done:
	pop ax
	pop si
	ret

main:
	mov si, msg_hello
	call puts
	mov si, msg_stage
	call puts
	mov si, msg_boot_method
	call puts
    mov si, msg_platform
    call puts
	hlt

.halt:
	jmp .halt


msg_hello: db 'Welcome To Bacon!', ENDL, 0
msg_stage: db 'This is a test Stage 2', ENDL, 0
msg_boot_method: db 'By using Fat 12', ENDL,0
msg_platform: db 'On x86-64 asm on a floppy', ENDL,0
