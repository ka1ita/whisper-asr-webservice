# 017 - Offline image slept instead of running asr-webservice

**Status:** Done

## Ask

- After building the offline image (user referenced the pre-016 path
  `deploy/dev/scripts/offline/build-offline-image.sh`; it now lives at
  `deploy/dev/offline/build-offline-image.sh`), the container started from
  `asr-webservice:offline` never started the Python webservice — it only ran
  `sleep infinity`. Fix it: the offline image should run `asr-webservice`.

## Root cause

The build script starts its warm-up container with
`docker run --entrypoint sh <base> -c "sleep infinity"` (so models can be downloaded via
`docker exec`), then snapshots it with `docker commit`. `docker commit` persists the
container's *runtime config* — not just its filesystem — so the committed image inherited
`ENTRYPOINT sh` + `CMD ["-c", "sleep infinity"]` from the warm-up container. Every
`docker run asr-webservice:offline` therefore slept forever.

## What was done

- [`deploy/dev/offline/build-offline-image.sh`](../deploy/dev/offline/build-offline-image.sh)
  - `docker commit` now restores the Dockerfile config:
    `--change 'ENTRYPOINT ["asr-webservice"]' --change 'CMD []'`. Clearing CMD matters:
    the leftover `-c sleep infinity` args would otherwise be fed to the click CLI
    (`app.webservice:start` only accepts `--host`/`--port`).
  - Added a post-commit `docker image inspect` printout of Entrypoint/Cmd so a regression
    is visible in the build output.
  - Moved `HF_TOKEN` from `docker run -e` to `docker exec -e`. Runtime `-e` env is part of
    the container config that `docker commit` snapshots, so the old script baked the token
    into the exported image (the README explicitly claimed it didn't). Exec-time env never
    enters the container config. Same warning behavior: without the token, gated models are
    skipped with a warning.
- [`deploy/dev/offline/docker-compose.offline.yml`](../deploy/dev/offline/docker-compose.offline.yml)
  — pinned `entrypoint: ["asr-webservice"]`. This un-bricks offline images committed by the
  old script (already exported/loaded on the isolated server) without rebuilding and
  re-shipping the tens-of-GB tar; the fixed build no longer needs it, but it's harmless.
- [`deploy/dev/offline/README.md`](../deploy/dev/offline/README.md) — updated the build
  description: mentions the entrypoint restore and states precisely how HF_TOKEN is passed
  (to the download exec, not the container config).

## Verified

- `bash -n` on the build script, `yaml.safe_load` and `docker compose config` on the compose
  file — all pass.
- The commit-config mechanism is confirmed by the reported symptom itself (the image
  sleeping proves commit inherits the run-time entrypoint/cmd).
- Not run here: the full build (daemon not running in this environment; it downloads tens of
  GB). User to confirm `./deploy/dev/offline/build-offline-image.sh` output now prints
  `Entrypoint: ["asr-webservice"] Cmd: []` and the image serves on :9000.

## Follow-ups / not done

- The stale worktree `.claude/worktrees/offline-image-asr-webservice-8302f3/` still has the
  old scripts (pre-016 layout, unfixed) — left untouched, as in task 016.
