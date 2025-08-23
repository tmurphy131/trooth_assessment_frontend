#!/bin/bash
# Quick fix for Flutter framework codesigning issue

echo "Applying codesigning fix for iOS Simulator..."

# Navigate to project directory
cd /Users/tmoney/Documents/ONLY\ BLV/trooth_assessment

# Set environment variables to disable codesigning
export CODE_SIGNING_REQUIRED=NO
export CODE_SIGNING_ALLOWED=NO
export CODE_SIGN_IDENTITY=""

echo "Building for iOS Simulator with codesigning disabled..."

# Try direct xcodebuild approach since flutter build still has codesigning issues
cd ios
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug \
    -destination 'platform=iOS Simulator,name=iPhone 16 Plus' \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGN_IDENTITY="" \
    DEVELOPMENT_TEAM="" \
    PROVISIONING_PROFILE="" \
    clean build 2>&1 | tee ../xcodebuild_direct.log

if [ $? -eq 0 ]; then
    echo "Build successful! Launching app on simulator..."
    cd ..
    flutter run -d "iPhone 16 Plus" --verbose
else
    echo "Build failed. Check xcodebuild_direct.log for details."
    cd ..
fi
