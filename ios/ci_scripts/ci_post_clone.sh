#!/bin/sh

# Fail this script if any subcommand fails.
set -e

# The default execution directory of this script is the ci_scripts directory.
cd $CI_PRIMARY_REPOSITORY_PATH # change working directory to the root of your cloned repo.

# Install Flutter using git.
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

# Install Flutter artifacts for iOS (--ios), or macOS (--macos) platforms.
flutter precache --ios

# Install Flutter dependencies.
flutter pub get

# Install CocoaPods using Homebrew.
HOMEBREW_NO_AUTO_UPDATE=1 # disable homebrew's automatic updates.
brew install cocoapods

# Install CocoaPods dependencies with retry logic for network failures.
cd ios

# Retry pod install up to 3 times with exponential backoff
MAX_RETRIES=3
RETRY_COUNT=0
RETRY_DELAY=5

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  echo "Attempting pod install (attempt $((RETRY_COUNT + 1)) of $MAX_RETRIES)..."
  
  if pod install --verbose; then
    echo "Pod install succeeded!"
    exit 0
  else
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
      echo "Pod install failed. Retrying in ${RETRY_DELAY} seconds..."
      sleep $RETRY_DELAY
      RETRY_DELAY=$((RETRY_DELAY * 2))  # Exponential backoff
      
      # Clean CocoaPods cache and try again
      pod cache clean --all
      rm -rf Pods Podfile.lock
    else
      echo "Pod install failed after $MAX_RETRIES attempts."
      exit 1
    fi
  fi
done

exit 1
