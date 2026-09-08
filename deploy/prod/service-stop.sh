#!/usr/bin/env bash
# Stops the asr-webservice production container and removes it along with the compose
# network (the preloaded image is left in place — rerun service-start.sh to bring it back
# without reloading anything).
#
# Usage (from anywhere; the script operates on the compose file next to itself):
#   ./deploy/prod/service-stop.sh
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

echo "Stopping asr-webservice ..."
docker compose -f docker-compose.yml down
