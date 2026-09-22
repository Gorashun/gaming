#!/usr/bin/env bash
# Bygger webbversionen för artefaktpublicering: Godot Web-export, Safari-patch,
# gzip till .z.wasm, versionerade filnamn (cache-bust) och laddarsida.
# Användning: tools/web/build_web.sh [GODOT_BIN]
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT_BIN="${1:-${GODOT_BIN:-godot}}"
V="$(git rev-parse --short HEAD)"
rm -rf build/web && mkdir -p build/web
"$GODOT_BIN" --headless --export-release "Web" build/web/pipwreck.html >/dev/null 2>&1 || true
test -s build/web/pipwreck.wasm && test -s build/web/pipwreck.pck
python3 - <<'PY'
p='build/web/pipwreck.js'; s=open(p).read()
old='var currentSafariVersion=userAgent.includes("Safari/")&&userAgent.match(/Version\\/(\\d+\\.?\\d*\\.?\\d*)/)?humanReadableVersionToPacked(userAgent.match(/Version\\/(\\d+\\.?\\d*\\.?\\d*)/)[1]):TARGET_NOT_SUPPORTED;'
new='var currentSafariVersion=(userAgent.includes("Safari/")&&!userAgent.includes("Chrome/")&&!userAgent.includes("Android")&&userAgent.match(/Version\\/(\\d+\\.?\\d*\\.?\\d*)/))?humanReadableVersionToPacked(userAgent.match(/Version\\/(\\d+\\.?\\d*\\.?\\d*)/)[1]):TARGET_NOT_SUPPORTED;'
assert old in s, 'Safari-check pattern not found; check Godot version'
open(p,'w').write(s.replace(old,new))
PY
cd build/web
gzip -9 -k pipwreck.wasm && mv pipwreck.wasm.gz "pipwreck.$V.z.wasm"
gzip -9 -k pipwreck.pck  && mv pipwreck.pck.gz  "pipwreck.pck.$V.z.wasm"
mv pipwreck.js "pipwreck.$V.js"
cp ../../tools/web/index.html index.html
V="$V" python3 - <<'PY'
import os,re
V=os.environ['V']; p='index.html'; s=open(p).read()
w=os.path.getsize('pipwreck.wasm'); k=os.path.getsize('pipwreck.pck')
s=re.sub(r"src: 'pipwreck(\.[0-9a-f]+)?\.z\.wasm'", f"src: 'pipwreck.{V}.z.wasm'", s)
s=re.sub(r"src: 'pipwreck\.pck(\.[0-9a-f]+)?\.z\.wasm'", f"src: 'pipwreck.pck.{V}.z.wasm'", s)
s=re.sub(r'<script src="pipwreck(\.[0-9a-f]+)?\.js"></script>', f'<script src="pipwreck.{V}.js"></script>', s)
s=re.sub(r"type: 'application/wasm', size: \d+", f"type: 'application/wasm', size: {w}", s)
s=re.sub(r"type: 'application/octet-stream', size: \d+", f"type: 'application/octet-stream', size: {k}", s)
s=re.sub(r"fileSizes: \{ 'pipwreck.pck': \d+, 'pipwreck.wasm': \d+ \}", f"fileSizes: {{ 'pipwreck.pck': {k}, 'pipwreck.wasm': {w} }}", s)
if "cache: 'no-store'" not in s: s=s.replace("const res = await fetch(f.src);","const res = await fetch(f.src, { cache: 'no-store' });")
if f'build {V}' not in s: s=s.replace("<h1>Pipwreck</h1>", f"<h1>Pipwreck</h1>\n  <p style=\"font-size:12px;color:var(--muted)\">build {V}</p>")
open(p,'w').write(s)
print(f'build {V}: wasm {w} B, pck {k} B')
PY
echo "files: pipwreck.$V.js pipwreck.$V.z.wasm pipwreck.pck.$V.z.wasm"
