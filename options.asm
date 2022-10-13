; Macros to turn features on and off

; %define ACCEPT_UPPER_CASE ;costs 12 bytes of ROM

;assumes registers are 0 at boot (with the exception of DX, CS, IP)
;saves about 3 bytes
;%define ASSUME_ZERO_REGISTERS 

;do not change stack location (note: this may not really be possible to get away with!)
;saves 8 bytes
;%define USE_DEFAULT_CALL_STACK

;provide error messages, otherwise errors are ignored
;uses (so far) 4 bytes
%define PROVIDE_ERRORS

;uses far call instead of far jmp to enter compiler code
;Note that there is no sensible reason to retf back to the bootloader code
;This saves 2 bytes
%define USE_FAR_CALL_JMP

;include the keyword for generating function calls
;costs 36 bytes 
;%define SUPPORT_KEYWORD_CALL

;prints greeting of "MF" when starting metaforward
;costs 12 bytes
%define PRINT_GREETING


;adds buffer overflow checking to get_string function in console
;costs 12 bytes
;%define CHECK_OVERFLOW_GET_STRING


;prints size of function once the function is ended using ';'
;uses 24 bytes
;%define PRINT_FUNCTION_SIZE

;Includes the print_string function
;This only matters for API and meta reasons
;uses 8 bytes
;%define INCLUDE_PRINT_STRING

;Makes the console prompt "> " instead of just ">"
;Uses 5 bytes. Has no effect if INCLUDE_PRINT_STRING is defined
%define EXTENDED_PROMPT

