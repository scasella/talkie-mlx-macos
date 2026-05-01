#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

swift build --package-path "$ROOT_DIR"
python3 -m py_compile "$ROOT_DIR/Sources/TalkieCabinet/Resources/talkie_mlx_server.py"
rm -rf "$ROOT_DIR/Sources/TalkieCabinet/Resources/__pycache__"

if find "$ROOT_DIR" \
  \( -path "$ROOT_DIR/.git" -o -path "$ROOT_DIR/.build" -o -path "$ROOT_DIR/dist" -o -path "$ROOT_DIR/release" \) -prune \
  -o \( -name "__pycache__" -o -name "*.pyc" -o -name ".DS_Store" \) -print | grep -q .; then
  echo "Generated cache files found in release tree." >&2
  exit 1
fi

if grep -R --exclude=.env.example --exclude=check_release.sh --exclude-dir=.git --exclude-dir=.build --exclude-dir=dist --exclude-dir=release \
  -E 'hf_[A-Za-z0-9]{20,}|MODAL_TOKEN|TOKEN_SECRET|APPLE_APP_SPECIFIC_PASSWORD=' "$ROOT_DIR"; then
  echo "Potential credential material found." >&2
  exit 1
fi

echo "Release checks passed."
