---
model: sonnet
allowed-tools: Bash, Read
---

# Memory Query

Query the Memory Agent for project history and knowledge.

## Usage
```
/pm:memory-query <question>
```

## Instructions

1. **Validate arguments:**
   - If `$ARGUMENTS` is empty → output "❌ Usage: /pm:memory-query <question>" and stop.

2. **Check Memory Agent availability:**
   ```bash
   bash .claude/scripts/pm/memory-health.sh
   ```
   - If exit code is non-zero → output "❌ Memory Agent not running. Start: `ccpm-memory start`" and stop.

3. **Query Memory Agent:**
   ```bash
   source .claude/scripts/pm/lifecycle-helpers.sh
   memory_query "$ARGUMENTS" "markdown" "10"
   ```

4. **Format response:**
   - If non-empty response: display as-is (Memory Agent returns markdown format)
   - If empty or no results: output "No memories found for: '$ARGUMENTS'"
   - Append footer line:
     ```
     ---
     🧠 Query: {question} | Results: {count} | Source: Memory Agent
     ```
