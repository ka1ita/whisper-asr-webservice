# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Whisper ASR Webservice is a FastAPI-based speech recognition webservice built around OpenAI's Whisper models. It exposes a REST API (`/asr`, `/detect-language`) that transcribes/translates audio and supports multiple interchangeable ASR engines.

## Commands

```shell
# Install poetry v2.X, then install deps (choose one extra)
pip3 install poetry
poetry install --extras cpu    # or: poetry install --extras cuda

# Run the service locally
poetry run whisper-asr-webservice --host 0.0.0.0 --port 9000
# Swagger UI at http://localhost:9000/docs

# Lint / format (configured in pyproject.toml, not wired into CI)
poetry run ruff check .
poetry run black .

# Tests
poetry run pytest
```

There is currently no `tests/` directory and no lint/test job in CI — `.github/workflows/` only builds and publishes Docker images on tag push. If you add tests, `pytest` is already a dev dependency and will pick them up.

Docker builds: `Dockerfile` (CPU) and `Dockerfile.gpu` (CUDA); see `docker-compose.yml` / `docker-compose.gpu.yml` for local container runs. Both compose files load `.env` (copy from `.env.example`; git-ignored) via `env_file` for secrets like `HF_TOKEN`, and define a `client` service (profile `client`, so it's excluded from a plain `docker compose up`) that runs the sample client in `client/` against the ASR service. `./scripts/start-docker.sh` / `.ps1` wraps: start the ASR service, wait for readiness, rebuild the client image only if `client/` changed (`./scripts/rebuild-client.sh` / `.ps1`, hash-gated via `client/.docker-build-hash`), run the client. For fast local iteration without Docker, `./scripts/start-client.sh` / `.ps1` runs the client directly with Python (manages a venv at `client/.venv`, reinstalling `requirements.txt` only when it changes).

## Architecture

- `app/webservice.py` — FastAPI app and route definitions (`/asr`, `/detect-language`). Instantiates a single global `asr_model` at import time via `ASRModelFactory` and loads it immediately (`asr_model.load_model()`), so the model is created once per process, not per request.
- `app/factory/asr_model_factory.py` — picks the concrete engine class based on `CONFIG.ASR_ENGINE`.
- `app/asr_models/asr_model.py` — `ASRModel` abstract base class every engine implements (`load_model`, `transcribe`, `language_detection`), plus shared idle-timeout logic (`monitor_idleness`/`release_model`) that unloads the model from memory/GPU after `MODEL_IDLE_TIMEOUT` seconds of inactivity.
- `app/asr_models/{openai_whisper,faster_whisper,mbain_whisperx}_engine.py` — the three interchangeable engine implementations (`openai_whisper`, `faster_whisper`, `whisperx`). Adding a new engine means implementing `ASRModel` and registering it in the factory.
- `app/config.py` — single `CONFIG` class reading all runtime configuration from environment variables (`ASR_ENGINE`, `ASR_MODEL`, `ASR_DEVICE`, `MODEL_IDLE_TIMEOUT`, etc.), with device/quantization defaults derived from `torch.cuda.is_available()`. This is the source of truth for supported env vars — check it before assuming a config option exists.
- `app/utils.py` — audio loading/decoding helpers (ffmpeg-based) shared across engines.
- The `/asr` endpoint funnels all engine-specific options (`vad_filter`, `word_timestamps`, diarization params) through a single `transcribe(...)` call; engines that don't support an option (e.g. VAD is `faster_whisper`-only, diarization is `whisperx`-only) ignore it, and the Swagger schema conditionally hides params that don't apply to the currently configured `ASR_ENGINE`.
- Output formatting (`txt`, `vtt`, `srt`, `tsv`, `json`) is handled per-engine and streamed back via `StreamingResponse`.

## Documentation

User-facing docs live under `docs/` (mkdocs-material, published via `.github/workflows/documentation.yml`) — `docs/endpoints.md`, `docs/environmental-variables.md`, `docs/run.md`, `docs/build.md` mirror what's implemented in `app/`; update both together when changing API behavior or config options.
