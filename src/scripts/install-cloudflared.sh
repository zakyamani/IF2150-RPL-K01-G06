#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
# Pinned upstream release, linux x86_64; verify upstream SHA-256 before executing.
mkdir -p "$root/.tooling"
file="$root/.tooling/cloudflared.download"
curl -fL https://github.com/cloudflare/cloudflared/releases/download/2026.10.0/cloudflared-linux-amd64 -o "$file"
echo "d33ff2d14475178d2012c2c56beba87389ac5ded27649519f198a7d3134a99db  $file" | sha256sum -c
chmod 755 "$file"
mv "$file" "$root/.tooling/cloudflared"
