; virtual map
; 0x00000000 -> 0x00000000 [4kiB]: trampoline
; 0xffffffffc0400000 -> 0xffff0000 [64kiB]: BIOS
; 0xffffffffc05ff000 -> 0x00000000 [4kiB]: stack [repurposed from trampoline page]
; 0xffffffffe0000000 -> 0xe0000000 [12kiB]: devices
; 0xfffffffffec00000 -> 0xfec00000 [4kiB]: IO-APIC
; 0xfffffffffee00000 -> 0xfee00000 [4kiB]: APIC
; 0xffffffffff000000 -> 0x00000000 [16MiB]: RAM

; physical map [the fixed part]
; 0x00000000: trampoline
; 0x00001000: l4 page table
; 0x00002000: l3 page table [addr 0]
; 0x00003000: l2 page table [addr 0]
; 0x00004000: l1 page table [addr 0]
; 0x00005000: l3 page table [addr 0xffffff8000000000]
; 0x00006000: l2 page table [addr 0xffffffffc0000000]
; 0x00007000: l1 page table [addr 0xffffffffc0400000]

var_paddr  equ 0xffffffffc05ffff8
var_page   equ 0xffffffffc0600000
idt_page   equ 0xffffffffc0602000
desc_so    equ 0xffffffffc0800000
desc_block equ 0xffffffffc0802000
buf_so     equ 0xffffffffc0804000
buf_block  equ 0xffffffffc1800000

dev_so     equ 0xffffffffe0000000
dev_block  equ 0xffffffffe0002000
dev_ioapic equ 0xfffffffffec00000
dev_lapic  equ 0xfffffffffee00000

var_bcap   equ 0xffffffffc0600000
var_bdone  equ 0xffffffffc0600004
var_bput   equ 0xffffffffc0600008
var_bget   equ 0xffffffffc060000c

var_hstate equ 0xffffffffc0600040
var_padb   equ 0xffffffffc0600080
var_hashw  equ 0xffffffffc0600100

org 0xffffffffc0400000
bits 64
base:

;;;; 64-bit entry point

start64:
; load proper gdt + idt
lgdt [gdtp]
lidt [idtp]

; initialize stack and data
mov rsp, var_paddr
mov [rsp], dword 0xfff000

; kill trampoline page
mov qword [0xffffffffff004000], 0
invlpg [0]

; map devices
mov rdi, 0xfffffffffee00000
mov rsi, 0xfee00000
call map_virt
mov rdi, 0xfffffffffec00000
mov rsi, 0xfec00000
call map_virt
mov rdi, 0xffffffffe0000000
mov rsi, 0xe0000000
call map_virt
mov rdi, 0xffffffffe0001000
mov rsi, 0xe0001000
call map_virt
mov rdi, 0xffffffffe0002000
mov rsi, 0xe0002000
call map_virt

; alloc variables
mov rdi, var_page
call alloc_virt

; alloc idt
mov rdi, idt_page
call alloc_virt
xor rax, rax
mov rcx, 0x200
rep stosq

; initialize SO
mov rdi, desc_so
call alloc_virt
mov [desc_so+0x800], dword 0
mov [desc_so+0xc00], dword 0
mov [dev_so], eax
mov rdi, buf_so
call alloc_virt
mov [desc_so], eax
mov [dev_so+4], dword 0x0001

; initialize blockdev
mov rdi, desc_block
call alloc_virt
mov [desc_block+0x800], dword 0
mov [desc_block+0xc00], dword 0
mov [dev_block], eax
mov r12, desc_block
mov rdi, buf_block
.fill_blocks:
call alloc_virt
mov [r12], eax
add rdi, 0x1000
add r12, 0x10
cmp r12, desc_block+0x800
jnz .fill_blocks
mov [dev_block+4], dword 0x7f01

mov eax, [dev_block+0xc]
mov [var_bcap], eax
mov dword [var_bput], 0
mov dword [var_bget], 0

; initialize idt
mov rdi, 0xf0
mov rsi, so_handler
call fill_idt_irq
mov rdi, 0xf1
mov rsi, block_handler
call fill_idt_irq
mov rdi, 0xff
mov rsi, spur_handler
call fill_idt_irq

; initialize interrupts
mov al, 0xff
out 0x21, al
out 0xa1, al
mov [dev_lapic+0xf0], dword 0x1ff
mov [dev_ioapic], dword 0x16
mov [dev_ioapic+0x10], dword 0xf0
mov [dev_ioapic], dword 0x17
mov [dev_ioapic+0x10], dword 0x0
mov [dev_ioapic], dword 0x1a
mov [dev_ioapic+0x10], dword 0xf1
mov [dev_ioapic], dword 0x1b
mov [dev_ioapic+0x10], dword 0x0
sti

; initialize hash
movdqa xmm0, [hash_init]
movdqa xmm1, [hash_init+0x10]
movdqa xmm2, [hash_init+0x20]
movdqa xmm3, [hash_init+0x30]
movdqa [var_hstate], xmm0
movdqa [var_hstate+0x10], xmm1
movdqa [var_hstate+0x20], xmm2
movdqa [var_hstate+0x30], xmm3

; main loop!
main:
; first, submit more requests
mov eax, [var_bdone]
add eax, 0x7f
mov ecx, [var_bput]
cmp ecx, [var_bcap]
jz .submit_nope
cmp ecx, eax
jz .submit_nope
.submit_loop:
mov edx, ecx
and edx, 0x7f
shl edx, 4
mov [desc_block+rdx+0x4], ecx
mov [desc_block+rdx+0x8], dword 0
mov [desc_block+rdx+0xc], dword 0xdead
add ecx, 1
cmp ecx, [var_bcap]
jz .submit_done
cmp ecx, eax
jnz .submit_loop
.submit_done:
mov [var_bput], ecx
and ecx, 0x7f
mov [desc_block+0x800], ecx
mov [dev_block+8], eax
.submit_nope:

; try to process some stuff
mov eax, [var_bdone]
cmp eax, [var_bget]
jnz .do_process
cmp eax, [var_bcap]
jz .done

; well then, wait.
.process_wait:
cli
cmp eax, [var_bget]
jnz .do_process_sti
sti
hlt
jmp .process_wait

.do_process_sti:
sti
.do_process:
and eax, 0x7f
shl eax, 4
cmp dword [desc_block+rax+0xc], 0
jnz .fail
shl eax, 8
lea rdi, [rax+buf_block]
.proc_loop:
call hash_block
add rdi, 0x80
test rdi, 0xfff
jnz .proc_loop
add dword [var_bdone], 1
jmp main

.fail:
mov dx, 0x900
mov al, 1
out dx, al
cli
hlt

.done:

; padding
mov rdi, var_padb
pxor xmm0, xmm0
mov eax, [var_bcap]
shl rax, 12+3
bswap rax
movdqa [rdi+0x00], xmm0
movdqa [rdi+0x10], xmm0
movdqa [rdi+0x20], xmm0
movdqa [rdi+0x30], xmm0
movdqa [rdi+0x40], xmm0
movdqa [rdi+0x50], xmm0
movdqa [rdi+0x60], xmm0
movdqa [rdi+0x70], xmm0
mov [rdi], byte 0x80
mov [rdi+0x78], rax
call hash_block

; finalize hash
mov r8, [var_hstate+0x00]
mov r9, [var_hstate+0x08]
mov r10, [var_hstate+0x10]
mov r11, [var_hstate+0x18]
mov r12, [var_hstate+0x20]
mov r13, [var_hstate+0x28]
mov r14, [var_hstate+0x30]
mov r15, [var_hstate+0x38]
bswap r8
bswap r9
bswap r10
bswap r11
bswap r12
bswap r13
bswap r14
bswap r15
mov [buf_so+0x00], r8
mov [buf_so+0x08], r9
mov [buf_so+0x10], r10
mov [buf_so+0x18], r11
mov [buf_so+0x20], r12
mov [buf_so+0x28], r13
mov [buf_so+0x30], r14
mov [buf_so+0x38], r15

; send it
mov [desc_so+0x800], dword 0x40
mov [dev_so+8], eax

wait_for_out:
hlt
jmp wait_for_out

;;;; hash stuff

hash_block:
mov r8, [rdi+0x00]
mov r9, [rdi+0x08]
mov r10, [rdi+0x10]
mov r11, [rdi+0x18]
mov r12, [rdi+0x20]
mov r13, [rdi+0x28]
mov r14, [rdi+0x30]
mov r15, [rdi+0x38]
bswap r8
bswap r9
bswap r10
bswap r11
bswap r12
bswap r13
bswap r14
bswap r15
mov [var_hashw+0x00], r8
mov [var_hashw+0x08], r9
mov [var_hashw+0x10], r10
mov [var_hashw+0x18], r11
mov [var_hashw+0x20], r12
mov [var_hashw+0x28], r13
mov [var_hashw+0x30], r14
mov [var_hashw+0x38], r15
mov r8, [rdi+0x40]
mov r9, [rdi+0x48]
mov r10, [rdi+0x50]
mov r11, [rdi+0x58]
mov r12, [rdi+0x60]
mov r13, [rdi+0x68]
mov r14, [rdi+0x70]
mov r15, [rdi+0x78]
bswap r8
bswap r9
bswap r10
bswap r11
bswap r12
bswap r13
bswap r14
bswap r15
mov [var_hashw+0x40], r8
mov [var_hashw+0x48], r9
mov [var_hashw+0x50], r10
mov [var_hashw+0x58], r11
mov [var_hashw+0x60], r12
mov [var_hashw+0x68], r13
mov [var_hashw+0x70], r14
mov [var_hashw+0x78], r15

mov rcx, 0x10
movdqa xmm5, [var_hashw+0x70]
.expand:

movdqu xmm0, [var_hashw - 15*8 + rcx*8]
movdqa xmm10, [var_hashw - 16*8 + rcx*8]
movdqu xmm11, [var_hashw - 7*8 + rcx*8]
movdqa xmm1, xmm0
movdqa xmm2, xmm0
movdqa xmm3, xmm0
movdqa xmm4, xmm0
movdqa xmm6, xmm5
movdqa xmm7, xmm5
movdqa xmm8, xmm5
movdqa xmm9, xmm5
paddq xmm10, xmm11
; s0 := (w[i-15] rightrotate 1) xor (w[i-15] rightrotate 8) xor (w[i-15] rightshift 7)
psrlq xmm0, 1
psllq xmm1, 64-1
psrlq xmm2, 8
psllq xmm3, 64-8
psrlq xmm4, 7
; s1 := (w[i-2] rightrotate 19) xor (w[i-2] rightrotate 61) xor (w[i-2] rightshift 6)
psrlq xmm5, 19
psllq xmm6, 64-19
psrlq xmm7, 61
psllq xmm8, 64-61
psrlq xmm9, 6
por xmm0, xmm1
por xmm2, xmm3
por xmm5, xmm6
por xmm7, xmm8
pxor xmm0, xmm2
pxor xmm0, xmm4
pxor xmm5, xmm7
pxor xmm5, xmm9
paddq xmm0, xmm10
paddq xmm5, xmm0
movdqa [var_hashw + rcx*8], xmm5

add rcx, 2
cmp rcx, 0x50
jnz .expand


;mov rsi, var_hashw
;mov rcx, 0x280
;mov dx, 0x800
;rep outsb

mov r8, [var_hstate+0x00]
mov r9, [var_hstate+0x08]
mov r10, [var_hstate+0x10]
mov r11, [var_hstate+0x18]
mov r12, [var_hstate+0x20]
mov r13, [var_hstate+0x28]
mov r14, [var_hstate+0x30]
mov r15, [var_hstate+0x38]

xor rcx, rcx
.loop:

; S0 := (a rightrotate 28) xor (a rightrotate 34) xor (a rightrotate 39)
mov rax, r8
ror rax, 28
mov rdx, r8
ror rdx, 34
; S1 := (e rightrotate 14) xor (e rightrotate 18) xor (e rightrotate 41)
mov rsi, r12
ror rsi, 14
mov rbp, r12
ror rbp, 18
xor rax, rdx
xor rsi, rbp
mov rdx, r8
ror rdx, 39
mov rbp, r12
ror rbp, 41
xor rax, rdx
xor rsi, rbp

; temp1
add rsi, r15
add rsi, [hash_k + rcx * 8]
add rsi, [var_hashw + rcx * 8]
mov rdx, r12
and rdx, r13
mov rbx, r12
not rbx
and rbx, r14
xor rdx, rbx
add rsi, rdx

; temp2
mov rdx, r8
and rdx, r9
mov rbx, r8
and rbx, r10
mov rbp, r9
and rbp, r10
xor rdx, rbx
xor rdx, rbp
add rax, rdx

mov r15, r14
mov r14, r13
mov r13, r12
mov r12, r11
add r12, rsi
mov r11, r10
mov r10, r9
mov r9, r8
mov r8, rsi
add r8, rax

;push rsi
;push rcx
;push rdx
;push r15
;push r14
;push r13
;push r12
;push r11
;push r10
;push r9
;push r8
;mov rsi, rsp
;mov dx, 0x800
;mov rcx, 0x40
;rep outsb
;add rsp, 0x40
;pop rdx
;pop rcx
;pop rsi

add rcx, 1
cmp rcx, 0x50
jnz .loop

add [var_hstate+0x00], r8
add [var_hstate+0x08], r9
add [var_hstate+0x10], r10
add [var_hstate+0x18], r11
add [var_hstate+0x20], r12
add [var_hstate+0x28], r13
add [var_hstate+0x30], r14
add [var_hstate+0x38], r15
ret

align 0x10
hash_init:
dq 0x6a09e667f3bcc908, 0xbb67ae8584caa73b, 0x3c6ef372fe94f82b, 0xa54ff53a5f1d36f1, 0x510e527fade682d1, 0x9b05688c2b3e6c1f, 0x1f83d9abfb41bd6b, 0x5be0cd19137e2179
hash_k:
dq 0x428a2f98d728ae22, 0x7137449123ef65cd, 0xb5c0fbcfec4d3b2f, 0xe9b5dba58189dbbc, 0x3956c25bf348b538
dq 0x59f111f1b605d019, 0x923f82a4af194f9b, 0xab1c5ed5da6d8118, 0xd807aa98a3030242, 0x12835b0145706fbe
dq 0x243185be4ee4b28c, 0x550c7dc3d5ffb4e2, 0x72be5d74f27b896f, 0x80deb1fe3b1696b1, 0x9bdc06a725c71235
dq 0xc19bf174cf692694, 0xe49b69c19ef14ad2, 0xefbe4786384f25e3, 0x0fc19dc68b8cd5b5, 0x240ca1cc77ac9c65
dq 0x2de92c6f592b0275, 0x4a7484aa6ea6e483, 0x5cb0a9dcbd41fbd4, 0x76f988da831153b5, 0x983e5152ee66dfab
dq 0xa831c66d2db43210, 0xb00327c898fb213f, 0xbf597fc7beef0ee4, 0xc6e00bf33da88fc2, 0xd5a79147930aa725
dq 0x06ca6351e003826f, 0x142929670a0e6e70, 0x27b70a8546d22ffc, 0x2e1b21385c26c926, 0x4d2c6dfc5ac42aed
dq 0x53380d139d95b3df, 0x650a73548baf63de, 0x766a0abb3c77b2a8, 0x81c2c92e47edaee6, 0x92722c851482353b
dq 0xa2bfe8a14cf10364, 0xa81a664bbc423001, 0xc24b8b70d0f89791, 0xc76c51a30654be30, 0xd192e819d6ef5218
dq 0xd69906245565a910, 0xf40e35855771202a, 0x106aa07032bbd1b8, 0x19a4c116b8d2d0c8, 0x1e376c085141ab53
dq 0x2748774cdf8eeb99, 0x34b0bcb5e19b48a8, 0x391c0cb3c5c95a63, 0x4ed8aa4ae3418acb, 0x5b9cca4f7763e373
dq 0x682e6ff3d6b2b8a3, 0x748f82ee5defb2fc, 0x78a5636f43172f60, 0x84c87814a1f0ab72, 0x8cc702081a6439ec
dq 0x90befffa23631e28, 0xa4506cebde82bde9, 0xbef9a3f7b2c67915, 0xc67178f2e372532b, 0xca273eceea26619c
dq 0xd186b8c721c0c207, 0xeada7dd6cde0eb1e, 0xf57d4f7fee6ed178, 0x06f067aa72176fba, 0x0a637dc5a2c898a6
dq 0x113f9804bef90dae, 0x1b710b35131c471b, 0x28db77f523047d84, 0x32caab7b40c72493, 0x3c9ebe0a15c9bebc
dq 0x431d67c49c100d4c, 0x4cc5d4becb3e42b6, 0x597f299cfc657e2a, 0x5fcb6fab3ad6faec, 0x6c44198c4a475817

;;;; allocator + mapper

map_virt:
push rbx
mov rbx, cr3
and rbx, ~0xfff

mov rcx, rdi
shr rcx, 39
and rcx, 0x1ff
mov rax, [0xffffffffff000000+rbx+rcx*8]
test rax, rax
jnz .got_l3
call alloc_phys
or rax, 0x67
mov [0xffffffffff000000+rbx+rcx*8], rax
.got_l3:
mov rbx, rax
and rbx, ~0xfff

mov rcx, rdi
shr rcx, 30
and rcx, 0x1ff
mov rax, [0xffffffffff000000+rbx+rcx*8]
test rax, rax
jnz .got_l2
call alloc_phys
or rax, 0x67
mov [0xffffffffff000000+rbx+rcx*8], rax
.got_l2:
mov rbx, rax
and rbx, ~0xfff

mov rcx, rdi
shr rcx, 21
and rcx, 0x1ff
mov rax, [0xffffffffff000000+rbx+rcx*8]
test rax, 0x80
jnz .oops
test rax, rax
jnz .got_l1
call alloc_phys
or rax, 0x67
mov [0xffffffffff000000+rbx+rcx*8], rax
.got_l1:
mov rbx, rax
and rbx, ~0xfff

mov rcx, rdi
shr rcx, 12
and rcx, 0x1ff
lea rax, [rsi + 0x63]
mov [0xffffffffff000000+rbx+rcx*8], rax

pop rbx
ret

.oops:
ud2


alloc_phys:
mov rax, [var_paddr]
add qword [var_paddr], -0x1000
ret

alloc_virt:
call alloc_phys
mov rsi, rax
call map_virt
mov rax, rsi
ret

fill_idt_irq:
shl rdi, 4
mov rax, rsi
shr rax, 32
mov [idt_page+rdi+8], rax
mov rax, rsi
and rax, ~0xffff
or rax, 0x8e00
shl rax, 32
or rax, 0x00080000
mov rdx, rsi
and rdx, 0xffff
or rax, rdx
mov [idt_page+rdi], rax
ret

;;;; handlers

spur_handler:
iretq

so_handler:
cmp [desc_so+0xc00], dword 0x40
jz .shutdown
mov [dev_lapic+0xb0], dword 0
iretq

.shutdown:
mov dx, 0x900
mov al, 0
out dx, al
hlt

block_handler:
push rax
mov eax, [desc_block+0xc00]
sub eax, [var_bget]
and eax, 0x7f
add [var_bget], eax
pop rax
mov [dev_lapic+0xb0], dword 0
iretq

;;;; GDT

align 8
gdt:
dq 0
dq 0x00af9b000000ffff

align 8
gdtp:
dw 0xf
dq gdt

align 8
idtp:
dw 0xfff
dq idt_page

align 8
tgdtp:
dw 0xf
dd 0x80

;;;; 16-bit setup

bits 16
setup16:

; clear first 0x8000 bytes of RAM
xor di, di
mov es, di
mov ds, di
mov cx, 0x2000
xor eax, eax
rep stosd

; set up page tables
mov [0x1000], dword 0x2067
mov [0x1004], dword 0
mov [0x2000], dword 0x3067
mov [0x2004], dword 0
mov [0x3000], dword 0x4067
mov [0x3004], dword 0
mov [0x4000], dword 0x0061
mov [0x4004], dword 0

mov [0x1ff8], dword 0x5067
mov [0x1ffc], dword 0

mov [0x5ff8], dword 0x6067
mov [0x5ffc], dword 0

mov [0x6010], dword 0x7067
mov [0x6014], dword 0

mov [0x7ff8], dword 0x0063
mov [0x7ffc], dword 0

mov cx, 0x10
mov di, 0x7000
mov eax, 0xffff0063
.rom_pgt:
mov [di], eax
mov [di+4], dword 0
add eax, 0x1000
add di, 8
loop .rom_pgt

mov cx, 8
mov di, 0x6fc0
mov eax, 0x000000e3
.ram_pgt:
mov [di], eax
mov [di+4], dword 0
add eax, 0x200000
add di, 8
loop .ram_pgt

; set up CRs
mov eax, 0x00001000
mov cr3, eax
mov eax, 0x00000220
mov cr4, eax
; set up EFER
mov ecx, 0xc0000080
xor edx, edx
mov eax, 0x00000100
wrmsr

; set up trampoline: 16-bit
mov [0], dword 0x66c0220f
mov [4], byte 0xea
mov [5], dword 0x10
mov [9], word 0x8

; set up trampoline: 64-bit
mov [0x10], word 0xb848
mov [0x12], dword start64 - 0xffffffff00000000
mov [0x16], dword 0xffffffff
mov [0x1a], word 0xe0ff

; set up temp GDT
mov si, gdt
mov cx, 0x10
mov di, 0x80
cs rep movsb

; prep CR0 value
mov eax, 0x80000031

; jump to 64-bit mode
jmp 0:0

times 0xfff0-($-base) db 0

reset:
lgdt [cs:(tgdtp-base)]
jmp setup16

times 0x10000-($-base) db 0
