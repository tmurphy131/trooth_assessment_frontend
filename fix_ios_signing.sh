#!/bin/bash
# Script to fix iOS simulator code signing issues

echo "Setting up automatic code signing for iOS Simulator..."

# Navigate to project directory
cd /Users/tmoney/Documents/ONLY\ BLV/trooth_assessment

# Clean everything
echo "Cleaning project..."
flutter clean
rm -rf ios/Pods
rm -rf ios/Podfile.lock
rm -rf build/

# Regenerate packages after cleaning
echo "Getting dependencies..."
flutter pub get

# Update pod repo
echo "Updating CocoaPods..."
cd ios
pod repo update --silent
pod deintegrate
pod install
cd ..

# Build with specific Xcode settings for simulator
echo "Building for iOS Simulator with automatic code signing..."
flutter build ios --simulator --debug --verbose 2>&1 | tee build.log

# If build fails, try manual xcodebuild
if [ $? -ne 0 ]; then
    echo "Flutter build failed, trying direct xcodebuild..."
    cd ios
    xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug \
        -destination 'platform=iOS Simulator,name=iPhone 16 Plus' \
        -allowProvisioningUpdates \
        CODE_SIGN_STYLE=Automatic \
        CODE_SIGNING_ALLOWED=YES \
        CODE_SIGNING_REQUIRED=NO \
        DEVELOPMENT_TEAM="" \
        clean build
    cd ..
fi

echo "Attempting to run on simulator..."
flutter run -d "iPhone 16 Plus" --verbose
