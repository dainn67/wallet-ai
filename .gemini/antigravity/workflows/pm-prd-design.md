---
name: pm-prd-design
description: PRD Design — Generate design system, mockups, and implementation specs from PRD
# tier: heavy
---

# PRD Design

Generate design system, visual mockups, and implementation specs from a PRD.

## Usage
```
/pm:prd-design <feature_name> [--screen <screen_name>]
```

## Preflight (silent — do not show progress to user)

1. **Parse arguments:**
   - Split `$FEATURE_NAME` into `feature_name` and optional `--screen <screen_name>`.
   - Extract: `FEATURE` = first argument (kebab-case name), `TARGET_SCREEN` = value after `--screen` (or empty).
   - If `$FEATURE_NAME` is empty → `❌ Missing feature name. Usage: /pm:prd-design <feature_name> [--screen <screen_name>]` and stop.
   - `FEATURE` MUST match `^[a-z0-9][a-z0-9-]*[a-z0-9]$`. If invalid → `❌ Feature name must be kebab-case. Got: '$FEATURE'` and stop.

2. **Locate PRD:**
   - If `.gemini/prds/$FEATURE.md` doesn't exist → `❌ PRD not found: .gemini/prds/$FEATURE.md. Run: /pm:prd-new $FEATURE` and stop.

3. **Check lifecycle config:**
   - Read `config/lifecycle.json`. If `design_phase.enabled` is `false` → `⚠️ Design phase is disabled in config/lifecycle.json. Enable it or run /pm:prd-parse $FEATURE directly.` and stop.

4. **Detect tools — determine operation mode:**
   Check for UUPM and Stitch availability. Determine MODE:
   - `FULL` — both UUPM and Stitch available
   - `DESIGN_ONLY` — UUPM available, Stitch not available
   - `MOCKUP_ONLY` — Stitch available, UUPM not available
   - `TEXT_ONLY` — neither available

   Display: `Operating in {MODE} mode`

5. **Handle --screen flag (targeted iteration):**
   - If `TARGET_SCREEN` is set:
     - Verify `.gemini/designs/$FEATURE/` exists → if not: `❌ No existing designs for '$FEATURE'. Run /pm:prd-design $FEATURE first (without --screen).` and stop.
     - Verify `TARGET_SCREEN` appears in `.gemini/designs/$FEATURE/screen-inventory.md` → if not: `❌ Screen '$TARGET_SCREEN' not found in inventory. Available screens:` then list screens from inventory and stop.
     - Skip Phase 1. Run Phase 2 only for `TARGET_SCREEN`, then Phase 3 only for `TARGET_SCREEN`.
     - Jump to **Phase 2** instructions.

6. **Check existing designs (re-run menu):**
   - If `.gemini/designs/$FEATURE/` exists and `TARGET_SCREEN` is empty:
     - Ask user:
       ```
       ⚠️ Designs already exist for '$FEATURE'. Choose an action:
       1. Regenerate all (delete existing, run full pipeline)
       2. Regenerate specific screen (enter screen name, run Phase 2+3 for that screen)
       3. Update design system only (re-run Phase 1, keep existing screens/specs)
       ```
     - Option 1: Delete existing designs then continue with full pipeline.
     - Option 2: Ask for screen name → set `TARGET_SCREEN` → skip Phase 1, run Phase 2+3 for that screen only.
     - Option 3: Run Phase 1 only, then display summary and stop.

7. **Create directory structure:**
   Ensure `.gemini/designs/$FEATURE/{prompts,screens,specs}` directories exist.

## Role & Mindset

You are a senior UI/UX architect who translates product specifications into cohesive design systems and implementation-ready specs. Your designs are known for:
- Visual consistency through strict token-based design systems
- Practical component hierarchies that map cleanly to frontend frameworks
- Accessibility-aware color palettes with sufficient contrast ratios
- Responsive layouts that degrade gracefully across breakpoints

Your approach — apply all four lenses:
- **User:** What does the persona need to see, do, and feel on each screen?
- **Consistency:** Does every element reference the design system? Zero ad-hoc values.
- **Developer:** Can an engineer build this screen from the spec alone, without guessing?
- **Pragmatism:** Is this the simplest visual design that meets the product goals?

## Instructions

### Phase 1: PRD Analysis + Design System Generation

**1a. Read and analyze the PRD:**

Load `.gemini/prds/$FEATURE.md` and extract:
- **Product type:** SaaS dashboard, mobile app, internal tool, CLI, landing page, etc.
- **Target personas:** From Target Users section — note technical sophistication, usage context, frequency.
- **Screen inventory (preliminary):** Scan User Stories for UI interactions. Each UI-related user story maps to at least one screen.
- **Mood/tone keywords:** From Executive Summary and Problem Statement.
- **Brand/style hints:** Any existing color, font, or style mentions.

**1b. Check for UI context:**

If PRD has zero UI-related user stories (all backend/API/infrastructure):
- Display: `⚠️ PRD '$FEATURE' has no UI-related user stories. Design pipeline works best with UI requirements.`
- Ask user: `Continue with minimal design system (useful for API documentation styling)? Or skip? (continue/skip)`
- If skip → stop with message: `Skipped. Run /pm:prd-parse $FEATURE to proceed without design.`

If PRD has >10 screens identified:
- Display: `⚠️ Found {count} potential screens. Recommend prioritizing top 5 for initial design pass.`
- Ask user to confirm screen list or trim.

**1c. Generate design system:**

Generate `.gemini/designs/$FEATURE/design-system.md` with sections:
- Style Recommendation (visual style + reasoning)
- Color Palette (named tokens with hex values, usage, accessibility notes)
- Typography (font roles, sizes, weights, line heights, pairing rationale)
- Spacing Scale (base unit + token scale xs through 3xl)
- Component Patterns (buttons, inputs, cards, navigation, tables)
- Anti-patterns (what to avoid for this product type)

**Mode branching:**
- **FULL or DESIGN_ONLY:** Invoke UUPM for design intelligence. Fall back to native reasoning on failure.
- **MOCKUP_ONLY or TEXT_ONLY:** Use native reasoning based on product type conventions and persona needs.

Display: `✅ Phase 1 complete: design-system.md generated`

---

### Phase 2: Screen Inventory + Mockup Generation

**2a. Generate screen inventory:**

Create `.gemini/designs/$FEATURE/screen-inventory.md` with priority-ordered table:
- Priority (user flow order), Screen Name (kebab-case), Source User Story, Description, Key Components.
- Every UI-related user story must map to at least one screen.

**2b. Generate Stitch prompts:**

For each screen, create `.gemini/designs/$FEATURE/prompts/{screen-name}.txt` with:
- Screen context (product type, persona, purpose)
- Design system references (colors, typography, spacing tokens)
- Key components and layout hints
- Constraints (single HTML, semantic HTML5, WCAG AA, no JS)

**2c. Mode branching for mockups:**
- **FULL or MOCKUP_ONLY:** Invoke Stitch for each screen. Save HTML to `screens/{screen-name}.html`. Retry up to 3 times on failure.
- **DESIGN_ONLY or TEXT_ONLY:** Display prompt save location and manual usage tip. Skip HTML generation.

Display: `✅ Phase 2 complete: {N} screens inventoried, {M} mockups generated`

---

### Phase 3: Implementation Spec Generation

For each screen in inventory (priority order):

**3a. Determine spec source:**
- If HTML mockup exists → parse for component extraction.
- If no HTML → generate text-based spec from design system + description.

**3b. Generate spec:**

Write `.gemini/designs/$FEATURE/specs/{screen-name}-spec.md` with:
- Component Tree (indented hierarchy with design token references)
- Layout (container, grid/flex, section spacing using tokens)
- Color Usage (element → design system token mapping)
- Typography (element → design system token mapping)
- Interactive States (default, hover, active, disabled, loading per component)
- Responsive Breakpoints (mobile, tablet, desktop layout changes)
- Component Reuse Map (shared components across screens)

**Spec rules:**
- Every color → design system token name (never raw hex)
- Every spacing → spacing/{token} (never raw pixels)
- Every typography → typography/{role} (never raw font-size)
- Keep specs under 200 lines per screen

Display: `✅ Phase 3 complete: {N} implementation specs generated`

---

### Post-execution

Display summary:
```
Design Pipeline Complete: {FEATURE}
Mode: {MODE}
Design System: .gemini/designs/{FEATURE}/design-system.md
Screens: {count} screens in inventory
Mockups: {count} HTML files generated (or "prompts saved for manual use")
Specs: {count} implementation specs generated

Next actions:
→ Parse to epic:      /pm:prd-parse {FEATURE}
→ Iterate a screen:   /pm:prd-design {FEATURE} --screen {first_screen_name}
→ View design system: Read .gemini/designs/{FEATURE}/design-system.md
→ View screen spec:   Read .gemini/designs/{FEATURE}/specs/{first_screen_name}-spec.md
```

## IMPORTANT

- The design system is the **single source of truth** for all visual decisions. Specs MUST reference it — never hardcode values.
- Design system file persists on filesystem — reused across re-runs and by downstream commands (`prd-parse`, `epic-decompose`).
- In TEXT_ONLY mode, the pipeline MUST still produce usable artifacts: `design-system.md`, `screen-inventory.md`, prompt files, and text-based specs.
- Screen names are kebab-case and used as filenames throughout — consistency is critical.
- When iterating a single screen (`--screen`), preserve existing design system and other screen artifacts.
- Prompts in `prompts/` directory are useful even without Stitch — users can paste them into any design tool.
- Keep specs under 200 lines per screen. Be precise, not verbose.
