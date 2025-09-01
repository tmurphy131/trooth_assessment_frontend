#!/bin/bash
# Recursively strip extended attributes (incl. provenance) from frameworks before codesign
set -euo pipefail
TARGET_DIR="$1"
if [ ! -d "$TARGET_DIR" ]; then
  echo "Target dir $TARGET_DIR does not exist" >&2
  exit 0
fi
# Use xattr -rc (c = clear recursive) on macOS 15; fallback loop if needed
if xattr -h 2>&1 | grep -q -- '-c'; then
  echo "Clearing extended attributes recursively under $TARGET_DIR" >&2
  xattr -rc "$TARGET_DIR" || true
else
  echo "Clearing extended attributes via manual traversal" >&2
  find "$TARGET_DIR" -type f -o -type d | while read -r p; do
    xattr -c "$p" 2>/dev/null || true
  done
fi
