---
epic: image-input
branch: epic/image-input
snapshot_at: 2026-04-21T16:55:41Z
---
# Execution Status: image-input

## Branch
`epic/image-input` (pushed to origin)

## Counts
- Ready: 1
- Blocked: 6
- In-progress: 0
- Complete: 0/7

## Ready Issues
- **#170** — Dependencies and platform permission manifests (phase 1, simple, sonnet)

## Blocked Issues
- **#171** — ImageProcessingService (blocked on #170)
- **#172** — ImagePickerService wrapper (blocked on #170)
- **#173** — Model, provider, and API payload wiring (blocked on #171)
- **#174** — Chat input attachment UI (blocked on #172, #173)
- **#175** — Outgoing bubble image rendering and fullscreen viewer (blocked on #173)
- **#176** — Integration verification and cross-platform QA (blocked on #170, #171, #172, #173, #174, #175)

## Dependency Notes
Task frontmatter `depends_on` still references pre-sync local IDs (001, 010, 011, 012, 020, 021).
Mapping to GitHub issue numbers:
- 001 → #170
- 010 → #171
- 011 → #172
- 012 → #173
- 020 → #174
- 021 → #175
- 090 → #176
