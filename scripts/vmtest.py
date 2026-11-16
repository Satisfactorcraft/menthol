#!/usr/bin/env python3
"""Boot menthol.img in QEMU and verify it. Exit status is 0 only if every check passes.

usage: MENTHOL_TEST_PW=<password of user menthol> vmtest.py MODE [VARS_FD]
  MODE     uefi | bios
  VARS_FD  writable copy of OVMF_VARS (uefi only; default: a temporary copy)

The password is read from the environment, typed at the sudo/login prompts (never put on a
command line) and masked in the printed transcript.
"""
import os
import re
import select
import shutil
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
IMG = Path(os.environ.get("IMG", ROOT / "menthol.img"))
OVMF_CODE = "/usr/share/edk2/x64/OVMF_CODE.4m.fd"
OVMF_VARS = "/usr/share/OVMF/OVMF_VARS_4M.fd"
USER = "menthol"
BOOT_TIMEOUT = 150


def free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


# terminal escapes: CSI sequences and OSC sequences (systemd shell integration emits OSC 3008)
ANSI = re.compile(r"\x1b\[[0-9;?]*[a-zA-Z]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)")


class Console:
    """QEMU with the guest serial console on our stdin/stdout."""

    def __init__(self, cmd, password):
        self.password = password
        self.proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                     stderr=subprocess.STDOUT)
        os.set_blocking(self.proc.stdout.fileno(), False)
        self.raw = ""   # everything received, untouched
        self.buf = ""   # raw with escape sequences removed (recomputed, so split sequences are handled)
        self.seq = 0

    def pump(self, seconds):
        end = time.time() + seconds
        while time.time() < end:
            ready, _, _ = select.select([self.proc.stdout], [], [], 0.2)
            if ready:
                try:
                    data = self.proc.stdout.read(65536)
                except BlockingIOError:
                    data = None
                if data:
                    self.raw += data.decode(errors="replace")
                    self.buf = ANSI.sub("", self.raw)
            if self.proc.poll() is not None and not ready:
                break

    def expect(self, pattern, timeout, start=0):
        end = time.time() + timeout
        while time.time() < end:
            self.pump(0.5)
            m = re.search(pattern, self.buf[start:], re.M)
            if m:
                return m
            if self.proc.poll() is not None:
                break
        return None

    def send(self, text):
        self.proc.stdin.write(text.encode())
        self.proc.stdin.flush()

    def run(self, cmd, timeout=20, sudo=False):
        """Run a shell command in the guest. Returns (output, exit_status) or (output, None)."""
        self.seq += 1
        mark = f"__M{self.seq}__"
        start = len(self.buf)
        self.send(f"{cmd}; echo {mark}$?\n")
        if sudo:
            if self.expect(r"password for " + USER + ":", 15, start):
                self.send(self.password + "\n")
        m = self.expect(mark + r"(\d+)\s*$", timeout, start)
        if not m:
            return self.buf[start:], None
        out = self.buf[start:start + m.start()]
        # drop the echoed command line (it contains the marker with a literal $?)
        out = "\n".join(l for l in out.splitlines() if mark not in l).strip()
        return out, int(m.group(1))

    def transcript(self, since=0):
        return self.buf[since:].replace(self.password, "***")


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ("uefi", "bios"):
        sys.exit(__doc__)
    mode = sys.argv[1]
    password = os.environ.get("MENTHOL_TEST_PW")
    if not password:
        sys.exit("ERROR: set MENTHOL_TEST_PW to the password of user 'menthol'")
    if not IMG.exists():
        sys.exit(f"ERROR: {IMG} not found")
    port = free_port()
    cmd = ["qemu-system-x86_64", "-m", "2G", "-smp", "4", "-display", "none",
           "-serial", "stdio", "-monitor", "none",
           "-drive", f"file={IMG},format=raw,if=virtio",
           "-nic", f"user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:{port}-:22"]
    if os.access("/dev/kvm", os.W_OK):
        cmd[1:1] = ["-enable-kvm", "-cpu", "host"]
    else:
        print("note: /dev/kvm not usable, running without KVM (slow)")
        cmd[1:1] = ["-cpu", "max"]
    tmpdir = None
    if mode == "uefi":
        vars_fd = sys.argv[2] if len(sys.argv) > 2 else None
        if not vars_fd:
            tmpdir = tempfile.mkdtemp()
            vars_fd = os.path.join(tmpdir, "vars.fd")
            shutil.copy(OVMF_VARS, vars_fd)
        cmd += ["-machine", "q35",
                "-drive", f"if=pflash,format=raw,readonly=on,file={OVMF_CODE}",
                "-drive", f"if=pflash,format=raw,file={vars_fd}"]

    results = []

    def check(name, ok, detail=""):
        results.append((name, bool(ok)))
        print(f"  [{'PASS' if ok else 'FAIL'}] {name}" + (f"  ({detail})" if detail and not ok else ""))

    con = Console(cmd, password)
    print(f"[{mode}] booting {IMG.name}, ssh forwarded on 127.0.0.1:{port}")
    try:
        up = con.expect(r"menthol login:", BOOT_TIMEOUT)
        check("boots to a login prompt", up)
        if up:
            con.send(USER + "\n")
            con.expect(r"Password:", 10)
            login_start = len(con.buf)
            con.send(password + "\n")
            # login(1) flushes pending input, so wait for the shell prompt before typing anything
            con.expect(USER + r"@menthol:~\$ ", 30, login_start)
            ready, rc = con.run("echo READY", 30)
            check("login as 'menthol'", rc == 0, ready[-120:])
            if rc == 0:
                motd = con.buf[login_start:].count("Linux 1.0  (LFS 13.1, systemd)")
                check("MOTD shown exactly once", motd == 1, f"shown {motd}x")
                out, rc = con.run("id -nG")
                check("user is in group wheel", rc == 0 and "wheel" in out.split(), out)
                out, rc = con.run("sudo -k; sudo whoami", 20, sudo=True)
                check("sudo works", rc == 0 and out.splitlines()[-1:] == ["root"], out)
                out, rc = con.run("curl -sI https://www.linuxfromscratch.org | head -1", 30)
                check("curl HTTPS (CA bundle)", "200" in out, out)
                out, rc = con.run("wget -q --spider https://www.linuxfromscratch.org && echo WGET_OK", 30)
                check("wget HTTPS", "WGET_OK" in out, out)
                out, rc = con.run("git --version")
                check("git installed", out.startswith("git version"), out)
                out, rc = con.run("systemctl is-active sshd")
                check("sshd active", out == "active", out)
                out, rc = con.run("systemctl is-system-running")
                check("systemd is running", out == "running", out)
                out, rc = con.run("systemctl --failed --no-legend")
                check("no failed units", rc == 0 and out == "", out)
                out, rc = con.run(r"grep -E '\([A-Z ]*C' /proc/consoles | cut -d' ' -f1")
                check("system console is tty0 (not the serial port)", out == "tty0", out)
                out, rc = con.run("getent passwd tester")
                check("no leftover 'tester' account", out == "", out)
                out, rc = con.run("grep -E '^(PasswordAuthentication|PermitRootLogin) ' /etc/ssh/sshd_config | sort | tr '\\n' ' '")
                check("sshd_config: key-only, no root login",
                      "PasswordAuthentication no" in out and "PermitRootLogin no" in out, out)
                # host-side SSH checks
                try:
                    with socket.create_connection(("127.0.0.1", port), timeout=5) as s:
                        banner = s.recv(64).decode(errors="replace").strip()
                except OSError as e:
                    banner = f"error: {e}"
                check("sshd answers with an SSH banner", banner.startswith("SSH-2.0-"), banner)
                r = subprocess.run(["ssh", "-p", str(port), "-o", "BatchMode=yes",
                                    "-o", "PubkeyAuthentication=no",
                                    "-o", "PreferredAuthentications=password",
                                    "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null",
                                    "-o", "ConnectTimeout=10", f"{USER}@127.0.0.1", "true"],
                                   capture_output=True, text=True)
                check("ssh password login is rejected",
                      r.returncode != 0 and "Permission denied (publickey" in r.stderr
                      and "password" not in r.stderr.split("Permission denied")[-1], r.stderr.strip()[-120:])
            con.run("sudo poweroff", 10, sudo=True)
            con.pump(5)
    finally:
        try:
            con.proc.wait(30)
        except subprocess.TimeoutExpired:
            con.proc.kill()
        if tmpdir:
            shutil.rmtree(tmpdir, ignore_errors=True)

    failed = [n for n, ok in results if not ok]
    print(f"[{mode}] {len(results) - len(failed)}/{len(results)} checks passed")
    if failed:
        print("failed: " + "; ".join(failed))
        print("--- last console output (password masked) ---")
        print(con.transcript()[-1500:])
    sys.exit(1 if failed or not results else 0)


if __name__ == "__main__":
    main()
