# 005 - Refactor scripts/ to bash-only, four scripts

**Status:** Done

## Ask

Refactor [`scripts/`](../scripts/): drop the PowerShell (`.ps1`) variants and keep bash
(`.sh`) only. Consolidate the current six scripts (`rebuild-client.sh`, `start-client.sh`,
`start-docker.sh`, and their `.ps1` counterparts) into four:

- `docker-rebuild.sh` — rebuild the docker compose ASR service image *and* the client image.
- `docker-start.sh` — run the ASR service and client (no rebuild).
- `docker-stop.sh` — stop the ASR service and client.
- `python-start.sh` — run the client directly with Python (no Docker).

## Current state (for reference)

- [`scripts/start-docker.sh`](../scripts/start-docker.sh) — starts the ASR service with
  `docker compose up -d --build` (always rebuilds the service image), waits for readiness,
  calls `rebuild-client.sh` (conditional client rebuild), then `docker compose run --rm client`.
- [`scripts/rebuild-client.sh`](../scripts/rebuild-client.sh) — hashes `client/` and rebuilds
  the client image only when it changed (`client/.docker-build-hash`). Does not touch the
  ASR service image.
- [`scripts/start-client.sh`](../scripts/start-client.sh) — runs `client/transcribe_client.py`
  directly via a venv at `client/.venv`, reinstalling `requirements.txt` only when changed.
- No stop script currently exists (`docker compose down` is run manually).
- `.ps1` versions of all three duplicate the above for native PowerShell.

## Plan

- `docker-rebuild.sh`: combine today's service `--build` step (from `start-docker.sh`) with
  `rebuild-client.sh`'s hash-gated client rebuild, so both images get rebuilt in one command
  (service unconditionally per `docker compose build`, client only if `client/` changed).
- `docker-start.sh`: today's `start-docker.sh` minus `--build` — start the service, wait for
  readiness, run the client — assuming images already exist (built via `docker-rebuild.sh`
  at least once).
- `docker-stop.sh`: new — `docker compose -f <compose_file> down` (or equivalent) for the
  service + client.
- `python-start.sh`: rename of `start-client.sh`, behavior unchanged.
- Delete all `.ps1` scripts; update `CLAUDE.md` and `client/README.md` references
  accordingly (drop PowerShell usage notes, update script names).
- Both `docker-*` scripts keep the existing `gpu` positional arg to select
  `docker-compose.gpu.yml` / the `-gpu` service name.

## What was done

- [`scripts/docker-rebuild.sh`](../scripts/docker-rebuild.sh) — `docker compose build` on the
  ASR service (always) plus the client's existing hash-gated conditional rebuild (from the old
  `rebuild-client.sh`), combined into one script.
- [`scripts/docker-start.sh`](../scripts/docker-start.sh) — old `start-docker.sh` minus
  `--build`: starts the service from whatever images already exist, waits for readiness, runs
  the client.
- [`scripts/docker-stop.sh`](../scripts/docker-stop.sh) — new; `docker compose down` (stops
  containers/network, leaves images and the `cache-whisper` volume in place).
- [`scripts/python-start.sh`](../scripts/python-start.sh) — straight rename of
  `start-client.sh`, behavior unchanged.
- Deleted `start-docker.sh`, `rebuild-client.sh`, `start-client.sh` and all `.ps1`
  counterparts — `scripts/` is bash-only now.
- Updated references in `CLAUDE.md`, `client/README.md`, and `.gitignore` comments.

Verified: all four new scripts pass `bash -n` (syntax check); the hash-gating logic in
`docker-rebuild.sh` is unchanged from the already-verified `rebuild-client.sh` (task
[003](003-split-startup-and-conditional-client-rebuild.md)). Did not do a live end-to-end
`docker compose build`/`up` run (pulls large ML deps / model weights — too heavy to trigger
as part of this refactor); recommend a manual smoke test (`docker-rebuild.sh` →
`docker-start.sh` → `docker-stop.sh`) before relying on this in CI or onboarding docs.

## Follow-ups / not done

- Windows users now need Git Bash/WSL to run these scripts (no native PowerShell versions
  anymore), per the ask.
- `docker-stop.sh` only stops containers; add an `--rmi`/`--volumes` option later if a "full
  clean" variant turns out to be needed.
