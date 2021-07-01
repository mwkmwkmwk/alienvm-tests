import subprocess
import sys
import random

NUM_RUNS = 10

def rc4(key, num):
    s = bytearray(range(0x100))
    j = 0
    for i in range(0x100):
        j = (j + s[i] + key[i & 0xf]) & 0xff
        s[i], s[j] = s[j], s[i]
    res = bytearray()
    i = j = 0
    for _ in range(num):
        i = (i + 1) & 0xff
        j = (j + s[i]) & 0xff
        s[i], s[j] = s[j], s[i]
        res.append(s[(s[i] + s[j]) & 0xff])
    return res

for _ in range(NUM_RUNS):
    key = bytes(random.randrange(256) for _ in range(16))
    p = subprocess.Popen(['./avm', 'rc4.bin'], stdout=subprocess.PIPE, stdin=subprocess.PIPE)
    num_check = random.randrange(0x80000, 0x400000)
    p.stdin.write(key)
    p.stdin.flush()
    data = p.stdout.read(num_check)
    p.stdin.write(b'\0')
    p.stdin.flush()
    p.wait()
    if p.returncode != 0:
        print(f'wrong return code {p.returncode}')
        sys.exit(1)
    if data != rc4(key, num_check):
        print(f'data mismatch')
        sys.exit(1)
