#!/usr/bin/env bash
set -euo pipefail

export UID
export GID="$(id -g)"
docker compose build
echo "Build complete. Run './scripts/run.sh' to start."
