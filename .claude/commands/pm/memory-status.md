---
model: haiku
allowed-tools: Bash
---

# Memory Status

Show Memory Agent health and statistics.

## Usage
```
/pm:memory-status
```

## Instructions

1. **Check Memory Agent availability:**
   ```bash
   STATUS=$(bash .claude/scripts/pm/memory-health.sh 2>/dev/null)
   HEALTH_EXIT=$?
   ```

2. **If agent not running (exit code non-zero):**
   Display:
   ```
   🧠 Memory Agent Status
   ═══════════════════════
   Status: ❌ Offline
   Start:  ccpm-memory start
   ```

3. **If agent running (exit code 0):**
   - Parse STATUS JSON for: `status`, `memories` count, `unconsolidated_count`, `uptime`, `last_consolidation`
   - Get db file size:
     ```bash
     du -h .claude/memory-agent/memory.db 2>/dev/null || du -h memory-agent/memory.db 2>/dev/null || echo "unknown"
     ```
   - Read config toggles from `.claude/config/lifecycle.json` (or `config/lifecycle.json`) under `memory_agent` section
   - Display:
     ```
     🧠 Memory Agent Status
     ═══════════════════════
     Status:             ✅ Running
     Memories:           {count}
     Unconsolidated:     {unconsolidated_count}
     Last Consolidation: {last_consolidation}
     Uptime:             {uptime}
     DB Size:            {size}
     Config toggles:
       enabled:          {true/false}
       query_on_prime:   {true/false}
       query_on_pretask: {true/false}
       query_on_prd:     {true/false}
       query_on_verify:  {true/false}
       auto_ingest:      {true/false}
     ```
   - If JSON parse fails for any field, show "unknown" for that field.
