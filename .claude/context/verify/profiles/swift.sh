#!/bin/bash
# CCPM Verification Profile: Swift/iOS
set -o pipefail

FAIL=0
PROJECT_ROOT="${1:-.}"
cd "$PROJECT_ROOT"

echo "═══ CCPM Verify: Swift/iOS ═══"
echo ""

# Detect project type
if [ -f "Package.swift" ]; then
    BUILD_SYSTEM="spm"
elif ls ./*.xcodeproj 1>/dev/null 2>&1; then
    BUILD_SYSTEM="xcode"
    SCHEME=$(xcodebuild -list -json 2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin)
schemes=d.get('project',{}).get('schemes',[])
print(schemes[0] if schemes else '')
" 2>/dev/null)
else
    echo "❌ No Swift project found"
    echo "VERIFY_FAIL: No Package.swift or .xcodeproj"
    exit 1
fi

# Step 1: Build
echo "── Step 1: Build ──"
if [ "$BUILD_SYSTEM" = "spm" ]; then
    swift build 2>&1
else
    xcodebuild -scheme "$SCHEME" \
      -destination 'platform=iOS Simulator,name=iPhone 16' \
      build 2>&1 | tail -10
fi
if [ $? -eq 0 ]; then
    echo "✅ Build: Success"
else
    echo "❌ Build: Failed"
    FAIL=1
fi

# Step 2: Tests
echo ""
echo "── Step 2: Tests ──"
if [ "$BUILD_SYSTEM" = "spm" ]; then
    swift test 2>&1
else
    xcodebuild -scheme "$SCHEME" \
      -destination 'platform=iOS Simulator,name=iPhone 16' \
      test 2>&1 | tail -20
fi
if [ $? -eq 0 ]; then
    echo "✅ Tests: All passing"
else
    echo "❌ Tests: Failures detected"
    FAIL=1
fi

# Step 3: SwiftLint
echo ""
echo "── Step 3: SwiftLint ──"
if command -v swiftlint &> /dev/null; then
    if swiftlint lint --strict 2>&1; then
        echo "✅ Lint: Clean"
    else
        echo "❌ Lint: Issues found"
        FAIL=1
    fi
else
    echo "⏭️ Lint: SwiftLint not installed, skipping"
fi

echo ""
echo "═══════════════════════════"
if [ $FAIL -eq 0 ]; then
    echo "VERIFY_PASS"
    exit 0
else
    echo "VERIFY_FAIL: One or more checks failed. See output above."
    exit 1
fi
