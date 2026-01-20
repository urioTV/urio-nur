#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq nix-prefetch

set -euo pipefail

# Get latest version from GitHub releases
LATEST=$(curl -s https://api.github.com/repos/WowUp/WowUp.CF/releases/latest | jq -r '.tag_name' | sed 's/^v//')
CURRENT=$(grep 'version = ' pkgs/wowup-cf/default.nix | head -1 | sed 's/.*"\(.*\)".*/\1/')

if [ "$LATEST" = "$CURRENT" ]; then
    echo "wowup-cf is up to date ($CURRENT)"
    exit 0
fi

echo "Updating wowup-cf: $CURRENT -> $LATEST"

# Get new hash
URL="https://github.com/WowUp/WowUp.CF/releases/download/v${LATEST}/WowUp-CF-${LATEST}.AppImage"
HASH=$(nix-prefetch-url "$URL" 2>/dev/null)

# Update version and hash in file
sed -i "s/version = \"${CURRENT}\"/version = \"${LATEST}\"/" pkgs/wowup-cf/default.nix
sed -i "s|sha256 = \".*\"|sha256 = \"${HASH}\"|" pkgs/wowup-cf/default.nix

echo "Updated wowup-cf to $LATEST"
