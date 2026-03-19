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

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            GlanceContent(context, currentState())
        }
    }

    @Composable
    private fun GlanceContent(context: Context, currentState: HomeWidgetGlanceState) {
        val prefs = currentState.preferences
        val title = prefs.getString("title", "Wallet AI") ?: "Wallet AI"

        // Background: Using a slightly off-white/light-gray for a premium feel
        val backgroundColor = Color(0xFFF8F9FA)
        val inputFieldColor = Color(0xFFEEEEEE)
        val accentColor = Color(0xFF6200EE) // Primary theme color

        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(backgroundColor)
                .appWidgetBackground()
                .cornerRadius(24.dp) // Modern deep rounded corners
                .padding(16.dp),
            horizontalAlignment = Alignment.Start, // Left-aligned looks more native
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Header: Small, subtle, and clean
            Row(
                modifier = GlanceModifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = GlanceModifier
                        .size(8.dp)
                        .background(accentColor)
                        .cornerRadius(4.dp)
                ) {}
                Spacer(modifier = GlanceModifier.width(8.dp))
                Text(
                    text = title.uppercase(),
                    style = TextStyle(
                        fontSize = 11.sp, 
                        fontWeight = FontWeight.Bold,
                        color = ColorProvider(Color.Gray)
                    )
                )
            }

            Spacer(modifier = GlanceModifier.height(12.dp))

            // The "Input Field": Redesigned for a "Pill" look
            Row(
                modifier = GlanceModifier
                    .fillMaxWidth()
                    .height(54.dp) // Slightly taller for better touch target
                    .background(inputFieldColor)
                    .cornerRadius(27.dp) // Perfect Pill shape (Height / 2)
                    .padding(horizontal = 16.dp)
                    .clickable(
                        actionStartActivity<MainActivity>(
                            context,
                            Uri.parse("homeWidget://record")
                        )
                    ),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Image(
                    provider = ImageProvider(R.drawable.ic_input_add), // "+" icon looks cleaner for "new record"
                    contentDescription = "Add",
                    modifier = GlanceModifier.size(20.dp),
                    colorFilter = ColorFilter.tint(ColorProvider(Color.DarkGray))
                )

                Spacer(modifier = GlanceModifier.width(12.dp))

                Text(
                    text = "Quick Record...",
                    style = TextStyle(
                        fontSize = 15.sp,
                        color = ColorProvider(Color(0xFF666666))
                    )
                )
                
                Spacer(modifier = GlanceModifier.defaultWeight())
                
                // Mic icon to suggest voice/quick action
                Image(
                    provider = ImageProvider(R.drawable.ic_btn_speak_now),
                    contentDescription = "Voice",
                    modifier = GlanceModifier.size(18.dp),
                    colorFilter = ColorFilter.tint(ColorProvider(Color.LightGray))
                )
            }
        }
    }
}