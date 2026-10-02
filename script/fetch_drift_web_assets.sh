#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
release='https://github.com/simolus3/drift/releases/download/drift-2.35.0'
for asset in sqlite3.wasm drift_worker.js; do
  curl --fail --location --retry 2 "$release/$asset" --output "$root/web/$asset"
done
(cd "$root" && shasum -a 256 -c web/drift-assets.sha256)
