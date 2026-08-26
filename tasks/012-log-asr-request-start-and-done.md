# 012 - Log /asr and /detect-language request start/done for all ASR_ENGINE values

**Status:** Done

## Ask

`docker logs` showed nothing between the startup config dump and uvicorn's own access-log line
for a client request — for `whisperx` (and the other engines) the whole `/asr` pipeline
(transcribe + align + diarize + write) runs with zero logging of its own, and uvicorn only logs
a request after the response is fully sent. On CPU with diarization this made it look like the
service had silently stopped responding to the client query. Add logging that covers all
`ASR_ENGINE` values, not just `whisperx`, and make it possible to switch off via an env var.

## What was done

- [`app/webservice.py`](../app/webservice.py) — added `print()` calls in the shared `/asr` and
  `/detect-language` route handlers (not per-engine, since every engine funnels through these two
  endpoints): one at request start (filename, task, language, diarize, output for `/asr`;
  filename for `/detect-language`), tagged `[{CONFIG.ASR_ENGINE}]`, and one when
  `asr_model.transcribe(...)` / `asr_model.language_detection(...)` returns, with elapsed seconds.
  Covers `whisperx`, `faster_whisper`, `openai_whisper`, and `gigaam` from one place.
- [`app/config.py`](../app/config.py) — added `CONFIG.REQUEST_LOGGING`, read from
  `ASR_REQUEST_LOGGING` (defaults to `false`, opt-in), and added it to the existing `Starting
  with config: ...` startup print. Both print pairs in `webservice.py` are gated behind
  `if CONFIG.REQUEST_LOGGING:`.
- [`docs/environmental-variables.md`](../docs/environmental-variables.md) — documented
  `ASR_REQUEST_LOGGING` in a new "Configuring Request Logging" section.

## Verified

- Read through the edited handlers; no syntax issues found by inspection. Could not exercise the
  actual request/response cycle in this environment (no running service). Should be confirmed
  with `./scripts/docker-rebuild.sh` + `docker-start.sh` — expect a `[<engine>] /asr start: ...`
  line to appear immediately when the client posts a file, and a `[<engine>] /asr done: ... in
  N.Ns` line when it finishes; this requires `ASR_REQUEST_LOGGING=true` since it's opt-in.

## Follow-ups / not done

- No per-engine progress logging (e.g. mid-transcription) was added — only start/done around the
  whole request. If diarization/alignment steps need their own visibility, that would need
  separate log lines inside each engine's `transcribe()`.
- `docker-compose.yml` / `docker-compose.gpu.yml` weren't changed — neither enumerates most
  `CONFIG` env vars explicitly (only `ASR_ENGINE`), so `ASR_REQUEST_LOGGING` was left to its
  default like the rest.
