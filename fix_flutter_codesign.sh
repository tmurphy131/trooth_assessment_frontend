#!/bin/bash
# Script to fix Flutter framework codesigning for iOS Simulator

echo "Fixing Flutter framework codesigning issues..."

# Navigate to project directory
cd /Users/tmoney/Documents/ONLY\ BLV/trooth_assessment

# Clean and rebuild with specific focus on codesigning
echo "Cleaning project completely..."
flutter clean
rm -rf ios/Pods
rm -rf ios/Podfile.lock
rm -rf build/
rm -rf ios/.symlinks
rm -rf ios/Flutter/ephemeral
rm -rf .dart_tool

# Get dependencies
echo "Getting Flutter dependencies..."
flutter pub get

# Reinstall pods with clean slate
echo "Reinstalling CocoaPods..."
cd ios
pod cache clean --all
pod deintegrate
pod install --repo-update
cd ..

# Create custom Xcode configuration to disable codesigning for simulator
echo "Creating simulator build configuration..."
mkdir -p ios/Flutter
cat > ios/Flutter/Debug-Simulator.xcconfig << EOF
#include "Generated.xcconfig"
CODE_SIGNING_ALLOWED=NO
CODE_SIGNING_REQUIRED=NO
CODE_SIGN_IDENTITY=""
DEVELOPMENT_TEAM=""
PROVISIONING_PROFILE=""
PROVISIONING_PROFILE_SPECIFIER=""
EOF

# Modify the Flutter framework to not require codesigning
echo "Configuring Flutter engine for simulator..."

# Build specifically for simulator using environment variables to disable codesigning
export CODE_SIGNING_REQUIRED=NO
export CODE_SIGNING_ALLOWED=NO
export CODE_SIGN_IDENTITY=""

echo "Building for iOS Simulator with codesigning disabled..."
flutter build ios --simulator --debug --verbose 2>&1 | tee flutter_build.log

# Check if build failed due to codesigning, try direct xcodebuild
if [ $? -ne 0 ]; then
    echo "Flutter build failed, trying direct xcodebuild approach..."
    cd ios
    xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug \
        -destination 'platform=iOS Simulator,name=iPhone 16 Plus' \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGN_IDENTITY="" \
        DEVELOPMENT_TEAM="" \
        PROVISIONING_PROFILE="" \
        clean build 2>&1 | tee ../xcodebuild.log
    cd ..
fi

echo "Build completed. Checking for Flutter.framework..."
if [ -d "build/ios/Debug-iphonesimulator/Flutter.framework" ]; then
    echo "Flutter framework found. Attempting to run on simulator..."
    flutter run -d "iPhone 16 Plus" --verbose
else
    echo "Flutter framework not found. Build may have failed."
    echo "Check flutter_build.log and xcodebuild.log for details."
fi
