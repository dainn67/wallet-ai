package com.example.wallet_ai

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.*
import androidx.glance.appwidget.*
import androidx.glance.layout.*
import androidx.glance.text.*
import androidx.compose.ui.unit.DpSize
import androidx.glance.unit.ColorProvider
import android.net.Uri
import androidx.glance.appwidget.cornerRadius
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.actionStartActivity
import android.R 
import androidx.glance.action.clickable
import com.example.wallet_ai.MainActivity

class AppWidget : GlanceAppWidget() {
    override val stateDefinition = HomeWidgetGlanceStateDefinition()

    // Define standard responsive sizes for Glance to match against
    companion object {
        private val TINY = DpSize(60.dp, 60.dp)      // 1x1
        private val WIDE = DpSize(150.dp, 60.dp)     // 2x1
        private val TALL = DpSize(60.dp, 150.dp)     // 1x2
        private val SQUARE = DpSize(150.dp, 150.dp)   // 2x2
        private val FULL = DpSize(300.dp, 300.dp)     // 4x4
    }

    override val sizeMode = SizeMode.Responsive(setOf(TINY, WIDE, TALL, SQUARE, FULL))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            GlanceContent(context, currentState())
        }
    }

    @Composable
    private fun GlanceContent(context: Context, currentState: HomeWidgetGlanceState) {
        val size = LocalSize.current
        val prefs = currentState.preferences
        val title = prefs.getString("title", "Wallet AI") ?: "Wallet AI"

        // Layout Thresholds: Roughly based on standard Android launcher cell sizes (approx 70-80dp per cell)
        val isNarrow = size.width <= 110.dp  // Fits 1x1, 1x2, 1x3, 1x4
        val isShort = size.height <= 110.dp  // Fits 2x1, 3x1, 4x1

        // Background / Color Palette
        val backgroundColor = Color(0xFFF8F9FA)
        val inputFieldColor = Color(0xFFEEEEEE)
        val accentColor = Color(0xFF6200EE)

        when {
            // Case A: 1-column wide (1x1, 1x2, 1x3, 1x4) -> Always show the quick-add icon
            isNarrow -> SmallLayout(context, accentColor)
            
            // Case B: 2+ columns wide, but only 1-row tall (2x1, 4x1, etc.) -> Show the search bar banner
            isShort -> MediumLayout(context, title, backgroundColor, inputFieldColor, accentColor)
            
            // Case C: 2+ columns wide and 2+ rows tall (2x2, 2x4, 4x4, etc.) -> Show the stats dashboard
            else -> LargeLayout(context, title, backgroundColor, inputFieldColor, accentColor, currentState)
        }
    }

    @Composable
    private fun SmallLayout(context: Context, accentColor: Color) {
        // 1x1: Simple "Add" Icon Button
        Box(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(accentColor)
                .appWidgetBackground()
                .cornerRadius(24.dp)
                .clickable(actionStartActivity<MainActivity>(context, Uri.parse("homeWidget://record"))),
            contentAlignment = Alignment.Center
        ) {
            Image(
                provider = ImageProvider(R.drawable.ic_input_add),
                contentDescription = "Add",
                modifier = GlanceModifier.size(32.dp),
                colorFilter = ColorFilter.tint(ColorProvider(Color.White))
            )
        }
    }

    @Composable
    private fun MediumLayout(
        context: Context, 
        title: String, 
        backgroundColor: Color, 
        inputFieldColor: Color, 
        accentColor: Color
    ) {
        // 2x1+: Current Pill Search Bar
        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(backgroundColor)
                .appWidgetBackground()
                .cornerRadius(24.dp)
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            SearchBar(context, inputFieldColor, accentColor)
        }
    }

    @Composable
    private fun LargeLayout(
        context: Context, 
        title: String, 
        backgroundColor: Color, 
        inputFieldColor: Color, 
        accentColor: Color,
        currentState: HomeWidgetGlanceState
    ) {
        // 2x2 or 2x4: Header + Stats + Search Bar
        val totalBalance = currentState.preferences.getString("total_balance", "VND 0") ?: "VND 0"
        val income = currentState.preferences.getString("total_income", "0") ?: "0"
        val spend = currentState.preferences.getString("total_spend", "0") ?: "0"

        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(backgroundColor)
                .appWidgetBackground()
                .cornerRadius(28.dp)
                .padding(16.dp)
        ) {
            // Header
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(GlanceModifier.size(8.dp).background(accentColor).cornerRadius(4.dp)) {}
                Spacer(GlanceModifier.width(8.dp))
                Text(title.uppercase(), style = TextStyle(fontSize = 11.sp, fontWeight = FontWeight.Bold, color = ColorProvider(Color.Gray)))
            }

            Spacer(GlanceModifier.defaultWeight())

            // Balanced Overview
            Text("Total Balance", style = TextStyle(fontSize = 12.sp, color = ColorProvider(Color.Gray)))
            Text(totalBalance, style = TextStyle(fontSize = 24.sp, fontWeight = FontWeight.Bold, color = ColorProvider(Color.Black)))
            
            Spacer(GlanceModifier.height(8.dp))

            Row(modifier = GlanceModifier.fillMaxWidth()) {
                Column(modifier = GlanceModifier.defaultWeight()) {
                    Text("Income", style = TextStyle(fontSize = 10.sp, color = ColorProvider(Color.Gray)))
                    Text("+ $income", style = TextStyle(fontSize = 14.sp, color = ColorProvider(Color(0xFF4CAF50)), fontWeight = FontWeight.Bold))
                }
                Column(modifier = GlanceModifier.defaultWeight()) {
                    Text("Spent", style = TextStyle(fontSize = 10.sp, color = ColorProvider(Color.Gray)))
                    Text("- $spend", style = TextStyle(fontSize = 14.sp, color = ColorProvider(Color(0xFFF44336)), fontWeight = FontWeight.Bold))
                }
            }

            Spacer(GlanceModifier.defaultWeight())

            // Search Bar at the bottom
            SearchBar(context, inputFieldColor, accentColor)
        }
    }

    @Composable
    private fun SearchBar(context: Context, inputFieldColor: Color, accentColor: Color) {
        Row(
            modifier = GlanceModifier
                .fillMaxWidth()
                .height(48.dp)
                .background(inputFieldColor)
                .cornerRadius(24.dp)
                .padding(horizontal = 16.dp)
                .clickable(actionStartActivity<MainActivity>(context, Uri.parse("homeWidget://record"))),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Image(
                provider = ImageProvider(R.drawable.ic_input_add),
                contentDescription = "Add",
                modifier = GlanceModifier.size(20.dp),
                colorFilter = ColorFilter.tint(ColorProvider(Color.DarkGray))
            )
            Spacer(GlanceModifier.width(12.dp))
            Text("Quick Record...", style = TextStyle(fontSize = 14.sp, color = ColorProvider(Color(0xFF666666))))
        }
    }
}