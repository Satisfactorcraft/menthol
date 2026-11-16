#!/bin/bash
# Run in the chroot after blfs.sh/polish.sh. Idempotent.
#  - sshd: key-only login, no root login
#  - remove the leftover chapter-7 "tester" account
set -eE
trap 'echo "FAILED: line $LINENO: $BASH_COMMAND" >&2' ERR
add_line() { grep -qxF -- "$1" "$2" 2>/dev/null || echo "$1" >> "$2"; }

CONF=/etc/ssh/sshd_config
add_line "PermitRootLogin no" $CONF
add_line "PasswordAuthentication no" $CONF
add_line "KbdInteractiveAuthentication no" $CONF
add_line "PubkeyAuthentication yes" $CONF
grep -E '^(PermitRootLogin|PasswordAuthentication|KbdInteractiveAuthentication|PubkeyAuthentication)' $CONF

if id tester >/dev/null 2>&1; then
  userdel -r tester || userdel tester
  rm -rf /home/tester
fi
if getent group tester >/dev/null; then groupdel tester; fi
echo "=== DONE harden"
