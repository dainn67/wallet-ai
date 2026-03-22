#!/bin/bash
# detect-web.sh — Secondary validation for web QA agent detection
# Returns exit 0 if project is a web project, exit 1 otherwise
set -euo pipefail

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# Check for package.json with web-related dependencies
# Accept optional first argument as path to package.json
PKG="${1:-$PROJECT_ROOT/package.json}"
[ -f "$PKG" ] || exit 1

# Validate it's a web project (has common web deps or scripts)
python3 -c "
import json, sys
try:
    pkg = json.load(open(sys.argv[1]))
    deps = {}
    deps.update(pkg.get('dependencies', {}))
    deps.update(pkg.get('devDependencies', {}))
    scripts = pkg.get('scripts', {})
    web_indicators = [
        'react', 'vue', 'angular', 'next', 'nuxt', 'svelte',
        'webpack', 'vite', 'parcel', 'rollup',
        'express', 'koa', 'fastify', 'hapi',
        'jest', 'cypress', 'playwright', 'vitest'
    ]
    has_web = any(ind in k.lower() for ind in web_indicators for k in deps)
    has_build = any(k in scripts for k in ['build', 'start', 'dev', 'serve'])
    sys.exit(0 if (has_web or has_build) else 1)
except Exception:
    sys.exit(1)
" "$PKG"
