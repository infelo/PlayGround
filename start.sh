#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
/usr/bin/time -p mkdir -p dist
# No npm dependencies for this static single-file game; install only if a package.json ever appears.
/usr/bin/time -p bash -c 'if [ -f package.json ]; then npm install --no-audit --no-fund; fi'
/usr/bin/time -p cp -f dragon5d.html dist/index.html
/usr/bin/time -p bash -c 'web_dir="${OPENCODE_WEB_DIR:-/home/runner/work/_temp/omgithub-web}"; mkdir -p "$web_dir"; proj="$(pwd)"; printf "%s" "{\"project\":\"$proj\",\"directory\":\"$proj/dist\"}" > "$web_dir/deployment-output.json"; cat "$web_dir/deployment-output.json"; echo'
/usr/bin/time -p python3 -m http.server "${PORT:-3000}" --directory dist --bind 0.0.0.0
