#!/usr/bin/env bash
# TEMP DIAGNOSTIC (never merge)
set -u
strace=$(nix build --no-link --print-out-paths --no-write-lock-file --inputs-from . nixpkgs#strace 2>&1 | tail -1)/bin/strace
fd=$(nix build --no-link --print-out-paths --no-write-lock-file '.#packages.x86_64-linux.lantern-engine.launcher.fetch-deps' 2>&1 | tail -1)
s=$(mktemp -d); mkdir -p $s/tmp $s/home
echo "DIAG: getent=$(getent passwd "$(id -u)")"
TMPDIR=$s/tmp HOME=$s/home DOTNET_CLI_HOME=$s/home timeout 900 "$strace" -f -v -s 600 -o $s/trace -e trace=all "$fd" $s/deps.json > $s/log 2>&1; echo "DIAG: exit=$?"
pid=$(grep -m1 'mkdir("/.dotnet"' $s/trace | awk '{print $1}')
echo "DIAG: pid=$pid"
grep "^$pid " $s/trace | grep -B45 -m1 'mkdir("/.dotnet"' | grep -vE "readlink|mprotect|mmap|munmap|futex|rt_sig|madvise" | tail -30 | cut -c1-220 | sed 's/^/DIAG-C: /'
grep -E 'nscd|/etc/passwd|nsswitch|libnss' $s/trace | head -8 | cut -c1-200 | sed 's/^/DIAG-N: /'
ls -la /var/run/nscd/ 2>&1 | sed 's/^/DIAG-S: /'
exit 0
