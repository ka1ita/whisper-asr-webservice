"""
Downloads every model this offline deployment needs so they end up cached under
/root/.cache inside the container's filesystem. Run once inside a throwaway container
built from the whisper-asr-webservice image (see build-offline-image.sh), then
`docker commit` that container to bake the cache into a new image for offline transfer.

Requires HF_TOKEN in the environment for the gated pyannote models (whisperx diarization,
gigaam's long-form VAD segmentation model) - transcription-only models download without it.

Edit the constants below to change which models get baked in.
"""
import os
import wave

os.environ.setdefault("ASR_DEVICE", "cpu")
os.environ.setdefault("ASR_QUANTIZATION", "int8")

from app.config import CONFIG  # noqa: E402

# Used by openai_whisper, faster_whisper, and whisperx alike.
WHISPER_SIZES = ["small", "medium", "large-v3", "large-v3-turbo"]

# GigaAM model names - see docs/environmental-variables.md for the full list of options.
GIGAAM_MODELS = ["v3_rnnt", "v3_ctc", "v3_e2e_rnnt", "v3_e2e_ctc"]

# Languages to preload whisperx word-alignment models for.
ALIGN_LANGUAGES = ["en", "ru"]


def _make_silent_wav(path: str, seconds: float = 30.0, sample_rate: int = 16000) -> None:
    with wave.open(path, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(b"\x00\x00" * int(seconds * sample_rate))


def warm_openai_whisper():
    import whisper

    for size in WHISPER_SIZES:
        print(f"[openai_whisper] downloading {size}")
        whisper.load_model(name=size, device="cpu", download_root=CONFIG.MODEL_PATH)


def warm_faster_whisper():
    from faster_whisper import WhisperModel

    for size in WHISPER_SIZES:
        print(f"[faster_whisper] downloading {size}")
        WhisperModel(model_size_or_path=size, device="cpu", compute_type="int8", download_root=CONFIG.MODEL_PATH)


def warm_whisperx():
    import whisperx

    from app.diarization import _allow_full_unpickling_for_pyannote_checkpoints, load_diarization_pipeline

    with _allow_full_unpickling_for_pyannote_checkpoints():
        for size in WHISPER_SIZES:
            print(f"[whisperx] downloading {size}")
            whisperx.load_model(size, device="cpu", compute_type="int8", asr_options={"without_timestamps": False})

        for lang in ALIGN_LANGUAGES:
            print(f"[whisperx] downloading align model for '{lang}'")
            whisperx.load_align_model(language_code=lang, device="cpu")

        print("[whisperx] downloading diarization pipeline (requires HF_TOKEN)")
        pipeline = load_diarization_pipeline()
        if pipeline is None:
            print("  WARNING: HF_TOKEN not set - diarization model was NOT downloaded.")


def warm_gigaam():
    import gigaam

    # Importing this module applies the app's monkeypatch for gigaam's segmentation-model
    # loading bug (HFValidationError) - see app/asr_models/gigaam_engine.py.
    import app.asr_models.gigaam_engine  # noqa: F401

    models = {}
    for name in GIGAAM_MODELS:
        print(f"[gigaam] downloading {name}")
        models[name] = gigaam.load_model(name, device="cpu")

    print("[gigaam] downloading long-form VAD segmentation model (requires HF_TOKEN)")
    wav_path = "/tmp/gigaam_warmup_silence.wav"
    _make_silent_wav(wav_path)
    try:
        # Any one model triggers the (shared) VAD download; reuse the first.
        next(iter(models.values())).transcribe_longform(wav_path)
    finally:
        os.remove(wav_path)


if __name__ == "__main__":
    if not CONFIG.HF_TOKEN:
        print(
            "WARNING: HF_TOKEN is not set - gated pyannote models (whisperx diarization, "
            "gigaam long-form VAD) will fail to download."
        )

    warm_openai_whisper()
    warm_faster_whisper()
    warm_whisperx()
    warm_gigaam()

    print("Done. Cache contents:")
    os.system(f'du -sh "{CONFIG.MODEL_PATH}" 2>/dev/null')
    os.system("du -sh /root/.cache/* 2>/dev/null")
