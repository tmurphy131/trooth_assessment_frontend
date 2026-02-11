#!/bin/bash
# Build iOS app with RevenueCat API key from Google Secret Manager

set -e

cd "$(dirname "$0")/.."

echo "🔑 Fetching RevenueCat API key from Secret Manager..."
REVENUECAT_KEY=$(gcloud secrets versions access latest --secret=REVENUECAT_APPLE_KEY --project=trooth-prod)

if [ -z "$REVENUECAT_KEY" ]; then
    echo "❌ Failed to fetch RevenueCat API key"
    exit 1
fi

echo "✅ API key retrieved (${REVENUECAT_KEY:0:10}...)"

echo "🧹 Cleaning..."
flutter clean

echo "📦 Getting packages..."
flutter pub get

echo "🔨 Building IPA..."
flutter build ipa --release --dart-define=REVENUECAT_APPLE_KEY=$REVENUECAT_KEY

echo ""
echo "✅ Build complete!"
echo "📁 IPA location: build/ios/ipa/"
echo ""
echo "Upload to App Store Connect using:"
echo "  - Transporter app (recommended)"
echo "  - Or: xcrun altool --upload-app -f build/ios/ipa/*.ipa -t ios -u YOUR_APPLE_ID"
