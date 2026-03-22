#!/bin/bash
set -euo pipefail

PORTS="${1:-3000 4000 5173 8080}"

for port in $PORTS; do
    status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 1 "http://localhost:$port" 2>/dev/null || echo "000")
    if [[ "$status" =~ ^[23] ]]; then
        python3 -c "import json; print(json.dumps({'found': True, 'url': 'http://localhost:$port', 'status': $status}))"
        exit 0
    fi
done

python3 -c "import json; print(json.dumps({'found': False, 'scanned_ports': [int(p) for p in '$PORTS'.split()]}))"
exit 0
