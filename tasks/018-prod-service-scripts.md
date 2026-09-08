# 018 - Prod service scripts for the offline image

**Status:** Done

## Ask

- Add `service-start`, `service-stop`, `service-restart`, `service-logs` scripts to
  `deploy/prod/`, running the preloaded image `asr-webservice:offline` via docker compose.

## Scope

`deploy/prod/` until now only held `dist/` (the git-ignored drop zone for the offline image
tarballs). Step 3 of the offline README told the operator to run raw
`docker compose -f deploy/dev/offline/docker-compose.offline.yml up -d` on the isolated
server — dev-side tooling, requiring the whole repo over there. This task gives
`deploy/prod/` its own runtime: a compose file pinned to the offline image plus the four
service scripts, so the folder can be copied to the server as-is (see task 015 for the
dev/prod audience split).

## Decisions

1. New `deploy/prod/docker-compose.yml` instead of pointing the scripts at
   `deploy/dev/offline/docker-compose.offline.yml` — the prod folder must be
   self-contained for the transfer; the offline compose stays for dev-side verification.
2. Unlike the dev scripts (which `cd` to `repo_root`), the prod scripts `cd` to their own
   directory and use the co-located compose file — no repo needed on the server.
3. Config via `.env` next to the compose file rather than editing the file: the compose
   interpolates `${ASR_ENGINE:-gigaam}`, `${ASR_MODEL:-v3_ctc}`, `${HF_TOKEN:-}` and
   `${ASR_IMAGE:-asr-webservice:offline}` (the `:-` defaults keep it zero-config, and the
   `ASR_IMAGE` knob selects the GPU tag `asr-webservice:offline-gpu` without a second
   compose file). Compose v2 resolves `.env` from the compose file's directory, so this
   works both via the scripts and via a raw `docker compose -f deploy/prod/...`.
4. `restart: unless-stopped` added to the prod service (absent from dev/offline composes) —
   a prod box should bring the webservice back after a daemon restart / host reboot;
   `docker compose down` in service-stop.sh still wins over it.
5. No `version:` key (the dev composes' `version: "3.4"` is obsolete in compose v2 and would
   print a warning on every script invocation), and a fixed top-level
   `name: asr-webservice-prod` so the compose project doesn't depend on the folder's name
   on the server — renaming the copied folder must not silently create a second stack
   next to the first (which would then lose the port-9000 race).
6. Kept the `entrypoint: ["asr-webservice"]` pin from the offline compose: the 35 GB tar
   currently sitting in `deploy/prod/dist/` (`whisper-asr-preloaded.tar`, built Sep 7)
   predates the task-017 commit fix, so its image would sleep without the pin.
7. service-start.sh preflights the image (`docker compose config --images` resolves the
   same `ASR_IMAGE` default / `.env` interpolation compose would use) and tells the
   operator to `docker load -i` the tar — otherwise compose tries to *pull* on the
   air-gapped host with a confusing network error. Readiness wait mirrors the dev scripts
   (curl `/docs`, 60×5s) but exits non-zero with a pointer to service-logs.sh on timeout,
   and skips itself if curl isn't installed.
8. service-logs.sh defaults to `logs -f --tail 100 asr-webservice`; any args replace the
   defaults and pass through to `docker compose logs` (`--no-color`, `--since`, ...).

## What was done

- [`deploy/prod/docker-compose.yml`](../deploy/prod/docker-compose.yml) — new (decisions
  3–5 above; header comment documents the `.env` mechanism and the missing-volume rationale).
- [`deploy/prod/service-start.sh`](../deploy/prod/service-start.sh) — image preflight,
  `up -d`, readiness wait.
- [`deploy/prod/service-stop.sh`](../deploy/prod/service-stop.sh) — `down` (image stays).
- [`deploy/prod/service-restart.sh`](../deploy/prod/service-restart.sh) —
  `up -d --force-recreate` (env changes) + readiness wait.
- [`deploy/prod/service-logs.sh`](../deploy/prod/service-logs.sh) — follow logs, arg
  passthrough.
- [`deploy/prod/README.md`](../deploy/prod/README.md) — new: server-side setup
  (load tar, `.env` options) + day-to-day commands.
- [`deploy/dev/offline/README.md`](../deploy/dev/offline/README.md) — transfer step now
  says to copy `deploy/prod/` too; "load and run" leads with
  `docker load` + `./deploy/prod/service-start.sh`, with the old raw-compose/run
  alternatives kept as the underlying commands.
- [`deploy/dev/offline/export-offline-image.sh`](../deploy/dev/offline/export-offline-image.sh)
  — header and closing message now end in `./deploy/prod/service-start.sh` (and mention
  copying `deploy/prod/`); keep-in-sync comment extended to the prod compose.
- [`deploy/dev/offline/build-offline-image.sh`](../deploy/dev/offline/build-offline-image.sh)
  — keep-in-sync comment extended the same way.
- [`CLAUDE.md`](../CLAUDE.md) — tooling paragraph now describes `deploy/prod/` as the
  self-contained server runtime (compose + service scripts, `.env`-driven).

## Verified

- `bash -n` passes on all four scripts.
- `docker compose -f deploy/prod/docker-compose.yml config` renders with the expected
  defaults (`asr-webservice:offline`, `gigaam`/`v3_ctc`, entrypoint pin, restart policy,
  no obsolete-`version` warning); `config --images` prints `asr-webservice:offline`; env
  vars (`HF_TOKEN`, `ASR_IMAGE`, `ASR_ENGINE`, `ASR_MODEL`) and a `.env` file next to the
  compose all override correctly.
- Full smoke test on this machine (daemon was up and the offline image already loaded),
  run from the repo root to confirm the scripts work from any cwd:
  `service-start.sh` → container `asr-webservice-prod-asr-webservice-1` up, readiness wait
  passed, `/docs` answered HTTP 200 with the gigaam/v3_ctc defaults;
  `service-logs.sh` → startup log + live follow;
  `service-restart.sh` with `ASR_MODEL=v3_rnnt` in `deploy/prod/.env` → force-recreated,
  ready again, config echo confirmed the override;
  `service-stop.sh` → container + network removed (image untouched). Test `.env` removed,
  machine left as found.
- Exec bits set in the working tree (Git Bash runs them via `./…`). In git they'll be
  recorded 100644, same as every existing script in `deploy/dev/` (`core.filemode=false`
  on Windows) — on a Linux checkout call them as `bash service-start.sh` or `chmod +x`
  first, exactly like the dev scripts.

## Follow-ups / not done

- `deploy/dev/offline/docker-compose.offline.yml` and `deploy/prod/docker-compose.yml` are
  near-duplicates by design (dev-side verification vs. server runtime); if their drift
  becomes a problem, the offline one could be reduced to a pointer at prod's.
- No healthcheck in the compose (`HEALTHCHECK`/`depends_on: condition: service_healthy`)
  — the scripts' curl wait covers it; revisit if something else ever depends on the
  webservice container within compose.
- Not verified on a real air-gapped server (the smoke test used this dev machine's loaded
  image and localhost) — expect no differences, but that's the environment that matters.
