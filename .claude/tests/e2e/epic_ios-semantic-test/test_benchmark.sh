#!/bin/bash
# E2E Tests: NFR-2 Benchmark set validation
# Tests that the benchmark directory has correct structure
set -euo pipefail

PASS=0
FAIL=0
BENCHMARK_DIR=".claude/qa/benchmark"

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  ✅ $desc"
    (( PASS++ )) || true
  else
    echo "  ❌ $desc: expected '$expected', got '$actual'"
    (( FAIL++ )) || true
  fi
}

echo "=== NFR-2 Benchmark Tests ==="

# Test 1: Benchmark directory exists
if [ -d "$BENCHMARK_DIR" ]; then
  echo "  ✅ benchmark directory exists"
  (( PASS++ )) || true
else
  echo "  ❌ benchmark directory not found: $BENCHMARK_DIR"
  (( FAIL++ )) || true
  echo ""
  echo "Results: $PASS passed, $FAIL failed"
  exit 1
fi

# Test 2: 50 state directories exist
state_count=$(ls -d "$BENCHMARK_DIR"/state-* 2>/dev/null | wc -l | tr -d ' ')
assert_eq "50 state directories" "50" "$state_count"

# Test 3: Each state has required files
missing_files=0
for i in $(seq -w 1 50); do
  state_dir="$BENCHMARK_DIR/state-$i"
  if [ ! -d "$state_dir" ]; then
    echo "  ❌ Missing directory: $state_dir"
    (( missing_files++ )) || true
    continue
  fi
  for file in accessibility-tree.json assertion.md ground-truth.md; do
    if [ ! -f "$state_dir/$file" ]; then
      echo "  ❌ Missing: $state_dir/$file"
      (( missing_files++ )) || true
    fi
  done
done
if [ "$missing_files" -eq 0 ]; then
  echo "  ✅ All states have required files (accessibility-tree.json, assertion.md, ground-truth.md)"
  (( PASS++ )) || true
else
  echo "  ❌ $missing_files missing files"
  (( FAIL++ )) || true
fi

# Test 4: Each accessibility-tree.json is valid JSON
invalid_json=0
for i in $(seq -w 1 50); do
  tree_file="$BENCHMARK_DIR/state-$i/accessibility-tree.json"
  if [ -f "$tree_file" ]; then
    if ! jq . "$tree_file" >/dev/null 2>&1; then
      echo "  ❌ Invalid JSON: $tree_file"
      (( invalid_json++ )) || true
    fi
  fi
done
if [ "$invalid_json" -eq 0 ]; then
  echo "  ✅ All accessibility-tree.json files are valid JSON"
  (( PASS++ )) || true
else
  echo "  ❌ $invalid_json invalid JSON files"
  (( FAIL++ )) || true
fi

# Test 5: 25 PASS verdicts (states 01-25)
pass_count=0
for i in $(seq -w 1 25); do
  truth_file="$BENCHMARK_DIR/state-$i/ground-truth.md"
  if [ -f "$truth_file" ]; then
    verdict=$(grep '^Verdict:' "$truth_file" | sed 's/Verdict: //' | tr -d '[:space:]')
    if [ "$verdict" = "PASS" ]; then
      (( pass_count++ )) || true
    fi
  fi
done
assert_eq "25 PASS verdicts in states 01-25" "25" "$pass_count"

# Test 6: 25 FAIL verdicts (states 26-50)
fail_count=0
for i in $(seq -w 26 50); do
  truth_file="$BENCHMARK_DIR/state-$i/ground-truth.md"
  if [ -f "$truth_file" ]; then
    verdict=$(grep '^Verdict:' "$truth_file" | sed 's/Verdict: //' | tr -d '[:space:]')
    if [ "$verdict" = "FAIL" ]; then
      (( fail_count++ )) || true
    fi
  fi
done
assert_eq "25 FAIL verdicts in states 26-50" "25" "$fail_count"

# Test 7: Benchmark runner script exists and is executable
if [ -f "$BENCHMARK_DIR/run-benchmark.sh" ]; then
  echo "  ✅ run-benchmark.sh exists"
  (( PASS++ )) || true
else
  echo "  ❌ run-benchmark.sh not found"
  (( FAIL++ )) || true
fi

# Test 8: README exists
if [ -f "$BENCHMARK_DIR/README.md" ]; then
  echo "  ✅ README.md exists"
  (( PASS++ )) || true
else
  echo "  ❌ README.md not found"
  (( FAIL++ )) || true
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
