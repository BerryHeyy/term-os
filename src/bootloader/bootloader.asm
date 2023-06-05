org 0x7c00
bits 16

%define ENDL 0x0d, 0x0a

;
; FAT12 header.
;
jmp short start
nop

bpb_oem:					db "MSWIN4.1"
bpb_bytes_per_sector:		dw 512
bpb_sectors_per_cluster:	db 1
bpb_reserved_sectors:		dw 1
bpb_fat_count:				db 2
bpb_dir_entries_count:		dw 0e0h
bpb_total_sectors:			dw 2880
bpb_media_descriptor_type:	db 0f0h
bpb_sectors_per_fat:		dw 9
bpb_sectors_per_track:		dw 18
bpb_heads:					dw 2
bpb_hidden_sectors:			dd 0
bpb_large_sector_count:		dd 0

; Extended boot record.
ebr_drive_number:			db 0
							db 0					; Reserved byte.
ebr_signature:				db 29h
ebr_volume_id:				db 12h, 24h, 56h, 78h	; Arbitrary serial id.
ebr_volume_label:			db "testos     "		; 11 bytes.
ebr_system_id:				db "FAT12   "			; 8 bytes

;
; Code.
;

start:
	jmp main

; Prints a string to the screen.
; Params:
; 	- ds:si points to null-terminated string.
puts:
	; Save modified registers.
	push si
	push ax

.loop:
	lodsb
	or al, al
	jz .done

	mov ah, 0x0e
	mov bh, 0x0
	int 0x10

	jmp .loop

.done:
	pop ax
	pop si
	ret

main:
	; Setup data segments.
	mov ax, 0
	mov ds, ax
	mov es, ax

	; Setup stack.
	mov ss, ax
	mov sp, 0x7c00

	; Read something from floppy disk.
	; BIOS should have set DL to the drive number.
	mov [ebr_drive_number], dl

	mov ax, 1		; LBA=1, second sector from disk.
	mov cl, 1		; 1 sector to read.
	mov bx, 0x7e00	; Data should be after the bootloader.
	call disk_read

	; Print hello world.
	mov si, str_hello
	call puts

	cli
	hlt

;
; Error handlers.
;

floppy_error:
	mov si, str_read_failed
	call puts
	jmp wait_key_and_reboot

wait_key_and_reboot:
	mov ah, 0
	int 16h			; Wait for keypress.
	jmp 0FFFFh:0	; Jump to beginning of BIOS; should reboot.

.halt:
	cli				; Disable interupts. This way CPU can't get out of halt state.
	hlt

; Converts an LBA addres to a CHS address.
; Parameters:
;	- ax: LBA address.
; Returns:
;	- cx [bits 0-5]: sector number.
;	- cx [bits 6-15]: cylinder.
;	- dh: head.
lba_to_chs:
	push ax
	push dx

	xor dx, dx							; dx = 0.
	div word [bpb_sectors_per_track]	; ax = LBA / sectors_per_track
										; dx = LBA % sectors_per_track
	inc dx								; dx = (LBA % sectors_per_track) + 1 = sector
	mov cx, dx							; cx = sector

	xor dx, dx							; dx = 0
	div word [bpb_heads]				; ax = (LBA / sectors_per_track) / heads = cylinder
										; ax = (LBA / sectors_per_track) % heads = head
	
	mov dh, dl							; dh = head

	mov ch, al							; ch = cylinder
	shl ah, 6
	or cl, ah

	pop ax
	mov dl, al							; Restore dl.
	pop ax
	ret

; Reads sectors from a disk.
; Parameters:
;	- ax: LBA address.
;	- cl: number of sectors to read (up to 128).
;	- al: drive number.
;	- es:bx: memory address where to store read data.
disk_read:
	push ax
	push bx
	push cx
	push dx
	push di

	push cx								; Temporarily save CL (number of sectors to read).
	call lba_to_chs						; Compute CHS.
	pop ax								; AL = numer of sectors to read.
	
	mov ah, 02h
	mov di, 3							; Retry count.

.retry:
	pusha								; Save all registers. We don't know what the bios modifies.
	stc									; Set carry flag. Some BIOS'es don't set it.
	int 13h
	jnc .done							; Carry flag cleared = success.

	; Read failed.
	popa
	call disk_reset

	dec di
	test di, di
	jnz .retry

.fail:
	; Reached max attempts.
	jmp floppy_error

.done:
	popa

	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	ret

; Resets disk controller.
; Parameters:
;	- dl: drive number.
disk_reset:
	pusha
	mov ah, 0
	stc
	int 13h
	jc floppy_error
	popa
	ret
	

str_hello: 			db "Hello world!", ENDL, 0
str_read_failed:	db "Failed to read from disk.", ENDL, 0

times 510-($-$$) db 0
dw 0aa55h
