#!/usr/bin/env bash
# Builds an asr-webservice image with every model listed in warmup_models.py already
# downloaded into /root/.cache, then commits it to asr-webservice:offline (CPU) or
# asr-webservice:offline-gpu (GPU). Export the committed image to a tar for transfer with
# ./deploy/dev/scripts/offline/export-offline-image.sh.
#
# Requires HF_TOKEN in the environment to download the gated pyannote models (whisperx
# diarization, gigaam long-form VAD) - export it or `set -a; source .env; set +a` first.
# Transcription-only models still download fine without it.
#
# Usage:
#   ./deploy/dev/scripts/offline/build-offline-image.sh            # CPU (Dockerfile)
#   ./deploy/dev/scripts/offline/build-offline-image.sh gpu        # GPU (Dockerfile.gpu)
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$repo_root"

arg="${1:-}"

# Shared default image name - keep in sync with export-offline-image.sh and
# docker-compose.offline.yml.
dockerfile="Dockerfile"
image="asr-webservice:offline"
if [[ "$arg" == "gpu" ]]; then
  dockerfile="Dockerfile.gpu"
  image="asr-webservice:offline-gpu"
fi

if [[ -z "${HF_TOKEN:-}" ]]; then
  echo "WARNING: HF_TOKEN is not set - gated pyannote models (whisperx diarization, gigaam" >&2
  echo "long-form VAD) will NOT be downloaded. Export HF_TOKEN first if you need them." >&2
fi

base_tag="${image}-base"
container="asr-warmup-$$"

echo "Building base image ${base_tag} from ${dockerfile} ..."
docker build -f "$dockerfile" -t "$base_tag" .

echo "Starting warm-up container ${container} ..."
docker run -d --name "$container" --entrypoint sh -e "HF_TOKEN=${HF_TOKEN:-}" "$base_tag" -c "sleep infinity"
trap 'docker rm -f "$container" >/dev/null 2>&1 || true' EXIT

echo "Copying warm-up script into container ..."
docker cp "$repo_root/deploy/dev/scripts/offline/warmup_models.py" "$container:/app/warmup_models.py"

echo "Downloading models (this can take a while and pull tens of GB) ..."
# Double leading slash survives Git Bash/MSYS path conversion (which would otherwise rewrite
# these into Windows paths before they reach docker exec) - Linux collapses it back to one.
docker exec "$container" //app/.venv/bin/python //app/warmup_models.py

echo "Cache size:"
docker exec "$container" du -sh //root/.cache

echo "Committing warmed-up container to ${image} ..."
docker commit "$container" "$image"

echo ""
echo "Done. Image ${image} is ready. Export it to a tar for transfer with:"
echo "  ./deploy/dev/scripts/offline/export-offline-image.sh${arg:+ $arg}"
