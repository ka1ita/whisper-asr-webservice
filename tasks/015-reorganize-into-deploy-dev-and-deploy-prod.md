# 015 - Reorganize tooling into `deploy/dev/` and `deploy/prod/`

**Status:** Done

## Ask

- Add a `deploy/dev/` directory and move `scripts/` into it (`deploy/dev/scripts/`).
- Add a `deploy/prod/` directory and move `dist/` into it (`deploy/prod/dist/`).
- Update [`build-offline-image.sh`](../deploy/dev/scripts/offline/build-offline-image.sh) and
  [`export-offline-image.sh`](../deploy/dev/scripts/offline/export-offline-image.sh) for the
  new `dist/` location.
- Remove the export (tar `docker save`) step from `build-offline-image.sh` — that job now
  belongs solely to `export-offline-image.sh`.

## Scope

`scripts/` held the dev-facing bash tooling (`docker-{rebuild,restart,start,stop}.sh`,
`python-start.sh`, and `offline/`). `dist/` was the (git-ignored, empty) drop location for the
offline image tarballs. The two are different audiences — local dev workflow vs. the artifact
shipped to an air-gapped prod server — so they split into `deploy/dev/` and `deploy/prod/`.

### Path recomputation

Every moved script derives `repo_root` by walking up from `BASH_SOURCE`. The move adds two
levels (`deploy/dev/`), so each `cd .../..` grew by `/../..`:

- `deploy/dev/scripts/*.sh` — `dirname/..` → `dirname/../../..`
- `deploy/dev/scripts/offline/*.sh` — `dirname/../..` → `dirname/../../../..`

## Decisions

1. `scripts/` moved wholesale to `deploy/dev/scripts/` (kept the `scripts/` leaf name and the
   `offline/` subdir) rather than flattening — the internal layout was already fine.
2. `build-offline-image.sh` no longer writes a tar at all (previously it saved one to the repo
   root *and* `export-offline-image.sh` could re-export to `dist/`). Build → commit only;
   export is a separate explicit step. Removed the `out_file` variable and the closing
   `docker save` + transfer echo; the final message now points at `export-offline-image.sh`.
3. `export-offline-image.sh` writes to `deploy/prod/dist/` instead of `dist/`.
4. `deploy/prod/dist/` gets a `.gitkeep` so the directory exists in a fresh clone;
   `.gitignore` `/dist/*` → `/deploy/prod/dist/*` (plus a `!.gitkeep` negation).
5. Historical `tasks/` notes referencing `scripts/...` left as written — history.

## What was done

- `git mv` of all tracked files under `scripts/` → `deploy/dev/scripts/` (same tree shape).
  `scripts/offline/export-offline-image.sh` (untracked at the time) recreated at the new path.
- [`deploy/dev/scripts/docker-rebuild.sh`](../deploy/dev/scripts/docker-rebuild.sh),
  [`docker-restart.sh`](../deploy/dev/scripts/docker-restart.sh),
  [`docker-start.sh`](../deploy/dev/scripts/docker-start.sh),
  [`docker-stop.sh`](../deploy/dev/scripts/docker-stop.sh),
  [`python-start.sh`](../deploy/dev/scripts/python-start.sh) — `repo_root` walk `+/../..`,
  header-comment usage paths → `./deploy/dev/scripts/...`.
- [`deploy/dev/scripts/offline/build-offline-image.sh`](../deploy/dev/scripts/offline/build-offline-image.sh)
  — `repo_root` walk `+/../..`; `docker cp` source →
  `deploy/dev/scripts/offline/warmup_models.py`; removed the `out_file` logic and the trailing
  `docker save` + transfer instructions; new closing message points at `export-offline-image.sh`;
  docstring reworded (build+commit only).
- [`deploy/dev/scripts/offline/export-offline-image.sh`](../deploy/dev/scripts/offline/export-offline-image.sh)
  — `repo_root` walk; output dir `dist/` → `deploy/prod/dist/`; `docker compose -f` and
  cross-references updated to the new script paths; docstring reflects that build no longer
  emits a tar.
- [`deploy/dev/scripts/offline/README.md`](../deploy/dev/scripts/offline/README.md) — all
  invocation paths, the "saves it to `…​.tar` in the repo root" paragraph (now: commit only,
  then export to `deploy/prod/dist/`), and the `docker compose -f` path.
- [`deploy/prod/dist/.gitkeep`](../deploy/prod/dist/.gitkeep) — new.
- [`.gitignore`](../.gitignore) — `/deploy/prod/dist/*` + `!/deploy/prod/dist/.gitkeep`
  (old `/dist/*` line left in place, harmless).
- [`CLAUDE.md`](../CLAUDE.md) — `scripts/` → `deploy/dev/scripts/` throughout the tooling
  paragraph; added a sentence on `deploy/dev/scripts/offline/` and `deploy/prod/dist/`.
- [`client/README.md`](../client/README.md) — `./scripts/` → `./deploy/dev/scripts/`.

## Verified

- `grep -rn 'scripts/\|dist/'` (excluding `client/.venv/` and historical `tasks/`) returns
  only the new `deploy/dev/scripts/` / `deploy/prod/dist/` paths.
- `repo_root` math checked by hand: `deploy/dev/scripts/` is 3 levels deep, `.../offline/` is
  4; the `cd` expressions match.
- Not run in this environment: the scripts themselves / `docker` / `docker compose`. User to
  confirm `./deploy/dev/scripts/docker-start.sh` and the offline build/export still work.

## Follow-ups / not done

- Root `docker-compose.yml` / `docker-compose.gpu.yml` left at the repo root (not moved into
  `deploy/dev/`) — they're referenced by relative `context: .` build paths and by every
  script via `-f docker-compose*.yml` from `repo_root`; moving them is a larger change.
- `.gitignore` still carries the now-redundant `/dist/*` line — left as a harmless catch-all.
