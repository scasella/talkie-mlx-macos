#!/usr/bin/env bash
set -euo pipefail

MODEL_ID="${MODEL_ID:-scasella91/talkie-1930-13b-it-MLX-q4}"
APP_HOME="${TALKIE_CABINET_HOME:-$HOME/Library/Application Support/Talkie Cabinet}"
VENV_DIR="$APP_HOME/.venv"
MODEL_DIR="$APP_HOME/Models/talkie-1930-13b-it-MLX-q4"

mkdir -p "$APP_HOME" "$(dirname "$MODEL_DIR")"

if [[ ! -x "$VENV_DIR/bin/python" ]]; then
  python3 -m venv "$VENV_DIR"
fi

"$VENV_DIR/bin/python" -m pip install --upgrade pip
"$VENV_DIR/bin/python" -m pip install --upgrade huggingface_hub mlx mlx-lm transformers sentencepiece safetensors

HF_MODEL_ID="$MODEL_ID" HF_MODEL_DIR="$MODEL_DIR" "$VENV_DIR/bin/python" - <<'PY'
import os
from huggingface_hub import snapshot_download

model_id = os.environ["HF_MODEL_ID"]
model_dir = os.environ["HF_MODEL_DIR"]
token = os.environ.get("HF_TOKEN") or None

snapshot_download(
    repo_id=model_id,
    local_dir=model_dir,
    local_dir_use_symlinks=False,
    token=token,
)
print(f"Downloaded {model_id} to {model_dir}")
PY

cat <<EOF

Talkie Cabinet model setup complete.

Python: $VENV_DIR/bin/python
Model:  $MODEL_DIR

The app will find these automatically. You can also launch with:
TALKIE_MLX_PYTHON="$VENV_DIR/bin/python" TALKIE_MLX_MODEL="$MODEL_DIR" open -a "Talkie Cabinet"
EOF
