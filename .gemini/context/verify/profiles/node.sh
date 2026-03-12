#!/bin/bash
# CCPM Verification Profile: Node/TypeScript
set -o pipefail

FAIL=0
PROJECT_ROOT="${1:-.}"
cd "$PROJECT_ROOT"

echo "═══ CCPM Verify: Node/TypeScript ═══"
echo ""

# Step 1: Dependencies
echo "── Step 1: Dependencies ──"
install_exit=0
if [ -f "package-lock.json" ]; then
    npm ci --silent 2>&1 || install_exit=$?
elif [ -f "pnpm-lock.yaml" ]; then
    pnpm install --frozen-lockfile --silent 2>&1 || install_exit=$?
elif [ -f "bun.lockb" ]; then
    bun install --frozen-lockfile 2>&1 || install_exit=$?
elif [ -f "package.json" ]; then
    npm install --silent 2>&1 || install_exit=$?
fi
if [ $install_exit -eq 0 ]; then
    echo "✅ Dependencies: Installed"
else
    echo "❌ Dependencies: Install failed"
    FAIL=1
fi

# Step 2: Type check
echo ""
echo "── Step 2: Type Check ──"
if [ -f "tsconfig.json" ]; then
    if npx tsc --noEmit 2>&1; then
        echo "✅ Types: Clean"
    else
        echo "❌ Types: Errors found"
        FAIL=1
    fi
else
    echo "⏭️ Types: No tsconfig.json, skipping"
fi

# Step 3: Lint
echo ""
echo "── Step 3: Lint ──"
if [ -f ".eslintrc.json" ] || [ -f ".eslintrc.js" ] || [ -f "eslint.config.js" ] || [ -f "eslint.config.mjs" ]; then
    if npx eslint . 2>&1; then
        echo "✅ Lint: Clean"
    else
        echo "❌ Lint: Issues found"
        FAIL=1
    fi
elif command -v biome &> /dev/null || [ -f "biome.json" ]; then
    if npx biome check . 2>&1; then
        echo "✅ Lint: Clean"
    else
        echo "❌ Lint: Issues found"
        FAIL=1
    fi
else
    echo "⏭️ Lint: No linter configured, skipping"
fi

# Step 4: Tests
echo ""
echo "── Step 4: Tests ──"
if grep -q '"test"' package.json 2>/dev/null; then
    if npm test 2>&1; then
        echo "✅ Tests: All passing"
    else
        echo "❌ Tests: Failures detected"
        FAIL=1
    fi
else
    echo "⏭️ Tests: No test script in package.json, skipping"
fi

# Step 5: Build
echo ""
echo "── Step 5: Build ──"
if grep -q '"build"' package.json 2>/dev/null; then
    if npm run build 2>&1; then
        echo "✅ Build: Success"
    else
        echo "❌ Build: Failed"
        FAIL=1
    fi
else
    echo "⏭️ Build: No build script, skipping"
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
