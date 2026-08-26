# 009 - Add GigaAM as a new ASR engine, with diarization support

**Status:** Done

## Ask

Add [GigaAM](https://github.com/salute-developers/GigaAM) (Sber's Conformer-based Russian/multilingual
ASR model family) as a fourth interchangeable engine, alongside `openai_whisper`, `faster_whisper`, and
`whisperx`, with speaker diarization support (like `whisperx` already has).

## Research findings

### GigaAM itself

- PyPI has a package named `gigaam`, but it's a stale, unofficial-looking snapshot: version `0.1.0`,
  uploaded 2025-04-11, pinned to `torch<=2.5.1`/`torchaudio<=2.5.1`, and missing everything below the
  v1/v2 CTC/RNNT models (no v3, no multilingual, no `e2e_*` variants). **Not used** — installed from the
  GitHub source instead (poetry git dependency), matching what the project's own README documents
  (`pip install -e .[torch]` after `git clone`).
- Current GitHub `main` (`pyproject.toml` there is at version `0.2.0`, `requires-python >= 3.10`):
  - Model families: `v1` (wav2vec2 pretrain), `v2` (HuBERT pretrain), `v3` (scaled HuBERT, 700k hours),
    and a `multilingual` line (70+ languages, incl. Kazakh/Kyrgyz/Uzbek). v1-v3 are Russian-only. `v3`
    also has end-to-end `e2e_ctc`/`e2e_rnnt` variants with punctuation.
  - Decoder heads: CTC and RNNT. Model names look like `ctc`/`rnnt` (= `v3_ctc`/`v3_rnnt`), `v1_ctc`,
    `v1_rnnt`, `v2_ctc`, `v2_rnnt`. Per GigaAM's own WER table, `v2_rnnt` ("rnnt") has the best published
    WER — used as the default.
  - API (from `gigaam/model.py`/`types.py` on GitHub): `gigaam.load_model(name, device=...)` →
    `model.transcribe(wav_file, word_timestamps=False)` for clips up to 25s (raises `ValueError` above
    that, directing to `transcribe_longform`), returning a `TranscriptionResult(text, words)`;
    `model.transcribe_longform(wav_file, word_timestamps=False)` for longer audio, returning
    `LongformTranscriptionResult(segments=[Segment(text, start, end, words)])`. **Both take a file path,
    not an in-memory array** — they shell out to `ffmpeg` themselves via `gigaam.preprocess.load_audio`.
  - **No native speaker diarization** in GigaAM itself.
  - Base install: `torch>=2.6`/`torchaudio>=2.6` (compatible with this project's pinned
    `torch==2.7.1`/`torchaudio==2.7.1`). The `longform` extra pins `torch==2.10.*`/`pyannote.audio==4.0.*`
    — **conflicts** with this project's torch pin — but it turned out **not to be needed**: GigaAM's own
    `transcribe_longform` lazily imports `pyannote.audio` only inside `gigaam/vad_utils.py` (for a VAD
    segmentation pass using `pyannote/segmentation-3.0`), and `pyannote.audio` is already present via the
    `whisperx` dependency at a torch-2.7.1-compatible version. So long-form GigaAM audio "just works"
    once `HF_TOKEN` is set, without ever installing GigaAM's `longform` extra.

### This project's engine architecture (for context, see also `CLAUDE.md`)

- Adding an engine = implement `app/asr_models/asr_model.py`'s `ASRModel` ABC
  (`load_model`, `transcribe`, `language_detection`) and register it in
  `app/factory/asr_model_factory.py` against `CONFIG.ASR_ENGINE`.
- `whisperx` engine already had a working, torch-2.7.1-compatible diarization integration:
  `whisperx.diarize.DiarizationPipeline` (a thin wrapper around `pyannote.audio`), gated on
  `CONFIG.HF_TOKEN`, plus the `_allow_full_unpickling_for_pyannote_checkpoints()` fix from
  [task 008](008-fix-whisperx-torch-load-crash.md). Confirmed (by extracting the exact pinned
  `whisperx==3.4.5` wheel and reading `diarize.py` directly) that `whisperx.diarize.assign_word_speakers`
  works on plain dicts with `start`/`end`/`text` keys and doesn't require word-level alignment - so it's
  directly reusable for GigaAM's segment-level output too, no custom overlap-assignment code needed.

## What was done

- [`app/diarization.py`](../app/diarization.py) — new shared module: `load_diarization_pipeline()`
  (builds `whisperx.diarize.DiarizationPipeline`, gated on `CONFIG.HF_TOKEN`, returns `None` otherwise)
  and `_allow_full_unpickling_for_pyannote_checkpoints()` (moved here from the whisperx engine
  unchanged). [`app/asr_models/mbain_whisperx_engine.py`](../app/asr_models/mbain_whisperx_engine.py)
  now calls this shared helper instead of duplicating the logic; also fixed a pre-existing bug there
  where `diarize_model(audio, min_speakers, max_speakers)` passed `min_speakers`/`max_speakers`
  positionally, which actually bound to the pipeline's `num_speakers`/`min_speakers` parameters (leaving
  the real `max_speakers` never passed) — now passed as keywords.
- [`app/asr_models/gigaam_engine.py`](../app/asr_models/gigaam_engine.py) — new `GigaAMASR` engine:
  - `load_model`: `gigaam.load_model(CONFIG.MODEL_NAME, device=CONFIG.DEVICE)` plus the shared
    diarization pipeline.
  - `transcribe`: writes the already-decoded audio to a temp WAV (`_write_temp_wav`, since GigaAM needs
    a file path), picks `transcribe`/`transcribe_longform` based on a 25s duration threshold (mirroring
    GigaAM's own `LONGFORM_THRESHOLD`), maps the result into plain dicts, runs diarization + speaker
    assignment via `whisperx.diarize.assign_word_speakers` when `diarize=true` and `HF_TOKEN` is set, then
    builds `Segment`/`Word` dataclasses (prefixing `[SPEAKER_XX]: ` onto `.text` when a speaker was
    assigned, matching whisperx's own txt/srt/vtt/tsv convention) for
    [`app/utils.py`](../app/utils.py)'s existing `ResultWriter`/`WriteJSON`/`WriteSRT`/`WriteTSV`/
    `WriteTXT`/`WriteVTT` (same writer path `faster_whisper` uses) - no new output-format code needed.
    `task=translate` is ignored with a warning (GigaAM only transcribes).
  - `language_detection`: GigaAM has no language-ID capability; returns a fixed `("ru", 1.0)` with a
    warning rather than raising, so `/detect-language` stays usable.
- [`app/factory/asr_model_factory.py`](../app/factory/asr_model_factory.py) — registers `"gigaam"`.
- [`app/config.py`](../app/config.py) — `MODEL_NAME` defaults to `"rnnt"` when `ASR_ENGINE == "gigaam"`
  (was hardcoded `"base"`, a Whisper size); added an `HF_TOKEN`-missing warning for `gigaam` (needed for
  long-form audio and/or diarization); documented `MODEL_QUANTIZATION` as ignored by this engine.
- [`app/webservice.py`](../app/webservice.py) — `word_timestamps`, `diarize`, `min_speakers`,
  `max_speakers` Swagger visibility now also includes `ASR_ENGINE == "gigaam"`.
- **Dependency**: added `gigaam` to `pyproject.toml` as a poetry git dependency pinned to commit
  `7447938d791c4f3e643386ee22c33777004293a5` on `salute-developers/GigaAM` (base install only, not the
  `longform` extra). Ran `poetry lock` (using a separate Python 3.11 environment set up just for this,
  since this sandbox's default Python is 3.14, outside the project's `<3.14` constraint) to verify it
  resolves cleanly — it does: `gigaam 0.2.0` plus its own deps (`hydra-core`, `numpy`, `omegaconf`,
  `onnx`, `onnxruntime`, `sentencepiece`, `soundfile`, `tqdm`) resolve with no conflicts against the
  existing pins (torch/torchaudio/whisperx versions all unchanged in the regenerated lock file). One
  side effect: `onnxruntime` moved from `1.24.3` to `1.23.2` to satisfy GigaAM's `onnxruntime==1.23.*`
  constraint (used elsewhere in the dependency tree, likely by faster-whisper's VAD path) — a minor
  downgrade, not expected to matter, but not runtime-verified in this session (see follow-ups).
- Docs: [`docs/environmental-variables.md`](../docs/environmental-variables.md),
  [`docs/endpoints.md`](../docs/endpoints.md), [`docs/run.md`](../docs/run.md), `CLAUDE.md`, and
  `README.md` all updated to mention the `gigaam` engine, its model-name options, and its
  diarization/long-form `HF_TOKEN` requirement.

## Follow-ups / not done

- **Not runtime-tested** — this sandbox has no compatible Python/poetry/Docker setup to actually install
  `torch`/`whisperx`/`gigaam` and run a real transcription (only `poetry lock`'s dependency *resolution*
  was verified, in a separate ad hoc Python 3.11 env). Before relying on this, build the Docker image
  (`./scripts/docker-rebuild.sh`) with `ASR_ENGINE=gigaam` and send it real audio, covering: short (<25s)
  and long (>25s) clips, `word_timestamps=true`, and `diarize=true` with `HF_TOKEN` set (which also
  exercises GigaAM's own long-form VAD pyannote path for the first time in this project).
  Also confirm `pyannote/segmentation-3.0` doesn't require its own separate HF model-access acceptance
  the way `pyannote/speaker-diarization-3.1` did for whisperx.
- The `onnxruntime` downgrade (`1.24.3` → `1.23.2`) noted above wasn't verified against
  `faster_whisper`'s VAD filter or any other onnxruntime consumer in this repo.
- `language_detection` always returns `("ru", 1.0)` regardless of whether a `multilingual_*` model is
  configured — acceptable simplification (GigaAM has no language-ID API to call instead) but worth
  revisiting if multilingual GigaAM usage becomes a real need.
- The `language` request parameter is silently ignored by this engine (GigaAM's `transcribe`/
  `transcribe_longform` take no language argument); not enforced/validated at the API layer.
- Long-form chunk boundaries come entirely from GigaAM's own VAD segmentation (`max_duration=22s`,
  `strict_limit_duration=30s` by default) - not tunable from this project's config/API.
- The git dependency is pinned to a commit SHA for reproducibility; GigaAM has no tagged releases past
  the stale `0.1.0` PyPI one, so bumping it later means picking a new commit by hand.
