#!/usr/bin/env bash
# TEMP DIAGNOSTIC (never merge)
set -u
echo "DIAG: id=$(id) HOME=$HOME TMPDIR=${TMPDIR:-unset} umask=$(umask)"
strace=$(nix build --no-link --print-out-paths --inputs-from . nixpkgs#strace 2>/dev/null)/bin/strace
fd=$(nix build --no-link --print-out-paths --no-write-lock-file '.#packages.x86_64-linux.lantern-engine.launcher.fetch-deps' 2>/dev/null)
s=$(mktemp -d); mkdir -p $s/tmp $s/home
TMPDIR=$s/tmp HOME=$s/home DOTNET_CLI_HOME=$s/home timeout 900 "$strace" -f -Z -o $s/trace -e trace=file,desc,ipc,memory,process "$fd" $s/deps.json > $s/log 2>&1; echo "DIAG: exit=$?"
grep -o "NuGet-Migrations\|Successfully wrote lockfile" $s/log | head -2 | sed 's/^/DIAG: /'
grep -E "dotnet|shm|lockfile|EPERM|EACCES|ENOSYS|EROFS" $s/trace | grep -vE "ENOENT" | tail -40 | sed 's/^/DIAG-T: /'
echo "DIAG: --- ENOSYS/EPERM summary"; grep -oE "^[0-9]+ +[a-z_0-9]+\(.*= -1 (EPERM|EACCES|ENOSYS|EROFS)" $s/trace | awk '{print $2}' | cut -d'(' -f1 | sort | uniq -c | sed 's/^/DIAG: /'
grep -E "= -1 (EPERM|ENOSYS|EACCES|EROFS)" $s/trace | grep -v "/proc\|/sys" | tail -25 | sed 's/^/DIAG-E: /'
exit 0
