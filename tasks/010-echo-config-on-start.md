# 010 - Echo ASR_ENGINE, ASR_MODEL, and other params for asr webservice on start

**Status:** Done

## Ask

On startup, log/echo the effective runtime configuration — `ASR_ENGINE`, `ASR_MODEL`
(`CONFIG.MODEL_NAME`), and other relevant `CONFIG` params (device, quantization, model path,
idle timeout, etc.) — so it's visible in the container/process logs which settings the service
is actually running with.

## What was done

- [`app/config.py`](../app/config.py) — added a `print()` at the end of the `CONFIG` class body
  (after all env vars are resolved) that logs a single `Starting with config: ...` line with
  `ASR_ENGINE`, `ASR_MODEL`, `ASR_DEVICE`, `ASR_QUANTIZATION`, `ASR_MODEL_PATH`,
  `MODEL_IDLE_TIMEOUT`, and `HF_TOKEN` (logged as `set`/`unset` rather than the raw secret value).
  Runs once at import time, same as the existing `HF_TOKEN` warning prints already in that file.

## Verified

- `python -m py_compile app/config.py` passes. Could not exercise the actual import/print output
  in this environment (`torch` and `poetry` aren't available on the local Python/PATH), so the
  print statement itself wasn't run — only syntax-checked. Should be confirmed with
  `poetry run whisper-asr-webservice` or `./scripts/docker-rebuild.sh` + `docker-start.sh`.

## Follow-ups / not done

- `docs/environmental-variables.md` documents each env var already; not updated since this is a
  logging-only change with no new/renamed config options.
