# Offline / air-gapped deployment

Bakes ASR model weights into the docker image so it can run on a server with no internet
access. Every engine downloads its models on first use; since an isolated server can't reach
the internet, the models need to already be present in the image before it's transferred
there.

Because `ASR_ENGINE`/`ASR_MODEL` select a single engine and model at runtime, this preloads a
*curated* set rather than literally everything - see the constants at the top of
[warmup_models.py](warmup_models.py) for exactly what's included and to change it:

- `openai_whisper` / `faster_whisper` / `whisperx`: `small`, `medium`, `large-v3`, `large-v3-turbo`
- `gigaam`: `v3_rnnt`, `v3_ctc`, `v3_e2e_rnnt`, `v3_e2e_ctc`
- `whisperx` word-alignment models: `en`, `ru`
- `whisperx`/`gigaam` diarization pipeline and gigaam's long-form VAD model (gated on HF_TOKEN)

Expect the resulting image to be tens of GB - downloading and saving it takes a while.

## 1. Build the preloaded image (on a machine with internet)

```bash
export HF_TOKEN=hf_xxx   # needed for whisperx diarization + gigaam long-form VAD; omit to skip those
./scripts/offline/build-offline-image.sh          # CPU (Dockerfile)
./scripts/offline/build-offline-image.sh gpu      # GPU (Dockerfile.gpu)
```

This builds the normal image, runs [warmup_models.py](warmup_models.py) inside a throwaway
container to populate `/root/.cache`, commits that container to
`asr-webservice:offline-preloaded` (or `-gpu`), and saves it to
`whisper-asr-preloaded.tar` (or `-gpu.tar`) in the repo root. `HF_TOKEN` is only ever passed as
a runtime env var to the warm-up container, never baked into an image layer.

## 2. Transfer

Copy the tar file to the isolated server (scp, USB, etc.) however you'd normally move files
into that environment.

## 3. Load and run on the isolated server

```bash
docker load -i whisper-asr-preloaded.tar
docker compose -f scripts/offline/docker-compose.offline.yml up -d
```

Edit `ASR_ENGINE`/`ASR_MODEL` in [docker-compose.offline.yml](docker-compose.offline.yml) first
to pick one of the models baked in above. Set `HF_TOKEN` in the shell (or a `.env` file next to
it) if you need diarization on that server too - the token is only used to satisfy the pyannote
license check when loading an already-cached model, not to download anything.

To run without compose instead:

```bash
docker run -d -p 9000:9000 \
  -e ASR_ENGINE=gigaam -e ASR_MODEL=v3_e2e_rnnt -e HF_TOKEN=hf_xxx \
  asr-webservice:offline-preloaded
```

## Updating the model set later

Edit the constants in `warmup_models.py`, then rerun `build-offline-image.sh` and repeat the
transfer - there's no incremental update path, the whole image gets rebuilt and re-shipped.

## Why not the `cache-whisper` volume from docker-compose.yml?

The main `docker-compose.yml` mounts a named volume at `/root/.cache` for local dev, so model
downloads survive container recreation without bloating the dev image. `docker-compose.offline.yml`
deliberately skips that mount: the models are already in the image layer, and mounting a
volume there only matters if you want the isolated server to *also* persist newly-downloaded
models (which it can't do anyway, being offline) or reuse a cache across image updates. If you
add that volume back, note Docker only auto-populates a named volume from the image's directory
content when the volume is brand new - a volume that already exists (e.g. leftover from an
earlier `docker run` on that host) stays whatever it already was and will shadow the preloaded
cache.
