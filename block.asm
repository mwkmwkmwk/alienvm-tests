bits 16
base:


align 8
rgdtp:
dw rgdt_end-rgdt-1
dd 0xffff0000 + rgdt

align 8
gdtp:
dw 0xff
dd 0x00ff0800

align 8
idtp:
dw 0x7ff
dd 0x00ff0000

align 8
rgdt:
dq 0
; 0x08: the code segment
dq 0xff009bff0000ffff
; 0x10: CPL 0 data and stack segment
dq 0x000093fe0000ffff
; 0x18: CPL 3 code segment
dq 0xff00fbff0000ffff
; 0x20: CPL 3 data and stack segment
dq 0x0000f3fb0000ffff
; 0x28: special cpu structs segment
dq 0x000093ff0000ffff
; 0x30: TSS
dq 0x000081ff0900002b
; 0x38: MMIO segment
dq 0xe000930000002fff
; 0x40: serial output ring
dq 0x000093fc0000ffff
; 0x48: serial input ring
dq 0x000093fd0000ffff
; 0x53: syscall debug
dq 0x0000e40000080000 + (syscall_debug - base)
; 0x5b: syscall shutdown
dq 0x0000e40000080000 + (syscall_shutdown - base)
; 0x63: syscall read
dq 0x0000e40000080000 + (syscall_read - base)
; 0x6b: syscall write
dq 0x0000e40000080000 + (syscall_write - base)
; 0x73: syscall bread
dq 0x0000e40000080000 + (syscall_bread - base)
; 0x7b: syscall bwrite
dq 0x0000e40000080000 + (syscall_bwrite - base)
; 0x83: syscall bcapacity
dq 0x0000e40000080000 + (syscall_bcapacity - base)
rgdt_end:


init:
jmp 8:init_newcs
init_newcs:
mov ax, 0x10
mov ss, ax
xor sp, sp

; set up the cpu struct segment
mov ax, 0x28
mov es, ax
mov di, 0
mov cx, 0xa00
xor al, al
rep stosb
mov si, rgdt
mov cx, rgdt_end-rgdt
mov di, 0x800
cs rep movsb
; TSS ss0
mov [es:0x904], word 0x10
lgdt [cs:gdtp-base]
lidt [cs:idtp-base]
mov ax, 0x30
ltr ax

; set up the descriptors

mov cx, 0x10
mov bp, 0
mov ax, 0
setup_serial:
mov [bp], ax
mov [bp+2], word 0xfc
mov [bp+0x1000], ax
mov [bp+0x1002], word 0xfd
add ax, 0x1000
add bp, 4
loop setup_serial
mov [ss:0x800], word 0
mov [ss:0x802], word 0
mov [ss:0xc00], word 0
mov [ss:0xc02], word 0
mov [ss:0x1800], word 0
mov [ss:0x1802], word 0
mov [ss:0x1c00], word 0
mov [ss:0x1c02], word 0
mov [ss:0x2800], word 0
mov [ss:0x2802], word 0
mov [ss:0x2c00], word 0
mov [ss:0x2c02], word 0

mov ax, 0x38
mov ds, ax
mov dword [0x0000], 0xfe0000
mov dword [0x0004], 0xf01
mov dword [0x1000], 0xfe1000
mov dword [0x1004], 0xf01
mov dword [0x2000], 0xfe2000
mov dword [0x2004], 0x3f01

; setup int handlers

mov [es:0x118], word handle_irq
mov [es:0x11a], word 0x8
mov [es:0x11c], word 0x8600
mov [es:0x120], word handle_irq
mov [es:0x122], word 0x8
mov [es:0x124], word 0x8600
mov [es:0x128], word handle_irq
mov [es:0x12a], word 0x8
mov [es:0x12c], word 0x8600
mov [es:0x138], word handle_spurious
mov [es:0x13a], word 0x8
mov [es:0x13c], word 0x8600
mov [es:0x178], word handle_spurious
mov [es:0x17a], word 0x8
mov [es:0x17c], word 0x8600

; setup PIC

mov al, 0x11
out 0x20, al
out 0xa0, al
mov al, 0x20
out 0x21, al
mov al, 0x28
out 0xa1, al
mov al, 0x04
out 0x21, al
mov al, 0x02
out 0xa1, al
mov al, 0x01
out 0x21, al
out 0xa1, al

mov al, 0xc7
out 0x21, al
mov al, 0xff
out 0xa1, al

; start user

push word 0x23
push word 0
push word 0x0202
push word 0x1b
push word user_start
iret


;;;;;; irq handlers

; yep, do nothing; mere fact of interrupting hlt is enough
handle_irq:
push ax
mov al, 0x20
out 0x20, al
pop ax
iret

handle_spurious:
iret


;;;;;; syscall handlers

; i: ds:si buffer
; i: cx count
syscall_debug:
push dx
mov dx, 0x800
rep outsb
pop dx
retf

; i: es:di destination
; i: cx count
syscall_read:
push ds
push si
push di
push ax
push cx
jcxz sys_read_out
sys_read_again:
mov si, 0x48
mov ds, si
mov si, [ss:0x1800]
mov ax, [ss:0x1c00]
cmp si, ax
jz sys_read_sleep
sys_read_do:

push cx
sub ax, si
cmp cx, ax
jc sys_read_cx_ok
mov cx, ax
sys_read_cx_ok:
mov ax, cx
rep movsb
pop cx
mov [ss:0x1800], si
mov si, 0x38
mov ds, si
mov [0x1008], eax
sub cx, ax
jnz sys_read_again

sys_read_out:
pop cx
pop ax
pop di
pop si
pop ds
retf

sys_read_do_sleep:
sti
hlt
sys_read_sleep:
cli
mov ax, [ss:0x1c00]
cmp si, ax
jz sys_read_do_sleep
sti
jmp sys_read_do


; i: ds:si source
; i: cx count
syscall_write:
push es
push si
push di
push ax
push cx
jcxz sys_write_out
sys_write_again:
mov di, 0x40
mov es, di
mov di, [ss:0x0800]
mov ax, [ss:0x0c00]
dec ax
cmp di, ax
jz sys_write_sleep
sys_write_do:

push cx
sub ax, di
cmp cx, ax
jc sys_write_cx_ok
mov cx, ax
sys_write_cx_ok:
mov ax, cx
rep movsb
pop cx
mov [ss:0x0800], di
mov di, 0x38
mov es, di
mov [es:0x0008], eax
sub cx, ax
jnz sys_write_again

sys_write_out:
pop cx
pop ax
pop di
pop si
pop es
retf

sys_write_do_sleep:
sti
hlt
sys_write_sleep:
cli
mov ax, [ss:0x0c00]
dec ax
cmp di, ax
jz sys_write_do_sleep
sti
jmp sys_write_do




sys_brd_ret0:
xor ax, ax
retf

; i: es:di destination
; i: dx:ax block idx
; i: cx count
; o: ax status
syscall_bread:
cmp cx, 0xf
ja einval
test di, 0xfff
jnz einval
jcxz sys_brd_ret0
push ax
mov ax, es
cmp ax, 0x23
pop ax
jnz einval

push bp
push di
push dx
push cx
push ds

mov bp, [ss:0x2800]
shl bp, 4
push cx
push bp
sys_brd_put_req:
mov [bp+0x2000], di
mov [bp+0x2002], word 0xfb
mov [bp+0x2004], ax
mov [bp+0x2006], dx
mov [bp+0x2008], word 0
mov [bp+0x200a], word 0
mov [bp+0x200c], word 0xdead
add bp, 0x10
and bp, 0xf0
add di, 0x1000
add ax, 1
adc dx, 0
loop sys_brd_put_req
shr bp, 4
mov [ss:0x2800], bp

mov ax, 0x38
mov ds, ax
mov [ds:0x2008], eax

sys_brd_wait:
cli
mov ax, [ss:0x2c00]
cmp ax, bp
jz sys_brd_wait_done
sti
hlt
jmp sys_brd_wait
sys_brd_wait_done:
sti

pop bp
pop cx

sys_brd_get_req:
mov ax, [bp+0x200c]
test ax, ax
jnz sys_brd_err
add bp, 0x10
and bp, 0xf0
loop sys_brd_get_req
sys_brd_err:

pop ds
pop cx
pop dx
pop di
pop bp
retf




sys_bwr_ret0:
xor ax, ax
retf

; i: ds:si source
; i: dx:ax block idx
; i: cx count
; o: ax status
syscall_bwrite:
cmp cx, 0xf
ja einval
test si, 0xfff
jnz einval
jcxz sys_bwr_ret0
push ax
mov ax, ds
cmp ax, 0x23
pop ax
jnz einval

push bp
push si
push dx
push cx
push ds

mov bp, [ss:0x2800]
shl bp, 4
push cx
push bp
sys_bwr_put_req:
mov [bp+0x2000], si
mov [bp+0x2002], word 0xfb
mov [bp+0x2004], ax
mov [bp+0x2006], dx
mov [bp+0x2008], word 1
mov [bp+0x200a], word 0
mov [bp+0x200c], word 0xdead
add bp, 0x10
and bp, 0xf0
add si, 0x1000
add ax, 1
adc dx, 0
loop sys_bwr_put_req
shr bp, 4
mov [ss:0x2800], bp

mov ax, 0x38
mov ds, ax
mov [ds:0x2008], eax

sys_bwr_wait:
cli
mov ax, [ss:0x2c00]
cmp ax, bp
jz sys_bwr_wait_done
sti
hlt
jmp sys_bwr_wait
sys_bwr_wait_done:
sti

pop bp
pop cx

sys_bwr_get_req:
mov ax, [bp+0x200c]
test ax, ax
jnz sys_bwr_err
add bp, 0x10
and bp, 0xf0
loop sys_bwr_get_req
sys_bwr_err:

pop ds
pop cx
pop dx
pop si
pop bp
retf

einval:
int 0x1f
retf

; i: al status
syscall_shutdown:
push ax
cli
mov ax, [ss:0x0800]
shutdown_flush:
cmp ax, [ss:0x0c00]
jz shutdown_flush_done
sti
hlt
cli
jmp shutdown_flush
shutdown_flush_done:
pop ax

mov dx, 0x900
out dx, al
mov dx, 0x800
oops:
mov al, 'O'
out dx, al
mov al, 'o'
out dx, al
mov al, 'p'
out dx, al
mov al, 's'
out dx, al
mov al, 10
out dx, al
jmp oops

; o: dx:ax capacity
syscall_bcapacity:
push ds
mov ax, 0x38
mov ds, ax
mov eax, [0x200c]
mov edx, eax
shr edx, 16
pop ds
retf


;;;;;; user code

user_start:
mov ax, ss
mov es, ax
mov ds, ax

read_cmd:
mov di, 0
mov cx, 1
call 0x63:0
mov al, [di]
cmp al, ' '
jz read_cmd
cmp al, 9
jz read_cmd
cmp al, 10
jz read_cmd
cmp al, 'r'
jz cmd_r
cmp al, 'w'
jz cmd_w
cmp al, 's'
jz cmd_s
cmp al, 'd'
jz cmd_d
cmp al, 'e'
jz cmd_e
cmp al, 'c'
jz cmd_c

unk_cmd:
mov ax, cs
mov ds, ax
mov si, str_cmd_err
mov cx, str_cmd_err_e-str_cmd_err
call 0x53:0
mov ax, ss
mov ds, ax
cmp [0], byte 10
jz read_cmd
skip_until_nl:
mov di, 0
mov cx, 1
call 0x63:0
skip_until_nl_gn:
cmp [di], byte 10
jnz skip_until_nl
jmp read_cmd

mal_cmd:
mov ax, cs
mov ds, ax
mov si, str_cmd_mal
mov cx, str_cmd_mal_e-str_cmd_mal
call 0x53:0
mov ax, ss
mov ds, ax
jmp skip_until_nl

cmd_r:
mov di, 0
mov cx, 1
call 0x63:0
cmp [di], byte ' '
jnz unk_cmd

call getnum
jc skip_until_nl_gn
push ax
push dx
call getnum
mov cx, ax
mov bx, dx
pop dx
pop ax
jc skip_until_nl_gn
test bx, bx
jnz num_big

call end_cmdln_gn
jc mal_cmd

test cx, cx
jz read_cmd

cmd_r_loop:
push cx
push dx
push ax
cmp cx, 8
jc cmd_r_nofix
mov cx, 8
cmd_r_nofix:
xor di, di
call 0x73:0
test ax, ax
jnz cmd_r_err

push cx
mov si, 0

cmd_r_cvt_loop:
push cx
push si
mov cx, cs
mov ds, cx
mov si, str_ok
mov cx, str_ok_e-str_ok
call 0x6b:0
mov cx, ss
mov ds, cx
pop si

mov di, 0x8000
mov cx, 0x1000
mov bx, xlat_tonum
cmd_r_cvt_subloop:
lodsb
mov ah, al
shr al, 4
cs xlat
stosb
mov al, ah
and al, 0xf
cs xlat
stosb
loop cmd_r_cvt_subloop
mov al, 10
stosb

push si
mov si, 0x8000
mov cx, 0x2001
call 0x6b:0
pop si

pop cx
loop cmd_r_cvt_loop

pop bx
pop ax
pop dx
pop cx
add ax, bx
adc dx, 0
sub cx, bx
jnz cmd_r_loop
jmp read_cmd

cmd_r_err:
cmp ax, 1
jz cmd_r_oob
mov dx, cs
mov ds, dx
mov si, str_err
mov cx, str_err_e-str_err
call 0x6b:0
mov dx, ss
mov ds, dx
xor dx, dx
call printnum
mov si, 0
mov [si], byte 10
mov cx, 1
call 0x6b:0
pop ax
pop dx
pop cx
jmp read_cmd

cmd_r_oob:
mov dx, cs
mov ds, dx
mov si, str_oob
mov cx, str_oob_e-str_oob
call 0x6b:0
mov dx, ss
mov ds, dx
pop ax
pop dx
pop cx
jmp read_cmd


cmd_w:
mov di, 0
mov cx, 1
call 0x63:0
cmp [di], byte ' '
jnz unk_cmd


call getnum
jc skip_until_nl_gn
push ax
push dx
call getnum
mov cx, ax
mov bx, dx
pop dx
pop ax
jc skip_until_nl_gn
test bx, bx
jnz num_big

call end_cmdln_gn
jc mal_cmd

test cx, cx
jz read_cmd

cmd_w_loop:
push cx
push dx
push ax
cmp cx, 8
jc cmd_w_nofix
mov cx, 8
cmd_w_nofix:

push cx
mov di, 0

cmd_w_cvt_loop:
push cx

push di
mov di, 0x8000
mov cx, 0x2001
call 0x63:0
pop di

mov si, 0x8000
mov cx, 0x1000
mov bx, xlat_num
cmd_w_cvt_subloop:
lodsb
cs xlat
cmp al, 0xff
jz cmd_w_invblk
mov ah, al
lodsb
cs xlat
cmp al, 0xff
jz cmd_w_invblk
shl ah, 4
or al, ah
stosb
loop cmd_w_cvt_subloop
lodsb
cmp al, 10
jnz cmd_w_invblk

pop cx
loop cmd_w_cvt_loop

pop cx
pop ax
pop dx
push dx
push ax
xor si, si
call 0x7b:0
test ax, ax
jnz cmd_w_err
mov bx, cx

pop ax
pop dx
pop cx
add ax, bx
adc dx, 0
sub cx, bx
jnz cmd_w_loop
jmp read_cmd

cmd_w_err:
cmp ax, 1
jz cmd_w_oob
mov dx, cs
mov ds, dx
mov si, str_err
mov cx, str_err_e-str_err
call 0x6b:0
mov dx, ss
mov ds, dx
xor dx, dx
call printnum
mov si, 0
mov [si], byte 10
mov cx, 1
call 0x6b:0
pop ax
pop dx
pop cx
jmp read_cmd

cmd_w_oob:
mov dx, cs
mov ds, dx
mov si, str_oob
mov cx, str_oob_e-str_oob
call 0x6b:0
mov dx, ss
mov ds, dx
pop ax
pop dx
pop cx
jmp read_cmd

cmd_w_invblk:
mov dx, cs
mov ds, dx
mov si, str_invblk
mov cx, str_invblk_e-str_invblk
call 0x6b:0
mov dx, ss
mov ds, dx
add sp, 0xa
jmp read_cmd

cmd_s:
mov di, 0
mov cx, 1
call 0x63:0
cmp [di], byte ' '
jnz unk_cmd

call getnum
jc skip_until_nl_gn
test dx, dx
jnz num_big
test ax, 0xff00
jnz num_big
call end_cmdln_gn
jc mal_cmd
call 0x5b:0


cmd_c:
mov di, 0
mov cx, 1
call 0x63:0
cmp [di], byte 10
jnz unk_cmd

call 0x83:0
call printnum
mov si, 0
mov [si], byte 10
mov cx, 1
call 0x6b:0
jmp read_cmd

cmd_d:
mov di, 0
mov cx, 1
call 0x63:0
cmp [di], byte ' '
jnz unk_cmd

cmd_d_loop:
mov di, 0
mov si, 0
mov cx, 1
call 0x63:0
call 0x53:0
cmp [di], byte 10
jnz cmd_d_loop
jmp read_cmd


cmd_e:
mov di, 0
mov cx, 1
call 0x63:0
cmp [di], byte ' '
jnz unk_cmd

cmd_e_loop:
mov di, 0
mov si, 0
mov cx, 1
call 0x63:0
call 0x6b:0
cmp [di], byte 10
jnz cmd_e_loop
jmp read_cmd


num_big:
mov ax, cs
mov ds, ax
mov si, str_num_big
mov cx, str_num_big_e-str_num_big
call 0x53:0
mov ax, ss
mov ds, ax
jmp skip_until_nl_gn


end_cmdln_gn:
push di
push cx
mov di, 0
mov cx, 1
cmp [di], byte 10
jz end_cmdln_ret
end_cmdln_check:
cmp [di], byte 9
jz end_cmdln_loop
cmp [di], byte ' '
jnz end_cmdln_fail
end_cmdln_loop:
call 0x63:0
cmp [di], byte 10
jnz end_cmdln_check
end_cmdln_ret:
pop cx
pop di
clc
ret

end_cmdln_fail:
pop cx
pop di
stc
ret


printnum:
mov cx, 8
mov di, 7
mov bx, xlat_tonum
std
printnum_l1:
push ax
and al, 0xf
cs xlat
stosb
pop ax
shr ax, 4
mov si, dx
shl si, 12
or ax, si
shr dx, 4
loop printnum_l1
cld
xor di, di
mov cx, 8
mov al, 0x30
repz scasb
jz printnum_0
mov si, di
dec si
inc cx
call 0x6b:0
ret

printnum_0:
mov si, 0
mov [si], byte 0x30
mov cx, 1
call 0x6b:0
ret


getnum:
mov di, 0
mov cx, 1
call 0x63:0
mov al, [di]
cmp al, ' '
jz getnum
cmp al, 9
jz getnum
mov bx, xlat_num
cs xlat
cmp al, 0xff
jz getnum_wc
xor ah, ah
xor dx, dx

getnum_loop:
push ax
mov di, 0
mov cx, 1
call 0x63:0
mov al, [di]
cmp al, ' '
jz getnum_end
cmp al, 9
jz getnum_end
cmp al, 10
jz getnum_end
mov bx, xlat_num
cs xlat
cmp al, 0xff
jz getnum_end_wc
xor ah, ah
pop cx
test dx, 0xf000
jnz getnum_big
shl dx, 4
mov bx, cx
shr bx, 12
or dx, bx
shl cx, 4
or ax, cx
jmp getnum_loop

getnum_end:
pop ax
clc
ret

getnum_end_wc:
pop ax
getnum_wc:
mov ax, cs
mov ds, ax
mov si, str_num_inv
mov cx, str_num_inv_e-str_num_inv
call 0x53:0
mov ax, ss
mov ds, ax
stc
ret

getnum_big:
mov ax, cs
mov ds, ax
mov si, str_num_big
mov cx, str_num_big_e-str_num_big
call 0x53:0
mov ax, ss
mov ds, ax
stc
ret


str_cmd_err: db "unknown command", 10
str_cmd_err_e:

str_cmd_mal: db "too many arguments", 10
str_cmd_mal_e:

str_num_big: db "number too big", 10
str_num_big_e:

str_num_inv: db "invalid number", 10
str_num_inv_e:

str_err: db "io error "
str_err_e:

str_ok: db "ok "
str_ok_e:

str_oob: db "out of bounds error", 10
str_oob_e:

str_invblk: db "invalid block data", 10
str_invblk_e:

xlat_num:
times 0x30 db 0xff
db 0, 1, 2, 3, 4, 5, 6, 7, 8, 9
times 0x41-0x3a db 0xff
db 10, 11, 12, 13, 14, 15
times 0x61-0x47 db 0xff
db 10, 11, 12, 13, 14, 15
times 0x100-0x67 db 0xff

xlat_tonum:
db "0123456789abcdef"

;;;;;; reset vector

times 0xfff0-($-base) db 0

reset:
mov ax, 0x11
lmsw ax
o32 lgdt [cs:rgdtp-base]
jmp init
times 0x10000-($-base) db 0
