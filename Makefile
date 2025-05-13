FILES = ./build/kernel.asm.o ./build/kernel.o
FLAGS = -g -ffreestanding -nostdlib -nostartfiles -nodefaultlibs -Wall -O0 -Iinc

all:
	nasm -f bin ./src/bootloader/boot.asm -o ./build/boot.bin
	nasm -f elf -g ./src/kernel/kernel.asm -o ./build/kernel.asm.o
	i686-elf-gcc -I./src $(FLAGS) -std=gnu99 -c ./src/kernel/kernel.c -o ./build/kernel.o
	i686-elf-ld -g -relocatable $(FILES) -o ./build/main.o
	i686-elf-gcc $(FLAGS) -T ./src/kernel/linker.ld -o ./build/kernel.bin -ffreestanding -O0 -nostdlib ./build/main.o
	
	dd if=./build/boot.bin >> ./build/main_os.bin
	dd if=./build/kernel.bin >> ./build/main_os.bin
	dd if=/dev/zero bs=512 count=8 >> ./build/main_os.bin

run:
	qemu-system-x86_64 -hda ./build/main_os.bin

debug:
	bochs -f bochs_config -debugger

clean:
	rm -rf build/*
