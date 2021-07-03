import subprocess
import sys
import random
import os
import tempfile
import hashlib

NUM_RUNS = 100

def randbytes(num):
    try:
        return random.randbytes(num)
    except:
        return os.urandom(num)

for _ in range(NUM_RUNS):
    num_blocks = random.randrange(3, 0x400)
    data = randbytes(num_blocks << 12)
    with tempfile.NamedTemporaryFile() as f:
        f.write(data)
        p = subprocess.run(["./avm", "sha512.bin", f.name], stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.DEVNULL)
    if p.returncode != 0:
        print(f'wrong returncode {p.returncode}')
        sys.exit(1)
    if p.stderr != b'':
        print(f'have stderr {p.stderr}')
        sys.exit(1)
    h = hashlib.sha512()
    h.update(data)
    exp = h.digest()
    if p.stdout != exp:
        print(f'stdout mismatch {p.stdout} {exp}')
        sys.exit(1)
