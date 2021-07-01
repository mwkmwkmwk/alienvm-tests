bits 32
org 0xffff0000

;;;; constants

desc_so equ 0x100000
desc_si equ 0x101000
buf_si equ 0x102000
v_state equ 0x103000
v_gotkey equ 0x103100

;;;; main

base:

start32:
mov esp, 0x1000000
mov [v_gotkey], byte 0
call setup_apic
call setup_so
call setup_si

wait_for_key:
cli
cmp [v_gotkey], byte 0
jnz init_rc4
sti
hlt
jmp wait_for_key

init_rc4:
sti
xor eax, eax
xor ecx, ecx
.init_loop:
mov [v_state+eax], al
inc al
jnz .init_loop
.init_loop2:
add cl, [v_state+eax]
mov edx, eax
and edx, 0xf
add cl, [buf_si+edx]
mov dl, [v_state+eax]
mov bl, [v_state+ecx]
mov [v_state+eax], bl
mov [v_state+ecx], dl
inc al
jnz .init_loop2

; main loop time!
xor eax, eax
xor ecx, ecx
xor edx, edx
xor edi, edi
xor esi, esi
main:
inc al
add cl, [v_state+eax]
mov dl, [v_state+eax]
mov bl, [v_state+ecx]
mov [v_state+eax], bl
mov [v_state+ecx], dl
add dl, bl
mov bl, [v_state+edx]
mov [edi], bl
inc edi
and edi, 0xfffff
cmp edi, esi
jz .wait
.maybe_kick:
test edi, 0xffff
jnz main
; if low bits 0, kick
mov [desc_so+0x800], edi
mov [0xe0000008], eax
jmp main

.wait:
cli
mov esi, [desc_so+0xc00]
cmp edi, esi
jz .really_wait
sti
jmp .maybe_kick

.really_wait:
sti
hlt
jmp .wait

jmp main

;;;; setup functions

setup_apic:
; disable PIC
mov al, 0xff
out 0x21, al
out 0xa1, al
; enable local APIC
mov [0xfee000f0], dword 0x12f
; set up IOAPIC vectors for input 3 & 4
mov [0xfec00000], dword 0x16
mov [0xfec00010], dword 0x00000020
mov [0xfec00000], dword 0x17
mov [0xfec00010], dword 0
mov [0xfec00000], dword 0x18
mov [0xfec00010], dword 0x00000021
mov [0xfec00000], dword 0x19
mov [0xfec00010], dword 0
ret

setup_so:
mov eax, desc_so
mov [eax+0x800], dword 0
mov [eax+0xc00], dword 0
mov [0xe0000000], eax
mov ecx, 0
.loop:
mov [eax], ecx
add eax, 4
add ecx, 0x1000
cmp ecx, 0x100000
jnz .loop
mov [0xe0000004], dword 0xff01
ret

setup_si:
mov eax, desc_si
mov [eax], dword buf_si
mov [eax+0x800], dword 0
mov [eax+0xc00], dword 0
mov [0xe0001000], eax
mov [0xe0001004], dword 1
ret

;;;; irq handlers

so_handler:
mov [0xfee000b0], dword 0
iret

si_handler:
push eax
mov eax, [desc_si+0xc00]
cmp eax, 16
ja .shutdown
setnc al
mov [v_gotkey], al
pop eax
mov [0xfee000b0], dword 0
iret

.shutdown:
xor al, al
mov dx, 0x900
out dx, al
jmp .shutdown

sp_handler:
iret

;;;; gdt + idt

align 8
gdtp:
dw 0x17
dd gdt

align 8
idtp:
dw 0x17f
dd idt

align 8
gdt:
dq 0
dq 0x00cf9b000000ffff
dq 0x00cf93000000ffff

align 8
idt:
times 0x20 dq 0
dq 0xffff8e0000080000 + (so_handler - base)
dq 0xffff8e0000080000 + (si_handler - base)
times 0xd dq 0
dq 0xffff8e0000080000 + (sp_handler - base)

;;;; 16-bit setup code

bits 16

setup16:
o32 lgdt [cs:(gdtp-base)]
o32 lidt [cs:(idtp-base)]
mov ax, 0x10
mov ss, ax
mov es, ax
mov ds, ax
xor ax, ax
mov fs, ax
mov gs, ax
jmp 0x08:dword start32

times 0xfff0-($-base) db 0

reset:
mov eax, 0x31
mov cr0, eax
jmp setup16

times 0x10000-($-base) db 0
