#!/usr/bin/env bash
set -euo pipefail

REPO_ID="${HF_REPO_ID:-scasella91/talkie-1930-13b-it-MLX-q4}"
SOURCE_MODEL_DIR="${1:-}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -z "$SOURCE_MODEL_DIR" || ! -d "$SOURCE_MODEL_DIR" ]]; then
  echo "usage: $0 /path/to/talkie-1930-13b-it-MLX-q4" >&2
  exit 2
fi

if [[ -z "${HF_TOKEN:-}" && -z "${HUGGING_FACE_HUB_TOKEN:-}" ]]; then
  echo "Set HF_TOKEN or HUGGING_FACE_HUB_TOKEN before publishing." >&2
  exit 2
fi

python3 - <<'PY' "$REPO_ID" "$SOURCE_MODEL_DIR" "$ROOT_DIR/docs/huggingface-model-card.md"
import os
import sys
from pathlib import Path
from huggingface_hub import HfApi

repo_id = sys.argv[1]
source_dir = Path(sys.argv[2])
card_path = Path(sys.argv[3])
token = os.environ.get("HF_TOKEN") or os.environ.get("HUGGING_FACE_HUB_TOKEN")
api = HfApi(token=token)

api.create_repo(
    repo_id=repo_id,
    repo_type="model",
    private=False,
    exist_ok=True,
)

api.upload_folder(
    repo_id=repo_id,
    repo_type="model",
    folder_path=str(source_dir),
    commit_message="Upload Talkie MLX q4 model",
    ignore_patterns=[".DS_Store", "__pycache__/*", "*.pyc"],
)

api.upload_file(
    repo_id=repo_id,
    repo_type="model",
    path_or_fileobj=str(card_path),
    path_in_repo="README.md",
    commit_message="Add Talkie MLX q4 model card",
)

print(f"Published {repo_id}")
PY
