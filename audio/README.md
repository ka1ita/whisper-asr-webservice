# audio/

Drop sample audio files here for manual testing and for the sample client in [`client/`](../client/).

- Any format ffmpeg can decode works (`.wav`, `.mp3`, `.m4a`, `.flac`, `.ogg`, ...).
- `sample_tone.wav` is a synthetic 2-second 440Hz tone included only to verify the pipeline end-to-end (upload, request, response, file written) — it contains no speech, so transcription output will be empty/near-empty. Replace it with real speech recordings to see meaningful ASR results.
- Files in this directory are not tracked for content correctness by the project; add whatever samples are useful for your own testing.
