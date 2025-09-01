#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$ROOT_DIR/../build/ios/Debug-iphonesimulator/Runner.app"
if [ ! -d "$APP_DIR" ]; then
  echo "Runner.app not found at $APP_DIR (build first)." >&2
  exit 0
fi
if xattr -h 2>&1 | grep -q -- '-c'; then
  echo "Recursively clearing xattrs in $APP_DIR" >&2
  xattr -rc "$APP_DIR" || true
else
  echo "Fallback clearing xattrs (no -c flag)" >&2
  find "$APP_DIR" -type f -o -type d | while read -r p; do
    xattr -c "$p" 2>/dev/null || true
  done
fi
