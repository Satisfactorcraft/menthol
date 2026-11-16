#!/usr/bin/env python3
"""Boot menthol.img in QEMU and run checks over the serial console.

usage: MENTHOL_TEST_PW=<password of user menthol> vmtest.py MODE [VARS_FD]   (MODE = uefi | bios)

Exit status: 0 if every check passed, 1 if a check failed, 2 on usage errors.

Environment:
  MENTHOL_TEST_PW       password of user menthol (required, never hard-code it)
  MENTHOL_IMG           image path (default: menthol.img next to the repo's scripts/ directory)
  MENTHOL_OVMF_CODE     OVMF firmware (default: /usr/share/edk2/x64/OVMF_CODE.4m.fd)
  MENTHOL_SSH_PORT      host port forwarded to the guest's sshd (default: 2222)
  MENTHOL_TEST_OFFLINE  set to 1 to skip the checks that need internet access
  MENTHOL_TEST_SNAPSHOT set to 1 to boot with -snapshot (the image is not modified)
  MENTHOL_TEST_LOG      write the full console log to this file
"""
import os, re, select, socket, subprocess, sys, time

if len(sys.argv) < 2 or sys.argv[1] not in ("uefi", "bios"):
    print(__doc__, file=sys.stderr); sys.exit(2)
mode = sys.argv[1]
if mode == "uefi" and len(sys.argv) < 3:
    print("uefi mode needs VARS_FD (a writable copy of OVMF_VARS_4M.fd)", file=sys.stderr); sys.exit(2)
PW = os.environ.get("MENTHOL_TEST_PW")
if not PW:
    print("MENTHOL_TEST_PW is not set", file=sys.stderr); sys.exit(2)

HERE = os.path.dirname(os.path.realpath(__file__))
IMG = os.environ.get("MENTHOL_IMG", os.path.join(os.path.dirname(HERE), "menthol.img"))
OVMF = os.environ.get("MENTHOL_OVMF_CODE", "/usr/share/edk2/x64/OVMF_CODE.4m.fd")
PORT = int(os.environ.get("MENTHOL_SSH_PORT", "2222"))
OFFLINE = os.environ.get("MENTHOL_TEST_OFFLINE") == "1"
if not os.path.exists(IMG):
    print(f"image not found: {IMG} (set MENTHOL_IMG)", file=sys.stderr); sys.exit(2)

KVM = os.access("/dev/kvm", os.R_OK | os.W_OK)
SLOW = 1 if KVM else 8   # software emulation is much slower
cmd = ["qemu-system-x86_64", "-m", "2G", "-smp", "4", "-display", "none",
       "-serial", "stdio", "-monitor", "none",
       "-drive", f"file={IMG},format=raw,if=virtio",
       "-nic", f"user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:{PORT}-:22"]
cmd += ["-enable-kvm", "-cpu", "host"] if KVM else ["-cpu", "max"]
if os.environ.get("MENTHOL_TEST_SNAPSHOT") == "1":
    cmd += ["-snapshot"]
if mode == "uefi":
    cmd += ["-machine", "q35",
            "-drive", f"if=pflash,format=raw,readonly=on,file={OVMF}",
            "-drive", f"if=pflash,format=raw,file={sys.argv[2]}"]
if not KVM:
    print("note: /dev/kvm is not usable, falling back to software emulation (slow)")

p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
os.set_blocking(p.stdout.fileno(), False)
buf = b""

def text():
    """Console output so far, without ANSI escapes and carriage returns."""
    return re.sub(r"\x1b\[[0-9;?]*[a-zA-Z]|\r", "", buf.decode(errors="replace"))

def pump(t):
    global buf
    r, _, _ = select.select([p.stdout], [], [], t)
    if r:
        try:
            d = p.stdout.read(65536)
        except BlockingIOError:
            d = None
        if d:
            buf += d

def wait_for(pat, t, start=0):
    """Wait until pat shows up in the console output after offset start."""
    end = time.time() + t * SLOW
    while True:
        m = re.search(pat, text()[start:], re.M)
        if m:
            return m
        if time.time() >= end or p.poll() is not None:
            return None
        pump(0.2)

def send(s):
    p.stdin.write(s.encode()); p.stdin.flush()

seq = 0
def run(command, t=15, answer=None):
    """Run a shell command in the guest. Returns (exit status or None on timeout, output)."""
    global seq
    seq += 1
    start = len(text())
    # $? is expanded by the guest shell, so the marker only matches real output, not the echoed command line
    send(f'{command}; echo "__RC{seq}=$?__"\n')
    if answer:
        if wait_for(answer[0], t, start):
            send(answer[1] + "\n")
    m = wait_for(rf"__RC{seq}=(\d+)__", t, start)
    out = text()[start:]
    return (int(m.group(1)) if m else None), out

results = []
def check(name, ok, detail=""):
    results.append((name, bool(ok)))
    print(f"[{mode}] {'PASS' if ok else 'FAIL'}  {name}" + (f"  ({detail})" if detail and not ok else ""))

def expect(name, command, pattern=None, t=15, answer=None):
    rc, out = run(command, t, answer)
    if rc is None:
        return check(name, False, "timeout")
    if pattern is None:
        return check(name, rc == 0, f"exit status {rc}")
    check(name, re.search(pattern, out, re.M), "unexpected output")

booted = wait_for(r"menthol login:", 150)
check("boot to login prompt", booted, "no login prompt within the time limit")
if booted:
    send("menthol\n")
    wait_for(r"Password:", 15)
    send(PW + "\n")
    rc, _ = run("true", 20)
    check("login as menthol", rc == 0, "no shell after login")
    if rc == 0:
        expect("user is menthol", "whoami", r"^menthol$")
        expect("menthol is in wheel", "id -nG", r"\bwheel\b.*\n")
        # the prompt is quoted in two parts so the echoed command line does not look like the prompt itself
        expect("sudo works", "sudo -p 'SUDO''PW:' whoami", r"(^|SUDOPW:)root$", answer=(r"SUDOPW:", PW))
        expect("os-release is MentholLinux", '. /etc/os-release; echo "id=$ID"', r"^id=menthol$")
        expect("shell profile is installed", "test -r /etc/profile.d/menthol.sh")
        if not OFFLINE:
            expect("curl over HTTPS", "curl -sI --max-time 20 https://www.linuxfromscratch.org | head -1",
                   r"^HTTP/\S+ [23]\d\d", t=30)
            expect("wget over HTTPS", "wget -q -T 20 --spider https://www.linuxfromscratch.org", t=30)
        expect("git runs", "git --version", r"^git version \d")
        expect("ssh client runs", "ssh -V")
        expect("mpkg runs", "mpkg version", r"^mpkg \d")
        expect("sshd is active", "systemctl is-active sshd", r"^active$")
        expect("system state is running", "systemctl is-system-running --wait", r"^running$", t=90)
        expect("no failed units", "systemctl --failed --no-legend | wc -l", r"^0$")
        try:
            s = socket.create_connection(("127.0.0.1", PORT), timeout=10 * SLOW)
            s.settimeout(10 * SLOW)
            banner = s.recv(64).decode(errors="replace").strip()
            s.close()
            check("ssh banner on forwarded port", banner.startswith("SSH-2.0"), banner)
        except OSError as e:
            check("ssh banner on forwarded port", False, str(e))
        # sudo credentials are still cached from the check above
        send("sudo -n poweroff\n")
        try:
            end = time.time() + 60 * SLOW
            while p.poll() is None and time.time() < end:
                pump(0.5)
            check("clean poweroff", p.poll() is not None, "guest did not power off")
        except Exception as e:
            check("clean poweroff", False, str(e))

if p.poll() is None:
    p.terminate()
    try:
        p.wait(10)
    except subprocess.TimeoutExpired:
        p.kill()

log = os.environ.get("MENTHOL_TEST_LOG")
if log:
    with open(log, "w") as f:
        f.write(text().replace(PW, "********"))
failed = [n for n, ok in results if not ok]
print(f"[{mode}] {len(results) - len(failed)}/{len(results)} checks passed")
if failed and not log:
    print("---- last console output ----")
    print("\n".join(text().replace(PW, "********").splitlines()[-40:]))
sys.exit(1 if failed else 0)
