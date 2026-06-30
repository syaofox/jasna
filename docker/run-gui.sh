#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

export MY_UID="$(id -u)"
export MY_GID="$(id -g)"

echo "==> Allowing X11 connections from local containers"
xhost +local:

cleanup() {
    echo
    echo "==> Revoking X11 access for local containers"
    xhost -local:
}
trap cleanup EXIT

echo "==> Starting Jasna GUI"
echo "    Press Ctrl+C to stop."
echo
docker compose up
