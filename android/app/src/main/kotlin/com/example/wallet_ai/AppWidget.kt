package com.leslie.wallyai

import android.content.Context
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.*
import androidx.glance.appwidget.*
import androidx.glance.layout.*
import androidx.glance.text.*
import androidx.glance.unit.ColorProvider
import androidx.glance.action.clickable
import androidx.glance.appwidget.cornerRadius
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.actionStartActivity
class AppWidget : GlanceAppWidget() {
    override val stateDefinition = HomeWidgetGlanceStateDefinition()

    companion object {
        private val WIDE   = DpSize(160.dp, 80.dp)   // 2×1
        private val MEDIUM = DpSize(160.dp, 160.dp)   // 2×2
        private val LARGE  = DpSize(240.dp, 200.dp)   // 3×2+
    }

    override val sizeMode = SizeMode.Responsive(setOf(WIDE, MEDIUM, LARGE))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val size = LocalSize.current
            val state = currentState<HomeWidgetGlanceState>()
            val prefs = state.preferences

            // UI Theme Constants - Premium Minimalist Palette
            val bgColor = Color(0xFFFFFFFF)
            val surfaceColor = Color(0xFFF5F6FA)
            val accentColor = Color(0xFF6366F1) // Indigo
            val textColorPrimary = Color(0xFF1F2937)
            val textColorSecondary = Color(0xFF6B7280)
            val incomeColor = Color(0xFF10B981)
            val spentColor = Color(0xFFEF4444)

            // FR-5: root clickable as fallback — inner clickables (bar, icons) win because
            // Glance's hit-test resolves leaf-to-root, so they are declared first inside
            // the layout composables, and the root .clickable is applied last here.
            Box(
                modifier = GlanceModifier
                    .fillMaxSize()
                    .background(bgColor)
                    .appWidgetBackground()
                    .cornerRadius(28.dp)
                    .clickable(actionStartActivity<MainActivity>(context, Uri.parse("homeWidget://open")))
            ) {
                when (size) {
                    WIDE   -> WideLayout(context, surfaceColor, accentColor, textColorSecondary)
                    MEDIUM -> MediumLayout(context, prefs, surfaceColor, accentColor, textColorPrimary, textColorSecondary, incomeColor, spentColor)
                    else   -> LargeLayout(context, prefs, surfaceColor, accentColor, textColorPrimary, textColorSecondary, incomeColor, spentColor)
                }
            }
        }
    }

    // ─── Breakpoint Layouts ───────────────────────────────────────────────────

    @Composable
    private fun WideLayout(
        context: Context,
        surfaceColor: Color,
        accentColor: Color,
        textColor: Color
    ) {
        Box(
            modifier = GlanceModifier.fillMaxSize().padding(8.dp),
            contentAlignment = Alignment.Center
        ) {
            QuickActionRow(context, surfaceColor, accentColor, textColor, expandText = false)
        }
    }

    @Composable
    private fun MediumLayout(
        context: Context,
        prefs: android.content.SharedPreferences,
        surfaceColor: Color,
        accentColor: Color,
        textPrimary: Color,
        textSecondary: Color,
        incomeColor: Color,
        spentColor: Color
    ) {
        val balance = prefs.getString("total_balance", "0") ?: "0"
        val income = prefs.getString("total_income", "0") ?: "0"
        val spend = prefs.getString("total_spend", "0") ?: "0"
        val currency = prefs.getString("currency", "$") ?: "$"
        val month = prefs.getString("current_month", "") ?: ""

        Column(modifier = GlanceModifier.fillMaxSize().padding(16.dp)) {
            val label = if (month.isNotEmpty()) "Available Balance ($month)" else "Available Balance"
            Text(label, style = TextStyle(fontSize = 10.sp, color = ColorProvider(textSecondary)))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(balance, style = TextStyle(fontSize = 26.sp, fontWeight = FontWeight.Bold, color = ColorProvider(textPrimary)))
                Spacer(GlanceModifier.width(4.dp))
                Text(currency, style = TextStyle(fontSize = 12.sp, color = ColorProvider(textPrimary)))
            }

            Spacer(GlanceModifier.height(12.dp))

            Row(modifier = GlanceModifier.fillMaxWidth()) {
                StatItem("Income", income, currency, incomeColor, textSecondary, GlanceModifier.defaultWeight())
                StatItem("Spent", spend, currency, spentColor, textSecondary, GlanceModifier.defaultWeight())
            }

            Spacer(GlanceModifier.defaultWeight())

            QuickActionRow(context, surfaceColor, accentColor, textSecondary, expandText = false)
        }
    }

    @Composable
    private fun LargeLayout(
        context: Context,
        prefs: android.content.SharedPreferences,
        surfaceColor: Color,
        accentColor: Color,
        textPrimary: Color,
        textSecondary: Color,
        incomeColor: Color,
        spentColor: Color
    ) {
        val balance = prefs.getString("total_balance", "0") ?: "0"
        val income = prefs.getString("total_income", "0") ?: "0"
        val spend = prefs.getString("total_spend", "0") ?: "0"
        val currency = prefs.getString("currency", "$") ?: "$"
        val month = prefs.getString("current_month", "") ?: ""

        Column(modifier = GlanceModifier.fillMaxSize().padding(16.dp)) {
            val label = if (month.isNotEmpty()) "Available Balance ($month)" else "Available Balance"
            Text(label, style = TextStyle(fontSize = 11.sp, color = ColorProvider(textSecondary)))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(balance, style = TextStyle(fontSize = 28.sp, fontWeight = FontWeight.Bold, color = ColorProvider(textPrimary)))
                Spacer(GlanceModifier.width(5.dp))
                Text(currency, style = TextStyle(fontSize = 13.sp, fontWeight = FontWeight.Medium, color = ColorProvider(textPrimary)))
            }

            Spacer(GlanceModifier.height(10.dp))

            // Stats Row
            Row(modifier = GlanceModifier.fillMaxWidth().background(surfaceColor).cornerRadius(14.dp).padding(10.dp)) {
                StatItem("Income", income, currency, incomeColor, textSecondary, GlanceModifier.defaultWeight())
                Box(GlanceModifier.width(1.dp).height(28.dp).background(textSecondary.copy(alpha = 0.15f))) {}
                Spacer(GlanceModifier.width(10.dp))
                StatItem("Expenses", spend, currency, spentColor, textSecondary, GlanceModifier.defaultWeight())
            }

            Spacer(GlanceModifier.defaultWeight())

            QuickActionRow(context, surfaceColor, accentColor, textSecondary, expandText = true)
        }
    }

    // ─── Shared Composables ───────────────────────────────────────────────────

    @Composable
    private fun StatItem(label: String, value: String, currency: String, valueColor: Color, labelColor: Color, modifier: GlanceModifier) {
        Column(modifier = modifier) {
            Text(label, style = TextStyle(fontSize = 11.sp, color = ColorProvider(labelColor)))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(value, style = TextStyle(fontSize = 16.sp, fontWeight = FontWeight.Bold, color = ColorProvider(valueColor)))
                Spacer(GlanceModifier.width(3.dp))
                Text(currency, style = TextStyle(fontSize = 10.sp, fontWeight = FontWeight.Medium, color = ColorProvider(valueColor)))
            }
        }
    }

    /**
     * QuickActionRow — unified bottom action row.
     * expandText = false (WIDE, MEDIUM): two icon circles side by side [✏️] [📷]
     * expandText = true  (LARGE+):       input box fills width [✏️ Add record ....] [📷]
     */
    @Composable
    private fun QuickActionRow(
        context: Context,
        surfaceColor: Color,
        accentColor: Color,
        textColor: Color,
        expandText: Boolean
    ) {
        Row(
            modifier = if (expandText) GlanceModifier.fillMaxWidth() else GlanceModifier,
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Record button — expands or stays as icon circle
            Row(
                modifier = (if (expandText) GlanceModifier.defaultWeight() else GlanceModifier.size(44.dp))
                    .height(44.dp)
                    .background(surfaceColor)
                    .cornerRadius(22.dp)
                    .padding(horizontal = if (expandText) 14.dp else 0.dp)
                    .clickable(actionStartActivity<MainActivity>(context, Uri.parse("homeWidget://record"))),
                verticalAlignment = Alignment.CenterVertically,
                horizontalAlignment = if (expandText) Alignment.Start else Alignment.CenterHorizontally
            ) {
                Image(
                    provider = ImageProvider(com.leslie.wallyai.R.drawable.ic_widget_edit),
                    contentDescription = null,
                    modifier = GlanceModifier.size(18.dp),
                    colorFilter = ColorFilter.tint(ColorProvider(accentColor))
                )
                if (expandText) {
                    Spacer(GlanceModifier.width(10.dp))
                    Text("Add record", style = TextStyle(fontSize = 14.sp, color = ColorProvider(textColor)))
                }
            }

            Spacer(GlanceModifier.width(8.dp))

            // Camera button — always icon circle
            Box(
                modifier = GlanceModifier
                    .size(44.dp)
                    .background(surfaceColor)
                    .cornerRadius(22.dp)
                    .clickable(actionStartActivity<MainActivity>(context, Uri.parse("homeWidget://camera"))),
                contentAlignment = Alignment.Center
            ) {
                Image(
                    provider = ImageProvider(com.leslie.wallyai.R.drawable.ic_widget_camera),
                    contentDescription = null,
                    modifier = GlanceModifier.size(20.dp),
                    colorFilter = ColorFilter.tint(ColorProvider(accentColor))
                )
            }
        }
    }
}
