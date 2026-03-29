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
import android.R // For standard system icons

class AppWidget : GlanceAppWidget() {
    override val stateDefinition = HomeWidgetGlanceStateDefinition()

    companion object {
        private val SMALL  = DpSize(80.dp, 80.dp)    // 1×1
        private val TALL   = DpSize(80.dp, 160.dp)   // 1×2+
        private val WIDE   = DpSize(160.dp, 80.dp)   // 2×1
        private val MEDIUM = DpSize(160.dp, 160.dp)   // 2×2
        private val LARGE  = DpSize(240.dp, 200.dp)   // 3×2+
    }

    override val sizeMode = SizeMode.Responsive(setOf(SMALL, TALL, WIDE, MEDIUM, LARGE))

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

            Box(
                modifier = GlanceModifier
                    .fillMaxSize()
                    .background(bgColor)
                    .appWidgetBackground()
                    .cornerRadius(28.dp)
            ) {
                // Determine layout based on size
                when {
                    // Small / Wide layouts (1x1 to 4x1) - Just the chat-style record bar
                    size.height < 100.dp -> RecordBarOnlyLayout(context, surfaceColor, accentColor, textColorSecondary, size.width < 100.dp)
                    
                    // Vertical tall layout (1x2, 1x3, 1x4)
                    size.width < 130.dp -> VerticalDashboard(context, prefs, surfaceColor, accentColor, textColorPrimary, textColorSecondary)
                    
                    // Medium/Square layout (2x2)
                    size.height < 200.dp -> MediumDashboard(context, prefs, surfaceColor, accentColor, textColorPrimary, textColorSecondary, incomeColor, spentColor)
                    
                    // Large wide/full dashboard
                    else -> LargeDashboard(context, prefs, surfaceColor, accentColor, textColorPrimary, textColorSecondary, incomeColor, spentColor)
                }
            }
        }
    }

    @Composable
    private fun RecordBarOnlyLayout(context: Context, surfaceColor: Color, accentColor: Color, textColor: Color, isCompact: Boolean) {
        Box(
            modifier = GlanceModifier.fillMaxSize().padding(8.dp),
            contentAlignment = Alignment.Center
        ) {
            QuickRecordBar(context, surfaceColor, accentColor, textColor, "Add record", isCompact)
        }
    }

    @Composable
    private fun VerticalDashboard(
        context: Context, 
        prefs: android.content.SharedPreferences, 
        surfaceColor: Color, 
        accentColor: Color,
        textPrimary: Color,
        textSecondary: Color
    ) {
        val balance = prefs.getString("total_balance", "0") ?: "0"
        val currency = prefs.getString("currency", "$") ?: "$"

        Column(
            modifier = GlanceModifier.fillMaxSize().padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Minimal Balance Section
            Text("Balance", style = TextStyle(fontSize = 11.sp, color = ColorProvider(textSecondary)))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(balance, style = TextStyle(fontSize = 20.sp, fontWeight = FontWeight.Bold, color = ColorProvider(textPrimary)))
                Spacer(GlanceModifier.width(4.dp))
                Text(currency, style = TextStyle(fontSize = 11.sp, color = ColorProvider(textPrimary)))
            }

            Spacer(GlanceModifier.defaultWeight())

            // Compact Record Button for tall narrow widgets
            Box(
                modifier = GlanceModifier
                    .fillMaxWidth()
                    .height(44.dp)
                    .background(surfaceColor)
                    .cornerRadius(22.dp)
                    .clickable(actionStartActivity<MainActivity>(context, Uri.parse("homeWidget://record"))),
                contentAlignment = Alignment.Center
            ) {
                Image(
                    provider = ImageProvider(R.drawable.ic_menu_edit), 
                    contentDescription = null, 
                    modifier = GlanceModifier.size(18.dp),
                    colorFilter = ColorFilter.tint(ColorProvider(accentColor))
                )
            }
        }
    }

    @Composable
    private fun MediumDashboard(
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
            // Balance Detail
            val label = if (month.isNotEmpty()) "Available Balance ($month)" else "Available Balance"
            Text(label, style = TextStyle(fontSize = 10.sp, color = ColorProvider(textSecondary)))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(balance, style = TextStyle(fontSize = 26.sp, fontWeight = FontWeight.Bold, color = ColorProvider(textPrimary)))
                Spacer(GlanceModifier.width(4.dp))
                Text(currency, style = TextStyle(fontSize = 12.sp, color = ColorProvider(textPrimary)))
            }

            Spacer(GlanceModifier.height(12.dp))

            // Quick Stats
            Row(modifier = GlanceModifier.fillMaxWidth()) {
                StatItem("Income", income, currency, incomeColor, textSecondary, GlanceModifier.defaultWeight())
                StatItem("Spent", spend, currency, spentColor, textSecondary, GlanceModifier.defaultWeight())
            }

            Spacer(GlanceModifier.defaultWeight())

            QuickRecordBar(context, surfaceColor, accentColor, textSecondary, "Add record")
        }
    }

    @Composable
    private fun LargeDashboard(
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

        Column(modifier = GlanceModifier.fillMaxSize().padding(20.dp)) {
            // Header with App Name/Icon style
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(GlanceModifier.size(4.dp, 12.dp).background(accentColor).cornerRadius(2.dp)) {}
                Spacer(GlanceModifier.width(8.dp))
                Text("WALLY AI", style = TextStyle(fontSize = 11.sp, fontWeight = FontWeight.Bold, color = ColorProvider(textSecondary)))
            }

            Spacer(GlanceModifier.height(16.dp))

            // Main Balance Section
            val label = if (month.isNotEmpty()) "Available Balance ($month)" else "Available Balance"
            Text(label, style = TextStyle(fontSize = 11.sp, color = ColorProvider(textSecondary)))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(balance, style = TextStyle(fontSize = 32.sp, fontWeight = FontWeight.Bold, color = ColorProvider(textPrimary)))
                Spacer(GlanceModifier.width(6.dp))
                Text(currency, style = TextStyle(fontSize = 14.sp, fontWeight = FontWeight.Medium, color = ColorProvider(textPrimary)))
            }

            Spacer(GlanceModifier.height(16.dp))

            // Stats Row
            Row(modifier = GlanceModifier.fillMaxWidth().background(surfaceColor).cornerRadius(16.dp).padding(12.dp)) {
                StatItem("Income", income, currency, incomeColor, textSecondary, GlanceModifier.defaultWeight())
                Box(GlanceModifier.width(1.dp).fillMaxHeight().background(textSecondary.copy(alpha = 0.1f))) {}
                Spacer(GlanceModifier.width(12.dp))
                StatItem("Expenses", spend, currency, spentColor, textSecondary, GlanceModifier.defaultWeight())
            }

            Spacer(GlanceModifier.defaultWeight())

            QuickRecordBar(context, surfaceColor, accentColor, textSecondary, "Add record")
        }
    }

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

    @Composable
    private fun QuickRecordBar(context: Context, surfaceColor: Color, accentColor: Color, textColor: Color, text: String, isCompact: Boolean = false) {
        val barWidth = if (isCompact) 48.dp else GlanceModifier.fillMaxWidth()
        
        Row(
            modifier = GlanceModifier
                .then(if (isCompact) GlanceModifier.width(48.dp) else GlanceModifier.fillMaxWidth())
                .height(48.dp)
                .background(surfaceColor)
                .cornerRadius(24.dp)
                .padding(horizontal = if (isCompact) 0.dp else 16.dp)
                .clickable(actionStartActivity<MainActivity>(context, Uri.parse("homeWidget://record"))),
            verticalAlignment = Alignment.CenterVertically,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Image(
                provider = ImageProvider(R.drawable.ic_menu_edit), 
                contentDescription = null, 
                modifier = GlanceModifier.size(18.dp),
                colorFilter = ColorFilter.tint(ColorProvider(accentColor))
            )
            if (!isCompact) {
                Spacer(GlanceModifier.width(12.dp))
                Text(text, style = TextStyle(fontSize = 14.sp, color = ColorProvider(textColor)))
            }
        }
    }
}
