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

            // UI Theme Constants
            val bgColor = Color(0xFFFBFBFF)
            val surfaceColor = Color(0xFFF0F0F7)
            val accentColor = Color(0xFF6750A4) // Deep Purple

            Box(
                modifier = GlanceModifier
                    .fillMaxSize()
                    .background(bgColor)
                    .appWidgetBackground()
                    .cornerRadius(28.dp)
            ) {
                when {
                    size.width < 130.dp && size.height < 130.dp -> SmallLayout(context, surfaceColor, accentColor)
                    size.width < 130.dp -> TallLayout(context, prefs, surfaceColor, accentColor)
                    size.height < 130.dp -> WideLayout(context, prefs, surfaceColor, accentColor)
                    size.height < 200.dp -> MediumLayout(context, prefs, surfaceColor, accentColor)
                    else -> LargeDashboard(context, prefs, surfaceColor, accentColor)
                }
            }
        }
    }

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

    @Composable
    private fun TallLayout(context: Context, prefs: android.content.SharedPreferences, surfaceColor: Color, accentColor: Color) {
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

    @Composable
    private fun WideLayout(context: Context, prefs: android.content.SharedPreferences, surfaceColor: Color, accentColor: Color) {
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

    @Composable
    private fun MediumLayout(context: Context, prefs: android.content.SharedPreferences, surfaceColor: Color, accentColor: Color) {
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

    @Composable
    private fun LargeDashboard(context: Context, prefs: android.content.SharedPreferences, surfaceColor: Color, accentColor: Color) {
        val balance = prefs.getString("total_balance", "0") ?: "0"
        val income = prefs.getString("total_income", "0") ?: "0"
        val spend = prefs.getString("total_spend", "0") ?: "0"
        val currency = prefs.getString("currency", "VND") ?: "VND"
        val month = prefs.getString("current_month", "") ?: ""

        Column(modifier = GlanceModifier.fillMaxSize().padding(16.dp)) {
            // Header Tag
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(GlanceModifier.size(10.dp, 4.dp).background(accentColor).cornerRadius(2.dp)) {}
                Spacer(GlanceModifier.width(6.dp))
                Text("WALLY AI", style = TextStyle(fontSize = 10.sp, fontWeight = FontWeight.Bold, color = ColorProvider(Color.Gray)))
            }

            // Month label
            if (month.isNotEmpty()) {
                Spacer(GlanceModifier.height(2.dp))
                Text(month, style = TextStyle(fontSize = 11.sp, fontWeight = FontWeight.Bold, color = ColorProvider(Color.Gray)))
            }

            Spacer(GlanceModifier.defaultWeight())

            // Balance Section
            Text("Available Balance", style = TextStyle(fontSize = 11.sp, color = ColorProvider(Color(0xFF505050))))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(balance, style = TextStyle(fontSize = 28.sp, fontWeight = FontWeight.Bold, color = ColorProvider(Color.Black)))
                Spacer(GlanceModifier.width(4.dp))
                Text(currency, style = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Medium, color = ColorProvider(Color.Black)))
            }

            Spacer(GlanceModifier.height(14.dp))

            // Income/Expense Row
            Row(modifier = GlanceModifier.fillMaxWidth()) {
                StatItem("Income", income, currency, Color(0xFF2E7D32), GlanceModifier.defaultWeight())
                StatItem("Spent", spend, currency, Color(0xFFC62828), GlanceModifier.defaultWeight())
            }

            Spacer(GlanceModifier.defaultWeight())

            QuickRecordBar(context, surfaceColor)
        }
    }

    @Composable
    private fun StatItem(label: String, value: String, currency: String, color: Color, modifier: GlanceModifier) {
        Column(modifier = modifier) {
            Text(label, style = TextStyle(fontSize = 10.sp, color = ColorProvider(Color.Gray)))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(value, style = TextStyle(fontSize = 15.sp, fontWeight = FontWeight.Bold, color = ColorProvider(color)))
                Spacer(GlanceModifier.width(3.dp))
                Text(currency, style = TextStyle(fontSize = 9.sp, fontWeight = FontWeight.Medium, color = ColorProvider(color)))
            }
        }
    }

    @Composable
    private fun QuickRecordBar(context: Context, surfaceColor: Color) {
        Row(
            modifier = GlanceModifier
                .fillMaxWidth()
                .height(48.dp)
                .background(surfaceColor)
                .cornerRadius(24.dp)
                .padding(horizontal = 16.dp)
                .clickable(actionStartActivity<MainActivity>(context, Uri.parse("homeWidget://record"))),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Image(provider = ImageProvider(R.drawable.ic_menu_edit), contentDescription = null, modifier = GlanceModifier.size(16.dp))
            Spacer(GlanceModifier.width(12.dp))
            Text("Quick Record...", style = TextStyle(fontSize = 14.sp, color = ColorProvider(Color(0xFF606060))))
        }
    }
}
