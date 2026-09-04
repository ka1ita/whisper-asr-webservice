#!/usr/bin/env bash
# Starts asr-webservice via docker compose (using whatever images already exist —
# run ./deploy/dev/scripts/docker-rebuild.sh first to build/refresh them), waits for it to
# become ready, then runs the sample client (docker-compose.yml "client" service) against it.
#
# Usage:
#   ./deploy/dev/scripts/docker-start.sh            # CPU (docker-compose.yml)
#   ./deploy/dev/scripts/docker-start.sh gpu        # GPU (docker-compose.gpu.yml)
#
# HF_TOKEN and other overrides: copy .env.example to .env and edit it first.
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

if [[ ! -f .env && -f .env.example ]]; then
  echo "No .env found — copying .env.example to .env (edit it to set HF_TOKEN etc.)."
  cp .env.example .env
fi

echo "Starting ${service} ..."
docker compose -f "$compose_file" up -d "$service"

echo "Waiting for ${service} to become ready..."
for _ in $(seq 1 60); do
  if curl --silent --fail --output /dev/null "http://localhost:9000/docs"; then
    echo "${service} is ready."
    break
  fi
  sleep 5
done

echo "Running client against ${service} ..."
docker compose -f "$compose_file" run --rm client
