#!/usr/bin/env bash
# ccpm-epic-verify: phase-a.sh
#
# Gathers epic context and review criteria for Phase A (Semantic Review).
# Outputs structured prompt/context for Claude to perform semantic review.
# Always exits 0 — advisory only.

set -uo pipefail

CONTEXT_DIR=".claude/context"
SCRIPTS_DIR=".claude/scripts"
PROMPTS_DIR=".claude/prompts"
CONFIG_DIR=".claude/config"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  PHASE A: SEMANTIC REVIEW"
echo "═══════════════════════════════════════════════════════"
echo ""

# --- Epic Input Assembly ---

echo "## Step 1: Epic Context Assembly"
echo ""

ASSEMBLY_SCRIPT="$SCRIPTS_DIR/epic-input-assembly.sh"

if [ -f "$ASSEMBLY_SCRIPT" ]; then
  echo "Running input assembly: $ASSEMBLY_SCRIPT"
  echo ""
  bash "$ASSEMBLY_SCRIPT" 2>/dev/null || echo "⚠️  Assembly script exited with error — continuing with partial context."
else
  echo "⚠️  No input assembly script found at $ASSEMBLY_SCRIPT"
  echo "    Continuing without assembled context."
fi

echo ""

# --- Review Criteria ---

echo "## Step 2: Review Criteria"
echo ""

PHASE_A_PROMPT="$PROMPTS_DIR/epic-phase-a.md"

if [ -f "$PHASE_A_PROMPT" ]; then
  echo "Found review criteria: $PHASE_A_PROMPT"
  echo ""
  cat "$PHASE_A_PROMPT" 2>/dev/null || echo "⚠️  Could not read epic-phase-a.md"
else
  echo "⚠️  No review criteria found at $PHASE_A_PROMPT — using fallback criteria."
  echo ""
  echo "### Fallback Review Criteria"
  echo ""
  echo "Evaluate the epic on the following dimensions:"
  echo ""
  echo "1. **Requirements Coverage**: Are all PRD requirements addressed by tasks?"
  echo "2. **Test Coverage**: Do tests exist for all acceptance criteria?"
  echo "3. **Documentation Quality**: Are tasks, designs, and handoffs complete?"
  echo "4. **Implementation Completeness**: Are all issues closed and verified?"
  echo "5. **Integration Readiness**: Does the implementation integrate cleanly?"
fi

echo ""

# --- Epic State ---

echo "## Step 3: Current Epic State"
echo ""

EPIC_STATE="$CONTEXT_DIR/verify/epic-state.json"

if [ -f "$EPIC_STATE" ]; then
  echo "Found epic state: $EPIC_STATE"
  echo ""
  if command -v jq >/dev/null 2>&1; then
    active_epic=$(jq -r '.active_epic // "none"' "$EPIC_STATE" 2>/dev/null || echo "unknown")
    phase=$(jq -r '.phase // "none"' "$EPIC_STATE" 2>/dev/null || echo "unknown")
    echo "  Active epic: $active_epic"
    echo "  Phase:       $phase"
    echo ""
    cat "$EPIC_STATE" 2>/dev/null || echo "⚠️  Could not read epic state file."
  else
    cat "$EPIC_STATE" 2>/dev/null || echo "⚠️  Could not read epic state file."
  fi
else
  echo "⚠️  No epic state found at $EPIC_STATE — verification not yet initialized."
fi

echo ""

# --- Output Template ---

echo "═══════════════════════════════════════════════════════"
echo "  PHASE A REVIEW TEMPLATE"
echo "  Fill in the sections below based on context above."
echo "═══════════════════════════════════════════════════════"
echo ""
echo "## Phase A: Semantic Review"
echo ""
echo "### Coverage Matrix"
echo ""
echo "| Requirement | Status | Notes |"
echo "| ----------- | ------ | ----- |"
echo "| {requirement} | ✅ / ❌ / ⚠️ | {notes} |"
echo ""
echo "### Gap Report"
echo ""
echo "| # | Severity | Gap Description | Recommendation |"
echo "| - | -------- | --------------- | -------------- |"
echo "| 1 | CRITICAL / HIGH / MEDIUM / LOW | {description} | {action} |"
echo ""
echo "### Quality Scorecard"
echo ""
echo "| Dimension | Score (1-5) | Notes |"
echo "| --------- | ----------- | ----- |"
echo "| Requirements coverage | {X}/5 | |"
echo "| Test coverage         | {X}/5 | |"
echo "| Documentation quality | {X}/5 | |"
echo "| Implementation completeness | {X}/5 | |"
echo "| Integration readiness | {X}/5 | |"
echo "| **Total**             | {X}/5 | |"
echo ""
echo "### Assessment: [EPIC_READY / EPIC_GAPS / EPIC_NOT_READY]"
echo ""
echo "**Rationale:** {brief explanation of assessment}"
echo ""

exit 0
