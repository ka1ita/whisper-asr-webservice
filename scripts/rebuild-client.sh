#!/usr/bin/env bash
# Rebuilds the docker compose "client" image, but only if anything under client/
# (excluding client/output/) has changed since the last build. Safe/cheap to call
# on every startup — it no-ops when there's nothing to do.
#
# Usage:
#   ./scripts/rebuild-client.sh            # CPU (docker-compose.yml)
#   ./scripts/rebuild-client.sh gpu        # GPU (docker-compose.gpu.yml)
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

compose_file="docker-compose.yml"
if [[ "${1:-}" == "gpu" ]]; then
  compose_file="docker-compose.gpu.yml"
fi

hash_file="client/.docker-build-hash"

current_hash="$(
  find client -type f \
    ! -path "client/output/*" \
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
  exit 0
fi

echo "client/ changed — building client image..."
docker compose -f "$compose_file" build client
echo "$current_hash" > "$hash_file"
