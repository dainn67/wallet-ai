#!/bin/bash
# CCPM Verification Profile: Rust
set -o pipefail

FAIL=0
PROJECT_ROOT="${1:-.}"
cd "$PROJECT_ROOT"

echo "═══ CCPM Verify: Rust ═══"
echo ""

# Step 1: Check (compile without codegen)
echo "── Step 1: Cargo Check ──"
if cargo check 2>&1; then
    echo "✅ Check: Compiles successfully"
else
    echo "❌ Check: Compilation errors found"
    FAIL=1
fi

# Step 2: Tests
echo ""
echo "── Step 2: Tests ──"
if cargo test 2>&1; then
    echo "✅ Tests: All passing"
else
    echo "❌ Tests: Failures detected"
    FAIL=1
fi

# Step 3: Clippy (linter)
echo ""
echo "── Step 3: Clippy ──"
if command -v cargo-clippy &> /dev/null || cargo clippy --version &> /dev/null; then
    if cargo clippy -- -D warnings 2>&1; then
        echo "✅ Lint: Clean"
    else
        echo "❌ Lint: Clippy warnings found"
        FAIL=1
    fi
else
    echo "⏭️ Lint: Clippy not installed, skipping"
fi

# Step 4: Format check
echo ""
echo "── Step 4: Format Check ──"
if cargo fmt --check 2>&1; then
    echo "✅ Format: Clean"
else
    echo "❌ Format: Formatting issues found"
    FAIL=1
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
