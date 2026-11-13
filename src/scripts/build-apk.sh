#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
signing=${SISARASA_SIGNING_FILE:-$root/android-app/android/key.properties}
if ! test -f "$signing"; then
  echo 'Release signing key.properties missing; run scripts/setup-signing.sh and keep the key private.' >&2
  exit 1
fi
origin=${1:-}
if test -z "$origin" && test -f "$root/.superpowers/tunnel.log"; then
  origin=$(python3 - "$root/.superpowers/tunnel.log" <<'PY'
import re,sys
m=re.search(r'https://[a-z0-9-]+\.trycloudflare\.com',open(sys.argv[1]).read())
print(m.group(0) if m else '')
PY
)
fi
python3 - "$origin" <<'PY'
import sys,urllib.parse
u=urllib.parse.urlsplit(sys.argv[1])
if u.scheme!='https' or not u.hostname or u.username or u.password or u.query or u.fragment or u.path not in ('','/'):
 raise SystemExit('Supply an HTTPS origin without credentials/path/query: ./scripts/build-apk.sh https://YOUR_HOST')
PY
cd "$root/android-app"
SISARASA_SIGNING_FILE="$signing" flutter build apk --release --dart-define="API_BASE=$origin"
mkdir -p "$root/artifacts"
cp build/app/outputs/flutter-apk/app-release.apk "$root/artifacts/sisarasa.apk"
python3 - "$root" "$origin" <<'PY'
import hashlib,json,pathlib,subprocess,sys,datetime,re
root=pathlib.Path(sys.argv[1]);apk=root/'artifacts/sisarasa.apk'
version=re.search(r'^version:\s*(\S+)',(root/'android-app/pubspec.yaml').read_text(),re.M).group(1)
m=dict(version=version,application_id='id.sisarasa.sisarasa_app',min_sdk=29,target_sdk=36,api_origin=sys.argv[2],apk='sisarasa.apk',bytes=apk.stat().st_size,sha256=hashlib.file_digest(open(apk,'rb'),'sha256').hexdigest(),built_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),finance='simulation',physical_device_verified=False)
(root/'artifacts/manifest.json').write_text(json.dumps(m,indent=2)+'\n')
print('Signed APK: '+str(apk))
print('SHA-256: '+m['sha256'])
PY

python3 "$root/scripts/verify-apk.py"
