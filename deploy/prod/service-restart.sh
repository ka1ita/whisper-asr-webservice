#!/usr/bin/env bash
# Force-recreates the asr-webservice production container without reloading the image —
# use this after changing ASR_ENGINE / ASR_MODEL / HF_TOKEN in the .env file, since
# `docker compose up` alone won't recreate an already-running container just because .env
# changed.
#
# Usage (from anywhere; the script operates on the compose file next to itself):
#   ./deploy/prod/service-restart.sh
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

service="asr-webservice"

echo "Force-recreating ${service} ..."
docker compose -f docker-compose.yml up -d --force-recreate "$service"

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
