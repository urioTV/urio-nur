#!/usr/bin/env bash
# TEMP DIAGNOSTIC (never merge)
set -u
strace=$(nix build --no-link --print-out-paths --no-write-lock-file --inputs-from . nixpkgs#strace 2>&1 | tail -1)/bin/strace
fd=$(nix build --no-link --print-out-paths --no-write-lock-file '.#packages.x86_64-linux.lantern-engine.launcher.fetch-deps' 2>&1 | tail -1)
s=$(mktemp -d); mkdir -p $s/tmp $s/home
echo "DIAG: getent=$(getent passwd "$(id -u)")"
TMPDIR=$s/tmp HOME=$s/home DOTNET_CLI_HOME=$s/home timeout 900 "$strace" -f -v -s 600 -o $s/trace -e trace=execve,mkdir,mkdirat,openat,getuid,geteuid "$fd" $s/deps.json > $s/log 2>&1; echo "DIAG: exit=$?"
grep -E 'execve\("[^"]*/(dotnet|\.dotnet-wrapped)"' $s/trace | head -1 | grep -oE '"(TMPDIR|TMP|TEMP|TEMPDIR|HOME|DOTNET_[A-Z_]*|NUGET_[A-Z_]*|NIX_BUILD_TOP|XDG_[A-Z_]*)=[^"]*"' | sed 's/^/DIAG-ENV: /'
grep -E '\.dotnet|NuGet|Migrations' $s/trace | grep -E 'mkdir|openat' | grep -v ENOENT | head -30 | sed 's/^/DIAG-T: /'
grep -E 'mkdir.*\.dotnet' $s/trace | head -10 | sed 's/^/DIAG-M: /'
exit 0
