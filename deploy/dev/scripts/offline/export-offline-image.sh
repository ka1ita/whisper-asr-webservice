#!/usr/bin/env bash
# Exports an already-built preloaded image (see build-offline-image.sh) to a tar file under
# deploy/prod/dist/ for transfer to a server with no internet access. On that server:
#   docker load -i deploy/prod/dist/<tar>
#   docker compose -f deploy/dev/scripts/offline/docker-compose.offline.yml up -d
#
# build-offline-image.sh builds and commits the preloaded image but does NOT write a tar;
# run this script to export the committed image into deploy/prod/dist/.
#
# Usage:
#   ./deploy/dev/scripts/offline/export-offline-image.sh                 # CPU (asr-webservice:offline)
#   ./deploy/dev/scripts/offline/export-offline-image.sh gpu             # GPU (asr-webservice:offline-gpu)
#   ./deploy/dev/scripts/offline/export-offline-image.sh <image[:tag]>   # explicit image reference
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$repo_root"

arg="${1:-}"

# Shared default image name - keep in sync with build-offline-image.sh and
# docker-compose.offline.yml.
image="asr-webservice:offline"
out_file="whisper-asr-preloaded.tar"
case "$arg" in
  ""|cpu)
    ;;
  gpu)
    image="asr-webservice:offline-gpu"
    out_file="whisper-asr-preloaded-gpu.tar"
    ;;
  *)
    image="$arg"
    out_file="$(printf '%s' "$arg" | tr '/:' '__').tar"
    ;;
esac

if ! docker image inspect "$image" >/dev/null 2>&1; then
  echo "ERROR: image '${image}' not found - run ./deploy/dev/scripts/offline/build-offline-image.sh first." >&2
  exit 1
fi

mkdir -p "$repo_root/deploy/prod/dist"
out_path="deploy/prod/dist/${out_file}"

echo "Exporting ${image} to ${out_path} ..."
docker save "$image" -o "$repo_root/$out_path"

echo ""
echo "Done ($(du -h "$repo_root/$out_path" | cut -f1)). Transfer ${out_path} to the isolated server, then:"
echo "  docker load -i ${out_file}"
echo "  docker compose -f deploy/dev/scripts/offline/docker-compose.offline.yml up -d"
