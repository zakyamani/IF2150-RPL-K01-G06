#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
"$root/scripts/health.sh" >/dev/null
binary=${CLOUDFLARED_BIN:-$root/.tooling/cloudflared}
if ! test -x "$binary"; then
  binary=$(command -v cloudflared || true)
fi
if test -z "$binary"; then
  echo 'Install cloudflared from https://developers.cloudflare.com/tunnel/downloads/ or run scripts/install-cloudflared.sh' >&2
  exit 1
fi
if test "${1:-}" = --config; then
  test "$#" = 2 || exit 1
  exec "$binary" tunnel --config "$2" run
fi
port=$(python3 - "$root/.env" <<'PY'
import sys
c=dict(line.split('=',1) for line in open(sys.argv[1]).read().splitlines() if line and not line.startswith('#'))
print(c['API_HOST_PORT'])
PY
)
exec "$binary" tunnel --no-autoupdate --protocol http2 --url "http://127.0.0.1:$port"
