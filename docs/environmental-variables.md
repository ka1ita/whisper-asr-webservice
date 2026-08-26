### Configuring the `Engine`

=== ":octicons-file-code-16: `openai_whisper`"

    ```shell
    export ASR_ENGINE=openai_whisper
    ```

=== ":octicons-file-code-16: `faster_whisper`"

    ```shell
    export ASR_ENGINE=faster_whisper
    ```

=== ":octicons-file-code-16: `whisperx`"

    ```shell
    export ASR_ENGINE=whisperx
    ```

=== ":octicons-file-code-16: `gigaam`"

    ```shell
    export ASR_ENGINE=gigaam
    ```

### Configuring the `Model`

```shell
export ASR_MODEL=base
```

Available ASR_MODELs are:

- Standard models: `tiny`, `base`, `small`, `medium`, `large-v1`, `large-v2`, `large-v3` (or `large`), `large-v3-turbo` (or `turbo`)
- English-optimized models: `tiny.en`, `base.en`, `small.en`, `medium.en`
- Distilled models: `distil-large-v2`, `distil-medium.en`, `distil-small.en`, `distil-large-v3` (only for whisperx and faster-whisper)

For English-only applications, the `.en` models tend to perform better, especially for the `tiny.en` and `base.en`
models. We observed that the difference becomes less significant for the `small.en` and `medium.en` models.

The distilled models offer improved inference speed while maintaining good accuracy.

For the `gigaam` engine (Russian-focused, from [GigaAM](https://github.com/salute-developers/GigaAM)),
`ASR_MODEL` is a GigaAM model name instead. Available ASR_MODELs are:

- Short names (aliased to the `v3_*` models below): `rnnt` (default), `ctc`, `e2e_rnnt`, `e2e_ctc`
- Russian-only models: `v1_rnnt`, `v1_ctc`, `v2_rnnt`, `v2_ctc`, `v3_rnnt`, `v3_ctc`, `v3_e2e_rnnt`, `v3_e2e_ctc`
- Multilingual models (CTC only): `multilingual_ctc`, `multilingual_large_ctc`
- A local filesystem path to a fine-tuned `.ckpt` checkpoint

GigaAM also ships `*_ssl` (self-supervised pretraining: `v1_ssl`, `v2_ssl`, `v3_ssl`, `multilingual_ssl`,
`multilingual_large_ssl`) and `emo` (emotion recognition) model names, but those aren't speech-to-text
models and aren't usable with this engine's transcription pipeline.

Audio longer than 25 seconds is automatically handled via GigaAM's own long-form transcription, which
requires `HF_TOKEN` (see below) to download a pyannote voice-activity-detection model.

### Configuring the `Model Path`

```shell
export ASR_MODEL_PATH=/data/whisper
```

### Configuring the `Model Unloading Timeout`

```shell
export MODEL_IDLE_TIMEOUT=300
```

Defaults to `0`. After no activity for this period (in seconds), unload the model until it is requested again. Setting
`0` disables the timeout, keeping the model loaded indefinitely.

### Configuring the `SAMPLE_RATE`

```shell
export SAMPLE_RATE=16000
```

Defaults to `16000`. Default sample rate for audio input. `16 kHz` is commonly used in `speech-to-text` tasks.

### Configuring Device and Quantization

```shell
export ASR_DEVICE=cuda  # or 'cpu'
export ASR_QUANTIZATION=float32  # or 'float16', 'int8'
```

The `ASR_DEVICE` defaults to `cuda` if GPU is available, otherwise `cpu`. 

The `ASR_QUANTIZATION` defines the precision for model weights:

- `float32`: 32-bit floating-point precision (higher precision, slower inference)
- `float16`: 16-bit floating-point precision (lower precision, faster inference)
- `int8`: 8-bit integer precision (lowest precision, fastest inference)

Defaults to `float32` for GPU, `int8` for CPU.

### Configuring Subtitle Options (WhisperX)

```shell
export SUBTITLE_MAX_LINE_WIDTH=1000
export SUBTITLE_MAX_LINE_COUNT=2
export SUBTITLE_HIGHLIGHT_WORDS=false
```

These options only apply when using the WhisperX engine:

- `SUBTITLE_MAX_LINE_WIDTH`: Maximum width of subtitle lines (default: 1000)
- `SUBTITLE_MAX_LINE_COUNT`: Maximum number of lines per subtitle (default: 2)
- `SUBTITLE_HIGHLIGHT_WORDS`: Enable word highlighting in subtitles (default: false)

### Hugging Face Token

```shell
export HF_TOKEN=your_token_here
```

Required when using the WhisperX engine to download the diarization model, and when using the GigaAM
engine (for its long-form audio VAD model and/or diarization).

When using `docker compose`, copy `.env.example` to `.env` and set `HF_TOKEN` there instead —
`docker-compose.yml` and `docker-compose.gpu.yml` both load it via `env_file`.
