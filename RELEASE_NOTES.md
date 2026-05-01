# Talkie Cabinet v0.1.0

Initial public macOS release of Talkie Cabinet, a native SwiftUI/MLX app for
running Talkie 1930 13B locally on Apple Silicon.

## Highlights

- Native macOS interface built around The Listening Bureau design system.
- Local MLX q4-safe model path using `scasella91/talkie-1930-13b-it-MLX-q4`.
- Prompt slips, transcript ledger, payload preview, context meter, stop/retry,
  and Signal Inspector.
- Signed and notarized DMG: `Talkie-Cabinet-v0.1.0.dmg`.

## Install

1. Download the DMG.
2. Drag **Talkie Cabinet.app** to Applications.
3. Run `./scripts/download_model.sh` once to install the MLX Python environment
   and model under `~/Library/Application Support/Talkie Cabinet`.
4. Open Talkie Cabinet.

## Validation

Validated locally on a MacBook Pro with M4 Pro and 24 GB unified memory:

- Model directory: about 8.8 GB on disk.
- App-reported peak memory: about 9.7 GB.
- Typical short-turn decode: roughly 20-25 tok/s after load.
- Coherent short-turn smoke prompts and prompt-slip generation.

## Links

- MLX model: <https://huggingface.co/scasella91/talkie-1930-13b-it-MLX-q4>
- Browser/WebGPU release: <https://github.com/scasella/talkie-quant-webgpu>
- Source model: <https://huggingface.co/lewtun/talkie-1930-13b-it-hf>
