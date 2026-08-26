# 004 - Script to start the client directly with Python (fast exec)

**Status:** Done

## Ask

Add a script to start the sample client ([`client/`](../client/)) directly with Python,
as a faster alternative to `scripts/start-docker.sh` / `.ps1` for local iteration — no Docker
build/startup overhead, just run `client/transcribe_client.py` against an already-running
(local or remote) ASR service.

## What was done

- [`scripts/start-client.sh`](../scripts/start-client.sh) /
  [`.ps1`](../scripts/start-client.ps1) — creates/reuses a venv at `client/.venv`
  (`.venv` was already git-ignored globally), (re)installs `client/requirements.txt` only
  when its hash differs from the last install (cached in `client/.venv/.requirements.hash`,
  now git-ignored), then runs `client/transcribe_client.py`, forwarding any extra CLI args
  (e.g. `--config other.yaml`).
- Picks a working Python interpreter defensively: tries `python3`/`python` by actually
  invoking `--version` (not just `command -v`), since on Windows a `python3` shim can exist
  on `PATH` but fail to execute — the Microsoft Store alias hit exactly this during testing —
  then falls back to `py -3`.
- `.gitignore` — added `/client/.venv/.requirements.hash`.
- Docs: `client/README.md` documents the script as the fastest local option; `CLAUDE.md`
  updated.

Verified manually: first run creates the venv and installs deps (~a few seconds); second run
with unchanged `requirements.txt` skips install entirely and runs in about a second.

## Follow-ups / not done

- No equivalent "only reinstall if changed" script existed for the main project's Poetry env —
  out of scope, `poetry install` already handles that itself.
