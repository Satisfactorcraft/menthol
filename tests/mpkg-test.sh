#!/bin/bash
# Tests for mpkg. Everything runs in a throwaway directory with --root, nothing touches the host.
# usage: tests/mpkg-test.sh
set -u
HERE=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
MPKG=$HERE/../scripts/files/mpkg
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
cd "$T" || exit 1
pass=0; fail=0
ok() { pass=$((pass + 1)); echo "ok    $1"; }
bad() { fail=$((fail + 1)); echo "FAIL  $1"; }
check() { local d=$1; shift; if "$@" > "$T/out" 2>&1; then ok "$d"; else bad "$d"; sed 's/^/      /' "$T/out"; fi; }
refuse() { local d=$1; shift; if "$@" > "$T/out" 2>&1; then bad "$d (should have failed)"; else ok "$d"; fi; }
has() { grep -q -- "$2" "$1"; }

new_root() {
  rm -rf root; mkdir -p root/etc/mpkg root/usr/lib root/usr/bin
  ln -s usr/lib root/lib
  echo "test $T/repo" > root/etc/mpkg/repos.conf
}
R() { "$MPKG" --root "$T/root" -y "$@"; }
stage() { rm -rf "st/$1"; mkdir -p "st/$1"; }

# --- packages for the tests
mkdir repo
stage libfoo; mkdir -p st/libfoo/lib st/libfoo/etc/foo st/libfoo/usr/share/libfoo
echo so > st/libfoo/lib/libfoo.so.1; echo old > st/libfoo/usr/share/libfoo/gone.txt; echo conf=1 > st/libfoo/etc/foo/foo.conf
chmod 700 st/libfoo/usr
stage foo; mkdir -p st/foo/usr/bin; echo foo > st/foo/usr/bin/foo
stage meta
check "build libfoo" "$MPKG" build -n libfoo -v 1.0 -o repo st/libfoo
check "build foo with a dependency" "$MPKG" build -n foo -v 2.1 -d "libfoo" -D "The foo tool" -o repo st/foo
check "build meta package" "$MPKG" build -n desktop-test -v 1 -a any -d "foo" -o repo st/meta
refuse "build rejects a bad name" "$MPKG" build -n "Bad Name" -v 1 -o repo st/meta
refuse "build rejects a bad dependency" "$MPKG" build -n x -v 1 -d "foo|bar" -o repo st/meta
check "index" "$MPKG" index repo
check "index has 3 packages" test "$(wc -l < repo/mpkg.index)" -eq 3

# --- install, query
new_root
check "update" R update
check "install with dependencies" R install desktop-test
check "all three installed" test "$(R list | wc -l)" -eq 3
check "file went through the /lib symlink" test -f root/usr/lib/libfoo.so.1
check "/lib is still a symlink" test -L root/lib
check "existing directory mode is untouched" test "$(stat -c %a root/usr)" = 755
check "root directory mode is untouched" test "$(stat -c %a root)" = "$(stat -c %a "$T/st")"
check "owner" test "$(R owner /lib/libfoo.so.1)" = libfoo
R search foo > s.txt; check "search marks installed packages" has s.txt "installed"
R info foo > i.txt; check "info shows dependency reason" has i.txt "installed (dep)"
check "verify" R verify
refuse "remove is blocked by dependants" R remove libfoo
refuse "install of an unknown package fails" R install nope

# --- upgrade
echo conf=local > root/etc/foo/foo.conf
rm st/libfoo/usr/share/libfoo/gone.txt; echo new > st/libfoo/usr/share/libfoo/new.txt; echo conf=2 > st/libfoo/etc/foo/foo.conf
"$MPKG" build -n libfoo -v 1.10 -o repo st/libfoo > /dev/null; "$MPKG" index repo > /dev/null 2>&1
check "hold" R hold libfoo
R upgrade > u.txt 2>&1; check "held package is not upgraded" has u.txt "held back"
check "unhold" R unhold libfoo
check "upgrade" R upgrade
check "1.10 is newer than 1.0" test "$(R list | awk '$1 == "libfoo" {print $2}')" = 1.10-1
check "stale file removed on upgrade" test ! -e root/usr/share/libfoo/gone.txt
check "new file installed on upgrade" test -f root/usr/share/libfoo/new.txt
check "changed config is kept" grep -q conf=local root/etc/foo/foo.conf
check "new config saved as .mpkgnew" grep -q conf=2 root/etc/foo/foo.conf.mpkgnew
R upgrade --no-refresh > u.txt 2>&1; check "second upgrade is a no-op" has u.txt "up to date"

# --- safety
stage bar; mkdir -p st/bar/usr/bin; echo x > st/bar/usr/bin/foo
"$MPKG" build -n bar -v 1 -o . st/bar > /dev/null
refuse "file conflict is refused" R install ./bar-1-1-"$(uname -m)".tar.xz
check "conflict left the file alone" grep -q foo root/usr/bin/foo
mkdir -p ev/.MPKG ev/a
printf 'name=evil\nversion=1\nrelease=1\narch=any\ndepends=\ndesc=\n' > ev/.MPKG/info
tar -cJf evil.tar.xz -P -C ev .MPKG --transform 's|^a|../../a|' a 2> /dev/null
refuse "package with ../ paths is refused" R install ./evil.tar.xz
"$MPKG" build -n wrongarch -v 1 -a nope -o . st/meta > /dev/null
refuse "wrong architecture is refused" R install ./wrongarch-1-1-nope.tar.xz
sed -i 's/|[0-9a-f]\{64\}|/|0000000000000000000000000000000000000000000000000000000000000000|/' repo/mpkg.index
R clean > /dev/null; R update > /dev/null 2>&1; R remove desktop-test foo libfoo > /dev/null
refuse "checksum mismatch is refused" R install libfoo
"$MPKG" index repo > /dev/null 2>&1

# --- remove
new_root; R update > /dev/null 2>&1; R install desktop-test > /dev/null 2>&1
check "remove" R remove desktop-test
check "autoremove drops orphaned dependencies" R autoremove
check "nothing left installed" test -z "$(R list)"
check "/lib survives removal" test -L root/lib
check "directories mpkg created are gone" test ! -e root/usr/share
check "directories that existed before stay" test -d root/usr/bin

# --- version constraints
stage app; mkdir -p st/app/usr/bin; echo app > st/app/usr/bin/app
"$MPKG" build -n app -v 1 -d "libfoo>=1.5" -o repo st/app > /dev/null; "$MPKG" index repo > /dev/null 2>&1
new_root; R update > /dev/null 2>&1
R install ./repo/libfoo-1.0-1-"$(uname -m)".tar.xz > /dev/null
check "constraint upgrades an installed dependency" R install app
check "dependency is now 1.10" test "$(R list | awk '$1 == "libfoo" {print $2}')" = 1.10-1
refuse "dependant with a constraint blocks removal" R remove libfoo
"$MPKG" build -n app2 -v 1 -d "libfoo>=9" -o repo st/app > /dev/null; "$MPKG" index repo > /dev/null 2>&1
R update > /dev/null 2>&1
refuse "unsatisfiable constraint fails" R install app2
rm repo/app2-*; "$MPKG" index repo > /dev/null 2>&1

# --- signatures
check "keygen" "$MPKG" keygen keys
check "signed index" "$MPKG" index --sign keys/mpkg.key repo
new_root; mkdir -p root/etc/mpkg/keys; cp keys/mpkg.pub root/etc/mpkg/keys/test.pub
check "update accepts a valid signature" R update
echo "evil|9-1|evil.tar.xz|00|1||x" >> repo/mpkg.index
refuse "update rejects a tampered list" R update
check "old list is kept after a bad signature" test "$(grep -c evil root/var/lib/mpkg/lists/test.index)" -eq 0
"$MPKG" index repo > /dev/null 2>&1
refuse "update rejects an unsigned list when a key is installed" R update

# --- recipes
mkdir -p rec/hello/hello-1.0
printf 'all:\n\tprintf "#!/bin/sh\\necho hello\\n" > hello\ninstall:\n\tinstall -Dm755 hello $(DESTDIR)/usr/bin/hello\n' > rec/hello/hello-1.0/Makefile
tar -czf rec/hello/hello-1.0.tar.gz -C rec/hello hello-1.0; rm -r rec/hello/hello-1.0
cat > rec/hello/recipe << EOR
name=hello
version=1.0
desc="Says hello"
source=(hello-1.0.tar.gz)
sha256=($(sha256sum rec/hello/hello-1.0.tar.gz | cut -d' ' -f1))
build() {
  cd hello-\$version
  make
  make DESTDIR="\$PKG" install
}
EOR
echo 'echo post' > rec/hello/post-install
new_root
check "make builds a recipe" "$MPKG" make -o out rec/hello
check "make --install" "$MPKG" --root "$T/root" make -o out --install rec/hello
check "recipe package is installed" test -x root/usr/bin/hello
check "post-install script is recorded" test -f root/var/lib/mpkg/installed/hello/post-install
sed -i 's/^sha256=.*/sha256=(0000)/' rec/hello/recipe
refuse "make rejects a wrong source checksum" "$MPKG" make -o out rec/hello
sed -i 's/^sha256=.*/sha256=(SKIP)/; s/  make$/  false; make/' rec/hello/recipe
refuse "make stops when a build step fails" "$MPKG" make -o out rec/hello

echo
echo "$pass passed, $fail failed"
[ $fail -eq 0 ]
