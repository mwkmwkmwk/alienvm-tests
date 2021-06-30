import subprocess
import sys
import random
import os
import tempfile

NUM_RUNS = 100

def randbytes(num):
    try:
        return random.randbytes(num)
    except:
        return os.urandom(num)

def gen_test():
    num_cmd = random.randrange(0x20, 0x100)
    num_blocks = random.randrange(3, 0x1000)
    init_data = randbytes(num_blocks << 12)
    stdin = []
    stdout = []
    stderr = []
    data = bytearray(init_data)
    for _ in range(num_cmd):
        t = random.randrange(0x100)
        if t < 4:
            stdin.append(b'c\n')
            stdout.append(f'{num_blocks:x}\n'.encode())
        elif t < 0x10:
            l = random.randrange(0x10, 0x50)
            payload = bytes(random.randrange(0x20, 0x7f) for _ in range(l))
            stdin.append(b'd ' + payload + b'\n')
            stderr.append(payload + b'\n')
        elif t < 0x20:
            l = random.randrange(0x10, 0x50)
            payload = bytes(random.randrange(0x20, 0x7f) for _ in range(l))
            stdin.append(b'e ' + payload + b'\n')
            stdout.append(payload + b'\n')
        elif t < 0x80:
            block = random.randrange(num_blocks)
            cnt = random.randrange(1, 0x20)
            if block + cnt > num_blocks:
                cnt = num_blocks - block
            stdin.append(f'r {block:x} {cnt:x}\n'.encode())
            for i in range(block, block+cnt):
                bdata = data[i*0x1000:(i+1)*0x1000].hex()
                stdout.append(f'ok {bdata}\n'.encode())
        elif t < 0x90:
            block = random.randrange(num_blocks, 1 << 32)
            cnt = random.randrange(1, 0x20)
            stdin.append(f'r {block:x} {cnt:x}\n'.encode())
            stdout.append(b'out of bounds error\n')
        else:
            block = random.randrange(num_blocks)
            cnt = random.randrange(1, 0x20)
            if block + cnt > num_blocks:
                cnt = num_blocks - block
            stdin.append(f'w {block:x} {cnt:x}\n'.encode())
            for i in range(block, block+cnt):
                bdata = randbytes(0x1000)
                data[i*0x1000:(i+1)*0x1000] = bdata
                stdin.append((bdata.hex() + '\n').encode())

    rcode = random.randrange(127)
    stdin.append(f's {rcode:x}\n'.encode())
    return init_data, b''.join(stdin), b''.join(stdout), b''.join(stderr), rcode, bytes(data)


for _ in range(NUM_RUNS):
    d, i, eo, ee, r, efd = gen_test()
    with tempfile.NamedTemporaryFile() as f:
        f.write(d)
        p = subprocess.Popen(["./avm", "block.bin", f.name], stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.PIPE)
        (o, e) = p.communicate(i)
        f.seek(0)
        fd = f.read()
    if e != ee:
        print(f'have stderr {e} expected {ee}')
        sys.exit(1)
    if o != eo:
        print(f'stdout mismatch {o} {eo}')
        sys.exit(1)
    if p.returncode != r:
        print(f'wrong returncode {p.returncode} expected {r}')
        sys.exit(1)
    if fd != efd:
        print(f'wrong final data {fd.hex()} expected {efd.hex()}')
        sys.exit(1)
