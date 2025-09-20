#!/bin/bash
set -e

MODE="${RUN_MODE:-ui}"

if [ "$MODE" = "serverless" ]; then
  echo "Starting ComfyUI in background..."
  /workspace/start.sh &

  # Wait for ComfyUI HTTP to be ready
  for i in $(seq 1 90); do
    if curl -s http://127.0.0.1:8188/ >/dev/null 2>&1; then
      echo "ComfyUI is ready"
      break
    fi
    sleep 2
  done

  echo "Starting Runpod handler..."
  exec python3 /workspace/handler.py
else
  echo "Starting in UI mode..."
  # Runtime'da Qwen modeli yoksa indirmeyi dene (HF token destekli)
  if [ ! -f "/workspace/ComfyUI/models/checkpoints/${QWEN_FILENAME}" ]; then
    echo "Qwen model not found; trying to download at runtime..."
    python3 - <<'PY'
import os
from huggingface_hub import hf_hub_download

repo_id = os.environ.get('QWEN_REPO_ID', 'Qwen/Qwen-Image')
filename = os.environ.get('QWEN_FILENAME', 'qwen_image_distill_full_bf16.safetensors')
token = os.environ.get('HF_TOKEN')
target_dir = '/workspace/ComfyUI/models/checkpoints'

try:
    path = hf_hub_download(repo_id=repo_id, filename=filename, token=token, local_dir=target_dir, local_dir_use_symlinks=False)
    print(f'Downloaded to: {path}')
except Exception as e:
    print(f'Runtime download failed: {e}')
PY
  fi
  exec /workspace/start.sh
fi


