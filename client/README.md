# Sample Python client

Transcribes every audio file in [`../audio/`](../audio/) by calling a running whisper-asr-webservice
instance's `/asr` endpoint, and writes each result to `<filename>.txt` next to its source audio
file, replacing it if one already exists.

## Setup

```shell
cd client
python -m venv .venv && source .venv/bin/activate   # optional
pip install -r requirements.txt
```

Or skip the manual venv/install steps with `./scripts/python-start.sh` (run from the repo
root) — it creates/reuses `client/.venv`, (re)installs `client/requirements.txt` only when it
has changed, and runs the client. It's the fastest way to iterate locally (no Docker
build/startup):

```shell
./scripts/python-start.sh
./scripts/python-start.sh --config other.yaml   # extra args are forwarded
```

Make sure a whisper-asr-webservice instance is running (see the repo root [README.md](../README.md)),
e.g.:

```shell
docker run -d -p 9000:9000 -e ASR_MODEL=base -e ASR_ENGINE=openai_whisper onerahmet/openai-whisper-asr-webservice:latest
```

## Configure

Edit [`config.yaml`](config.yaml) to set the server URL, the input audio directory, and the
`/asr` request options (task, language, VAD, word timestamps, diarization, etc.). Comments in
that file explain each field.

Speaker diarization (`diarize: true`, plus optional `min_speakers`/`max_speakers`) only works
when the server is running with `ASR_ENGINE=whisperx` and a valid `HF_TOKEN` — see the repo
root [README.md](../README.md) and [`.env.example`](../.env.example). It also only shows up in
the output if `output_format` is `json`, `srt`, or `vtt`; plain `txt` output has no speaker
labels.

## Run

```shell
python transcribe_client.py
# or: python transcribe_client.py --config path/to/other-config.yaml
```

Each audio file in `audio_dir` produces one `<stem>.txt` file next to it, containing the
transcription (an existing `.txt` with the same name is replaced). Files that fail to
transcribe are reported but don't stop the rest of the batch; the script exits non-zero if any
file failed.

## Running via Docker Compose

Instead of installing dependencies locally, the whole flow (start the ASR service, wait for
it, transcribe everything in `audio/`) can be run with one command from the repo root:

```shell
# copy .env.example to .env first if you need HF_TOKEN or other overrides
./scripts/docker-rebuild.sh      # build/refresh images (first run, or after changes)
./scripts/docker-start.sh        # CPU
./scripts/docker-start.sh gpu    # GPU
```

`docker-start` starts the `whisper-asr-webservice` (or `-gpu`) service using whatever images
already exist, waits for it to become ready, then runs the `client` service (defined in
`docker-compose.yml` / `docker-compose.gpu.yml`, `profiles: [client]` so it never starts with
a plain `docker compose up`) against it. The client container reads and writes `./audio` on
the host, dropping each `<filename>.txt` next to its source file — `config.yaml` is overridden
via the `ASR_CLIENT_SERVER_URL` / `ASR_CLIENT_AUDIO_DIR` env vars set in the compose file, so no
separate container config is needed.

`docker-rebuild` rebuilds the ASR service image every time, and the client image only if
something under `client/` has actually changed since the last build (hashed and compared
against `client/.docker-build-hash`) — so repeated runs are fast instead of re-building the
client image every time:

```shell
./scripts/docker-rebuild.sh        # CPU compose project
./scripts/docker-rebuild.sh gpu    # GPU compose project
```

To stop the service (and remove its containers/network — images and the cache volume are
left in place):

```shell
./scripts/docker-stop.sh        # CPU
./scripts/docker-stop.sh gpu    # GPU
```

To run the client alone against an already-running service, without any rebuild check:

```shell
docker compose run --rm client
```
