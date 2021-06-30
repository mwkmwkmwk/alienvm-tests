import subprocess
import sys
import random

NUM_RUNS = 20

def rot13(d):
    res = bytearray(d)
    for i in range(len(d)):
        c = res[i]
        if c in range(0x41, 0x4e) or c in range(0x61, 0x6e):
            res[i] += 0xd
        elif c in range(0x4e, 0x5b) or c in range(0x6e, 0x7b):
            res[i] -= 0xd
    return bytes(res)

for _ in range(NUM_RUNS):
    p = subprocess.Popen(["./avm", "rot13.bin"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.PIPE)
    l = random.randrange(0x100, 0x100000)
    idata = bytes(random.randrange(0x20, 0x7f) for _ in range(l))
    idata += b'\0'
    (o, e) = p.communicate(idata)
    if p.returncode != 0:
        print(f'wrong returncode {p.returncode}')
        sys.exit(1)
    if e != b'':
        print(f'have stderr {e}')
        sys.exit(1)
    exp = rot13(idata[:-1])
    if o != exp:
        print(f'stdout mismatch {o} {exp}')
        sys.exit(1)
