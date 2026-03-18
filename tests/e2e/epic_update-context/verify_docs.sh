#!/bin/bash
set -e
echo "Running smoke tests for update-context..."
test -d docs/features/ || (echo "❌ docs/features/ missing"; exit 1)
test -f docs/features/ai-chat.md || (echo "❌ ai-chat.md missing"; exit 1)
test -f docs/features/expense-records.md || (echo "❌ expense-records.md missing"; exit 1)
grep -q "Mermaid" docs/features/ai-chat.md || (echo "❌ Mermaid missing in ai-chat.md"; exit 1)
grep -q "Mermaid" docs/features/expense-records.md || (echo "❌ Mermaid missing in expense-records.md"; exit 1)
grep -q "Instructions found in GEMINI.md" GEMINI.md || (echo "❌ Mandatory mandate missing in GEMINI.md"; exit 1)
echo "✅ All doc smoke tests passed!"
