# Production deployment (offline / air-gapped server)

Runs the preloaded offline image (`asr-webservice:offline`) that was built and exported on
a machine with internet access — see [deploy/dev/offline/](../dev/offline/README.md) for
the build/export side. This directory is self-contained: the `service-*` scripts operate
on the `docker-compose.yml` next to themselves, so the whole `deploy/prod/` folder can be
copied to the server as-is (it doesn't need the rest of the repo).

## 1. One-time setup on the server

Transfer the image tar (from `dist/`, e.g. `asr-webservice-preloaded.tar`) and this
`deploy/prod/` folder to the server, then:

```bash
docker load -i asr-webservice-preloaded.tar
```

Optionally create a `.env` file next to `docker-compose.yml` (git-ignored; docker compose
reads it automatically) to configure the service without editing the compose file:

```bash
HF_TOKEN=hf_xxx          # only needed for diarization (license check on cached models)
#ASR_ENGINE=whisperx     # any engine/model combination baked in by warmup_models.py
#ASR_MODEL=large-v3
#ASR_IMAGE=asr-webservice:offline-gpu   # if you shipped the GPU variant
```

Defaults without a `.env`: `asr-webservice:offline` image, `gigaam` / `v3_ctc`.

## 2. Day-to-day operation

```bash
./deploy/prod/service-start.sh     # start, then wait until ready on :9000
./deploy/prod/service-stop.sh      # stop and remove the container (image stays)
./deploy/prod/service-restart.sh   # recreate (e.g. after editing .env), wait until ready
./deploy/prod/service-logs.sh      # follow the logs (last 100 lines + live)
```

Swagger UI: http://localhost:9000/docs
