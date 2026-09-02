# 014 - Rename `whisper-asr-webservice` to `asr-webservice`

**Status:** Done

## Ask

Rename the project identifier from `whisper-asr-webservice` to `asr-webservice`. The service is
no longer Whisper-only (faster-whisper, whisperx, gigaam engines), so the name should drop the
`whisper-` prefix.

## Scope

`whisper-asr-webservice` currently appears in 30 files. Occurrences fall into three groups that
need different handling:

### 1. Must change together — Python package identity

- [`pyproject.toml`](../pyproject.toml)
  - `name = "whisper-asr-webservice"` (line 2) → `asr-webservice`
  - `[project.scripts]` entry point `whisper-asr-webservice = "app.webservice:start"` (line 38)
    → `asr-webservice = ...`
- [`app/webservice.py`](../app/webservice.py) line 25 —
  `importlib.metadata.metadata("whisper-asr-webservice")` must match the new package `name` or
  startup crashes with `PackageNotFoundError`.
- Any docs referencing `poetry run whisper-asr-webservice` (see [`CLAUDE.md`](../CLAUDE.md),
  [`docs/run.md`](../docs/run.md)) — the console command changes with the entry point.

### 2. Local compose/service names (safe to rename, self-contained)

- [`docker-compose.yml`](../docker-compose.yml) — service `whisper-asr-webservice` (line 4),
  `depends_on` (line 30), `ASR_CLIENT_SERVER_URL=http://whisper-asr-webservice:9000` (line 32).
- [`docker-compose.gpu.yml`](../docker-compose.gpu.yml) — service `whisper-asr-webservice-gpu`
  (line 4), `depends_on` (line 33), `ASR_CLIENT_SERVER_URL` (line 35).
- [`scripts/*.sh`](../scripts/) — `docker-start.sh`, `docker-stop.sh`, `docker-rebuild.sh`,
  `docker-restart.sh`, `python-start.sh` reference the compose service name.
- [`scripts/offline/`](../scripts/offline/) — `build-offline-image.sh`,
  `docker-compose.offline.yml`, `warmup_models.py`, `README.md`.
- [`client/config.yaml`](../client/config.yaml), [`client/transcribe_client.py`](../client/transcribe_client.py),
  [`client/README.md`](../client/README.md) — comment/URL references to the service name.

### 3. Upstream project references — left as-is (see Decisions)

These point at the upstream repo this fork descends from, not the local artifact name:

- [`pyproject.toml`](../pyproject.toml) lines 34-35 — `Homepage` / `Repository` =
  `https://github.com/ahmetoner/whisper-asr-webservice`
- [`app/webservice.py`](../app/webservice.py) line 32 — `license_info` URL
- [`mkdocs.yml`](../mkdocs.yml) — `site_url`, `repo_url`, `repo_name`, release/Docker Hub links
- [`README.md`](../README.md), [`CHANGELOG.md`](../CHANGELOG.md), [`docs/index.md`](../docs/index.md),
  [`docs/build.md`](../docs/build.md) — Docker image names (`onerahmet/openai-whisper-asr-webservice`),
  historical changelog entries.
- [`tasks/001`, `tasks/002`, `tasks/003`, `tasks/010`](../tasks/) — historical task notes; do not
  rewrite history.

## Decisions

1. Upstream GitHub/Docker Hub URLs (group 3): **left unchanged** — this fork is not published
   under a new name. Applies to `pyproject.toml` `[project.urls]`, `app/webservice.py`
   `license_info` URL, `Dockerfile`/`Dockerfile.gpu` `org.opencontainers.image.source` label,
   `mkdocs.yml`, `README.md` badges, `CHANGELOG.md` release links, `docs/run.md` /
   `docs/index.md` Docker Hub image (`onerahmet/openai-whisper-asr-webservice`).
2. CI image tags: nothing to change — `.github/workflows/docker-publish.yml` takes the image
   name from `secrets.REPO_NAME`, not a hardcoded string.
3. Historical task notes (`tasks/001`, `002`, `003`, `010`): left as written — history.

## What was done

Group 1 — Python package identity:

- [`pyproject.toml`](../pyproject.toml) — `name` → `asr-webservice`; `[project.scripts]` entry
  point → `asr-webservice = "app.webservice:start"`.
- [`app/webservice.py`](../app/webservice.py) line 25 —
  `importlib.metadata.metadata("asr-webservice")`. (FastAPI `title` now renders as
  "Asr Webservice".)
- [`Dockerfile`](../Dockerfile), [`Dockerfile.gpu`](../Dockerfile.gpu) —
  `ENTRYPOINT ["asr-webservice"]`.
- CLI-command references in [`CLAUDE.md`](../CLAUDE.md), [`README.md`](../README.md),
  [`docs/build.md`](../docs/build.md) → `poetry run asr-webservice`.

Group 2 — compose service names, script vars, local image tags, doc/comment prose:

- [`docker-compose.yml`](../docker-compose.yml) — service `asr-webservice`, `depends_on`,
  `ASR_CLIENT_SERVER_URL=http://asr-webservice:9000`.
- [`docker-compose.gpu.yml`](../docker-compose.gpu.yml) — service `asr-webservice-gpu` (+
  `depends_on`, `ASR_CLIENT_SERVER_URL`).
- [`scripts/`](../scripts/) — `docker-start.sh`, `docker-stop.sh`, `docker-rebuild.sh`,
  `docker-restart.sh`, `python-start.sh` (`service=` vars + header comments).
- [`scripts/offline/`](../scripts/offline/) — `build-offline-image.sh` (local `tag=` values,
  now `asr-webservice:offline` / `:offline-gpu`), `docker-compose.offline.yml` (service +
  `image: asr-webservice:offline-preloaded`), `README.md`, `warmup_models.py` docstring.
- [`docs/build.md`](../docs/build.md) — local `docker build -t` / `docker run` examples →
  `asr-webservice` / `asr-webservice-gpu`.
- [`client/config.yaml`](../client/config.yaml), [`client/transcribe_client.py`](../client/transcribe_client.py),
  [`client/README.md`](../client/README.md), [`.env.example`](../.env.example) — prose/comment
  references to the service.

The offline transfer tar filenames (`whisper-asr-preloaded.tar` / `-gpu.tar`) were left as-is
— different string, not the project identifier.

## Verified

- `grep -rn 'whisper-asr-webservice'` now returns only intentionally-kept upstream URLs / image
  names / shields (see Decisions) and the historical `tasks/` notes.
- Not run in this environment: `poetry install` / service start / `docker compose` — user to
  confirm `poetry run asr-webservice ...` works and the containers build. The package `name`
  and the `importlib.metadata.metadata()` argument were changed together, so the metadata
  lookup will not raise `PackageNotFoundError` after a reinstall.

## Follow-ups / not done

- `poetry.lock` needs no change (the project itself is not a locked entry; confirmed no match).
- An existing editable install from before the rename will still expose the old
  `whisper-asr-webservice` console script until `poetry install` is re-run.
- `pyproject.toml` `description` still reads "Whisper ASR Webservice is a general-purpose
  speech recognition webservice." — left untouched (not the identifier); revisit if the
  Swagger title/description should drop "Whisper" too.
