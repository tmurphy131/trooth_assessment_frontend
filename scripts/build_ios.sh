#!/bin/bash
# Build a store IPA against the production backend (same as the release
# workflow). Prefer pushing a v* tag; use this for a manual upload.

set -e

cd "$(dirname "$0")/.."

API_BASE_URL="https://trooth-discipleship-api.onlyblv.com/"

echo "🧹 Cleaning..."
flutter clean

echo "📦 Getting packages..."
flutter pub get

echo "🔨 Building IPA (backend: $API_BASE_URL)..."
flutter build ipa --release --dart-define=API_BASE_URL=$API_BASE_URL

echo "📤 Uploading dSYMs to Crashlytics..."
./build/ios/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/upload-symbols \
  -gsp ios/Runner/GoogleService-Info.plist -p ios build/ios/archive/Runner.xcarchive/dSYMs \
  || echo "⚠️  dSYM upload failed; native iOS crashes won't be symbolicated for this build"

echo ""
echo "✅ Build complete!"
echo "📁 IPA location: build/ios/ipa/"
echo ""
echo "Upload to App Store Connect using:"
echo "  - Transporter app (recommended)"
echo "  - Or: xcrun altool --upload-app -f build/ios/ipa/*.ipa -t ios -u YOUR_APPLE_ID"
