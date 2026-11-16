#!/usr/bin/env python3
"""Boot menthol.img in QEMU and run checks over the serial console.
usage: MENTHOL_TEST_PW=<password of user menthol> vmtest.py MODE VARS_FD   (MODE = uefi | bios)"""
import subprocess, time, os, sys, select, re, socket
mode, vars_fd = sys.argv[1], sys.argv[2]
PW = os.environ["MENTHOL_TEST_PW"]  # never hard-code credentials here
cmd = ["qemu-system-x86_64","-enable-kvm","-cpu","host","-m","2G","-smp","4","-display","none",
       "-serial","stdio","-monitor","none",
       "-drive","file=/home/jan/LFS/menthol.img,format=raw,if=virtio",
       "-nic","user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:2222-:22"]
if mode == "uefi":
    cmd += ["-machine","q35","-drive","if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd",
            "-drive",f"if=pflash,format=raw,file={vars_fd}"]
p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
os.set_blocking(p.stdout.fileno(), False)
buf = b""
def read(t):
    global buf
    end = time.time()+t
    while time.time() < end:
        r,_,_ = select.select([p.stdout],[],[],0.2)
        if r:
            try: d = p.stdout.read(65536)
            except BlockingIOError: d = None
            if d: buf += d
def wait_for(pat, t):
    end = time.time()+t
    while time.time() < end:
        read(0.5)
        if re.search(pat, buf.decode(errors='replace')): return True
    return False
def send(s): p.stdin.write(s.encode()); p.stdin.flush()
clean = lambda b: re.sub(r'\x1b\[[0-9;?]*[a-zA-Z]','',b.decode(errors='replace'))
ok = wait_for(r"menthol login:", 150)
print(f"[{mode}] login prompt:", ok)
if ok:
    send("menthol\n"); wait_for(r"Password:", 10); send(PW+"\n"); time.sleep(3)
    mark = len(buf)
    cmds = ["whoami; id -nG", "echo $PS1 | head -c 40; echo",
            f"echo {PW} | sudo -S -p '' whoami",
            "curl -sI https://www.linuxfromscratch.org | head -1",
            "wget -q --spider https://www.linuxfromscratch.org && echo WGET_OK",
            "git --version", "ssh -V", "systemctl is-active sshd", "systemctl is-system-running",
            "systemctl --failed --no-legend"]
    for c in cmds:
        send(c+"\n"); time.sleep(5 if ("curl" in c or "wget" in c) else 2)
    # SSH banner via forwarded port
    try:
        s = socket.create_connection(("127.0.0.1",2222), timeout=5); print("ssh banner:", s.recv(64).decode().strip()); s.close()
    except Exception as e: print("ssh banner failed:", e)
    read(2)
    print(clean(buf[mark:]))
    send(f"echo {PW} | sudo -S -p '' poweroff\n"); read(10)
p.terminate()
try: p.wait(10)
except Exception: p.kill()
