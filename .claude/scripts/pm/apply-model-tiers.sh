#!/usr/bin/env bash
# Apply model tiers from config to command frontmatter.
# Usage: bash .claude/scripts/pm/apply-model-tiers.sh
#
# Reads .claude/config/model-tiers.json and writes model: field
# into each command's YAML frontmatter in .claude/commands/pm/*.md

set -euo pipefail

_CCPM_ROOT="${_CCPM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

CONFIG_FILE="$_CCPM_ROOT/config/model-tiers.json"
COMMANDS_DIR="$_CCPM_ROOT/commands/pm"

# --- Preflight ---

if [ ! -f "$CONFIG_FILE" ]; then
  echo "ℹ️ No model-tiers.json found. Skipping."
  exit 0
fi

if command -v jq &>/dev/null; then
  JSON_TOOL="jq"
elif command -v python3 &>/dev/null; then
  JSON_TOOL="python3"
else
  echo "❌ Neither jq nor python3 available"
  exit 1
fi

# Validate JSON
if [ "$JSON_TOOL" = "jq" ]; then
  jq empty "$CONFIG_FILE" 2>/dev/null || { echo "❌ Invalid JSON in model-tiers.json"; exit 1; }
else
  python3 -c "import json, sys; json.load(open(sys.argv[1]))" "$CONFIG_FILE" 2>/dev/null || { echo "❌ Invalid JSON in model-tiers.json"; exit 1; }
fi

# --- Build cmd→model mappings in a single call ---
# Output format: "cmd=model" or "cmd=model=override"

if [ "$JSON_TOOL" = "jq" ]; then
  MAPPINGS=$(jq -r '
    .tiers as $t | .overrides as $o |
    ((.commands | keys) + ($o | keys) | unique)[] as $cmd |
    if $o[$cmd] then "\($cmd)=\($o[$cmd])=override"
    elif .commands[$cmd] and $t[.commands[$cmd]] then "\($cmd)=\($t[.commands[$cmd]])"
    else empty end
  ' "$CONFIG_FILE")
else
  MAPPINGS=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    d = json.load(f)
t, c, o = d.get('tiers',{}), d.get('commands',{}), d.get('overrides',{})
for cmd, tier in c.items():
    if cmd in o and o[cmd]:
        print(f'{cmd}={o[cmd]}=override')
    elif tier in t:
        print(f'{cmd}={t[tier]}')
for cmd, model in o.items():
    if cmd not in c and model:
        print(f'{cmd}={model}=override')
" "$CONFIG_FILE")
fi

# --- Apply to command files ---

updated=0
skipped=0
overridden=0

for cmd_file in "$COMMANDS_DIR"/*.md; do
  [ -f "$cmd_file" ] || continue

  cmd_name=$(basename "$cmd_file" .md)

  # Look up mapping
  mapping=$(echo "$MAPPINGS" | grep "^${cmd_name}=" | head -1) || true
  if [ -z "$mapping" ]; then
    skipped=$((skipped + 1))
    continue
  fi

  model=$(echo "$mapping" | cut -d= -f2)
  is_override=$(echo "$mapping" | cut -d= -f3)

  # File must have frontmatter (first line = ---)
  if ! head -1 "$cmd_file" | grep -q '^---$'; then
    skipped=$((skipped + 1))
    continue
  fi

  # Update frontmatter via awk:
  # - Insert model: after opening --- (before other fields)
  # - If model: already exists, replace it and remove duplicates
  tmp_file="${cmd_file}.tmp.$$"
  awk -v model="$model" '
    NR==1 && /^---$/ { print; fm=1; next }
    fm && !model_done && !/^model:/ { print "model: " model; model_done=1 }
    fm && /^model:/ { if (!model_done) { print "model: " model; model_done=1 }; next }
    fm && /^---$/ { fm=0 }
    { print }
  ' "$cmd_file" > "$tmp_file"

  mv "$tmp_file" "$cmd_file"
  updated=$((updated + 1))
  [ "$is_override" = "override" ] && overridden=$((overridden + 1))
done

echo "✅ Applied model tiers: $updated commands updated, $skipped skipped, $overridden overrides"
