# 002 - Docker Compose script for asr-service + client, HF token via env file

**Status:** Done

## Ask

- Add a script to start, via docker compose, both the ASR service and the sample client
  ([`client/`](../client/), added in [001](001-sample-audio-and-client.md)).
- Add Hugging Face token (`HF_TOKEN`) support through an env file.

## What was done

- [`.env.example`](../.env.example) — template for `HF_TOKEN` and other overridable env vars
  (`ASR_ENGINE`, `ASR_MODEL`). Copy to `.env` (git-ignored) to use.
- `docker-compose.yml` / `docker-compose.gpu.yml`:
  - `whisper-asr-webservice(-gpu)` now loads `./.env` via `env_file` (`required: false`, so
    it works fine with no `.env` present) — this is how `HF_TOKEN` reaches the container.
  - Added a `client` service, gated behind the `client` compose profile so it never starts
    with a plain `docker compose up`. It builds [`client/Dockerfile`](../client/Dockerfile),
    mounts `./audio` read-only and `./client/output` for results, and points the client at
    the ASR service via `ASR_CLIENT_SERVER_URL`/`ASR_CLIENT_AUDIO_DIR`/`ASR_CLIENT_OUTPUT_DIR`
    env vars.
- `client/transcribe_client.py` — now reads those three `ASR_CLIENT_*` env vars as overrides
  over `config.yaml`, so the same config file works both locally and in the container.
- `client/Dockerfile` + `client/.dockerignore` — minimal image to run the client.
- [`scripts/start-docker.sh`](../scripts/start-docker.sh) and
  [`scripts/start-docker.ps1`](../scripts/start-docker.ps1) — copy `.env.example` to `.env`
  if missing, start the ASR service, poll `/docs` until ready (5 min soft timeout), then run
  the `client` service.
- Docs: `docs/environmental-variables.md` HF Token section now mentions the `.env` route;
  `client/README.md` documents the docker-compose flow; `CLAUDE.md` updated.

## Follow-ups / not done

- No CI coverage for the compose files or the client Dockerfile build.
- The readiness poll is a fixed-count loop, not a proper `healthcheck:`/`depends_on: condition:
  service_healthy` — the webservice has no health endpoint to depend on today.
