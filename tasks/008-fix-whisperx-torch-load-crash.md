# 008 - whisperx engine crashes on startup with torch weights_only unpickling error

**Status:** Done

## Ask

`ASR_ENGINE=whisperx` container exits immediately on startup with:

```
_pickle.UnpicklingError: Weights only load failed. ...
WeightsUnpickler error: Unsupported global: GLOBAL omegaconf.listconfig.ListConfig was not an allowed global by default.
```

Fix it.

## Root cause

Two stacked incompatibilities between pinned `torch (==2.7.1)` and the `whisperx`/`pyannote`
dependency stack, both triggered from
[`WhisperXASR.load_model`](../app/asr_models/mbain_whisperx_engine.py):

1. Since PyTorch 2.6, `torch.load` defaults to `weights_only=True`. `whisperx.load_model(...)`
   loads pyannote's bundled VAD checkpoint via `pyannote.audio`'s `Model.from_pretrained` →
   `lightning_fabric`'s `pl_load`, which contains `omegaconf`/pytorch-lightning objects the
   restrictive unpickler rejects. The same call chain is used again for the diarization model
   (`DiarizationPipeline(...)`, only reached when `CONFIG.HF_TOKEN` is set), which fails the same
   way once the VAD load is fixed.
2. Once (1) was patched, startup failed differently:
   `TypeError: hf_hub_download() got an unexpected keyword argument 'use_auth_token'`.
   `huggingface-hub` had drifted to `1.27.0` (no direct pin in `pyproject.toml`, resolved
   transitively), which removed the long-deprecated `use_auth_token` kwarg that
   `pyannote-audio 3.4.0` still passes internally.

## What was done

- [`app/asr_models/mbain_whisperx_engine.py`](../app/asr_models/mbain_whisperx_engine.py) — added
  `_allow_full_unpickling_for_pyannote_checkpoints()`, a context manager that temporarily patches
  `torch.load` to force `weights_only=False`, wrapped around both the `whisperx.load_model(...)`
  and `DiarizationPipeline(...)` calls in `load_model`. Scoped narrowly (only active during these
  two calls) since these checkpoints ship with `whisperx`/come from the official `pyannote` HF Hub
  repos, i.e. trusted sources.
- [`pyproject.toml`](../pyproject.toml) — added an explicit `huggingface-hub (>=0.19,<1.0)`
  constraint to keep the `use_auth_token` kwarg `pyannote-audio 3.4.0` depends on.
- [`poetry.lock`](../poetry.lock) — regenerated (`poetry lock`) to pick up the new constraint;
  resolved to `huggingface-hub 0.36.2`.

## Verified

Rebuilt the Docker image (`./scripts/docker-rebuild.sh`) and started the service with
`ASR_ENGINE=whisperx` and `HF_TOKEN` set (diarization enabled). Container stays up, logs show the
VAD model and `pyannote/speaker-diarization-3.1` both loading successfully, and `GET /docs`
returns `200`.

## Follow-ups / not done

- Not tested with `ASR_ENGINE=whisperx` and `HF_TOKEN` unset (diarization-disabled path) — should
  still work since that skips the `DiarizationPipeline` call entirely, but wasn't explicitly
  re-verified.
- No end-to-end transcription/diarization request was sent against the running container in this
  task — only startup/model-load was verified.
