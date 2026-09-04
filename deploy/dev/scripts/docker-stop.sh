#!/usr/bin/env bash
# Stops the asr-webservice docker compose service and removes its containers/network
# (images and the cache-whisper volume are left in place — rerun docker-start.sh to bring it
# back up without rebuilding).
#
# Usage:
#   ./deploy/dev/scripts/docker-stop.sh            # CPU (docker-compose.yml)
#   ./deploy/dev/scripts/docker-stop.sh gpu        # GPU (docker-compose.gpu.yml)
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$repo_root"

compose_file="docker-compose.yml"
if [[ "${1:-}" == "gpu" ]]; then
  compose_file="docker-compose.gpu.yml"
fi

echo "Stopping services in ${compose_file} ..."
docker compose -f "$compose_file" down
