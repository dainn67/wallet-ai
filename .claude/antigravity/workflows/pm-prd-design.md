---
name: pm-prd-design
description: PRD Design
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
   - If `.claude/prds/$FEATURE.md` doesn't exist → `❌ PRD not found: .claude/prds/$FEATURE.md. Run: /pm:prd-new $FEATURE` and stop.

3. **Check lifecycle config:**
   - Read `config/lifecycle.json`. If `design_phase.enabled` is `false` → `⚠️ Design phase is disabled in config/lifecycle.json. Enable it or run /pm:prd-parse $FEATURE directly.` and stop.

4. **Detect tools — determine operation mode:**
   ```bash
   uupm_available=false; stitch_available=false
   .claude/scripts/pm/detect-uupm.sh >/dev/null 2>&1 && uupm_available=true
   .claude/scripts/pm/detect-stitch.sh >/dev/null 2>&1 && stitch_available=true
   ```
   Determine MODE:
   - `FULL` — both UUPM and Stitch available
   - `DESIGN_ONLY` — UUPM available, Stitch not available
   - `MOCKUP_ONLY` — Stitch available, UUPM not available
   - `TEXT_ONLY` — neither available

   Display: `Operating in {MODE} mode`

5. **Handle --screen flag (targeted iteration):**
   - If `TARGET_SCREEN` is set:
     - Verify `.claude/designs/$FEATURE/` exists → if not: `❌ No existing designs for '$FEATURE'. Run /pm:prd-design $FEATURE first (without --screen).` and stop.
     - Verify `TARGET_SCREEN` appears in `.claude/designs/$FEATURE/screen-inventory.md` → if not: `❌ Screen '$TARGET_SCREEN' not found in inventory. Available screens:` then list screens from inventory and stop.
     - Skip Phase 1. Run Phase 2 only for `TARGET_SCREEN`, then Phase 3 only for `TARGET_SCREEN`.
     - Jump to **Phase 2** instructions.

6. **Check existing designs (re-run menu):**
   - If `.claude/designs/$FEATURE/` exists and `TARGET_SCREEN` is empty:
     - Ask user:
       ```
       ⚠️ Designs already exist for '$FEATURE'. Choose an action:
       1. Regenerate all (delete existing, run full pipeline)
       2. Regenerate specific screen (enter screen name, run Phase 2+3 for that screen)
       3. Update design system only (re-run Phase 1, keep existing screens/specs)
       ```
     - Option 1: `rm -rf .claude/designs/$FEATURE` then continue with full pipeline.
     - Option 2: Ask for screen name → set `TARGET_SCREEN` → skip Phase 1, run Phase 2+3 for that screen only.
     - Option 3: Run Phase 1 only, then display summary and stop.

7. **Create directory structure:**
   ```bash
   mkdir -p .claude/designs/$FEATURE/{prompts,screens,specs}
   ```

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

Load `.claude/prds/$FEATURE.md` and extract:
- **Product type:** SaaS dashboard, mobile app, internal tool, CLI, landing page, etc. — infer from Executive Summary and Problem Statement.
- **Target personas:** From Target Users section — note their technical sophistication, usage context (desktop/mobile/both), and frequency of use.
- **Screen inventory (preliminary):** Scan User Stories for stories that involve UI interaction. Each UI-related user story maps to at least one screen. List screen candidates with source user story IDs.
- **Mood/tone keywords:** From Executive Summary and Problem Statement — extract adjectives and context clues (e.g., "enterprise", "fast", "simple", "data-heavy", "consumer-friendly").
- **Brand/style hints:** Any existing color, font, or style mentions in the PRD or project context files.

**1b. Check for UI context:**

If the PRD has zero UI-related user stories (all backend/API/infrastructure):
- Display: `⚠️ PRD '$FEATURE' has no UI-related user stories. Design pipeline works best with UI requirements.`
- Ask user: `Continue with minimal design system (useful for API documentation styling)? Or skip? (continue/skip)`
- If skip → stop with message: `Skipped. Run /pm:prd-parse $FEATURE to proceed without design.`

If PRD has >10 screens identified:
- Display: `⚠️ Found {count} potential screens. Recommend prioritizing top 5 for initial design pass.`
- Ask user to confirm screen list or trim.

**1c. Generate design system:**

Generate `.claude/designs/$FEATURE/design-system.md` with the following sections:

```markdown
# Design System: {FEATURE}

## Style Recommendation
[Overall visual style — modern minimal, enterprise, playful, data-dense, etc.]
[Reasoning: why this style fits the product type and personas]

## Color Palette
| Name       | Hex     | Usage                          |
|------------|---------|--------------------------------|
| primary    | #XXXXXX | CTAs, primary actions, links   |
| secondary  | #XXXXXX | Secondary buttons, accents     |
| accent     | #XXXXXX | Highlights, notifications      |
| background | #XXXXXX | Page background                |
| surface    | #XXXXXX | Card/panel backgrounds         |
| text       | #XXXXXX | Primary body text              |
| text-muted | #XXXXXX | Secondary/helper text          |
| border     | #XXXXXX | Dividers, input borders        |
| success    | #XXXXXX | Success states                 |
| warning    | #XXXXXX | Warning states                 |
| error      | #XXXXXX | Error states                   |

### Accessibility Notes
[Contrast ratios for text-on-background combinations. Flag any pairs below WCAG AA 4.5:1.]

## Typography
| Role    | Font          | Size  | Weight | Line Height |
|---------|---------------|-------|--------|-------------|
| h1      | [font-family] | Xrem  | 700    | 1.2         |
| h2      | [font-family] | Xrem  | 600    | 1.3         |
| h3      | [font-family] | Xrem  | 600    | 1.3         |
| body    | [font-family] | 1rem  | 400    | 1.5         |
| caption | [font-family] | Xrem  | 400    | 1.4         |
| label   | [font-family] | Xrem  | 500    | 1.4         |

### Font Pairing Rationale
[Why these fonts work together and fit the product.]

## Spacing Scale
Base unit: {N}px
| Token | Value  |
|-------|--------|
| xs    | {N}px  |
| sm    | {N}px  |
| md    | {N}px  |
| lg    | {N}px  |
| xl    | {N}px  |
| 2xl   | {N}px  |
| 3xl   | {N}px  |

## Component Patterns
### Buttons
[Primary, secondary, ghost, destructive — size variants, border-radius, padding tokens]

### Inputs
[Text input, select, checkbox, radio — border, focus ring, error state styling]

### Cards
[Padding, border-radius, shadow, hover state]

### Navigation
[Top nav / sidebar / tabs — active state, spacing, responsive collapse behavior]

### Tables (if data-heavy)
[Row height, header styling, striping, responsive behavior]

## Anti-patterns
- [What to avoid — specific to this product type]
- [Common mistakes for this visual style]
- [Accessibility pitfalls]
```

**Mode branching for generation:**
- **FULL or DESIGN_ONLY:** Invoke the UUPM skill to provide design intelligence. Use its recommendations as the foundation for the design system. Prompt UUPM with: product type, personas, mood keywords, and any brand constraints. Incorporate its output into the design system structure above. If UUPM invocation fails → fall back to Claude native reasoning (same as TEXT_ONLY path).
- **MOCKUP_ONLY or TEXT_ONLY:** Use Claude's native reasoning to generate the design system. Base decisions on: product type conventions, persona needs, mood keywords, and established design principles.

Write output to `.claude/designs/$FEATURE/design-system.md`.

Display: `✅ Phase 1 complete: design-system.md generated`

---

### Phase 2: Screen Inventory + Mockup Generation

**2a. Generate screen inventory:**

Create `.claude/designs/$FEATURE/screen-inventory.md`:

```markdown
# Screen Inventory: {FEATURE}

| Priority | Screen Name       | Source User Story | Description                    | Key Components              |
|----------|-------------------|-------------------|--------------------------------|-----------------------------|
| 1        | {screen-name}     | US-N              | [1-sentence description]       | [nav, form, table, etc.]    |
| 2        | {screen-name}     | US-N              | [1-sentence description]       | [components]                |
| ...      | ...               | ...               | ...                            | ...                         |
```

Rules:
- Priority order follows user flow (e.g., onboarding → dashboard → detail → settings).
- Screen names are kebab-case (used as filenames).
- Every UI-related user story must map to at least one screen.
- Group closely related stories into one screen where natural.

**2b. Generate Stitch prompts:**

For each screen, create `.claude/designs/$FEATURE/prompts/{screen-name}.txt`:

```
Design a {screen-name} screen for a {product-type} application.

Target user: {persona name} — {persona context}
Screen purpose: {description from inventory}

Design System References:
- Colors: Use primary (#hex) for CTAs, secondary (#hex) for secondary actions, background (#hex) for page bg
- Typography: {h1 font} at {h1 size} for headings, {body font} at {body size} for body text
- Spacing: Base unit {N}px, use {md}px for component padding, {lg}px for section gaps
- Border radius: {value} for cards, {value} for buttons
- Shadows: {card shadow value}

Key Components:
{list of components from inventory with layout hints}

Layout:
- {mobile-first or desktop-first based on persona} responsive design
- {specific layout guidance: sidebar + main, single column, grid, etc.}

{If not the first screen: "Reuse components from: {list of prior screen names} where applicable."}

Constraints:
- Single HTML file with inline CSS
- Semantic HTML5 elements
- WCAG AA compliant contrast
- No JavaScript required (static mockup)
```

**2c. Mode branching for mockup generation:**

- **FULL or MOCKUP_ONLY:** For each screen (in priority order):
  1. Read the prompt file for the screen.
  2. Invoke Stitch MCP tool with the prompt content.
  3. Save returned HTML to `.claude/designs/$FEATURE/screens/{screen-name}.html`.
  4. On Stitch error: retry up to 3 times with exponential backoff (2s, 4s, 8s). On persistent failure: log `⚠️ Stitch failed for '{screen-name}' — prompt saved for manual use`, continue with remaining screens.
  5. After all screens: display count of successful HTML generations.

- **DESIGN_ONLY or TEXT_ONLY:**
  - Display: `ℹ️ Stitch MCP not available — prompts saved for manual use at .claude/designs/$FEATURE/prompts/`
  - Display: `Tip: Paste prompts into stitch.withgoogle.com and save HTML to .claude/designs/$FEATURE/screens/`
  - Skip HTML generation entirely.

Display: `✅ Phase 2 complete: {N} screens inventoried, {M} mockups generated`

---

### Phase 3: Implementation Spec Generation

For each screen in the inventory (in priority order):

**3a. Determine spec source:**
- If `.claude/designs/$FEATURE/screens/{screen-name}.html` exists → parse HTML for component extraction.
- If no HTML → generate text-based spec from design system + screen description.

**3b. Generate spec:**

Write `.claude/designs/$FEATURE/specs/{screen-name}-spec.md`:

```markdown
# Implementation Spec: {screen-name}

Source: {screens/{screen-name}.html | text-based from design system}

## Component Tree
```
Page
  Header
    Logo
    Navigation
      NavItem (active: design-system/primary)
      NavItem
    UserMenu
  Main (padding: spacing/lg)
    SectionTitle (typography/h2)
    ContentArea (background: design-system/surface)
      ComponentA (padding: spacing/md)
      ComponentB
  Footer
```

## Layout
- Container: [max-width, centering strategy]
- Grid/Flex: [layout type, column count, gap using spacing tokens]
- Section spacing: spacing/{token} between major sections

## Color Usage
| Element          | Design System Token | Usage Context       |
|------------------|---------------------|---------------------|
| Page background  | background          | Base layer          |
| Card surface     | surface             | Content containers  |
| Primary CTA      | primary             | Main action buttons |
| Body text        | text                | Paragraphs, labels  |
| Helper text      | text-muted          | Descriptions, hints |
| ...              | ...                 | ...                 |

**Rule: Zero hardcoded hex values.** Every color references a design-system token name.

## Typography
| Element        | Design System Token | Context            |
|----------------|---------------------|--------------------|
| Page title     | h1                  | Main heading       |
| Section header | h2                  | Section divisions  |
| Body text      | body                | Content paragraphs |
| Form labels    | label               | Input labels       |
| Help text      | caption             | Descriptions       |

## Interactive States
| Component  | Default      | Hover           | Active          | Disabled         | Loading         |
|------------|------------- |-----------------|-----------------|------------------|-----------------|
| Button-primary | primary, white text | primary darkened 10% | primary darkened 20% | primary at 50% opacity | spinner icon |
| Input      | border color | border primary  | border primary  | bg surface muted | —               |
| Card       | surface, shadow-sm | shadow-md | — | opacity 50% | skeleton pulse |
| ...        | ...          | ...             | ...             | ...              | ...             |

## Responsive Breakpoints
| Breakpoint | Width   | Layout Changes                           |
|------------|---------|------------------------------------------|
| mobile     | < 640px | [specific changes: stack columns, hide sidebar, etc.] |
| tablet     | 640-1024px | [specific changes]                    |
| desktop    | > 1024px | [default layout as designed]            |

## Component Reuse Map
| Component      | Also used in         | Shared props/tokens  |
|----------------|----------------------|----------------------|
| Navigation     | [other screen names] | Same nav items       |
| Button-primary | [other screen names] | Same design tokens   |
| ...            | ...                  | ...                  |
```

**Spec rules:**
- Every color value MUST reference a `design-system` token name — never a raw hex.
- Every spacing value MUST reference a `spacing/{token}` — never a raw pixel value.
- Every typography element MUST reference a `typography/{role}` — never a raw font-size.
- Component tree uses indentation to show hierarchy.
- If parsing HTML: extract actual component structure. If text-based: generate reasonable structure from screen description and component list.

Display after each spec: `  ✅ specs/{screen-name}-spec.md`

Display: `✅ Phase 3 complete: {N} implementation specs generated`

---

### Post-execution

Display summary:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Design Pipeline Complete: {FEATURE}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Mode: {MODE}
Design System: .claude/designs/{FEATURE}/design-system.md
Screens: {count} screens in inventory
Mockups: {count} HTML files generated (or "prompts saved for manual use")
Specs: {count} implementation specs generated

Next actions:
→ Parse to epic:      /pm:prd-parse {FEATURE}
→ Iterate a screen:   /pm:prd-design {FEATURE} --screen {first_screen_name}
→ View design system: Read .claude/designs/{FEATURE}/design-system.md
→ View screen spec:   Read .claude/designs/{FEATURE}/specs/{first_screen_name}-spec.md
```

## IMPORTANT

- The design system is the **single source of truth** for all visual decisions. Specs MUST reference it — never hardcode values.
- Design system file persists on filesystem — it is reused across re-runs and by downstream commands (`prd-parse`, `epic-decompose`).
- In TEXT_ONLY mode, the pipeline MUST still produce usable artifacts: `design-system.md`, `screen-inventory.md`, prompt files, and text-based specs.
- Screen names are kebab-case and used as filenames throughout — consistency is critical.
- When iterating a single screen (`--screen`), preserve the existing design system and other screen artifacts.
- Prompts in `prompts/` directory are useful even without Stitch — users can paste them into any design tool.
- Keep specs under 200 lines per screen. Be precise, not verbose.
