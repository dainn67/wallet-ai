# Manual Skill Trigger Tests: Antigravity Port
# Issue #57 — test-antigravity-prompts.md

## Overview

Manual test prompts for validating skill trigger accuracy in Antigravity IDE.
Run each prompt in Antigravity and record which skill activates.

**Target:** ≥17/20 prompts trigger the correct skill (85% accuracy threshold)
**Overlap rule:** Each ambiguous prompt must trigger exactly 1 skill, no duplicates

**Skills under test:**
| Skill | Trigger Intent |
|---|---|
| `ccpm-context-loader` | Start task, resume session, begin work |
| `ccpm-context-sync` | Switch IDE, sync context between Claude Code / Antigravity |
| `ccpm-epic-planning` | Fix gaps, plan gap fixes, address epic coverage issues |
| `ccpm-epic-verify` | Verify epic quality, check if epic is ready to merge |
| `ccpm-handoff` | End session, wrap up, stop for now |
| `ccpm-pre-implementation` | Implement, code, build feature, start coding |
| `ccpm-verification` | Done, complete, close issue, mark task finished |

---

## Category A: Explicit Prompts (7)

Each prompt unambiguously targets exactly 1 skill. Expected: 7/7 correct.

| # | Prompt | Expected Skill | Result |
|---|---|---|---|
| A1 | "I'm starting work on issue #45. Load my context and get me up to speed." | `ccpm-context-loader` | |
| A2 | "I just switched from Claude Code to Antigravity. Sync my context over." | `ccpm-context-sync` | |
| A3 | "The epic has gaps in coverage. Help me plan how to fix all of them." | `ccpm-epic-planning` | |
| A4 | "Verify the epic and check if it's ready to merge into main." | `ccpm-epic-verify` | |
| A5 | "I'm done for today. Write a handoff note so the next session can pick up." | `ccpm-handoff` | |
| A6 | "I'm about to implement the user authentication feature. Let's start coding." | `ccpm-pre-implementation` | |
| A7 | "I've finished implementing this task. Close the issue and mark it complete." | `ccpm-verification` | |

**Score A: __ / 7**

---

## Category B: Ambiguous Prompts (10)

Each prompt uses indirect phrasing that maps to exactly 1 skill.
Expected: ≥10/10 correct with no overlap between skills.

| # | Prompt | Expected Skill | Result |
|---|---|---|---|
| B1 | "Let's get going on this." | `ccpm-context-loader` | |
| B2 | "Coming from Cursor just now." | `ccpm-context-sync` | |
| B3 | "We still have gaps to address in this epic." | `ccpm-epic-planning` | |
| B4 | "Is this epic ready?" | `ccpm-epic-verify` | |
| B5 | "Wrapping up for the day." | `ccpm-handoff` | |
| B6 | "Time to build the new dashboard component." | `ccpm-pre-implementation` | |
| B7 | "All done with this task." | `ccpm-verification` | |
| B8 | "Resuming from where I left off yesterday." | `ccpm-context-loader` | |
| B9 | "Just switched IDEs." | `ccpm-context-sync` | |
| B10 | "The epic needs gap fixes before we can merge." | `ccpm-epic-planning` | |

**Score B: __ / 10**

---

## Category C: Negative Prompts (3)

These prompts should trigger NO CCPM skill. Expected: 0 skills fire.

| # | Prompt | Expected | Result |
|---|---|---|---|
| C1 | "What's the weather today?" | No skill | |
| C2 | "Explain how git rebase works." | No skill | |
| C3 | "How many files does this project have?" | No skill | |

**Score C: __ / 3 (correct = no skill fires)**

---

## Scoring Summary

| Category | Score | Threshold |
|---|---|---|
| A — Explicit | __ / 7 | 7/7 |
| B — Ambiguous | __ / 10 | ≥8/10 |
| C — Negative | __ / 3 | 3/3 |
| **Total** | **__ / 20** | **≥17/20** |

**Overall Result:** ☐ PASS  ☐ FAIL

---

## Notes

- Record actual skill that triggered in the "Result" column
- If multiple skills trigger, mark as `OVERLAP: skill1 + skill2`
- If no skill triggers when one should, mark as `MISS`
- If wrong skill triggers, mark as `WRONG: actual-skill-name`
- Tester: ___________________
- Date: ___________________
- Antigravity version: ___________________
