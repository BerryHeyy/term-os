org 0x7c00
bits 16

%define ENDL 0x0d, 0x0a

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

	; Print hello world.
	mov si, str_hello
	call puts

	hlt

.halt:
	jmp .halt

str_hello: db "Hello world!", ENDL, 0

times 510-($-$$) db 0
dw 0aa55h
