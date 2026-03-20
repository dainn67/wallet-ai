package com.example.wallet_ai

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
        private val SMALL = DpSize(100.dp, 100.dp)
        private val WIDE = DpSize(200.dp, 100.dp)
        private val LARGE = DpSize(200.dp, 180.dp)
    }

    override val sizeMode = SizeMode.Responsive(setOf(SMALL, WIDE, LARGE))

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
                    size.width < 150.dp -> SmallLayout(context, accentColor)
                    size.height < 140.dp -> WideLayout(context, surfaceColor, accentColor)
                    else -> LargeDashboard(context, prefs, surfaceColor, accentColor)
                }
            }
        }
    }

    @Composable
    private fun SmallLayout(context: Context, accentColor: Color) {
        Box(
            modifier = GlanceModifier.fillMaxSize().padding(8.dp),
            contentAlignment = Alignment.Center
        ) {
            Box(
                modifier = GlanceModifier
                    .size(56.dp)
                    .background(accentColor)
                    .cornerRadius(16.dp)
                    .clickable(actionStartActivity<MainActivity>(context, Uri.parse("homeWidget://record"))),
                contentAlignment = Alignment.Center
            ) {
                Image(
                    provider = ImageProvider(R.drawable.ic_input_add),
                    contentDescription = null,
                    colorFilter = ColorFilter.tint(ColorProvider(Color.White))
                )
            }
        }
    }

    @Composable
    private fun WideLayout(context: Context, surfaceColor: Color, accentColor: Color) {
        Column(modifier = GlanceModifier.fillMaxSize().padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            QuickRecordBar(context, surfaceColor)
        }
    }

    @Composable
    private fun LargeDashboard(context: Context, prefs: android.content.SharedPreferences, surfaceColor: Color, accentColor: Color) {
        val balance = prefs.getString("total_balance", "0") ?: "0"
        val income = prefs.getString("total_income", "0") ?: "0"
        val spend = prefs.getString("total_spend", "0") ?: "0"
        val currency = prefs.getString("currency", "VND") ?: "VND"

        Column(modifier = GlanceModifier.fillMaxSize().padding(16.dp)) {
            // Header Tag
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(GlanceModifier.size(10.dp, 4.dp).background(accentColor).cornerRadius(2.dp)) {}
                Spacer(GlanceModifier.width(6.dp))
                Text("WALLET AI", style = TextStyle(fontSize = 10.sp, fontWeight = FontWeight.Bold, color = ColorProvider(Color.Gray)))
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