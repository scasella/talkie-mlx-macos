#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
import time
import traceback
from typing import Any

import mlx.core as mx
from mlx_lm.generate import stream_generate
from mlx_lm.sample_utils import make_logits_processors, make_sampler
from mlx_lm.utils import load
from transformers.utils import logging as hf_logging

hf_logging.set_verbosity_error()


def emit(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, ensure_ascii=False), flush=True)


SPECIAL_TEXT_TOKENS = ("<|endoftext|>", "<|end|>", "<|user|>", "<|assistant|>", "<|system|>")
FORBIDDEN_TOKEN_IDS = (0, 65537, 65538, 65539)
DEFAULT_TOP_K = 50
DEFAULT_REPETITION_PENALTY = 1.05
DEFAULT_FREQUENCY_PENALTY = 0.08
REPETITION_CONTEXT_SIZE = 96
SENTENCE_TERMINATORS = ".!?"
TRAILING_SENTENCE_CLOSERS = "\"')]}>”’"


def strip_special_text(text: str) -> str:
    for token in SPECIAL_TEXT_TOKENS:
        text = text.replace(token, "")
    return text


def contains_special_text(text: str) -> bool:
    return any(token in text for token in SPECIAL_TEXT_TOKENS)


def suppress_forbidden_tokens(_, logits):
    vocab_positions = mx.arange(logits.shape[-1])
    mask = vocab_positions == FORBIDDEN_TOKEN_IDS[0]
    for token_id in FORBIDDEN_TOKEN_IDS[1:]:
        mask = mask | (vocab_positions == token_id)
    return mx.where(mask[None, :], mx.full(logits.shape, -1.0e9, dtype=logits.dtype), logits)


def main() -> int:
    parser = argparse.ArgumentParser(description="Persistent MLX worker for Talkie Cabinet.")
    parser.add_argument("--model", required=True)
    args = parser.parse_args()

    emit({"type": "status", "status": "loading", "model": args.model})
    started = time.perf_counter()
    model, tokenizer = load(
        args.model,
        tokenizer_config={"trust_remote_code": True},
        lazy=False,
    )
    emit(
        {
            "type": "ready",
            "model": args.model,
            "loadSeconds": time.perf_counter() - started,
            "peakMemory": mx.get_peak_memory() / 1e9,
        }
    )

    cancelled = False

    for raw_line in sys.stdin:
        if not raw_line.strip():
            continue
        try:
            command = json.loads(raw_line)
            command_type = command.get("type")
            if command_type == "cancel":
                cancelled = True
                continue
            if command_type != "generate":
                continue

            cancelled = False
            request_id = command.get("id")
            messages = sanitize_messages(command.get("messages", []))
            max_tokens = int(command.get("max_tokens", 256))
            temperature = float(command.get("temperature", 0.7))
            top_p = float(command.get("top_p", 0.9))
            top_k = int(command.get("top_k", DEFAULT_TOP_K))
            repetition_penalty = float(command.get("repetition_penalty", DEFAULT_REPETITION_PENALTY))
            frequency_penalty = float(command.get("frequency_penalty", DEFAULT_FREQUENCY_PENALTY))
            stop_after_sentence = bool(command.get("stop_after_sentence", False))

            prompt = tokenizer.apply_chat_template(
                messages,
                tokenize=True,
                add_generation_prompt=True,
            )
            sampler = make_sampler(temp=temperature, top_p=top_p, top_k=top_k)
            logits_processors = make_logits_processors(
                repetition_penalty=repetition_penalty,
                repetition_context_size=REPETITION_CONTEXT_SIZE,
                frequency_penalty=frequency_penalty,
                frequency_context_size=REPETITION_CONTEXT_SIZE,
            )
            logits_processors.append(suppress_forbidden_tokens)

            last = None
            emitted_text = ""
            generated_text = ""
            finish_reason = "stop"
            for response in stream_generate(
                model,
                tokenizer,
                prompt,
                max_tokens=max_tokens,
                sampler=sampler,
                logits_processors=logits_processors,
            ):
                last = response
                if cancelled:
                    break
                clean_text = strip_special_text(response.text)
                if stop_after_sentence:
                    generated_text += clean_text
                    limited_text, sentence_complete = first_sentence(generated_text)
                    clean_text = limited_text[len(emitted_text) :]
                    generated_text = limited_text
                    if sentence_complete:
                        finish_reason = "sentence"
                if clean_text:
                    emitted_text += clean_text
                    emit(
                        {
                            "type": "delta",
                            "id": request_id,
                            "text": clean_text,
                            "promptTokens": int(response.prompt_tokens),
                            "promptTps": float(response.prompt_tps),
                            "generationTokens": int(response.generation_tokens),
                            "generationTps": float(response.generation_tps),
                            "peakMemory": float(response.peak_memory),
                        }
                    )
                if stop_after_sentence and finish_reason == "sentence":
                    break

            done = {
                "type": "done",
                "id": request_id,
                "finishReason": "cancelled" if cancelled else finish_reason,
                "peakMemory": mx.get_peak_memory() / 1e9,
            }
            if last is not None:
                done.update(
                    {
                        "promptTokens": int(last.prompt_tokens),
                        "promptTps": float(last.prompt_tps),
                        "generationTokens": int(last.generation_tokens),
                        "generationTps": float(last.generation_tps),
                    }
                )
            emit(done)
            mx.clear_cache()
        except Exception as exc:
            traceback.print_exc(file=sys.stderr)
            emit({"type": "error", "message": str(exc)})

    return 0


def sanitize_messages(messages: list[dict[str, Any]]) -> list[dict[str, str]]:
    sanitized: list[dict[str, str]] = []
    seen_user = False
    for message in messages:
        role = message.get("role")
        raw_content = str(message.get("content", ""))
        had_special_text = contains_special_text(raw_content)
        content = strip_special_text(raw_content).strip()
        if not content:
            continue
        if role == "system" and not seen_user:
            sanitized.append({"role": "system", "content": content})
        elif role == "user":
            seen_user = True
            sanitized.append({"role": "user", "content": content})
        elif role == "assistant" and seen_user:
            if had_special_text:
                continue
            sanitized.append({"role": "assistant", "content": content})
    return sanitized


def first_sentence(text: str) -> tuple[str, bool]:
    for index, character in enumerate(text):
        if character not in SENTENCE_TERMINATORS:
            continue

        end = index + 1
        while end < len(text) and text[end] in TRAILING_SENTENCE_CLOSERS:
            end += 1
        return text[:end], True

    return text, False


if __name__ == "__main__":
    raise SystemExit(main())
