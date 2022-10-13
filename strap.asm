;This is the boot strap code which creates core keywords etc
;This should be kept short so it can be typed in easily

[CPU 586]
[BITS 16]
[org 0xF000]

;should be loaded using the following syntax:
;`Lf000 <hex code>

console_execute equ 0x0000008C


entry_point:
;ah=2 for read from disk
;al = 4 sectors to read
mov ax, 0x0204 
;cylinder = 0, sector = 2
mov cx, 0x0002
;head = 0
mov dh, 0
;disk = initial DL register value from bootloader
mov dl, [ss:0x1000]

mov bx, 0xE000 ;enough room for 4 sectors, 1024 bytes
;es should already be set to cs (0x1000)
int 0x13
;data should now be loaded into [0x1000:E000]

strlen:
mov si, 0xE000


