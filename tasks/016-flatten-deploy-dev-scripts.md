# 016 - Flatten `deploy/dev/scripts/` into `deploy/dev/`

**Status:** Done

## Ask

- Move everything from `deploy/dev/scripts/` up one level into `deploy/dev/`
  (`docker-{rebuild,restart,start,stop}.sh`, `python-start.sh`, and `offline/` →
  `deploy/dev/offline/`).
- Remove the now-empty `scripts/` folder — it was an unnecessary nesting level.

## Scope

Task 015 kept the `scripts/` leaf when it moved `scripts/` → `deploy/dev/scripts/`
("moved wholesale ... rather than flattening"). This task reversed that: the extra
level bought nothing, so the scripts now live directly under `deploy/dev/`.

## What was done

- `git mv deploy/dev/scripts/offline` → `deploy/dev/offline` (directory rename — the
  git-ignored `offline/.env` came along), then the five `*.sh` files → `deploy/dev/`,
  then removed the empty `scripts/` folder.
- `repo_root` walk in each script lost one `/..`:
  - `deploy/dev/*.sh` — `dirname/../../..` → `dirname/../..`
  - `deploy/dev/offline/*.sh` — `dirname/../../../..` → `dirname/../../..`
- Header-comment usage paths in all seven scripts → `./deploy/dev/...` /
  `./deploy/dev/offline/...`.
- [`deploy/dev/offline/build-offline-image.sh`](../deploy/dev/offline/build-offline-image.sh)
  — `docker cp` source for `warmup_models.py` and the closing pointer to
  `export-offline-image.sh`.
- [`deploy/dev/offline/export-offline-image.sh`](../deploy/dev/offline/export-offline-image.sh)
  — header, the "run build-offline-image.sh first" error, and both
  `docker compose -f deploy/dev/offline/docker-compose.offline.yml` references.
- [`deploy/dev/offline/README.md`](../deploy/dev/offline/README.md) — invocation paths
  and the `docker compose -f` path.
- [`CLAUDE.md`](../CLAUDE.md) — tooling paragraph ("`deploy/dev/` is bash-only...", paths
  throughout, `deploy/dev/offline/` for the offline tooling).
- [`client/README.md`](../client/README.md) — all `./deploy/dev/...` invocation paths.
- [`.gitignore`](../.gitignore) — two stale comments still said `scripts/docker-rebuild.sh` /
  `scripts/python-start.sh` (pre-015 wording); now `deploy/dev/...`.

## Verified

- `bash -n` passes on all seven scripts.
- `repo_root` resolves to the repo root from both new locations (checked by running the
  `cd "$(dirname ...)/.."` expressions from `deploy/dev/` and `deploy/dev/offline/`).
- `grep -rn "dev/scripts"` (excluding historical `tasks/` notes and the stale
  `.claude/worktrees/` snapshot) returns nothing.
- `git status` shows clean renames (R/RM) for every moved file.

Not run in this environment: the scripts themselves / `docker` / `docker compose`. User to
confirm `./deploy/dev/docker-start.sh` and the offline build/export still work.

## Follow-ups / not done

- `.claude/worktrees/offline-image-asr-webservice-8302f3/` still contains the old
  `deploy/dev/scripts/` layout — a stale worktree snapshot, left untouched.
