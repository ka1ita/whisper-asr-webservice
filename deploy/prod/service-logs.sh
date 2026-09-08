#!/usr/bin/env bash
# Shows the asr-webservice production container logs: the last 100 lines, then follows
# live output (Ctrl-C to exit).
#
# Usage (from anywhere; the script operates on the compose file next to itself):
#   ./deploy/prod/service-logs.sh                     # follow live logs
#   ./deploy/prod/service-logs.sh --tail 500          # extra args replace the defaults and
#   ./deploy/prod/service-logs.sh --no-color          #   pass through to docker compose logs
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

if [[ $# -gt 0 ]]; then
  docker compose -f docker-compose.yml logs "$@" asr-webservice
else
  docker compose -f docker-compose.yml logs -f --tail 100 asr-webservice
fi
