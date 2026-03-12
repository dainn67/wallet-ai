#!/usr/bin/env bash
# Display model tier map showing all commands and their configured models.
# Usage: bash .gemini/scripts/pm/model-map.sh
set -euo pipefail

_CCPM_ROOT="${_CCPM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)}"
CONFIG_FILE="$_CCPM_ROOT/config/model-tiers.json"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ No model-tiers.json found at $CONFIG_FILE"
  exit 1
fi

if command -v jq &>/dev/null; then
  echo "Model Tier Map (config/model-tiers.json)"
  echo "═══════════════════════════════════════════════════"
  printf "%-25s%-9s%-9s%s\n" "Command" "Tier" "Model" "Source"
  echo "───────────────────────────────────────────────────"

  overrides=$(jq -r '.overrides | to_entries[] | "\(.key)=\(.value)"' "$CONFIG_FILE" 2>/dev/null || true)

  for tier_name in light medium heavy; do
    model=$(jq -r --arg t "$tier_name" '.tiers[$t] // ""' "$CONFIG_FILE")
    jq -r --arg t "$tier_name" '.commands | to_entries[] | select(.value == $t) | .key' "$CONFIG_FILE" | sort | while read -r cmd; do
      override_model=$(echo "$overrides" | grep "^${cmd}=" | cut -d= -f2 || true)
      if [ -n "$override_model" ]; then
        printf "%-25s%-9s%-9s%s\n" "$cmd" "$tier_name" "$override_model" "override"
      else
        printf "%-25s%-9s%-9s%s\n" "$cmd" "$tier_name" "$model" "tier"
      fi
    done
  done

  echo "───────────────────────────────────────────────────"
  total=$(jq '.commands | length' "$CONFIG_FILE")
  light=$(jq '[.commands | to_entries[] | select(.value == "light")] | length' "$CONFIG_FILE")
  medium=$(jq '[.commands | to_entries[] | select(.value == "medium")] | length' "$CONFIG_FILE")
  heavy=$(jq '[.commands | to_entries[] | select(.value == "heavy")] | length' "$CONFIG_FILE")
  num_overrides=$(jq '.overrides | length' "$CONFIG_FILE")
  echo "Total: $total commands ($light light, $medium medium, $heavy heavy)"
  echo "Overrides: $num_overrides"
else
  python3 -c "
import json

with open('$CONFIG_FILE') as f:
    cfg = json.load(f)

tiers = cfg['tiers']
commands = cfg['commands']
overrides = cfg.get('overrides', {})
tier_order = {'light': 0, 'medium': 1, 'heavy': 2}

rows = []
for cmd, tier in commands.items():
    if cmd in overrides:
        model, source = overrides[cmd], 'override'
    else:
        model, source = tiers.get(tier, ''), 'tier'
    rows.append((tier_order.get(tier, 99), cmd, tier, model, source))
rows.sort()

print('Model Tier Map (config/model-tiers.json)')
print('\u2550' * 51)
print(f\"{'Command':<25}{'Tier':<9}{'Model':<9}{'Source'}\")
print('\u2500' * 51)
for _, cmd, tier, model, source in rows:
    print(f'{cmd:<25}{tier:<9}{model:<9}{source}')
print('\u2500' * 51)

counts = {}
for t in commands.values():
    counts[t] = counts.get(t, 0) + 1
total = len(commands)
print(f\"Total: {total} commands ({counts.get('light',0)} light, {counts.get('medium',0)} medium, {counts.get('heavy',0)} heavy)\")
print(f'Overrides: {len(overrides)}')
" 2>/dev/null
fi
