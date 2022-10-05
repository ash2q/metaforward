; Macros to turn features on and off

; %define ACCEPT_UPPER_CASE ;costs 12 bytes of ROM

;assumes registers are 0 at boot (with the exception of DX, CS, IP)
;saves about 4 bytes
;%define ASSUME_ZERO_REGISTERS 

;do not change stack location (note: this may not really be possible to get away with!)
;saves 8 bytes
%define USE_DEFAULT_CALL_STACK

;provide error messages, otherwise errors are ignored
;uses (so far) 8 bytes
%define PROVIDE_ERRORS
