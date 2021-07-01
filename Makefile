all: hello.bin rot13.bin block.bin rc4.bin

hello.bin: hello.asm
	nasm -fbin hello.asm -o hello.bin

rot13.bin: rot13.asm
	nasm -fbin rot13.asm -o rot13.bin

block.bin: block.asm
	nasm -fbin block.asm -o block.bin

rc4.bin: rc4.asm
	nasm -fbin rc4.asm -o rc4.bin

clean:
	rm -f hello.bin rot13.bin block.bin
