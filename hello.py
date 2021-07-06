import subprocess
import sys

p = subprocess.run(["./avm", "hello.bin"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.DEVNULL)

if p.returncode != 42:
    print(f"wrong exit code {p.returncode}")
    sys.exit(1)

if p.stderr != b'Hello, world!\n':
    print(f"wrong stderr: {p.stderr}")
    sys.exit(1)

if p.stdout != b'':
    print(f"wrong stdout: {p.stdout}")
    sys.exit(1)
