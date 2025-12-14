#!/usr/bin/env bash
# reset_flutter_ios.sh
# Reset a Flutter project for a fresh iOS build.

set -euo pipefail

# -------- config / helpers --------
PROJECT_ROOT="$(pwd)"
IOS_DIR="$PROJECT_ROOT/ios"

log() { printf "\n🔧 %s\n" "$*"; }

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "❌ Required command not found: $1"
    exit 1
  fi
}

# -------- preflight checks --------
require_cmd flutter
if [[ "$OSTYPE" == "darwin"* ]]; then
  require_cmd pod
else
  echo "⚠️  This script targets macOS/iOS (CocoaPods)."
fi

log "Project root: $PROJECT_ROOT"
cd "$PROJECT_ROOT"

# -------- Flutter cleanup --------
log "Cleaning Flutter artifacts..."
flutter clean

# Optional: ensure iOS artifacts are available (useful after SDK updates)
log "Pre-caching Flutter iOS artifacts (safe, sometimes saves time later)..."
flutter precache --ios

log "Fetching Dart/Flutter packages..."
flutter pub get

# -------- Xcode DerivedData cleanup (macOS) --------
if [[ "$OSTYPE" == "darwin"* ]]; then
  DERIVEDDATA="$HOME/Library/Developer/Xcode/DerivedData"
  if [[ -d "$DERIVEDDATA" ]]; then
    log "Removing Xcode DerivedData (may take a bit)..."
    rm -rf "$DERIVEDDATA"/*
  else
    log "Skipping DerivedData removal (not found)."
  fi
fi

# -------- CocoaPods cleanup & reinstall --------
log "Resetting CocoaPods..."
cd "$IOS_DIR"

# Clean the workspace integration (safe to re-generate)
pod deintegrate

# Remove lockfile, pods, symlinks, and sometimes-stale podspec
rm -rf Podfile.lock Pods .symlinks Flutter/Flutter.podspec

# Reinstall Pods with repo update in one shot (faster than separate update)
log "Installing pods with repo update..."
pod install --repo-update

# -------- Optional Android cleanup (uncomment if you want parity) --------
# log "Android cleanup (optional)..."
# cd "$PROJECT_ROOT/android"
# ./gradlew clean

# -------- Finish --------
cd "$PROJECT_ROOT"
log "All done! Consider opening the workspace and building:"
echo "   open ios/Runner.xcworkspace"
echo "   # or build from CLI:"
echo "   flutter build ios"