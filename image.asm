bootsector:
incbin "boot.bin"
TIMES 510 - ($ - $$) db 0	;fill the rest of sector with 0
DW 0xAA55			; add boot signature at the end of bootloader


; pad out to 1.44Mb
TIMES 1474560 - ($ - $$) db 0	;fill the rest of image with 0