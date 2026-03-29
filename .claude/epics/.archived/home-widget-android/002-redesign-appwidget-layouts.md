---
name: Redesign AppWidget.kt with 5 responsive layouts
status: closed
created: 2026-03-29T05:11:10Z
updated: 2026-03-29T05:20:32Z
complexity: moderate
recommended_model: opus
phase: 2
priority: P1
github: "https://github.com/dainn67/wallet-ai/issues/148"
depends_on: [001]
parallel: false
conflicts_with: []
files:
  - android/app/src/main/kotlin/com/example/wallet_ai/AppWidget.kt
prd_requirements:
  - FR-1
  - FR-2
  - FR-4
  - NFR-2
---

# T2: Redesign AppWidget.kt with 5 responsive layouts

## Context
The current Android widget has 3 Glance breakpoints (SMALL/WIDE/LARGE). The 1×1 (Small) layout shows a bare purple box with an add icon — no affordance indicating what tapping does. Tall-narrow sizes (1×2, 1×3) fall back to the Small layout. Larger layouts lack a month label for the financial data shown.

## Description
Rewrite `AppWidget.kt` to define 5 Glance `DpSize` breakpoints covering 1×1 through 4×4 placements. Redesign the Small layout to match the existing `QuickRecordBar` visual style (rounded pill, pencil icon, hint text). Add Tall and Medium layouts. Add month label (`current_month` pref from T1) to Medium and Large layouts.

Per AD-2: expand breakpoints, keep `SizeMode.Responsive` pattern. Reuse existing `QuickRecordBar` and `StatItem` composables.

## Acceptance Criteria
- [ ] **FR-1 / 1×1 layout:** Widget at 1×1 shows a rounded-pill button with pencil icon (`ic_menu_edit`) and "Quick Record..." text — NOT the old purple box + add icon
- [ ] **FR-1 / Tap:** Tapping the 1×1 widget launches `homeWidget://record` deep link
- [ ] **FR-2 / Tall layout:** Widget at 1×2 or taller (width < 130dp, height ≥ 130dp) shows balance + currency at top, QuickRecordBar at bottom
- [ ] **FR-2 / Wide layout:** Widget at 2×1 (width ≥ 130dp, height < 130dp) shows balance on left, QuickRecordBar on right
- [ ] **FR-4 / Month label:** Widget at 2×2 (width ≥ 130dp, height ≥ 130dp) shows "March 2026" month label in header
- [ ] **FR-4 / Large month:** Widget at 3×2+ shows month label alongside the WALLY AI tag
- [ ] **NFR-2 / Text size:** All text in 1×1 layout ≥ 12sp; balance in large layout ≥ 24sp

## Implementation Steps

### Step 1: Update breakpoint constants
- Modify `android/app/src/main/kotlin/com/example/wallet_ai/AppWidget.kt`
- Replace the 3 companion constants with 5:
  ```kotlin
  companion object {
      private val SMALL  = DpSize(80.dp, 80.dp)    // 1×1
      private val TALL   = DpSize(80.dp, 160.dp)   // 1×2+
      private val WIDE   = DpSize(160.dp, 80.dp)   // 2×1
      private val MEDIUM = DpSize(160.dp, 160.dp)   // 2×2
      private val LARGE  = DpSize(240.dp, 200.dp)   // 3×2+
  }

  override val sizeMode = SizeMode.Responsive(setOf(SMALL, TALL, WIDE, MEDIUM, LARGE))
  ```

### Step 2: Update routing logic in `provideGlance`
- Replace the `when` block with size-based routing:
  ```kotlin
  when {
      size.width < 130.dp && size.height < 130.dp -> SmallLayout(context, surfaceColor, accentColor)
      size.width < 130.dp -> TallLayout(context, prefs, surfaceColor, accentColor)
      size.height < 130.dp -> WideLayout(context, prefs, surfaceColor, accentColor)
      size.height < 200.dp -> MediumLayout(context, prefs, surfaceColor, accentColor)
      else -> LargeDashboard(context, prefs, surfaceColor, accentColor)
  }
  ```
- Note: All layouts except SmallLayout now receive `prefs` (for balance/income/spend/month data)

### Step 3: Redesign SmallLayout (1×1)
- Replace the purple box + `ic_input_add` with a compact QuickRecord-style layout:
  ```kotlin
  @Composable
  private fun SmallLayout(context: Context, surfaceColor: Color, accentColor: Color) {
      Box(
          modifier = GlanceModifier.fillMaxSize().padding(8.dp),
          contentAlignment = Alignment.Center
      ) {
          Column(
              modifier = GlanceModifier
                  .fillMaxSize()
                  .background(surfaceColor)
                  .cornerRadius(16.dp)
                  .clickable(actionStartActivity<MainActivity>(context, Uri.parse("homeWidget://record"))),
              horizontalAlignment = Alignment.CenterHorizontally,
              verticalAlignment = Alignment.CenterVertically
          ) {
              Image(
                  provider = ImageProvider(R.drawable.ic_menu_edit),
                  contentDescription = null,
                  modifier = GlanceModifier.size(18.dp),
                  colorFilter = ColorFilter.tint(ColorProvider(accentColor))
              )
              Spacer(GlanceModifier.height(4.dp))
              Text("Quick Record...", style = TextStyle(fontSize = 12.sp, color = ColorProvider(Color(0xFF606060))))
          }
      }
  }
  ```
- Background: `surfaceColor` (light gray, matching QuickRecordBar) instead of `accentColor` (purple)
- Icon: `ic_menu_edit` (pencil) instead of `ic_input_add` (plus)
- Text: "Quick Record..." at 12sp minimum

### Step 4: Add TallLayout (1×2+)
- New composable for tall-narrow widgets:
  ```kotlin
  @Composable
  private fun TallLayout(context: Context, prefs: SharedPreferences, surfaceColor: Color, accentColor: Color) {
      val balance = prefs.getString("total_balance", "0") ?: "0"
      val currency = prefs.getString("currency", "VND") ?: "VND"

      Column(
          modifier = GlanceModifier.fillMaxSize().padding(12.dp),
          verticalAlignment = Alignment.CenterVertically
      ) {
          // Balance section
          Text("Balance", style = TextStyle(fontSize = 10.sp, color = ColorProvider(Color.Gray)))
          Row(verticalAlignment = Alignment.CenterVertically) {
              Text(balance, style = TextStyle(fontSize = 18.sp, fontWeight = FontWeight.Bold, color = ColorProvider(Color.Black)))
              Spacer(GlanceModifier.width(3.dp))
              Text(currency, style = TextStyle(fontSize = 10.sp, color = ColorProvider(Color.Black)))
          }

          Spacer(GlanceModifier.defaultWeight())

          QuickRecordBar(context, surfaceColor)
      }
  }
  ```

### Step 5: Update WideLayout (2×1) — add balance
- Modify existing `WideLayout` to show balance on the left:
  ```kotlin
  @Composable
  private fun WideLayout(context: Context, prefs: SharedPreferences, surfaceColor: Color, accentColor: Color) {
      val balance = prefs.getString("total_balance", "0") ?: "0"
      val currency = prefs.getString("currency", "VND") ?: "VND"

      Row(
          modifier = GlanceModifier.fillMaxSize().padding(12.dp),
          verticalAlignment = Alignment.CenterVertically
      ) {
          Column(modifier = GlanceModifier.defaultWeight()) {
              Text("Balance", style = TextStyle(fontSize = 10.sp, color = ColorProvider(Color.Gray)))
              Row(verticalAlignment = Alignment.CenterVertically) {
                  Text(balance, style = TextStyle(fontSize = 16.sp, fontWeight = FontWeight.Bold, color = ColorProvider(Color.Black)))
                  Spacer(GlanceModifier.width(3.dp))
                  Text(currency, style = TextStyle(fontSize = 9.sp, color = ColorProvider(Color.Black)))
              }
          }
          Box(modifier = GlanceModifier.defaultWeight()) {
              QuickRecordBar(context, surfaceColor)
          }
      }
  }
  ```

### Step 6: Add MediumLayout (2×2)
- New composable showing month label + balance + income/expense + QuickRecord:
  ```kotlin
  @Composable
  private fun MediumLayout(context: Context, prefs: SharedPreferences, surfaceColor: Color, accentColor: Color) {
      val balance = prefs.getString("total_balance", "0") ?: "0"
      val income = prefs.getString("total_income", "0") ?: "0"
      val spend = prefs.getString("total_spend", "0") ?: "0"
      val currency = prefs.getString("currency", "VND") ?: "VND"
      val month = prefs.getString("current_month", "") ?: ""

      Column(modifier = GlanceModifier.fillMaxSize().padding(14.dp)) {
          // Month label
          if (month.isNotEmpty()) {
              Text(month, style = TextStyle(fontSize = 11.sp, fontWeight = FontWeight.Bold, color = ColorProvider(Color.Gray)))
              Spacer(GlanceModifier.height(8.dp))
          }

          // Balance
          Text("Available Balance", style = TextStyle(fontSize = 10.sp, color = ColorProvider(Color(0xFF505050))))
          Row(verticalAlignment = Alignment.CenterVertically) {
              Text(balance, style = TextStyle(fontSize = 24.sp, fontWeight = FontWeight.Bold, color = ColorProvider(Color.Black)))
              Spacer(GlanceModifier.width(4.dp))
              Text(currency, style = TextStyle(fontSize = 11.sp, color = ColorProvider(Color.Black)))
          }

          Spacer(GlanceModifier.height(10.dp))

          // Income/Expense
          Row(modifier = GlanceModifier.fillMaxWidth()) {
              StatItem("Income", income, currency, Color(0xFF2E7D32), GlanceModifier.defaultWeight())
              StatItem("Spent", spend, currency, Color(0xFFC62828), GlanceModifier.defaultWeight())
          }

          Spacer(GlanceModifier.defaultWeight())

          QuickRecordBar(context, surfaceColor)
      }
  }
  ```

### Step 7: Update LargeDashboard — add month label
- Modify existing `LargeDashboard` to read `current_month` pref and display it below the WALLY AI tag:
  ```kotlin
  val month = prefs.getString("current_month", "") ?: ""
  ```
- Add after the WALLY AI header row:
  ```kotlin
  if (month.isNotEmpty()) {
      Spacer(GlanceModifier.height(2.dp))
      Text(month, style = TextStyle(fontSize = 11.sp, fontWeight = FontWeight.Bold, color = ColorProvider(Color.Gray)))
  }
  ```

## Interface Contract

### Receives from T1:
- Widget preference key: `current_month` → String formatted as "March 2026"
  - Guaranteed: non-null after first `_updateWidget()` call
  - Fallback: empty string `""` if key not yet written (handled with `prefs.getString("current_month", "")`)
- Widget preference keys: `total_income`, `total_spend` → now contain monthly-filtered values (formatted via `CurrencyHelper.format`)
- Existing keys unchanged: `total_balance`, `currency`

## Technical Details
- **Approach:** AD-2 — expand Glance Responsive breakpoints from 3 to 5
- **Files to modify:**
  - `android/app/src/main/kotlin/com/example/wallet_ai/AppWidget.kt` — rewrite breakpoints, SmallLayout, WideLayout; add TallLayout, MediumLayout; update LargeDashboard
- **Patterns to follow:** Existing `QuickRecordBar` and `StatItem` composables (reused as-is). Existing color constants (`bgColor`, `surfaceColor`, `accentColor`).
- **Edge cases:**
  - `current_month` key missing (first install, widget placed before app opened) → check `isNotEmpty()`, skip label
  - Very long balance string (e.g., "1,000,000,000") may clip in Small/Tall layouts → acceptable, large numbers truncate naturally
  - `ic_menu_edit` not available on very old Android → system drawable, available since API 1

## Tests to Write

### Manual Tests (Glance rendering cannot be unit tested)
- Place 1×1 widget on Pixel 7 emulator → verify pencil icon + "Quick Record..." text (not add icon)
- Place 1×2 widget → verify balance + QuickRecordBar stacked vertically
- Place 2×1 widget → verify balance on left, QuickRecordBar on right
- Place 2×2 widget → verify month label + balance + income/expense + QuickRecordBar
- Place 3×2 widget → verify WALLY AI tag + month label + full dashboard
- Tap each widget variant → verify app opens to record entry

## Verification Checklist
- [ ] `flutter build apk --debug` — successful build (Kotlin compilation passes)
- [ ] Deploy to emulator, place 1×1 widget — pencil icon + hint text visible
- [ ] Place 1×2 widget — balance and QuickRecordBar visible, no clipping
- [ ] Place 2×2 widget — "March 2026" month label visible
- [ ] Place 3×2 widget — full dashboard with month label
- [ ] Tap each widget — app opens to record entry screen

## Dependencies
- **Blocked by:** T1 (`current_month` preference key)
- **Blocks:** T3 (verification)
- **External:** None
