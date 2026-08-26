#!/usr/bin/env bash
# Builds a whisper-asr-webservice image with every model listed in warmup_models.py already
# downloaded into /root/.cache, then saves it to a tar file for transfer to a server with no
# internet access. On that server: `docker load -i <tar>` then run docker-compose.offline.yml.
#
# Requires HF_TOKEN in the environment to download the gated pyannote models (whisperx
# diarization, gigaam long-form VAD) - export it or `set -a; source .env; set +a` first.
# Transcription-only models still download fine without it.
#
# Usage:
#   ./scripts/offline/build-offline-image.sh            # CPU (Dockerfile)
#   ./scripts/offline/build-offline-image.sh gpu        # GPU (Dockerfile.gpu)
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

arg="${1:-}"

dockerfile="Dockerfile"
tag="whisper-asr-webservice:offline"
out_file="whisper-asr-preloaded.tar"
if [[ "$arg" == "gpu" ]]; then
  dockerfile="Dockerfile.gpu"
  tag="whisper-asr-webservice:offline-gpu"
  out_file="whisper-asr-preloaded-gpu.tar"
fi

if [[ -z "${HF_TOKEN:-}" ]]; then
  echo "WARNING: HF_TOKEN is not set - gated pyannote models (whisperx diarization, gigaam" >&2
  echo "long-form VAD) will NOT be downloaded. Export HF_TOKEN first if you need them." >&2
fi

preloaded_tag="${tag}-preloaded"
container="asr-warmup-$$"

echo "Building base image ${tag} from ${dockerfile} ..."
docker build -f "$dockerfile" -t "$tag" .

echo "Starting warm-up container ${container} ..."
docker run -d --name "$container" --entrypoint sh -e "HF_TOKEN=${HF_TOKEN:-}" "$tag" -c "sleep infinity"
trap 'docker rm -f "$container" >/dev/null 2>&1 || true' EXIT

echo "Copying warm-up script into container ..."
docker cp "$repo_root/scripts/offline/warmup_models.py" "$container:/app/warmup_models.py"

echo "Downloading models (this can take a while and pull tens of GB) ..."
docker exec "$container" /app/.venv/bin/python /app/warmup_models.py

echo "Cache size:"
docker exec "$container" du -sh /root/.cache

echo "Committing warmed-up container to ${preloaded_tag} ..."
docker commit "$container" "$preloaded_tag"

echo "Saving image to ${out_file} ..."
docker save "$preloaded_tag" -o "$out_file"

echo ""
echo "Done. Transfer ${out_file} to the isolated server, then:"
echo "  docker load -i ${out_file}"
echo "  docker compose -f scripts/offline/docker-compose.offline.yml up -d"
