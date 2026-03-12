#!/bin/bash
# CCPM Verification Profile: Python
set -o pipefail

FAIL=0
PROJECT_ROOT="${1:-.}"
cd "$PROJECT_ROOT"

echo "═══ CCPM Verify: Python ═══"
echo ""

# Step 1: Syntax check
echo "── Step 1: Syntax Check ──"
if find . -name "*.py" -not -path "*/venv/*" -not -path "*/.venv/*" \
  -exec python3 -m py_compile {} \; 2>&1; then
    echo "✅ Syntax: All .py files compile"
else
    echo "❌ Syntax: Compilation errors found"
    FAIL=1
fi

# Step 2: Import check
echo ""
echo "── Step 2: Import Check ──"
MAIN_PKG=$(find . -maxdepth 2 -name "__init__.py" -not -path "*/test*" \
  -not -path "*/venv/*" -not -path "*/.venv/*" | head -1 | xargs dirname 2>/dev/null)
if [ -n "$MAIN_PKG" ]; then
    if python3 -c "import importlib; importlib.import_module('$(echo "$MAIN_PKG" | sed 's|^\./||' | tr '/' '.')')" 2>&1; then
        echo "✅ Import: Main package imports successfully"
    else
        echo "❌ Import: Main package import failed"
        FAIL=1
    fi
else
    echo "⏭️ Import: No main package found, skipping"
fi

# Step 3: Tests
echo ""
echo "── Step 3: Tests ──"
if [ -f "pytest.ini" ] || [ -f "pyproject.toml" ] || [ -d "tests" ]; then
    if python3 -m pytest tests/ -v --tb=short 2>&1; then
        echo "✅ Tests: All passing"
    else
        echo "❌ Tests: Failures detected"
        FAIL=1
    fi
else
    echo "⏭️ Tests: No test configuration found, skipping"
fi

# Step 4: Lint
echo ""
echo "── Step 4: Lint ──"
if command -v ruff &> /dev/null; then
    ruff check . --fix 2>&1 || true
    if ruff check . 2>&1; then
        echo "✅ Lint: Clean"
    else
        echo "❌ Lint: Issues found"
        FAIL=1
    fi
elif command -v flake8 &> /dev/null; then
    if flake8 . 2>&1; then
        echo "✅ Lint: Clean"
    else
        echo "❌ Lint: Issues found"
        FAIL=1
    fi
else
    echo "⏭️ Lint: No linter available, skipping"
fi

# Step 5: Type check
echo ""
echo "── Step 5: Type Check ──"
if command -v mypy &> /dev/null && { [ -f "mypy.ini" ] || [ -f "pyproject.toml" ]; }; then
    if mypy . --ignore-missing-imports 2>&1; then
        echo "✅ Types: Clean"
    else
        echo "❌ Types: Errors found"
        FAIL=1
    fi
else
    echo "⏭️ Types: mypy not configured, skipping"
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
