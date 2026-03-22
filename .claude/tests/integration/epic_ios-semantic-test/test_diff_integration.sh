#!/bin/bash
# Integration Tests: diff-detect.sh — end-to-end with real git repo
# Creates a temp git repo, stages View files, runs detect_and_filter
set -euo pipefail

PASS=0
FAIL=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/qa/diff-detect.sh"
SCENARIO_DIR="$REPO_ROOT/.claude/qa/scenarios"

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

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if printf '%s' "$haystack" | grep -qF "$needle"; then
    echo "  ✅ $desc"
    (( PASS++ )) || true
  else
    echo "  ❌ $desc: expected to contain '$needle' in: $haystack"
    (( FAIL++ )) || true
  fi
}

echo "=== Diff-Detect Integration Tests ==="

# ---------------------------------------------------------------------------
# Setup: temp git repo with fake Swift files
# ---------------------------------------------------------------------------
TMPDIR_WORK=$(mktemp -d)
trap 'rm -rf "$TMPDIR_WORK"' EXIT

echo ""
echo "-- Setup temp git repo --"

cd "$TMPDIR_WORK"
git init -q
git config user.email "test@test.com"
git config user.name "Test"

# Create initial commit (needed for git diff HEAD to work)
touch README.md
git add README.md
git commit -q -m "initial"

# Create scenario dir mirroring real project
mkdir -p .claude/qa/scenarios
cp "$SCENARIO_DIR"/*.md .claude/qa/scenarios/ 2>/dev/null || true

# Source the script from real repo location (which sources axe-wrapper.sh from same dir)
# We need to set SCRIPT_DIR-equivalent for the sourced functions
# Approach: copy scripts/qa/ into temp repo so source paths work
mkdir -p scripts/qa
cp "$REPO_ROOT/scripts/qa/axe-wrapper.sh" scripts/qa/
cp "$SCRIPT" scripts/qa/diff-detect.sh

echo "  ✅ temp repo created at $TMPDIR_WORK"
(( PASS++ )) || true

# ---------------------------------------------------------------------------
# Test 1: Clean working tree → fallback (all scenarios)
# ---------------------------------------------------------------------------
echo ""
echo "-- Test: clean working tree → fallback --"

cd "$TMPDIR_WORK"
# Source in temp dir context
DETECT_RESULT=$(bash -c "source scripts/qa/diff-detect.sh && detect_affected_screens" 2>/dev/null)

assert_contains "clean tree → success:true" '"success":true' "$DETECT_RESULT"
assert_contains "clean tree → fallback key present" '"fallback"' "$DETECT_RESULT"

# ---------------------------------------------------------------------------
# Test 2: Change a View file → detected screen matches
# ---------------------------------------------------------------------------
echo ""
echo "-- Test: QuizView.swift changed → QuizView detected --"

cd "$TMPDIR_WORK"
# Create and stage a Swift View file change
echo "// QuizView change" > QuizView.swift
git add QuizView.swift

DETECT_RESULT=$(bash -c "source scripts/qa/diff-detect.sh && detect_affected_screens" 2>/dev/null)

assert_contains "QuizView.swift staged → success:true" '"success":true' "$DETECT_RESULT"
assert_contains "QuizView.swift staged → QuizView in screens" '"QuizView"' "$DETECT_RESULT"

# ---------------------------------------------------------------------------
# Test 3: detect_and_filter with View change → returns quiz-flow scenario
# ---------------------------------------------------------------------------
echo ""
echo "-- Test: detect_and_filter with QuizView change --"

cd "$TMPDIR_WORK"
FILTER_RESULT=$(bash -c "source scripts/qa/diff-detect.sh && detect_and_filter" 2>/dev/null)

assert_contains "detect_and_filter → success:true" '"success":true' "$FILTER_RESULT"
assert_contains "detect_and_filter → quiz-flow.md in scenarios" "quiz-flow.md" "$FILTER_RESULT"

# ---------------------------------------------------------------------------
# Test 4: ViewController change → strips suffix, detects screen
# ---------------------------------------------------------------------------
echo ""
echo "-- Test: SettingsViewController.swift changed → SettingsView detected --"

cd "$TMPDIR_WORK"
git reset HEAD QuizView.swift -q 2>/dev/null || true
echo "// SettingsViewController change" > SettingsViewController.swift
git add SettingsViewController.swift

DETECT_RESULT=$(bash -c "source scripts/qa/diff-detect.sh && detect_affected_screens" 2>/dev/null)

assert_contains "SettingsViewController staged → SettingsView detected" '"SettingsView"' "$DETECT_RESULT"

# ---------------------------------------------------------------------------
# Test 5: Non-screen file (Model) → no screens detected, fallback
# ---------------------------------------------------------------------------
echo ""
echo "-- Test: QuizModel.swift changed → no screens, fallback --"

cd "$TMPDIR_WORK"
git reset HEAD SettingsViewController.swift -q 2>/dev/null || true
echo "// QuizModel change" > QuizModel.swift
git add QuizModel.swift

DETECT_RESULT=$(bash -c "source scripts/qa/diff-detect.sh && detect_affected_screens" 2>/dev/null)

assert_contains "QuizModel staged → fallback (not a screen file)" '"fallback"' "$DETECT_RESULT"

# ---------------------------------------------------------------------------
# Test 6: Multiple View files → union of screens
# ---------------------------------------------------------------------------
echo ""
echo "-- Test: Multiple View files → union of screens --"

cd "$TMPDIR_WORK"
git reset HEAD QuizModel.swift -q 2>/dev/null || true
echo "// QuizView" > QuizView.swift
echo "// SettingsView" > SettingsViewController.swift
git add QuizView.swift SettingsViewController.swift

DETECT_RESULT=$(bash -c "source scripts/qa/diff-detect.sh && detect_affected_screens" 2>/dev/null)

assert_contains "multiple files → QuizView in screens" '"QuizView"' "$DETECT_RESULT"
assert_contains "multiple files → SettingsView in screens" '"SettingsView"' "$DETECT_RESULT"

# ---------------------------------------------------------------------------
# Test 7: /qa:run --diff-aware flag handling described in run.md
# ---------------------------------------------------------------------------
echo ""
echo "-- Test: --diff-aware flag parsing (documented in commands/qa/run.md) --"

RUN_MD="$REPO_ROOT/commands/qa/run.md"
if grep -q '\-\-diff-aware' "$RUN_MD"; then
  echo "  ✅ commands/qa/run.md contains --diff-aware documentation"
  (( PASS++ )) || true
else
  echo "  ❌ commands/qa/run.md missing --diff-aware documentation"
  (( FAIL++ )) || true
fi

if grep -q 'diff-detect.sh' "$RUN_MD"; then
  echo "  ✅ commands/qa/run.md references diff-detect.sh"
  (( PASS++ )) || true
else
  echo "  ❌ commands/qa/run.md does not reference diff-detect.sh"
  (( FAIL++ )) || true
fi

if grep -q 'detect_and_filter' "$RUN_MD"; then
  echo "  ✅ commands/qa/run.md calls detect_and_filter"
  (( PASS++ )) || true
else
  echo "  ❌ commands/qa/run.md does not call detect_and_filter"
  (( FAIL++ )) || true
fi

if grep -q 'Diff-aware:' "$RUN_MD"; then
  echo "  ✅ commands/qa/run.md report header includes Diff-aware info"
  (( PASS++ )) || true
else
  echo "  ❌ commands/qa/run.md report header missing Diff-aware info"
  (( FAIL++ )) || true
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
