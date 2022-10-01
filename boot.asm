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
mov cx, di ;string len for parse_hex
dec cx ;remove last \n character
mov al, cl
call print_hex
;es already set
mov si, 0 ;move to beginning of string
mov ax, seg_exec_space
mov ds, ax
mov di, 0
call parse_hex
mov ah, [ds:0]
mov al, ah
call print_hex
cmp ah, 0xF1

mov al, '~'
jne .whatever
mov al, '!'
.whatever:
mov ah, 0x0E

mov bx, 0
int 0x10

int3

jmp console

;converts A-Z to a-z
letters_to_lower:
;es:si should point to string
;ds:di should point to buffer for modified string
;cx should be count
;MUST be capable for es:si and ds:di to be the same
.convert_char:
mov al, [es:si] ;load character
;'a' = 0x61, 'A'=0x41, 'z' = 0x7A, 'Z'=0x5A
cmp al, 'Z'
jg .write_back
cmp al, 'A'
jl .write_back
;ok is within range A-Z
sub al, 0x20
.write_back:
mov [ds:di], al
inc si
inc di
loop .convert_char
ret




print_hex:
    ;al = number
    pusha
    mov dl, al ;save al for later
    ;display register init
    mov ah, 0x0E
    mov bx, 0

    
    ;al = working hex nibble, dl = original byte
    and al, 0xF0
    shr al, 4
    call nibble_to_hex
    ;nibble_to_hex has character in al
    int 0x10

    mov al, dl
    and al, 0x0F
    call nibble_to_hex
    int 0x10

    popa
ret

nibble_to_hex:
    ;input and output number in dl
    add al, '0'
    cmp al, '9'+1
    jl no_letter
    ;if gets here then it is a-f
    add al, ('a' - '0' - 10) ;I'll be honest, I have no idea why -10 is needed, my brain is broken
    no_letter:
    ret 

;282 -> 272 -> 251 bytes


parse_hex:
    ;es:si should point to ascii string
    ;ds;di should point to buffer for decoded bytes
    ;cx should be the string size (note: no guard for destination buffer overflow)
    ;preserves all registers
    ;cx shall be final number of bytes written to destination


    ;ascii: 0x30 = '0', 0x39 = '9', 0x61='a', 0x66='f'
    ;errors: all non-hex characters are ignored. 
    pusha
    xor dx, dx
    xor ax, ax ;ah=0 for top nibble, ah=1 for bottom nibble
    .step1:
    cmp cx, 0
    jne .step1_2
    ;end of string

    ;odd length string behavior: 0x1 = 0x01, 0x111 = 0x1101
    cmp ah, 1 
    jne .prep_return ;odd number of digits, so just use the in-progress data as-is
    mov [ds:di], dh
    inc di

    .prep_return:
    mov [cs:temp_var1], di
    popa
    mov cx, [cs:temp_var1] ;cx=new_di
    sub cx, di ;value = new_di - old_di
    ret

    .step1_2
    mov al, [es:si]
    cmp al, '0'
    jl .skip
    cmp al, '9'
    jg .letter1
    ;is number
    mov dl, al
    sub dl, '0'

    jmp .step2
    .letter1:
    cmp al, 'a'
    jl .skip
    cmp al, 'f'
    jg .skip
    ;is letter
    mov dl, al
    sub dl, 'a' - 10 ;decrease the ASCII offset, but add 10 for 0x0A = 10 in base-10

    .step2:
    cmp ah, 1
    je .bottom_nibble
    mov ah, 1
    ;if we get here, we're working with top nibble
    ;put in-progress result in dh
    mov dh, dl
    jmp .skip
    .bottom_nibble:
    mov ah, 0 ;reset back to top_nibble for next loop
    shl dh, 4 ;make data in dh the top nibble (note: this could be made to save a byte by using mul with register reorg)
    mov al, dl
    ;call print_hex
    mov al, dh
    ;call print_hex
    add dh, dl ;add top_nibble + bottom nibble to form result
    .write_byte:
    ;dh contains the completed byte
    mov [ds:di], dh
    xor dx, dx
    inc di

    .skip:
    inc si
    dec cx
    jmp .step1


end:
hlt



[section .bss]
hex_table: resb 16 ;??

temp_var1: resb 2



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

