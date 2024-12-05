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
bdb_reserved_sectors: 		dw 1
bdb_fat_count: 		db 2
bdb_dir_entries_count: 		dw 0E0h
bdb_total_sectors: 		dw 2880   ; 2880 * 512 = 1.44MB 
bdb_media_descriptor_type: 	db 0F0h   ; F0 = 3.5" floppy disk
bdb_sectors_per_fat: 		dw 9         ; 9 sectors/fat
bdb_sectors_per_track: 		dw 18
bdb_heads: 			dw 2
bdb_hidden_sectors: 		dd 0
bdb_large_sector_count:		dd 0

; extened boot record
ebr_drive_number: 		db 0
				db 0
ebr_signature: 			db 29h
ebr_volume_id: 			db 12h, 34h, 56h, 78h
ebr_volume_label:		db 'BACON OS   '
ebr_system_id:			db 'FAT12   '

times 90-($-$$) db 0

start:
	;setup data segments
	mov ax , 0          ;can not write directly to ds/es
	mov ds, ax
	mov es, ax

	;Setup Stack
	mov ss, ax
	mov sp, 0x7C00 ;stack grows downwards

    push es 
    push word .disk_setup
    retf

.disk_setup:
    ; read something from floppy disk
    ; BIOS should set DL to drive number
    mov [ebr_drive_number], dl

    ; read drive parameters (sectors per track and head count),
    ; instead of relying on data on formatted disk
    push es
    mov ah, 08h
    int 13h
    jc floppy_error
    pop es
    and cl, 0x3F                        ; remove top 2 bits
    xor ch, ch
    mov [bdb_sectors_per_track], cx     ; sector count
    inc dh
    mov [bdb_heads], dh                 ; head count

    mov dl, [ebr_drive_number]

.check_disk_extensions:
    mov ah, 41h 
    mov bx, 0x55AA
    stc 
    int 13h

    jc .no_disk_extentions
    cmp bx,0xAA55
    jne .no_disk_extentions
.disk_extentions:
    mov byte [have_extentions], 1 
    jmp .main 

.no_disk_extentions:
    mov byte [have_extentions], 0 

.main: 
    mov si, msg_welcome
    call puts

    mov cl, 1 
    mov bx, buffer
    mov ax, 1
    call disk_read

    mov si, buffer
    call puts

    jmp  wait_key_and_reboot

    

;
;Prints a string to the screen
;Params:
;   - ds:si points to the string
;
puts:
	; save registers we will modify
	push si
	push ax
    push bx

.loop:
	lodsb 		; loads next character in al
	or al, al 	; verify if the next character is null
	jz .done

	mov ah, 0x0E
	mov bh,0 
	int 0x10

	jmp .loop
	
.done:
    pop bx 
	pop ax
	pop si
	ret

;
;Disk routines
;

;
;Reads Data from Disk
;params:
;   -ax: LBA address
;   -dl: Drive number 
;   -cl: number of sectors to read 
;   -ES:BX: Buffer Address Pointer 
;
disk_read:
    push ax
    push bx
    push cx
    push dx 
    push di
    push si

    cmp byte [have_extentions], 1 
    jne .no_disk_extentions

.disk_extentions: 
    mov [extentions_dap.lba], eax
    mov [extentions_dap.segment], es 
    mov [extentions_dap.offset], bx 
    mov [extentions_dap.count], cl 

    mov ah, 0x42
    mov si, extentions_dap
    mov di, 3 
    jmp .retry

.no_disk_extentions:
    push cx
    call lba_to_chs
    pop ax

    mov ah, 0x02 
    mov di, 3 

.retry:
    pusha
    push si 
    mov si, msg_reading_disk
    call puts
    pop si 
    stc 
    int 13h 
    jnc .done

    dec di 
    test di, di 
    jnz .retry

.fail:
    ; all attempts are exhausted
    jmp floppy_error

.done:
    mov si, msg_disk_read
    call puts

    popa
    
    pop si 
    pop di
    pop dx 
    pop cx 
    pop bx 
    pop ax 
    ret 

;
;Converts an LBA address to a CHS address
;Params:
;   -ax: LBA address
;Returns:
;   -cx [bits 0-5]: sector number 
;   -cx [bits 6-15]: cylinder
;   -dh: head 
;

lba_to_chs:
  push ax
  push dx

  xor dx, dx                      ;dx = 0 
  div word [bdb_sectors_per_track] ;ax = LBA / SectorsPerTrack 
                                  ;dx = LBA % SectorsPerTrack
  inc dx                          ;dx = (LBA % SectorsPerTrack +1) = sector
  mov cx, dx                      ;cx = sector
  xor dx, dx                      ;dx = 0
  div word [bdb_heads]            ;ax = (LBA / SectorsPerTrack) / Heads = cylinder
                                  ;dx = (LBA / SectorsPerTrack) % Heads = head 
  mov dh, dl                      ;dh = head 
  mov ch, al                      ; ch = cylinder (lower 8 bits)
  shl ah, 6
  or cl, ah                       ; put upper 2 bits of cylinder in cl 

  pop ax
  mov dl, al                      ; restore DL 
  pop ax
  ret 

;
; Error handlers
;

floppy_error:
  mov si, msg_read_failed
  call puts
  jmp wait_key_and_reboot

wait_key_and_reboot:
    mov si, msg_reload
    call puts
    mov ah, 0 
    int 16h           ; wait for keypress
    jmp 0FFFFh:0      ; jump to begining of BIOS, should reboot 

.halt:
    cli                 ; disable interrupts, this way we can't get out of "halt" state
	hlt

msg_disk_read           : db 'Disk Read!', ENDL, 0 
msg_reading_disk        : db 'Reading Disk!', ENDL, 0
msg_read_failed         : db 'Read disk failed!', ENDL, 0
msg_loading             : db 'Loading...', ENDL,0 
msg_welcome             : db 'Welcome To Bacon OS! 0.0.1', ENDL,0
msg_reload              : db 'Press any key to reload', ENDL,0
file_kernel_bin         : db 'STAGE2  BIN'

have_extentions         : db 0 
extentions_dap          : 
    .size               : db 10h 
                          db 0 
    .count              : dw 0 
    .offset             : dw 0 
    .segment            : dw 0 
    .lba                : dq 0 


times 510-($-$$) db 0

dw 0AA55h

dw 0AAAAh

buffer: 

