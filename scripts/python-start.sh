#!/usr/bin/env bash
# Runs the sample client directly with Python (no Docker) — fast for local iteration.
# Creates/reuses a venv under client/.venv and (re)installs client/requirements.txt only
# when it has changed, then runs client/transcribe_client.py.
#
# Expects an ASR service already running (e.g. `poetry run whisper-asr-webservice` or
# `docker compose up whisper-asr-webservice`) at the server_url configured in client/config.yaml.
#
# Usage:
#   ./scripts/python-start.sh                          # uses client/config.yaml
#   ./scripts/python-start.sh --config other.yaml       # extra args forwarded as-is
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root/client"

venv_dir=".venv"
marker="$venv_dir/.requirements.hash"

# Picks the first interpreter that actually runs — command -v alone isn't enough on
# Windows, where a `python3` shim can exist on PATH but fail to execute (Microsoft Store alias).
python_cmd=()
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1 && "$candidate" --version >/dev/null 2>&1; then
    python_cmd=("$candidate")
    break
  fi
done
if [[ ${#python_cmd[@]} -eq 0 ]] && command -v py >/dev/null 2>&1; then
  python_cmd=(py -3)
fi
if [[ ${#python_cmd[@]} -eq 0 ]]; then
  echo "No working Python interpreter found (tried python3, python, py -3)." >&2
  exit 1
fi

if [[ ! -d "$venv_dir" ]]; then
  echo "Creating venv at client/$venv_dir ..."
  "${python_cmd[@]}" -m venv "$venv_dir"
fi

if [[ -x "$venv_dir/bin/python" ]]; then
  venv_python="$venv_dir/bin/python"
else
  venv_python="$venv_dir/Scripts/python.exe"
fi

current_hash="$(sha256sum requirements.txt | awk '{print $1}')"
previous_hash=""
[[ -f "$marker" ]] && previous_hash="$(cat "$marker")"

if [[ "$current_hash" != "$previous_hash" ]]; then
  echo "Installing client dependencies ..."
  "$venv_python" -m pip install --quiet --upgrade pip
  "$venv_python" -m pip install --quiet -r requirements.txt
  echo "$current_hash" > "$marker"
fi

exec "$venv_python" transcribe_client.py "$@"
