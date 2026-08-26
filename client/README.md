# Sample Python client

Transcribes every audio file in [`../audio/`](../audio/) by calling a running whisper-asr-webservice
instance's `/asr` endpoint, and writes each result to `client/output/<filename>.txt`.

## Setup

```shell
cd client
python -m venv .venv && source .venv/bin/activate   # optional
pip install -r requirements.txt
```

Make sure a whisper-asr-webservice instance is running (see the repo root [README.md](../README.md)),
e.g.:

```shell
docker run -d -p 9000:9000 -e ASR_MODEL=base -e ASR_ENGINE=openai_whisper onerahmet/openai-whisper-asr-webservice:latest
```

## Configure

Edit [`config.yaml`](config.yaml) to set the server URL, input/output directories, and the
`/asr` request options (task, language, VAD, word timestamps, etc.). Comments in that file
explain each field.

## Run

```shell
python transcribe_client.py
# or: python transcribe_client.py --config path/to/other-config.yaml
```

Each audio file in `audio_dir` produces one `<stem>.txt` file in `output_dir` containing the
transcription. Files that fail to transcribe are reported but don't stop the rest of the batch;
the script exits non-zero if any file failed.

## Running via Docker Compose

Instead of installing dependencies locally, the whole flow (start the ASR service, wait for
it, transcribe everything in `audio/`) can be run with one command from the repo root:

```shell
# copy .env.example to .env first if you need HF_TOKEN or other overrides
./scripts/start-docker.sh        # CPU
./scripts/start-docker.sh gpu    # GPU
# Windows: .\scripts\start-docker.ps1  [-Gpu]
```

This builds and starts the `whisper-asr-webservice` (or `-gpu`) service, then runs the
`client` service (defined in `docker-compose.yml` / `docker-compose.gpu.yml`, `profiles:
[client]` so it never starts with a plain `docker compose up`) against it. The client
container reads `./audio` read-only and writes results to `./client/output` on the host —
`config.yaml` is overridden via the `ASR_CLIENT_SERVER_URL` / `ASR_CLIENT_AUDIO_DIR` /
`ASR_CLIENT_OUTPUT_DIR` env vars set in the compose file, so no separate container config is
needed.

To run the client alone against an already-running service:

```shell
docker compose run --rm --build client
```
