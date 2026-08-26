#!/usr/bin/env python3
"""Sample client: transcribes every audio file in a directory via the
whisper-asr-webservice /asr endpoint and saves each result as a .txt file next
to its source audio file (replacing it if one already exists).

Usage:
    python transcribe_client.py [--config config.yaml]
"""

import argparse
import os
import sys
from pathlib import Path

import requests
import yaml

# Environment variables, when set, override the corresponding config.yaml value.
# Used to point the same config at container paths/hostnames (see docker-compose.yml)
# without needing a separate config file.
ENV_OVERRIDES = {
    "ASR_CLIENT_SERVER_URL": "server_url",
    "ASR_CLIENT_AUDIO_DIR": "audio_dir",
}


def load_config(config_path: Path) -> dict:
    with config_path.open("r", encoding="utf-8") as f:
        config = yaml.safe_load(f) or {}

    for env_var, key in ENV_OVERRIDES.items():
        value = os.environ.get(env_var)
        if value:
            config[key] = value

    base_dir = config_path.parent
    config["audio_dir"] = (base_dir / config["audio_dir"]).resolve()
    return config


def find_audio_files(audio_dir: Path, extensions: list[str]) -> list[Path]:
    extensions = {ext.lower() for ext in extensions}
    return sorted(p for p in audio_dir.iterdir() if p.is_file() and p.suffix.lower() in extensions)


def transcribe_file(audio_path: Path, config: dict) -> str:
    params = {
        "encode": str(config["encode"]).lower(),
        "task": config["task"],
        "output": config["output_format"],
        "vad_filter": str(config["vad_filter"]).lower(),
        "word_timestamps": str(config["word_timestamps"]).lower(),
        "diarize": str(config.get("diarize", False)).lower(),
    }
    if config.get("language"):
        params["language"] = config["language"]
    if config.get("initial_prompt"):
        params["initial_prompt"] = config["initial_prompt"]
    if config.get("min_speakers") is not None:
        params["min_speakers"] = config["min_speakers"]
    if config.get("max_speakers") is not None:
        params["max_speakers"] = config["max_speakers"]

    url = f"{config['server_url'].rstrip('/')}/asr"
    with audio_path.open("rb") as f:
        files = {"audio_file": (audio_path.name, f)}
        response = requests.post(
            url,
            params=params,
            files=files,
            timeout=config["request_timeout_seconds"],
        )
    response.raise_for_status()
    return response.text


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--config",
        type=Path,
        default=Path(__file__).parent / "config.yaml",
        help="Path to config.yaml (default: config.yaml next to this script)",
    )
    args = parser.parse_args()

    config = load_config(args.config)
    audio_dir: Path = config["audio_dir"]

    if not audio_dir.is_dir():
        print(f"Audio directory not found: {audio_dir}", file=sys.stderr)
        return 1

    audio_files = find_audio_files(audio_dir, config["audio_extensions"])
    if not audio_files:
        print(f"No audio files found in {audio_dir}")
        return 0

    failures = 0
    for audio_path in audio_files:
        print(f"Transcribing {audio_path.name} ...", end=" ", flush=True)
        try:
            result_text = transcribe_file(audio_path, config)
        except requests.RequestException as exc:
            print(f"FAILED ({exc})")
            failures += 1
            continue

        output_path = audio_path.with_suffix(".txt")
        output_path.write_text(result_text, encoding="utf-8")
        print(f"-> {output_path}")

    total = len(audio_files)
    print(f"\nDone: {total - failures}/{total} succeeded.")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
