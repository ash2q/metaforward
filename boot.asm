[CPU 486]
[BITS 16]
[ORG 0x7C00]

;mov ah, 0
;mov al, 3
;int 0x10




console:
mov ax, seg_string_exec
mov es, ax
mov di, 0

get_key:
mov ah, 0
int 0x16 ;int 16,0 wait for key and read char
;ascii in al
cmp al, 0 ;if no ascii then read again
je get_key
print_key:
mov ah, 0x0E
mov bx, 0
;al already set
int 0x10 ;print key
cmp al, 0x0D ;if carriage return
jne store_key
mov al, newline ;new line
int 0x10 ;print newline character (moving console line down 1)
;note: will store \n in the buffer
store_key:
mov [es:di], al
inc di
cmp al, newline
jne get_key
cmp di, 1
je console
console_exec:



mov ah, 0x0E
mov al, '~'
mov bx, 0
int 0x10


jmp $





;constants
seg_keyword_map equ 0x1000
seg_stack equ 0x2000
seg_function_map equ 0x3000
seg_functions equ 0x4000
seg_free_space equ 0x5000
seg_exec_space equ 0x6000
seg_string_construct equ 0x7000
seg_string_exec equ 0x8000
seg_keyword_code equ 0x9000

newline equ 0x0A

