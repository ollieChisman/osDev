org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

;
;FAT12 header
;
jmp short start
nop

bdb_oem:			db 'MSWIN4.1'		; 8bytes
bdb_bytes_per_sector:		dw 512
bdb_sector_per_cluster:		db 1
bdb_reeserved_sectors: 		dw 1
bdb__fat_count: 		db 2
bdb_dir_entries_count: 		dw 0E0h
bdb_total_sectors: 		dw 2880
dbd_media_descriptor_type: 	db 0F0h
dbd_sectors_per_fat: 		dw 9
dbd_sectors_per_track: 		dw 18
dbd_heads: 			dw 2
dbd_hidden_sectors: 		dd 0
dbd_large_sector_count:		dd 0

; extened boot record
ebr_drive_number: 		db 0
				db 0
ebr_signature: 			db 29h
ebr_volume_id: 			db 12h, 34h, 56h, 78h
ebr_volume_lable:		db 'BACON OS   '
ebr_system_id:			db 'FAT12   '

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
	;setup data segments
	mov ax , 0	;can not write directly to ds/es
	mov ds, ax
	mov es, ax

	;Setup Stack
	mov ss, ax
	mov sp, 0x7C00 ;stack grows downwards

	mov si, msg_hello
	call puts
	mov si, msg_melon
	call puts
	mov si, msg_bacon
	call puts
	hlt

.halt:
	jmp .halt


msg_hello: db 'Hello World!', ENDL, 0
msg_melon: db 'melon!', ENDL, 0
msg_bacon: db 'Welcome To Bacon', ENDL,0

times 510-($-$$) db 0
dw 0AA55h
