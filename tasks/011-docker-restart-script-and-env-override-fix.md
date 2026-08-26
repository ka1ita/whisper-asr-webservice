# 011 - Add docker-restart script; fix .env being overridden by compose `environment:`

**Status:** Done

## Ask

Investigate why the startup config log (`Starting with config: ...`) kept showing
`ASR_MODEL=base` even though `.env` had `ASR_MODEL=tiny`, and add a script to force-recreate
the docker compose container (to pick up `.env` changes without a full rebuild).

## What was done

- [`scripts/docker-restart.sh`](../scripts/docker-restart.sh) — new script, same conventions as
  the existing `docker-*.sh` scripts. Runs
  `docker compose -f <compose_file> up -d --force-recreate <service>` (CPU by default, `gpu` arg
  for `docker-compose.gpu.yml`) and waits for `/docs` to become reachable, same readiness loop as
  `docker-start.sh`. Needed because `docker compose up` alone won't recreate an already-running
  container just because `.env` changed.
- Root cause of the stale `ASR_MODEL=base`: [`docker-compose.yml`](../docker-compose.yml) and
  [`docker-compose.gpu.yml`](../docker-compose.gpu.yml) both had a hardcoded
  `environment: [ASR_MODEL=base]` block. Compose's `environment:` always takes precedence over
  `env_file:` for the same key, so `.env`'s `ASR_MODEL` was silently overridden regardless of
  rebuild/restart. Removed the hardcoded `environment:` block from both files so `.env` is the
  sole source for `ASR_MODEL` again.

## Verified

- Not run in this environment (no Docker available here). User to confirm with
  `./scripts/docker-restart.sh` (or `gpu`) that the startup log now shows `ASR_MODEL=tiny` per
  `.env`.

## Follow-ups / not done

- None — no other env vars were hardcoded in the `environment:` blocks of either compose file.
