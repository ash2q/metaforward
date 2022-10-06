[CPU 586]
[BITS 16]
[ORG 0x7C00]

%include "options.asm"

init:
cld
%ifndef USE_DEFAULT_CALL_STACK
push seg_stack
pop ss
;seg_stack is 0x8000
mov sp, ss ;setup stack to somewhere a bit more roomy (can potentially be eliminated if space is needed)
;because of excessive pusha/popa usage to save space, the stack may be unexpectedly large
%endif

copy_code:
%ifdef ASSUME_ZERO_REGISTERS
    mov cx, 1024
%else
    mov ds, di 
    ;push cs
    ;pop ds ;set ds to 0
    mov ch, 4 ;sets CX to 0x400, or 1024
%endif

mov si, begin_code
%ifdef ASSUME_ZERO_REGISTERS
    mov bh, 0x10 ;seg_compiler_code is 0x1000
    mov es, bx
%else
    push seg_compiler_code
    pop es
%endif
mov di, es ;copy compiler code to 0x1000, same as seg_compiler_code
%ifdef USE_FAR_CALL_JMP
    push di
    push di ;later is used by retf to far call to compiler code
%endif
.zero_memory
;zeros all memmory so that the .bss section can be safely assumed to be 0
;save cx and di so we can use them later
pusha
%ifndef ASSUME_ZERO_REGISTERS
    mov al, 0
%endif
rep stosb
popa
.copy_boot_code:
rep movsb

%ifdef USE_FAR_CALL_JMP
    retf
%else
    jmp 0x1000:0x1000 ;far jmp to where begin_code *should* be executed from
%endif
begin_code:
incbin "compiler.bin"

seg_compiler_code equ 0x1000
seg_stack equ 0x8000