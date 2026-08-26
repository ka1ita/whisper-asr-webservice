# 001 - Sample audio dir and sample Python client

**Status:** Done

## Ask

- Add an `audio/` directory for sample audio files.
- Add a `client/` directory with a sample Python client (with a config file) that transcribes
  every file in `audio/` against a running whisper-asr-webservice instance and saves each
  result as a `.txt` file.

## What was done

- [`audio/`](../audio/) — `README.md` explaining its purpose, plus a synthetic
  `sample_tone.wav` (2s, 440Hz) so the pipeline can be exercised immediately without
  needing a real recording. It contains no speech, so transcription of it will be empty —
  swap in real speech samples for meaningful output.
- [`client/`](../client/):
  - `config.yaml` — server URL, `audio_dir`/`output_dir`, allowed audio extensions, and all
    `/asr` request parameters (task, language, VAD filter, word timestamps, output format,
    timeout), commented.
  - `transcribe_client.py` — iterates matching files in `audio_dir`, POSTs each to
    `{server_url}/asr`, and writes the response to `output_dir/<stem>.txt`. Continues past
    per-file failures and reports a summary; exits non-zero if any file failed.
  - `requirements.txt` — `requests`, `PyYAML`.
  - `README.md` — setup/run instructions.
- `.gitignore` updated to exclude `client/output/` (generated transcription output).

## Follow-ups / not done

- No real speech sample audio included (only the synthetic tone) — add licensed/self-recorded
  speech samples to `audio/` if a meaningful end-to-end transcription check is needed.
- The client is a standalone script (own `requirements.txt`), not wired into the Poetry
  project or CI.
