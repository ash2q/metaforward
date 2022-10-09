[CPU 586]
[BITS 16]
[org 0x1000]

%include "options.asm"
begin_code:

init_keywords:
    ;store default keyword function into every keyword
    mov ax, keyword_error
    mov cl, 128 ;CX should be zero entering into this
    ;es should already be seg_compiler
    xor di, di ;keyword map is at 0
    ;ds will be set by bootloader to 0x1000 already
    rep stosw
    mov dx, install_keyword

    mov al, '`'
    mov bx, meta_create_keyword
    call dx

    mov bx, meta_begin_function
    mov al, '~'
    call dx

    mov bx, keyword_end_function
    mov al, ';'
    call dx

    mov bx, keyword_call
    mov al, '$'
    call dx

;continue executing...

proto_console:
    push cs
    pop es ;needed?
    mov si, console_prompt
    mov cx, 3
    call print_string

    push seg_string_exec
    pop es
    mov di, 0
    mov cx, 255

get_string:
    ;es:di = where to write string
    ;cx = size of string buffer, returned as final size of string
    pusha
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

        mov bp, sp
        mov [bp + 12], dx ;save dx into cx
        popa

    mov si, di
    call console_execute
jmp proto_console



console_execute:
    ;es:si = string to execute
    pusha
    cmp cx, 0
    je .done

    .valid:
        mov al, [es:si]
        ;al = keyword
        movzx bx, al
        imul bx, 2
        ;bx is now address of jump address in symbol map

        push seg_function_map
        pop fs
        push seg_functions
        pop ds
        mov di, [cs:current_fn_byte] ;should start at 0x1000
        mov bp, sp
        call [cs:bx]
        mov [cs:current_fn_byte], di

    .done:
    popa
    ret


meta_create_keyword:
;syntax, where x is keyword
;example: `x1000 9090cb
;1000 is where in memory to place the data
;next is the hex string of the opcodes to execute when encountering this keyword
;defines keyword of `x` which executes "nop nop retf" upon execution located at 0x1000
;note: the space between the memory and hex string is NOT enforced. That character is simply skipped. It can be anything
    pusha
    inc si
    mov al, [es:si] ;keyword to create
    push ax ;save the keyword
    inc si
    push cx
    call parse_hex_word
    pop cx
    ;ax should now be the address
    mov bx, ax ;save address to bx
    add si, 5 ;skip address and space
    sub cx, 6 ;remove those from total string length (plus initial keyword)
    ;note: no error checking!

    mov di, ax
    call parse_hex

    ;restore the keyword
    pop ax
    call install_keyword
    popa
    ret



keyword_error:
    ; installed at 0
    %ifdef PROVIDE_ERRORS
    mov al, 'E'
    call print_char
    %endif
    ret

keyword_end_function:
    ;keyword for `;` 
    mov al, 0xCB ;ret
    mov [ds:di], al ;inject ret
    inc di
ret


meta_begin_function:
    ; meta keyword for `~`
    ; syntax `~1234 where 1234 is function number`
    mov bx, 0x200 ;set to function slot area
    inc si ;get to start of number
    call parse_hex_word
    ;ax now function slot number
    mov [cs:bx], di
    ;now function slot number is set to the current fn byte
ret

keyword_call:
    ;keyword for `$`
    ;$1234 -- where 1234 is the function slot
    inc si
    call parse_hex_word
    ;ax = slot
    imul ax, 2
    add ax, 0x200
    mov cx, end_template_call - begin_template_call
    mov [cs:si+3], ax ;overwrite [fs:0] with slot address
    mov si, begin_template_call
    call copy_template_block
ret

begin_template_call:
    mov bx, [fs:0x0000] ;[FS:0] IS REPLACED
    ;64 8B 1E 0000 -- FS, MOV, RM(bx), OFFSET
    call bx
end_template_call:

keyword_execute:
    ;keyword for x
    ;no arguments
    ;mov bx, 0x1002
ret


copy_template_block:
    ;copy block of data from compiler code into function code
    ;incrementing di as required
    ;cx should be length
    ;si should be local code address
    ;should return di pointing at next free function code byte
    ;ax and cx will be trashed
    ;push cs
    ;pop ds
    .loop:
        mov al, [cs:si]
        mov [ds:di], al
        inc di
        inc si
    loop .loop
ret



install_keyword:
    ;al = keyword
    ;bx = address
    push ds
    push di
    push cs
    pop ds
    movzx di, al
    imul di, 2
    mov [ds:di], bx
    pop di
    pop ds
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
    ;cx = length
    pusha
    .loop:
        mov al, [es:si]
        call print_char
        inc si
    loop .loop
    .done:
    popa
    ret

print_hex_word:
    ;ax = number
    ;preserves all registers
    ;first print ah
    xchg al, ah
    call print_hex_byte
    ;now print al
    xchg ah, al
    call print_hex_byte
ret
    popa

print_hex_byte:
    ;al = number
    pusha
    mov dl, al ;save al for later
    ;display register init
    mov ah, 0x0E
    xor bx, bx

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

parse_hex_word:
    ;es:si should point to ascii string
    ;ax is return value
    ;note: cost 20 bytes
    push ds
    push cs
    pop ds
    push cx
    push di
    mov cx, 2
    mov di, temp_parse_word
    call parse_hex
    mov ax, [temp_parse_word]
    xchg ah, al ;swap endian
    pop di
    pop cx
    pop ds
    ret


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
    xor bx, bx
    
    .step1:
    cmp cx, 0
    jne .step1_2
    ;end of string

    ;odd length string behavior: 0x1 = 0x01, 0x111 = 0x1101
    cmp ah, 1 
    jne .prep_return ;odd number of digits, so just use the in-progress data as-is
    mov [ds:di+bx], dh
    inc bx

    .prep_return:
    mov bp, sp
    mov [bp+12], bx ;write to CX slot in stack
    popa
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
    sub al, '0'

    jmp .step2
    .letter:
    cmp al, 'a'
    jl .skip
    cmp al, 'f'
    jg .skip
    ;is letter
    sub al, 'a' - 10 ;decrease the ASCII offset, but add 10 for 0x0A = 10 in base-10

    .step2:
    cmp ah, 1
    je .bottom_nibble
    mov ah, 1
    ;if we get here, we're working with top nibble
    ;put in-progress result in dh
    mov dh, al
    jmp .skip
    .bottom_nibble:
    mov ah, 0 ;reset back to top_nibble for next loop
    shl dh, 4 ;make data in dh the top nibble (note: this could be made to save a byte by using mul with register reorg)
    add dh, al ;add top_nibble + bottom nibble to form result
    .write_byte:
    ;dh contains the completed byte
    mov [ds:di+bx], dh
    inc bx
    xor dx, dx

    .skip:
    inc si
    dec cx
    jmp .step1



[section .data]
console_prompt: db 0x0A, '>', ' ' ;\n> 
current_fn_byte: dw 0x1000
[section .bss]
begin_bss:

temp_var1: resb 2
function_count: resw 1

temp_parse_word: resb 2

end_bss:

;constants
seg_compiler_code equ 0x1000
seg_string_exec equ 0x2000
seg_function_map equ 0x3000
seg_functions equ 0x4000
seg_free_space equ 0x5000
seg_exec_space equ 0x6000
seg_string_construct equ 0x7000
seg_stack equ 0x8000
seg_keyword_code equ 0x9000

newline equ 0x0A

