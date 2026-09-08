#!/usr/bin/env bash
# Starts the asr-webservice production container via docker compose, using the preloaded
# offline image (asr-webservice:offline), then waits until the webservice answers on :9000.
# The image must already be on this host — on the isolated server load the transferred tar
# first: docker load -i <asr-webservice-preloaded tar>.
#
# Usage (from anywhere; the script operates on the compose file next to itself):
#   ./deploy/prod/service-start.sh
#
# HF_TOKEN and overrides (ASR_ENGINE, ASR_MODEL, ASR_IMAGE for the GPU tag): put them in a
# .env file next to docker-compose.yml — docker compose reads it automatically.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

service="asr-webservice"

# Resolved image reference, applying the same ASR_IMAGE default / .env interpolation
# docker compose itself would use.
image="$(docker compose -f docker-compose.yml config --images | head -n 1)"

if ! docker image inspect "$image" >/dev/null 2>&1; then
  echo "ERROR: image '${image}' not found on this host." >&2
  echo "Load the transferred tar first, e.g.:" >&2
  echo "  docker load -i asr-webservice-preloaded.tar" >&2
  exit 1
fi

echo "Starting ${service} (image ${image}) ..."
docker compose -f docker-compose.yml up -d "$service"

if ! command -v curl >/dev/null 2>&1; then
  echo "curl not found on this host - skipping the readiness check."
  exit 0
fi

echo "Waiting for ${service} to become ready ..."
ready=0
for _ in $(seq 1 60); do
  if curl --silent --fail --output /dev/null "http://localhost:9000/docs"; then
    ready=1
    break
  fi
  sleep 5
done

if [[ "$ready" == 1 ]]; then
  echo "${service} is ready."
else
  echo "WARNING: ${service} did not answer on http://localhost:9000/docs within 5 minutes." >&2
  echo "Check what it is doing with service-logs.sh (same directory)." >&2
  exit 1
fi
