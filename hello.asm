bits 16

base:

db "Hello, world!", 10
hello_end:

times 0xfff0-($-base) db 0

reset:
xor si, si
mov cx, hello_end
mov dx, 0x800
cs rep outsb
mov dh, 9
mov al, 42
out dx, al
