#!/usr/bin/env bash
# Rebuilds the docker compose ASR service image (always) and the client image (only if
# client/ has changed since the last build — hash-gated via client/.docker-build-hash, so
# it's cheap to call on every startup).
#
# Usage:
#   ./scripts/docker-rebuild.sh            # CPU (docker-compose.yml)
#   ./scripts/docker-rebuild.sh gpu        # GPU (docker-compose.gpu.yml)
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

arg="${1:-}"

compose_file="docker-compose.yml"
service="whisper-asr-webservice"
if [[ "$arg" == "gpu" ]]; then
  compose_file="docker-compose.gpu.yml"
  service="whisper-asr-webservice-gpu"
fi

echo "Building ${service} ..."
docker compose -f "$compose_file" build "$service"

hash_file="client/.docker-build-hash"

current_hash="$(
  find client -type f \
    ! -name ".docker-build-hash" \
    -print0 \
  | sort -z \
  | xargs -0 sha256sum \
  | sha256sum \
  | awk '{print $1}'
)"

previous_hash=""
if [[ -f "$hash_file" ]]; then
  previous_hash="$(cat "$hash_file")"
fi

if [[ "$current_hash" == "$previous_hash" ]]; then
  echo "client/ unchanged — skipping client image build."
else
  echo "client/ changed — building client image..."
  docker compose -f "$compose_file" build client
  echo "$current_hash" > "$hash_file"
fi
