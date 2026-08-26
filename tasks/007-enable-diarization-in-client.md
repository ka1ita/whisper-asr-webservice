# 007 - Diarization doesn't work in client, enable it

**Status:** Done

## Ask

Speaker diarization doesn't work when transcribing via the sample client
([`client/`](../client/)). Enable it.

## Root cause

The server (`/asr`) already supports diarization end-to-end, but only for the `whisperx`
engine: [`app/webservice.py:74-88`](../app/webservice.py) accepts `diarize`, `min_speakers`,
`max_speakers` query params and passes them through to
[`WhisperXASR.transcribe`](../app/asr_models/mbain_whisperx_engine.py), which runs the
diarization pipeline only when `diarize=true` **and** `CONFIG.HF_TOKEN` is set
([`mbain_whisperx_engine.py:81`](../app/asr_models/mbain_whisperx_engine.py)).

The client never sent these params at all — `client/config.yaml` had no
`diarize`/`min_speakers`/`max_speakers` fields, and `transcribe_file()` in
[`client/transcribe_client.py`](../client/transcribe_client.py) only built `encode`, `task`,
`output`, `vad_filter`, `word_timestamps`, plus optional `language`/`initial_prompt` — so
diarization was unreachable from the client regardless of server config.

## What was done

- [`client/config.yaml`](../client/config.yaml) — added `diarize` (bool, default `false`) and
  `min_speakers` / `max_speakers` (int or `null`) fields, next to the existing
  `vad_filter`/`word_timestamps` options, noting they're whisperx-only.
- [`client/transcribe_client.py`](../client/transcribe_client.py) `transcribe_file()` — sends
  `diarize` on every request (same pattern as `vad_filter`/`word_timestamps`), and
  `min_speakers`/`max_speakers` only when set (same pattern as `language`/`initial_prompt`).
- [`client/README.md`](../client/README.md) — documents that diarization requires
  `ASR_ENGINE=whisperx` + `HF_TOKEN` on the server, and that `output_format` must be `json`,
  `srt`, or `vtt` to actually see speaker labels (plain `txt` output has none).

## Follow-ups / not done

- Not verified against a live `whisperx` + `HF_TOKEN` server (no such instance running here) —
  confirm end-to-end with real audio before relying on this.
- Pre-existing, unrelated quirk noticed while touching this: the client always writes the
  server response to `<audio>.txt` regardless of `output_format` (see
  [tasks/006](006-client-output-txt-next-to-audio.md)), so setting `output_format: json` to see
  speaker labels produces a `.txt` file containing JSON. Left as-is — out of scope here.
