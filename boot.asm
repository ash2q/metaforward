[CPU 586]
[BITS 16]
[ORG 0x7C00]

%include "options.asm"

init:
cld
%ifndef USE_DEFAULT_CALL_STACK
mov sp, seg_stack ;this should be safe to use temporarily and thus not require cli
mov ss, sp
;seg_stack is 0x8000
;setup stack to somewhere a bit more roomy (can potentially be eliminated if space is needed)
;because of excessive pusha/popa usage to save space, the stack may be unexpectedly large
%endif

%ifndef ASSUME_ZERO_REGISTERS
mov ax, 0
;mov bx, ax
;mov cx, ax
;mov di, ax
;mov si, ax
%endif

copy_code:
mov cx, sp ;it's perfectly ok to clear 0x8000 bytes, even if unnecessary

mov si, begin_code
push seg_compiler_code
pop es
mov di, es ;copy compiler code to 0x1000:0x1000, same as seg_compiler_code
mov [ss:di], dl ;save dx to 0x8000:0x1000. 
%ifdef USE_FAR_CALL_JMP
    push di
    push di ;later is used by retf to far call to compiler code
%endif

.zero_memory
;zeros all memmory so that the .bss section can be safely assumed to be 0
;save cx and di so we can use them later
pusha
;ax should still be zero from init
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