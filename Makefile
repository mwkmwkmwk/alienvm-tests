all: hello.bin rot13.bin block.bin

hello.bin: hello.asm
	nasm -fbin hello.asm -o hello.bin

rot13.bin: rot13.asm
	nasm -fbin rot13.asm -o rot13.bin

block.bin: block.asm
	nasm -fbin block.asm -o block.bin

clean:
	rm -f hello.bin rot13.bin block.bin
