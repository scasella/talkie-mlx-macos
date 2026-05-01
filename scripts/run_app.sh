#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/Talkie Cabinet.app"

"$ROOT_DIR/scripts/build_app.sh" >/dev/null
/usr/bin/open -n "$APP_BUNDLE"
