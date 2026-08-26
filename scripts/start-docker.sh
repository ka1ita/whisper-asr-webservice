#!/usr/bin/env bash
# Starts whisper-asr-webservice via docker compose, waits for it to become ready,
# rebuilds the client image only if client/ has changed (see rebuild-client.sh), then
# runs the sample client (docker-compose.yml "client" service) against it.
#
# Usage:
#   ./scripts/start-docker.sh            # CPU (docker-compose.yml)
#   ./scripts/start-docker.sh gpu        # GPU (docker-compose.gpu.yml)
#
# HF_TOKEN and other overrides: copy .env.example to .env and edit it first.
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

if [[ ! -f .env && -f .env.example ]]; then
  echo "No .env found — copying .env.example to .env (edit it to set HF_TOKEN etc.)."
  cp .env.example .env
fi

echo "Starting ${service} ..."
docker compose -f "$compose_file" up -d --build "$service"

echo "Waiting for ${service} to become ready..."
for _ in $(seq 1 60); do
  if curl --silent --fail --output /dev/null "http://localhost:9000/docs"; then
    echo "${service} is ready."
    break
  fi
  sleep 5
done

"$repo_root/scripts/rebuild-client.sh" "$arg"

echo "Running client against ${service} ..."
docker compose -f "$compose_file" run --rm client
