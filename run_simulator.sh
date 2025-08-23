#!/bin/bash
# Script to run Flutter app with proper simulator settings

# Set environment to disable code signing for simulator
export CODE_SIGNING_REQUIRED=NO
export CODE_SIGNING_ALLOWED=NO
export EXPANDED_CODE_SIGN_IDENTITY=""
export CODE_SIGNING_IDENTITY=""
export DEVELOPMENT_TEAM=""

# Clean and run
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter run -d "iPhone 16 Plus"
