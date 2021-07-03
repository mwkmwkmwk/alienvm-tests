all: hello.bin rot13.bin block.bin rc4.bin sha512.bin

hello.bin: hello.asm
	nasm -fbin hello.asm -o hello.bin

rot13.bin: rot13.asm
	nasm -fbin rot13.asm -o rot13.bin

block.bin: block.asm
	nasm -fbin block.asm -o block.bin

rc4.bin: rc4.asm
	nasm -fbin rc4.asm -o rc4.bin

sha512.bin: sha512.asm
	nasm -fbin sha512.asm -o sha512.bin

clean:
	rm -f hello.bin rot13.bin block.bin rc4.bin sha512.bin
