---
license: apache-2.0
language:
- en
library_name: mlx
tags:
- talkie
- mlx
- apple-silicon
- macos
- quantization
- q4
- llm
- text-generation
- historical
- vintage
- pre-1931
base_model: lewtun/talkie-1930-13b-it-hf
pipeline_tag: text-generation
---

# Talkie 1930 13B IT MLX q4

Unofficial community MLX q4 release of
[`lewtun/talkie-1930-13b-it-hf`](https://huggingface.co/lewtun/talkie-1930-13b-it-hf),
prepared for local Apple Silicon inference with
[`Talkie Cabinet`](https://github.com/scasella/talkie-mlx-macos).

This is not an official Talkie release. It is a Mac-oriented companion to the
browser/WebGPU ONNX release:
[`scasella91/talkie-1930-13b-it-ONNX`](https://huggingface.co/scasella91/talkie-1930-13b-it-ONNX).

## Credit To Talkie

This repo packages `talkie-1930-13b-it`, a 13B-parameter instruction-tuned
language model from the [`talkie`](https://github.com/talkie-lm/talkie) family
developed by **Alec Radford, Nick Levine, and David Duvenaud**. Talkie was
pretrained on 260B tokens of pre-1931 English-language text and
instruction-tuned with a dataset extracted from vintage reference works,
including etiquette manuals, encyclopedias, letter-writing guides, and poetry
collections. The instruction model also used reinforcement learning via online DPO
with an LLM-as-a-judge to improve instruction following.

Read more in the [Talkie report](https://talkie-lm.com).

## Files

The repo contains the MLX model shards plus the tokenizer/config/chat-template
files needed by Talkie Cabinet:

- `model-00001-of-00002.safetensors`
- `model-00002-of-00002.safetensors`
- `model.safetensors.index.json`
- `config.json`
- `generation_config.json`
- `tokenizer.json`
- `tokenizer_config.json`
- `chat_template.jinja`
- `talkie_mlx.py`

## Validation Notes

The published q4-safe candidate keeps the language-model head and attention
value projections in BF16. It uses more memory than the smaller q4 experiment,
but avoids the short-prompt collapse observed in that smaller artifact.

Observed on a MacBook Pro with M4 Pro and 24 GB unified memory:

- On-disk model directory: about 8.8 GB.
- App-reported peak memory: about 9.7 GB.
- Typical short-turn decode after load: roughly 20-25 tok/s.
- Local load after setup: about 3 seconds.

## Use With Talkie Cabinet

```bash
git clone https://github.com/scasella/talkie-mlx-macos.git
cd talkie-mlx-macos
./scripts/download_model.sh
./scripts/run_app.sh
```

The setup script downloads this repo to:

```text
~/Library/Application Support/Talkie Cabinet/Models/talkie-1930-13b-it-MLX-q4
```

## Attribution

- Original Talkie researchers: Alec Radford, Nick Levine, and David Duvenaud
- Talkie report: [`talkie-lm.com`](https://talkie-lm.com)
- Source model: [`lewtun/talkie-1930-13b-it-hf`](https://huggingface.co/lewtun/talkie-1930-13b-it-hf)
- Original project: [`talkie-lm/talkie`](https://github.com/talkie-lm/talkie)
- Mac app: [`scasella/talkie-mlx-macos`](https://github.com/scasella/talkie-mlx-macos)
- Browser/WebGPU release: [`scasella/talkie-quant-webgpu`](https://github.com/scasella/talkie-quant-webgpu)
