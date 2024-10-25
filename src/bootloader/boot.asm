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
bdb__fat_count: 		db 2
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
    push word .after
    retf

.after:
  ; read somthing form floppy disk 
  ; BIOS should set DL to drive number 
    mov [ebr_drive_number], dl 

	mov si, msg_loading
	call puts
	
    ; check extensions present
    mov ah, 0x41
    mov bx, 0x55AA 
    stc 
    int 13h

    jc .load_stage2

    ; extensions are present
    mov byte [have_extensions], 1 

.load_stage2:

    ;load stage2 
    mov si, stage2_loacation 

    mov ax, STAGE2_LOAD_SEGMENT
    mov es, ax

    mov bx, STAGE2_LOAD_OFFSET

.loop:
    mov eax, [si]
    add si, 4 
    mov cl, [si] 
    inc si

    cmp eax , 0 
    je .read_finish

    call disk_read

    xor ch, ch 
    shl cx, 5 
    mov di, es 
    add di, cx 
    mov es, di 

    jmp .loop




.read_finish:
    ;jump to our kernel 
    mov dl, [ebr_drive_number]              ;boot drive in dl  

    mov ax, STAGE2_LOAD_SEGMENT             ; set segment registers
    mov ds, ax
    mov es, ax 
 

    jmp STAGE2_LOAD_SEGMENT:STAGE2_LOAD_OFFSET

    mov si, msg_kernel_not_found
    call puts

    jmp wait_key_and_reboot                 ; should never happens


    cli                                     ; disable interrupts, this way we can't get out of "halt" state
    hlt

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
; Error handlers
;

floppy_error:
  mov si, msg_read_failed
  call puts
  jmp wait_key_and_reboot

kernel_not_found_error:
    mov si, msg_kernel_not_found
    call puts
    jmp wait_key_and_reboot 


wait_key_and_reboot:
    mov ah, 0 
    int 16h           ; wait for keypress
    jmp 0FFFFh:0      ; jump to begining of BIOS, should reboot 

.halt:
    cli                 ; disable interrupts, this way we can't get out of "halt" state
	hlt

;
;Disk routines
;

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
; Reads sectors from a disk 
; Params:
;   - eax: LBA address
;   - cl: number of sectors to read (up to 128)
;   - dl: dive number 
;   -es:bx memory address where to store read data 
disk_read:


    push eax                         ; save registers we will modify
    push bx
    push cx
    push dx
    push si
    push di 

    cmp byte [have_extensions], 1 
    jne .no_disk_extensions

    ;with extensions 
    mov [extensions_DAP.lba], eax 
    mov [extensions_DAP.count], cl 
    mov [extensions_DAP.segment], es 
    mov [extensions_DAP.offset], bx 

    mov ah, 0x42 
    mov si, extensions_DAP
    int 13h
    mov di, 3 
    jmp .retry


.no_disk_extensions:
    push cx                         ; temporarily save CL (nummber of sectors to read)
    call lba_to_chs                 ; compute CHS 
    pop ax                          ; AL = number of sectors to read 

    mov ah, 02h 
    mov di, 3                       ; retry count  

.retry:
    pusha                           ; save all registers, we don't know what bios modifies 
    stc                             ; set carry flag, some BIOS'es don't set it 
    int 13h                         ; carry flag cleared = success
    jnc .done

    ; read failed
    popa 
    call disk_reset

    dec di 
    test di,di 
    jnz .retry

.fail:
    ;all attempts are exhausted
    jmp floppy_error

.done: 
    popa 
    pop di 
    pop si 
    pop dx
    pop cx
    pop bx
    pop eax
    ret 


;
; Resets disk controller
; Params:
;   dl: drive number 
;
disk_reset:
    pusha
    mov ah, 0 
    stc 
    int 13h 
    jc floppy_error
    popa
    ret
  
msg_kernel_not_found    : db 'Kernel not found!', ENDL, 0 
msg_read_failed         : db 'Read disk failed!', ENDL, 0
msg_loading             : db 'Loading...', ENDL,0 
file_kernel_bin         : db 'STAGE2  BIN'

extensions_DAP          :
    .size               : db 10h
                          db 0
    .count              : dw 0 
    .offset            : dw 0 
    .segment             : dw 0 
    .lba                : dq 0 

have_extensions         : db 0 

STAGE2_LOAD_SEGMENT     equ 0x2000
STAGE2_LOAD_OFFSET      equ 0 

times 510-30-($-$$) db 0

stage2_loacation        : times 30  db 0 

dw 0AA55h

buffer:

