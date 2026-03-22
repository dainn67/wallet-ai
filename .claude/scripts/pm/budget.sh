#!/usr/bin/env bash
set -euo pipefail

FEATURE="${1:-}"
if [ -z "$FEATURE" ]; then
  echo "❌ Usage: budget.sh <feature-name>"
  exit 1
fi

CONFIG=".claude/config/build.json"
[ ! -f "$CONFIG" ] && CONFIG="config/build.json"
[ ! -f "$CONFIG" ] && { echo "❌ config/build.json not found"; exit 1; }

read_config() {
  python3 -c "
import json
with open('$CONFIG') as f:
    c = json.load(f)
steps = c['workflow']['steps']
tpt = c['tokens_per_tier']
for i, s in enumerate(steps, 1):
    tokens = tpt.get(s['tier'], 5000)
    print(f\"{i}|{s['name']}|{s['tier']}|{tokens}\")
"
}

STATE_FILE=".claude/context/build-state/${FEATURE}.json"
CURRENT_STEP=-1
TOTAL_STEPS=0
if [ -f "$STATE_FILE" ]; then
  CURRENT_STEP=$(python3 -c "import json; d=json.load(open('$STATE_FILE')); print(d.get('current_step', -1))")
fi

TOTAL_STEPS=$(read_config | wc -l | tr -d ' ')

if [ "$CURRENT_STEP" -ge "$TOTAL_STEPS" ] && [ "$CURRENT_STEP" -ne -1 ]; then
  echo "⚠️  Build state step ($CURRENT_STEP) exceeds config steps ($TOTAL_STEPS) — showing all as pending"
  CURRENT_STEP=-1
fi

printf "\nToken Budget: %s\n\n" "$FEATURE"
printf "%-6s %-20s %-8s %-13s %s\n" "Step" "Name" "Tier" "Est. Tokens" "Status"
printf "%-6s %-20s %-8s %-13s %s\n" "────" "──────────────────" "──────" "───────────" "──────"

TOTAL_REMAINING=0
while IFS="|" read -r idx name tier tokens; do
  if [ "$CURRENT_STEP" -ne -1 ] && [ "$idx" -le "$CURRENT_STEP" ]; then
    status="✅ done"
    display_tokens="0"
  else
    status="⏳ pending"
    display_tokens=$(printf "%'.0f" "$tokens")
    TOTAL_REMAINING=$((TOTAL_REMAINING + tokens))
  fi
  printf "%-6s %-20s %-8s ~%-12s %s\n" "${idx}/${TOTAL_STEPS}" "$name" "$tier" "$display_tokens" "$status"
done < <(read_config)

printf "%-6s %-20s %-8s %-13s %s\n" "────" "──────────────────" "──────" "───────────" "──────"
TOTAL_FORMATTED=$(printf "%'.0f" "$TOTAL_REMAINING")
printf "Total estimated remaining:    ~%s tokens\n" "$TOTAL_FORMATTED"
echo ""
echo "⚠️  Estimates are heuristic (±20% accuracy)"
echo ""
