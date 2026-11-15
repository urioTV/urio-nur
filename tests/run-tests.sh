#!/usr/bin/env bash
# TEMP DIAGNOSTIC (never merge)
set -u
cp pkgs/lantern-engine/deps.json /tmp/before.json
bash scripts/refresh-dotnet-deps.sh > /tmp/refresh.log 2>&1; echo "DIAG: refresh exit=$?"
grep -E "Refreshed|Failed to refresh|NuGet-Migrations|Successfully wrote|error" /tmp/refresh.log | head -8 | sed 's/^/DIAG: /'
cmp -s /tmp/before.json pkgs/lantern-engine/deps.json && echo "DIAG: lock unchanged" || echo "DIAG: lock CHANGED"
exit 0
