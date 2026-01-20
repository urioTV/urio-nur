#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq nix-prefetch-github

set -euo pipefail

# Get latest commit from master branch
LATEST=$(curl -s https://api.github.com/repos/adnksharp/CyberGRUB-2077/commits/master | jq -r '.sha')
CURRENT=$(grep "rev = " pkgs/cybergrub2077/default.nix | sed 's/.*"\(.*\)".*/\1/')

if [ "$LATEST" = "$CURRENT" ]; then
    echo "cybergrub2077 is up to date ($CURRENT)"
    exit 0
fi

echo "Updating cybergrub2077: ${CURRENT:0:7} -> ${LATEST:0:7}"

# Get new hash
HASH=$(nix-prefetch-github adnksharp CyberGRUB-2077 --rev "$LATEST" 2>/dev/null | jq -r '.hash')

# Update rev and hash in file
sed -i "s/rev = \"${CURRENT}\"/rev = \"${LATEST}\"/" pkgs/cybergrub2077/default.nix
sed -i "s|sha256 = \"sha256-.*\"|sha256 = \"${HASH}\"|" pkgs/cybergrub2077/default.nix

echo "Updated cybergrub2077 to ${LATEST:0:7}"
