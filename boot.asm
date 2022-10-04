[CPU 486]
[BITS 16]
[ORG 0x7C00]

; %define ACCEPT_UPPER_CASE ;costs 12 bytes of ROM


init:
push seg_stack
pop ss
mov sp, 0x8000 ;setup stack to somewhere a bit more roomy (can potentially be eliminated if space is needed)
;because of excessive pusha/popa usage to save space, the stack may be unexpectedly large

clear_bss:
xor ax,ax
push cs
pop es
mov di, begin_bss
mov cx, (end_bss - begin_bss + 2)
rep stosw


proto_console:
push cs
pop es
mov si, console_prompt
mov cx, 3
call print_string

push seg_string_exec
pop es
mov di, 0
mov cx, 255
call get_string

mov si, di
call console_execute
jmp proto_console



console_execute:
    ;es:si = string to execute
    pusha
    push seg_symbol_map
    pop fs
    push seg_functions
    pop ds
    push seg_string_exec
    mov di, [cs:next_fn_byte]
    
    mov al, [es:si+1]
    inc si
    ;al = keyword
    mov dl, [cs:construct_mode]
    cmp dl, 0
    je .meta_mode
    
    .construction:
    movzx bx, al
    imul bx, 4
    mov bx, [fs:bx]
    ;bx is now address of far jump address in symbol map
    call FAR [bx]

    jmp .done
    .meta_mode:
    cmp al, '`'
    ;je meta_create_keyword
    .done:
    popa
    ret






get_string:
    ;es:di = where to write string (first byte at di is actual string size)
    ;cx = size of string buffer, returned as final size of string
    pusha
    inc di
    xor dx, dx ;dx = actual string length
    .read_key:
        cmp cx, 0
        je .out_of_room
        ;int 0x16, 0 -- wait for key and read char
        mov ah, 0
        int 0x16
        cmp al, 0 ;no ascii code (special key)
        je .read_key ;ignore the special key

        ;ascii returned in al
        cmp al, 0x0D ;\r, enter key is pressed
        je .done
        cmp al, 0x08 ;\b, backspace key is pressed
        jne .normal_key
        ;backspace
        cmp dx, 0
        je .read_key ;just loop back if no characters entered
        call print_char ;still print it (print_char erases and sets cursor)
        inc cx
        dec dx
        dec di
        jmp .read_key

        .normal_key:
        call print_char
        mov [es:di], al
        inc dx
        dec cx
        inc di
    jmp .read_key
    .out_of_room:
        ;mov al, 0x0D ;set to carriage return so next bit works right
    .done:
        mov al, 0x0A ;\n
        call print_char
        mov [cs:temp_var1], dx ;note, we can inject into the stack frame for this to save space
        popa
        mov cx, [cs:temp_var1]
        mov [es:di], cl ;only write lower byte into string for length prefix
    ret


%ifdef ACCEPT_UPPER_CASE
;converts A-Z to a-z
ascii_to_lower:
    ;al is letter. If not A-Z then do not touch
    .convert_char:
    ;'a' = 0x61, 'A'=0x41, 'z' = 0x7A, 'Z'=0x5A
    cmp al, 'Z'
    jg .done
    cmp al, 'A'
    jl .done
    ;ok is within range A-Z
    sub al, 0x20
    .done:
    ret
%endif

print_char:
    ;prints character in al
    pusha
    mov ah, 0x0E
    xor bx, bx
    int 0x10
    cmp al, 0x0A ;if \n
    jne .skip1
    mov al, 0x0D ;print \r too
    int 0x10

    .skip1:
    cmp al, 0x08 ;\b
    jne .done
    ;clear character for backspace
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    .done:
    popa
    ret

print_string:
    ;[es:si] = string to print
    ;cl = length
    pusha
    xor ch, ch
    .loop:
        cmp cl, 0
        je .done
        mov al, [es:si]
        call print_char
        dec cl
        inc si
        cmp al, 0x0A ;\n
        jne .loop
        mov al, 0x0D ;\r
        call print_char
    jmp .loop
    .done:
    popa
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
    %ifdef ACCEPT_UPPER_CASE
    call ascii_to_lower ;convert letter to lower case, in case it is upper case
    %endif
    cmp al, '0'
    jl .skip
    cmp al, '9'
    jg .letter
    ;is number
    mov dl, al
    sub dl, '0'

    jmp .step2
    .letter:
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



keyword_end_function:
; keword for `;` 
;note: PIC
mov al, 0xC3
mov [ds:di], al ;inject ret
inc di
mov [cs:next_fn_byte], di
retf

meta_begin_function:
    ; meta keyword for `:`
    ; syntax `:function_name`
    mov al, 1
    mov [cs:construct_mode], al
    mov di, [cs:next_fn_byte]
    push seg_functions
    pop ds


ret


string_equal:
    ;[es:si] -- string to find
    ;cx -- length
    ;[ds:di] -- string to compare
    ;dx -- length (?)
    ;al = 1 if equal, otherwise 0
    pusha
    cmp cx, dx
    jne .skip
    
    repne cmpsb
    .skip:
    cmp cx, 0
    popa
    sete al
    ret
ret

search_function:
    ;[es:si] -- function name string
    ;cx length
    ;bx -- (return) slot (0 being invalid)
    mov bx, 0
    push ds
    pusha
    push seg_function_map
    pop ds

    mov di, 0 ;start from beginning
    .loop:
        cmp bx, [cs:function_count]
        jg .not_found
        mov dx, [ds:di]
        inc di
        call string_equal
        add di, dx
        inc bx
        cmp al, 1
        je .found
    jmp .loop

    .found:
    mov bp, sp
    mov [bp+10], bx ;write into the bx saved by 'pusha'
    .not_found:
    popa
    pop ds
    ret


[section .data]
console_prompt: db 0x0A, '>', ' ' ;\n> 

[section .bss]
begin_bss:

temp_var1: resb 2
construct_mode: resb 1
next_fn_byte: resw 1
function_count: resw 1

end_bss:

;constants
seg_symbol_map equ 0x1000
seg_stack equ 0x2000
seg_function_map equ 0x3000
seg_functions equ 0x4000
seg_free_space equ 0x5000
seg_exec_space equ 0x6000
seg_string_construct equ 0x7000
seg_string_exec equ 0x8000
seg_keyword_code equ 0x9000

newline equ 0x0A

