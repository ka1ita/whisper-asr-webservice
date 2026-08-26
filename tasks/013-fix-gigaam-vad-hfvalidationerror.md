# 013 - gigaam engine crashes on transcribe with HFValidationError from pyannote VAD

**Status:** Done

## Ask

`ASR_ENGINE=gigaam` requests fail with a 500 as soon as longform transcription kicks in
(`transcribe_longform`, i.e. audio longer than the 25s threshold), with warnings and a traceback
like:

```
/app/.venv/lib/python3.12/site-packages/pyannote/database/util.py:182: SyntaxWarning: invalid escape sequence '\s'
...
huggingface_hub.errors.HFValidationError: Repo id must be in the form 'repo_name' or 'namespace/repo_name':
'/root/.cache/huggingface/hub/models--pyannote--segmentation-3.0/snapshots/e66f3d3b9eb0873085418a7b813d3b369bf160bb'.
Use `repo_type` argument if needed
```

Traceback originates in `gigaam.vad_utils.segment_audio_file` → `get_pipeline` →
`load_segmentation_model` → `pyannote.audio.core.model.Model.from_pretrained`.

Fix it.

## Root cause

Bug in the upstream `gigaam` package (pinned in `pyproject.toml` to a specific commit, which was
also confirmed to be the current tip of `main` — i.e. not yet fixed upstream), not a config issue:

`gigaam/vad_utils.py::load_segmentation_model()` resolves the `pyannote/segmentation-3.0` model to
its local HF Hub snapshot **directory** (via `snapshot_download`) and passes that directory
straight to `pyannote.audio.Model.from_pretrained(local_path)`.

`Model.from_pretrained` only handles three cases for its `checkpoint` argument: an existing *file*
(`os.path.isfile`), an `http(s)` URL, or a HF Hub repo id string. A bare local directory matches
none of those, so it falls through to the repo-id branch and `huggingface_hub.hf_hub_download`
rejects the path with `HFValidationError`. The actual checkpoint file (`pytorch_model.bin`,
`pyannote.audio`'s `HF_PYTORCH_WEIGHTS_NAME`) does exist inside that snapshot directory — `gigaam`
just never joins the path to it.

## What was done

- [`app/asr_models/gigaam_engine.py`](../app/asr_models/gigaam_engine.py) — added
  `_load_segmentation_model_from_local_snapshot()` and monkeypatched it over
  `gigaam.vad_utils.load_segmentation_model` at module import time. It calls the original
  (unpatched) `gigaam_vad_utils.resolve_local_segmentation_path()` to get the snapshot dir, joins
  it with `pyannote.audio.core.model.HF_PYTORCH_WEIGHTS_NAME` to get the actual weights file, and
  passes that file path to `Model.from_pretrained` inside the same `torch.serialization.safe_globals`
  context the original code used.

## Verified

- Rebuilt the Docker image (`./scripts/docker-rebuild.sh`) and restarted the service
  (`./scripts/docker-start.sh`) with `ASR_ENGINE=gigaam`, `ASR_MODEL=v3_e2e_rnnt`, `HF_TOKEN` set.
- Sent a real request (`diarize=true&language=ru`) via the sample client against a longform audio
  file (`Levitan_02.02.1943.mp3`, long enough to hit `transcribe_longform`).
- Confirmed via container logs (`docker logs`) that the `HFValidationError` no longer occurs and
  the pipeline proceeds past VAD segmentation into actual model inference; confirmed via
  `docker exec ... ps aux` that the server process was actively CPU-bound (not crashed/hung) well
  after the request was issued.

## Follow-ups / not done

- The sample-client run itself hit its own 1200s client-side read timeout before the request
  finished — CPU-only longform GigaAM transcription with VAD + full pyannote diarization on a long
  audio file is slow, unrelated to this bug. Did not confirm the request eventually completes
  end-to-end with a 200 and a well-formed transcript/diarization result; only confirmed the crash
  is gone and inference is progressing.
- Considered whether to raise the client's read timeout for CPU deployments, or reduce test audio
  length for faster iteration — not done, left for a follow-up task if needed.
