#!/bin/bash
# Diagnose Flutter/Xcode build issues

echo "=== Flutter/Xcode Build Diagnostics ==="
echo ""

echo "1. Checking Flutter SDK location..."
which flutter
echo ""

echo "2. Checking for stuck processes..."
ps aux | grep -E "(dart|flutter|xcodebuild|impellerc)" | grep -v grep | wc -l
echo "  (If > 0, kill with: killall -9 dart flutter xcodebuild impellerc)"
echo ""

echo "3. Checking Flutter SDK health..."
flutter doctor
echo ""

echo "4. Checking for iCloud attributes on Flutter SDK..."
xattr -l /Users/tmoney/Documents/flutter/packages/flutter_tools/lib/src/build_system/targets/ios.dart 2>&1 | head -5
echo ""

echo "5. Disk space..."
df -h / | tail -1
echo ""

echo "6. Recent build artifacts..."
ls -lhtr /Users/tmoney/Documents/ONLY\ BLV/trooth_assessment/build/ios 2>/dev/null | tail -5
echo ""

echo "=== Quick Fix Commands ==="
echo "If build hangs/times out:"
echo "  1. killall -9 dart flutter xcodebuild impellerc"
echo "  2. cd /Users/tmoney/Documents/ONLY\ BLV/trooth_assessment && flutter clean"
echo "  3. rm -rf ios/Pods ios/Podfile.lock ios/.symlinks"
echo "  4. flutter pub get && cd ios && pod install"
echo ""
