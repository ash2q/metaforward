default:
	yasm boot.asm -o boot.bin
	yasm image.asm -o image.img
	echo ""
	@./print_size.sh boot.bin

run: default
	echo "Reminder: use 'ctrl-a x' to exit"
	qemu-system-i386 -display curses -drive file=image.img,index=0,if=floppy,format=raw -nographic

run-graphical: default
	qemu-system-i386 -drive file=image.img,index=0,if=floppy,format=raw