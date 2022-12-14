default:
	yasm compiler.asm -o compiler.bin -l compiler.list.asm
	yasm boot.asm -o boot.bin -l boot.list.asm
	yasm strap.asm -o strap.bin -l strap.list.asm -o strap.bin
	yasm image.asm -o image.img
	echo ""
	@./print_size.sh boot.bin

run: default
	echo "Reminder: use 'ctrl-a x' to exit"
	qemu-system-i386 -display curses -drive file=image.img,index=0,if=floppy,format=raw -nographic

run-graphical: default
	qemu-system-i386 -drive file=image.img,index=0,if=floppy,format=raw

run-graphical-debug: default
	qemu-system-i386 -drive file=image.img,index=0,if=floppy,format=raw -s -S