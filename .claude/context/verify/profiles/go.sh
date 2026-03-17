#!/bin/bash
# CCPM Verification Profile: Go
set -o pipefail

FAIL=0
PROJECT_ROOT="${1:-.}"
cd "$PROJECT_ROOT"

echo "═══ CCPM Verify: Go ═══"
echo ""

# Step 1: Vet
echo "── Step 1: Go Vet ──"
if go vet ./... 2>&1; then
    echo "✅ Vet: Clean"
else
    echo "❌ Vet: Issues found"
    FAIL=1
fi

# Step 2: Build
echo ""
echo "── Step 2: Build ──"
if go build ./... 2>&1; then
    echo "✅ Build: Success"
else
    echo "❌ Build: Failed"
    FAIL=1
fi

# Step 3: Tests
echo ""
echo "── Step 3: Tests ──"
if go test ./... -v 2>&1; then
    echo "✅ Tests: All passing"
else
    echo "❌ Tests: Failures detected"
    FAIL=1
fi

# Step 4: Lint
echo ""
echo "── Step 4: Lint ──"
if command -v golangci-lint &> /dev/null; then
    if golangci-lint run 2>&1; then
        echo "✅ Lint: Clean"
    else
        echo "❌ Lint: Issues found"
        FAIL=1
    fi
else
    echo "⏭️ Lint: golangci-lint not installed, skipping"
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
