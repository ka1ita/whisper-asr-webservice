# 003 - Split startup script; rebuild client only when it changes

**Status:** Done

## Ask

`scripts/start-docker.sh` / `.ps1` (added in [002](002-docker-compose-client-and-hf-token.md))
passed `--build` on every run, so the `client` image got rebuilt on every invocation even when
nothing under `client/` changed — slow, and unnecessary.

Split into two scripts:

- One for plain startup (start the ASR service, wait for readiness, run the client using
  whatever client image already exists — no forced rebuild).
- One for rebuilding the client image, but only if `client/` has actually changed since the
  last build.

## What was done

- [`scripts/rebuild-client.sh`](../scripts/rebuild-client.sh) /
  [`.ps1`](../scripts/rebuild-client.ps1) — hashes every file under `client/` (excluding
  `client/output/` and its own cache file), compares against the hash stored in
  `client/.docker-build-hash` (git-ignored) from the last build, and only runs
  `docker compose build client` when it differs, updating the stored hash afterwards.
  No-ops (prints and exits) when nothing changed. Runnable standalone.
- `scripts/start-docker.sh` / `.ps1` — no longer pass `--build` to the client run step;
  instead they call `rebuild-client.sh`/`.ps1` first (so a plain startup still picks up
  client changes automatically) and then `docker compose run --rm client`.
- `.gitignore` — added `/client/.docker-build-hash`.
- Docs: `client/README.md` documents the new conditional-rebuild behavior and
  `rebuild-client` usage; `CLAUDE.md` updated.

Verified manually: first run builds the client image and writes the hash file; a second run
with no changes no-ops; editing a file under `client/` (and reverting it) each triggers a
rebuild, using Docker's own layer cache so it's fast; an unrelated run afterwards no-ops again.

## Follow-ups / not done

- The ASR service (`whisper-asr-webservice(-gpu)`) still always passes `--build` in
  `start-docker` — out of scope here since the ask was specifically about the client, but the
  same approach could apply there too if it becomes a problem.
- The hash covers file contents only, not permissions/executable bits.
