#!/usr/bin/env bash
# Force-recreates the asr-webservice container without rebuilding the image — use this
# after editing .env (e.g. ASR_MODEL) to make docker compose re-read env_file into a fresh
# container, since `docker compose up` alone won't restart an already-running container just
# because .env changed.
#
# Usage:
#   ./deploy/dev/scripts/docker-restart.sh            # CPU (docker-compose.yml)
#   ./deploy/dev/scripts/docker-restart.sh gpu        # GPU (docker-compose.gpu.yml)
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$repo_root"

arg="${1:-}"

compose_file="docker-compose.yml"
service="asr-webservice"
if [[ "$arg" == "gpu" ]]; then
  compose_file="docker-compose.gpu.yml"
  service="asr-webservice-gpu"
fi

echo "Force-recreating ${service} ..."
docker compose -f "$compose_file" up -d --force-recreate "$service"

echo "Waiting for ${service} to become ready..."
for _ in $(seq 1 60); do
  if curl --silent --fail --output /dev/null "http://localhost:9000/docs"; then
    echo "${service} is ready."
    break
  fi
  sleep 5
done
