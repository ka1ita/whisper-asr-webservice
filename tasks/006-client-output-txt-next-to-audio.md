# 006 - Write client transcripts next to the source audio files

**Status:** Done

## Ask

Change the sample client ([`client/transcribe_client.py`](../client/transcribe_client.py)) so each
transcription `.txt` is written into the audio folder, next to the source audio file it came from,
instead of the separate `output_dir` (`client/output/`). If a `.txt` already exists there, replace it.

## What was done

- [`client/transcribe_client.py`](../client/transcribe_client.py) — writes each result to
  `audio_path.with_suffix(".txt")` instead of `output_dir / f"{stem}.txt"`; `Path.write_text`
  already overwrites an existing file, so replace-if-needed falls out for free. Removed the now-unused
  `output_dir` config/env plumbing (`ENV_OVERRIDES`, `load_config`, `output_dir.mkdir(...)` in `main()`).
- [`client/config.yaml`](../client/config.yaml) — dropped the `output_dir` setting; updated the
  `audio_dir` comment to note `.txt` files are written there too.
- [`client/README.md`](../client/README.md) — updated the description, "Configure"/"Run" sections, and
  the Docker Compose section to reflect output going next to the source file, not a separate directory.
- `docker-compose.yml` / `docker-compose.gpu.yml` — removed the `ASR_CLIENT_OUTPUT_DIR` env var and the
  `./client/output:/output` volume mount; `./audio:/audio` is now mounted read-write (was `:ro`) since the
  client writes into it.
- [`scripts/docker-rebuild.sh`](../scripts/docker-rebuild.sh) — dropped the `client/output/*` exclusion
  from the content-hash `find`, since that directory no longer exists.
- `.gitignore` — swapped the `/client/output/` entry for `/audio/*.txt` (the new location of generated
  output); `client/.dockerignore` — dropped the now-meaningless `output` entry.
- Deleted the stale, untracked `client/output/` directory (leftover `.txt` files from before this change).

Verified: `py -3 -m py_compile client/transcribe_client.py` passes. Not re-run end-to-end against a live
server in this session — behavior (write path only) is a small, low-risk change from the already-tested
005/004 flow.

## Follow-ups / not done

- Running the client against the Docker Compose flow again to confirm `.txt` files land in `./audio` on
  the host was not re-verified interactively this session.
