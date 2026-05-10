#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="TokenWatcher"
APP_PATH="$PROJECT_DIR/dist/$APP_NAME.app"
SOURCES_DIR="$PROJECT_DIR/Sources"

if ! command -v fswatch &>/dev/null; then
    echo "fswatch not found. Install with: brew install fswatch"
    exit 1
fi

build_and_launch() {
    echo ""
    echo "[dev] Change detected — rebuilding..."
    pkill -x "$APP_NAME" 2>/dev/null || true
    if bash "$SCRIPT_DIR/build-app.sh"; then
        open "$APP_PATH"
        echo "[dev] Launched. Watching for changes..."
    else
        echo "[dev] Build failed. Fix errors and save again."
    fi
}

echo "[dev] Initial build..."
build_and_launch

fswatch -o "$SOURCES_DIR" | while read -r _; do
    build_and_launch
done
