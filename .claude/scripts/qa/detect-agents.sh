#!/bin/bash
set -euo pipefail

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
CONFIG_FILE="$PROJECT_ROOT/.claude/config/qa-agents.json"

[ -f "$CONFIG_FILE" ] || exit 0

python3 -c "
import json, glob, os, sys, subprocess
config = json.load(open(sys.argv[1]))
root = sys.argv[2]
for agent in config.get('agents', []):
    pattern = agent['detect_pattern']
    if not glob.glob(os.path.join(root, pattern)):
        continue
    detect_cmd = agent.get('detect_command')
    if detect_cmd:
        cmd_path = os.path.join(root, '.claude', detect_cmd)
        if not os.path.isfile(cmd_path):
            cmd_path = os.path.join(root, detect_cmd)
        result = subprocess.run([cmd_path], capture_output=True, cwd=root)
        if result.returncode != 0:
            continue
    print(json.dumps({
        'name': agent['name'],
        'command': agent['command'],
        'blocking': agent.get('blocking', False),
        'timeout': agent.get('timeout', 300)
    }))
" "$CONFIG_FILE" "$PROJECT_ROOT"

exit 0
