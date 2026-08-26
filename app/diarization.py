from contextlib import contextmanager
from typing import Optional

import torch
from whisperx.diarize import DiarizationPipeline

from app.config import CONFIG


@contextmanager
def _allow_full_unpickling_for_pyannote_checkpoints():
    """pyannote checkpoints (bundled VAD model, downloaded diarization models) contain omegaconf/lightning objects that torch>=2.6's default weights_only=True unpickler rejects."""
    original_load = torch.load

    def load_with_weights_only_false(*args, **kwargs):
        kwargs["weights_only"] = False
        return original_load(*args, **kwargs)

    torch.load = load_with_weights_only_false
    try:
        yield
    finally:
        torch.load = original_load


def load_diarization_pipeline() -> Optional[DiarizationPipeline]:
    """
    Builds the shared pyannote-based diarization pipeline, or returns None if no HF_TOKEN
    is configured (diarization is opt-in and requires Hugging Face model access).
    """
    if CONFIG.HF_TOKEN == "":
        return None
    with _allow_full_unpickling_for_pyannote_checkpoints():
        return DiarizationPipeline(use_auth_token=CONFIG.HF_TOKEN, device=CONFIG.DEVICE)
