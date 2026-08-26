import os
import tempfile
import time
import wave
from dataclasses import dataclass
from io import StringIO
from threading import Thread
from typing import BinaryIO, List, Optional, Union

import gigaam
import gigaam.vad_utils as gigaam_vad_utils
import numpy as np
import torch
from pyannote.audio import Model
from pyannote.audio.core.model import HF_PYTORCH_WEIGHTS_NAME
from pyannote.audio.core.task import Problem, Resolution, Specifications
from torch.torch_version import TorchVersion
from whisperx.diarize import assign_word_speakers

from app.asr_models.asr_model import ASRModel
from app.config import CONFIG
from app.diarization import load_diarization_pipeline
from app.utils import ResultWriter, WriteJSON, WriteSRT, WriteTSV, WriteTXT, WriteVTT

# GigaAM's own `transcribe()` raises for audio longer than this and requires
# `transcribe_longform()` instead - mirrors gigaam.model.LONGFORM_THRESHOLD (in seconds).
_LONGFORM_THRESHOLD_SECONDS = 25.0


def _load_segmentation_model_from_local_snapshot(model_id: str) -> Model:
    """
    Works around a bug in gigaam.vad_utils.load_segmentation_model: it passes the resolved
    snapshot *directory* to pyannote's Model.from_pretrained(), which only accepts a checkpoint
    file, a URL, or a HF repo id - a bare directory falls through to the repo-id branch and
    huggingface_hub raises HFValidationError. Point it at the actual weights file instead.
    """
    local_path = gigaam_vad_utils.resolve_local_segmentation_path(model_id=model_id)
    weights_path = os.path.join(local_path, HF_PYTORCH_WEIGHTS_NAME)

    with torch.serialization.safe_globals([TorchVersion, Problem, Specifications, Resolution]):
        return Model.from_pretrained(weights_path)


gigaam_vad_utils.load_segmentation_model = _load_segmentation_model_from_local_snapshot


@dataclass
class Word:
    start: float
    end: float
    text: str
    speaker: Optional[str] = None


@dataclass
class Segment:
    start: float
    end: float
    text: str
    speaker: Optional[str] = None
    words: Optional[List[Word]] = None


class GigaAMASR(ASRModel):
    """
    GigaAM (https://github.com/salute-developers/GigaAM) engine. Russian-only (v1-v3 model
    lines) or multilingual, depending on CONFIG.MODEL_NAME. Supports transcription only - no
    translation. Diarization is bolted on via the same pyannote-based pipeline the `whisperx`
    engine uses (see app/diarization.py), since GigaAM has no native speaker diarization.
    """

    def load_model(self):
        self.model = {
            "gigaam": gigaam.load_model(CONFIG.MODEL_NAME, device=CONFIG.DEVICE),
            "diarize_model": load_diarization_pipeline(),
        }

        Thread(target=self.monitor_idleness, daemon=True).start()

    def transcribe(
        self,
        audio,
        task: Union[str, None],
        language: Union[str, None],
        initial_prompt: Union[str, None],
        vad_filter: Union[bool, None],
        word_timestamps: Union[bool, None],
        options: Union[dict, None],
        output,
    ):
        self.last_activity_time = time.time()

        with self.model_lock:
            if self.model is None:
                self.load_model()

        if task == "translate":
            print("Warning: GigaAM only supports transcription, not translation. Ignoring task=translate.")

        duration = audio.shape[0] / CONFIG.SAMPLE_RATE
        wav_path = self._write_temp_wav(audio)
        try:
            with self.model_lock:
                if duration > _LONGFORM_THRESHOLD_SECONDS:
                    result = self.model["gigaam"].transcribe_longform(wav_path, word_timestamps=bool(word_timestamps))
                    segments = [
                        self._segment_to_dict(seg.start, seg.end, seg.text, seg.words) for seg in result.segments
                    ]
                else:
                    result = self.model["gigaam"].transcribe(wav_path, word_timestamps=bool(word_timestamps))
                    segments = [self._segment_to_dict(0.0, duration, result.text, result.words)]
        finally:
            os.remove(wav_path)

        if options.get("diarize", False) and self.model["diarize_model"] is not None:
            min_speakers = options.get("min_speakers", None)
            max_speakers = options.get("max_speakers", None)
            with self.model_lock:
                diarize_segments = self.model["diarize_model"](
                    audio, min_speakers=min_speakers, max_speakers=max_speakers
                )
            assign_word_speakers(diarize_segments, {"segments": segments})

        text = " ".join(s["text"] for s in segments)
        result_dict = {"language": "ru", "segments": self._build_output_segments(segments), "text": text}

        output_file = StringIO()
        self.write_result(result_dict, output_file, output)
        output_file.seek(0)

        return output_file

    def language_detection(self, audio):
        self.last_activity_time = time.time()

        with self.model_lock:
            if self.model is None:
                self.load_model()

        print("Warning: GigaAM does not perform language detection; assuming 'ru' (Russian).")
        return "ru", 1.0

    @staticmethod
    def _segment_to_dict(start: float, end: float, text: str, words) -> dict:
        segment = {"start": start, "end": end, "text": text}
        if words:
            segment["words"] = [{"start": w.start, "end": w.end, "text": w.text} for w in words]
        return segment

    @staticmethod
    def _build_output_segments(segments: List[dict]) -> List[Segment]:
        output_segments = []
        for seg in segments:
            speaker = seg.get("speaker")
            text = f"[{speaker}]: {seg['text']}" if speaker else seg["text"]
            words = None
            if seg.get("words"):
                words = [
                    Word(start=w["start"], end=w["end"], text=w["text"], speaker=w.get("speaker")) for w in seg["words"]
                ]
            output_segments.append(Segment(start=seg["start"], end=seg["end"], text=text, speaker=speaker, words=words))
        return output_segments

    @staticmethod
    def _write_temp_wav(audio: np.ndarray) -> str:
        """
        GigaAM's transcribe/transcribe_longform take a file path (they shell out to ffmpeg
        themselves), not an in-memory array, so the already-decoded audio has to be written
        back out to a temporary WAV file first.
        """
        pcm16 = np.clip(audio * 32768.0, -32768, 32767).astype(np.int16)
        fd, path = tempfile.mkstemp(suffix=".wav")
        os.close(fd)
        with wave.open(path, "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(CONFIG.SAMPLE_RATE)
            wf.writeframes(pcm16.tobytes())
        return path

    def write_result(self, result: dict, file: BinaryIO, output: Union[str, None]):
        if output == "srt":
            WriteSRT(ResultWriter).write_result(result, file=file)
        elif output == "vtt":
            WriteVTT(ResultWriter).write_result(result, file=file)
        elif output == "tsv":
            WriteTSV(ResultWriter).write_result(result, file=file)
        elif output == "json":
            WriteJSON(ResultWriter).write_result(result, file=file)
        else:
            WriteTXT(ResultWriter).write_result(result, file=file)
