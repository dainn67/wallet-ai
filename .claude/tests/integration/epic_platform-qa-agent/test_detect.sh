#!/bin/bash
# Integration Tests: detect-agents.sh
# Tests detection with/without *.xcodeproj, timing, and non-blocking behavior
set -euo pipefail

PASS=0
FAIL=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$REPO_ROOT"

DETECT_SCRIPT="$REPO_ROOT/scripts/qa/detect-agents.sh"
REGISTRY="$REPO_ROOT/config/qa-agents.json"

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

assert_empty() {
  local desc="$1" val="$2"
  if [ -z "$val" ]; then
    echo "  ✅ $desc"
    (( PASS++ )) || true
  else
    echo "  ❌ $desc: expected empty, got: $val"
    (( FAIL++ )) || true
  fi
}

# Helper: create a temp git repo with .claude/config/qa-agents.json
# Args: $1=config_json, $2=optional subdir to create (e.g. "Test.xcodeproj")
make_git_project() {
  local config_json="$1"
  local extra_dir="${2:-}"
  local d
  d=$(mktemp -d)
  git init "$d" -q
  mkdir -p "$d/.claude/config"
  printf '%s' "$config_json" > "$d/.claude/config/qa-agents.json"
  [ -n "$extra_dir" ] && mkdir -p "$d/$extra_dir"
  echo "$d"
}

echo "=== Detect Agents Integration Tests ==="

# Prerequisites
echo ""
echo "-- Prerequisites --"
if [ -f "$DETECT_SCRIPT" ]; then
  echo "  ✅ scripts/qa/detect-agents.sh exists"
  (( PASS++ )) || true
else
  echo "  ❌ scripts/qa/detect-agents.sh not found — run T191 first"
  (( FAIL++ )) || true
  echo ""; echo "Results: $PASS passed, $FAIL failed"; exit 1
fi

if [ -f "$REGISTRY" ]; then
  echo "  ✅ config/qa-agents.json exists"
  (( PASS++ )) || true
else
  echo "  ❌ config/qa-agents.json not found — run T191 first"
  (( FAIL++ )) || true
  echo ""; echo "Results: $PASS passed, $FAIL failed"; exit 1
fi

REGISTRY_JSON=$(cat "$REGISTRY")

# Test 1: iOS detection — project WITH *.xcodeproj
echo ""
echo "-- iOS detection (with xcodeproj) --"
TMPDIR_IOS=$(make_git_project "$REGISTRY_JSON" "Test.xcodeproj")
trap 'rm -rf "$TMPDIR_IOS"' EXIT

output=$(cd "$TMPDIR_IOS" && bash "$DETECT_SCRIPT" 2>/dev/null || true)
assert_contains "xcodeproj present → detects ios-qa-agent" "ios-qa-agent" "$output"

trap - EXIT
rm -rf "$TMPDIR_IOS"

# Test 2: No match — project WITHOUT *.xcodeproj
echo ""
echo "-- No match (without xcodeproj) --"
TMPDIR_NOIOS=$(make_git_project "$REGISTRY_JSON" "")
trap 'rm -rf "$TMPDIR_NOIOS"' EXIT

output=$(cd "$TMPDIR_NOIOS" && bash "$DETECT_SCRIPT" 2>/dev/null || true)
assert_empty "no xcodeproj → empty output" "$output"

(cd "$TMPDIR_NOIOS" && bash "$DETECT_SCRIPT" >/dev/null 2>&1)
exit_code=$?
assert_eq "no xcodeproj → exit 0" "0" "$exit_code"

trap - EXIT
rm -rf "$TMPDIR_NOIOS"

# Test 3: NFR-2 — zero degradation: no Tier 5 output for non-iOS project
echo ""
echo "-- NFR-2: non-iOS project has no QA agent output --"
NOQA_JSON='{"agents":[{"name":"ios-qa-agent","detect_pattern":"*.xcodeproj","command":"echo qa","blocking":false,"timeout":10}]}'
TMPDIR_NOQA=$(make_git_project "$NOQA_JSON" "")
trap 'rm -rf "$TMPDIR_NOQA"' EXIT

output=$(cd "$TMPDIR_NOQA" && bash "$DETECT_SCRIPT" 2>/dev/null || true)
assert_empty "non-iOS project → no QA agent output (NFR-2)" "$output"

trap - EXIT
rm -rf "$TMPDIR_NOQA"

# Test 4: NFR-1 — performance < 100ms
echo ""
echo "-- NFR-1: detect-agents.sh completes < 100ms --"
TMPDIR_PERF=$(make_git_project "$REGISTRY_JSON" "")
trap 'rm -rf "$TMPDIR_PERF"' EXIT

start_ns=$(date +%s%N 2>/dev/null || echo "")
(cd "$TMPDIR_PERF" && bash "$DETECT_SCRIPT" >/dev/null 2>&1) || true
end_ns=$(date +%s%N 2>/dev/null || echo "")

if [ -n "$start_ns" ] && [ -n "$end_ns" ]; then
  elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))
  if [ "$elapsed_ms" -lt 100 ]; then
    echo "  ✅ detect-agents.sh completed in ${elapsed_ms}ms (< 100ms, NFR-1)"
    (( PASS++ )) || true
  else
    echo "  ❌ detect-agents.sh took ${elapsed_ms}ms (>= 100ms, NFR-1 violated)"
    (( FAIL++ )) || true
  fi
else
  echo "  ⚠️  nanosecond timing unavailable — skipping NFR-1 timing check"
fi

trap - EXIT
rm -rf "$TMPDIR_PERF"

# Test 5: FR-1 — empty registry → empty output, exit 0
echo ""
echo "-- FR-1: empty registry → empty output, exit 0 --"
TMPDIR_EMPTY=$(make_git_project '{"agents":[]}' "")
trap 'rm -rf "$TMPDIR_EMPTY"' EXIT

output=$(cd "$TMPDIR_EMPTY" && bash "$DETECT_SCRIPT" 2>/dev/null || true)
assert_empty "empty registry → empty output (FR-1)" "$output"

(cd "$TMPDIR_EMPTY" && bash "$DETECT_SCRIPT" >/dev/null 2>&1)
exit_code=$?
assert_eq "empty registry → exit 0 (FR-1)" "0" "$exit_code"

trap - EXIT
rm -rf "$TMPDIR_EMPTY"

# Test 6: FR-2 — multiple agents, only matching returned
echo ""
echo "-- FR-2: multiple agents, only matching returned --"
MULTI_JSON='{"agents":[{"name":"ios-qa-agent","detect_pattern":"*.xcodeproj","command":"echo ios","blocking":false,"timeout":10},{"name":"android-qa-agent","detect_pattern":"*.apk","command":"echo android","blocking":false,"timeout":10}]}'
TMPDIR_MULTI=$(make_git_project "$MULTI_JSON" "App.xcodeproj")
trap 'rm -rf "$TMPDIR_MULTI"' EXIT

output=$(cd "$TMPDIR_MULTI" && bash "$DETECT_SCRIPT" 2>/dev/null || true)
assert_contains "multiple agents → ios-qa-agent matched (FR-2)" "ios-qa-agent" "$output"
if printf '%s' "$output" | grep -qF "android-qa-agent"; then
  echo "  ❌ multiple agents → android-qa-agent should NOT match (no .apk)"
  (( FAIL++ )) || true
else
  echo "  ✅ multiple agents → android-qa-agent not matched (FR-2)"
  (( PASS++ )) || true
fi

trap - EXIT
rm -rf "$TMPDIR_MULTI"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
