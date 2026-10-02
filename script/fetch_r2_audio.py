#!/usr/bin/env python3
"""Fetch private, hash-pinned BGM into a native release build's asset directory."""

import argparse
import hashlib
import os
from pathlib import Path
import re
import subprocess
import tempfile


TRACKS = {
    "tense_tactics.mp3": "5a261f1d15e1bcec001ea21c12834fccb68adc9b8d1ddbb086a4bc0d1332811b",
    "metropolis_destruction.mp3": "aa82af825cf87023006bd9e22023261c7ae0e87a2a9c350015a0faf9b99a09ee",
}


def fetch_audio(destination, tracks):
    names = ("R2_AUDIO_ENDPOINT", "R2_AUDIO_BUCKET", "R2_AUDIO_ACCESS_KEY_ID", "R2_AUDIO_SECRET_ACCESS_KEY")
    missing = [name for name in names if not os.environ.get(name)]
    if missing:
        raise RuntimeError("Missing R2 audio configuration: " + ", ".join(missing))
    endpoint = os.environ["R2_AUDIO_ENDPOINT"]
    if not re.fullmatch(r"https://[a-f0-9]{32}\.r2\.cloudflarestorage\.com", endpoint):
        raise RuntimeError("Invalid R2 audio endpoint")
    bucket = os.environ["R2_AUDIO_BUCKET"]
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]{1,61}[a-z0-9]", bucket):
        raise RuntimeError("Invalid R2 audio bucket")

    aws_env = os.environ.copy()
    # Use only this bucket's dedicated credentials, even on a configured local Mac.
    for name in ("AWS_PROFILE", "AWS_DEFAULT_PROFILE", "AWS_SESSION_TOKEN", "AWS_SECURITY_TOKEN"):
        aws_env.pop(name, None)
    aws_env.update({
        "AWS_ACCESS_KEY_ID": os.environ["R2_AUDIO_ACCESS_KEY_ID"],
        "AWS_SECRET_ACCESS_KEY": os.environ["R2_AUDIO_SECRET_ACCESS_KEY"],
        "AWS_CONFIG_FILE": os.devnull,
        "AWS_SHARED_CREDENTIALS_FILE": os.devnull,
        "AWS_EC2_METADATA_DISABLED": "true",
        "AWS_PAGER": "",
        "AWS_RETRY_MODE": "standard",
        "AWS_MAX_ATTEMPTS": "3",
    })
    destination = Path(destination)
    destination.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".r2-audio-", dir=destination.parent) as temporary:
        staging = Path(temporary)
        for filename, expected_hash in tracks.items():
            path = staging / filename
            command = [
                "aws", "--endpoint-url", endpoint, "--region", "auto",
                "--cli-connect-timeout", "15", "--cli-read-timeout", "60",
                "s3api", "get-object", "--bucket", bucket, "--key", filename, str(path),
            ]
            try:
                subprocess.run(command, env=aws_env, check=True, timeout=180,
                               stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            except (OSError, subprocess.SubprocessError) as error:
                raise RuntimeError(f"R2 audio download failed: {filename}") from error
            actual_hash = hashlib.sha256(path.read_bytes()).hexdigest()
            if actual_hash != expected_hash:
                raise RuntimeError(f"R2 audio SHA-256 mismatch: {filename}")
        # Do not replace any existing asset until every download is verified.
        for filename in tracks:
            os.replace(staging / filename, destination / filename)
            print(f"Verified R2 audio: {filename}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=Path("assets/audio"))
    arguments = parser.parse_args()
    try:
        fetch_audio(arguments.output_dir, TRACKS)
    except (RuntimeError, OSError) as error:
        parser.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
