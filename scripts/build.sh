#!/bin/bash

# Wally AI Build Script
# Usage: ./scripts/build.sh <a|i|android|ios> <version> <build_number>
# Example: ./scripts/build.sh a 1.0.0 5

PLATFORM=$1
VERSION=$2
BUILD_NUMBER=$3

# Function to show usage
show_usage() {
    echo "Usage: ./scripts/build.sh <a|i|android|ios> <version> <build_number>"
    echo "Example: ./scripts/build.sh a 1.0.0 5"
    exit 1
}

# Validate arguments
if [ -z "$PLATFORM" ] || [ -z "$VERSION" ] || [ -z "$BUILD_NUMBER" ]; then
    show_usage
fi

if [[ "$PLATFORM" == "a" || "$PLATFORM" == "android" ]]; then
    PLATFORM_NAME="android"
elif [[ "$PLATFORM" == "i" || "$PLATFORM" == "ios" ]]; then
    PLATFORM_NAME="ios"
else
    echo "Error: Platform must be 'a', 'i', 'android' or 'ios'"
    show_usage
fi

# Check for fvm
if ! command -v fvm &> /dev/null; then
    echo "Error: fvm is not installed. Please install fvm first."
    exit 1
fi

echo "🚀 Starting build for $PLATFORM_NAME (version: $VERSION, build_number: $BUILD_NUMBER)..."

# 1. Update version in pubspec.yaml
echo "📝 Updating pubspec.yaml to $VERSION+$BUILD_NUMBER..."
perl -i -pe "s/version: \d+\.\d+\.\d+\+\d+/version: ${VERSION}+${BUILD_NUMBER}/g" pubspec.yaml
if [ $? -ne 0 ]; then
    echo "❌ Failed to update version in pubspec.yaml."
    exit 1
fi
echo "✅ Updated pubspec.yaml"

# 2. Clean and get dependencies
echo "🧹 Cleaning project..."
fvm flutter clean

echo "📦 Getting dependencies..."
fvm flutter pub get

# 3. Build
if [ "$PLATFORM_NAME" == "android" ]; then
    echo "🤖 Building Android App Bundle..."
    fvm flutter build appbundle --build-name="$VERSION" --build-number="$BUILD_NUMBER"
else
    echo "🍎 Building iOS IPA..."
    fvm flutter build ipa --build-name="$VERSION" --build-number="$BUILD_NUMBER"
fi

if [ $? -eq 0 ]; then
    echo "✅ Build completed successfully!"
else
    echo "❌ Build failed!"
    exit 1
fi
